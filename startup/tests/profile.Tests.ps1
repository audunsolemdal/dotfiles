BeforeAll {
    $profilePath = Join-Path $PSScriptRoot '..\raw\profile.ps1'
    $tokens = $null
    $parseErrors = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($profilePath, [ref]$tokens, [ref]$parseErrors)
    if ($parseErrors) { throw ($parseErrors.Message -join "`n") }
    # Load only functions: never run profile startup, import modules, or read real Azure context.
    $ast.FindAll({
        param($node)
        $node -is [System.Management.Automation.Language.FunctionDefinitionAst]
    }, $false) | ForEach-Object { . ([scriptblock]::Create($_.Extent.Text)) }
    function az { throw 'Unexpected real Azure CLI call.' }

    $script:tenant = '11111111-1111-4111-8111-111111111111'
    $script:principal = '22222222-2222-4222-8222-222222222222'
    $script:group = '33333333-3333-4333-8333-333333333333'
    $script:roleId = '44444444-4444-4444-8444-444444444444'
    $script:fixtureSubId = '55555555-5555-4555-8555-555555555555'
    $payload = @{ oid = $principal; tid = $tenant } | ConvertTo-Json -Compress
    $script:fakeToken = 'header.' + [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($payload)).TrimEnd('=').Replace('+', '-').Replace('/', '_') + '.signature'
}

Describe 'azp' {
    BeforeEach {
        Mock az {
            $global:LASTEXITCODE = 0
            @(@{ name = "example's subscription"; id = $fixtureSubId; tenantId = $tenant }) | ConvertTo-Json
        }
        Mock Start-Process {}
    }

    It 'opens the exact subscription resource groups in Edge with runtime tenant context' {
        azp "example's subscription"
        Should -Invoke Start-Process -Times 1 -Exactly -ParameterFilter {
            $FilePath -eq "microsoft-edge:https://portal.azure.com/#@$tenant/resource/subscriptions/$fixtureSubId/resourceGroups"
        }
        Should -Invoke az -Times 1 -Exactly
    }

    It 'accepts a subscription ID' {
        azp $fixtureSubId
        Should -Invoke Start-Process -Times 1 -Exactly
    }

    It 'rejects unknown subscriptions' {
        { azp 'missing' } | Should -Throw '*found 0*'
        Should -Invoke Start-Process -Times 0
    }

    It 'rejects ambiguous names' {
        Mock az {
            $global:LASTEXITCODE = 0
            @(@{ name = 'duplicate' }, @{ name = 'duplicate' }) | ConvertTo-Json
        }
        { azp duplicate } | Should -Throw '*found 2*'
        Should -Invoke Start-Process -Times 0
    }

    It 'does not launch a browser after CLI failure' {
        Mock az { $global:LASTEXITCODE = 1 }
        { azp example } | Should -Throw '*az login*'
        Should -Invoke Start-Process -Times 0
    }
}

Describe 'Graph PIM self-activation' {
    BeforeEach {
        Mock az {
            $global:LASTEXITCODE = 0
            if ($args[0] -eq 'account' -and $args[1] -eq 'show') {
                @{ tenantId = $tenant; user = @{ name = 'user@example.invalid' } } | ConvertTo-Json
            }
            else { $fakeToken }
        }
        Mock Get-PimInteractiveToken { 'in-memory-test-token' }
        Mock Start-Process { throw 'Tests must never open a browser.' }
        $script:assignments = @([pscustomobject]@{
            principalId = $principal
            groupId = $group
            accessId = 'member'
            roleDefinitionId = $roleId
            roleDefinition = @{ displayName = 'Groups Administrator' }
            directoryScopeId = '/administrativeUnits/example'
        })
        Mock Invoke-RestMethod {
            if ($Method -eq 'Post') { @{ status = 'PendingApproval' } }
            else { @{ value = $script:assignments } }
        }
    }

    It 'requires explicit roles without invoking mandatory parameter prompts' {
        foreach ($name in 'pim-group', 'pim-entra') {
            $parameter = (Get-Command $name).Parameters.Role
            ($parameter.Attributes | Where-Object { $_ -is [Management.Automation.ParameterAttribute] }).Mandatory | Should -BeTrue
            $parameterAst = $ast.FindAll({
                param($node)
                $node -is [Management.Automation.Language.FunctionDefinitionAst] -and $node.Name -eq $name
            }, $false)[0].Body.ParamBlock.Parameters | Where-Object { $_.Name.VariablePath.UserPath -eq 'Role' }
            $parameterAst.DefaultValue | Should -BeNullOrEmpty
        }
    }

    It 'requests group membership with the four-hour and justification defaults' {
        pim-group $group member
        Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
            if ($Method -ne 'Post') { return $false }
            $bodyObject = $Body | ConvertFrom-Json
            $Method -eq 'Post' -and $Uri -like '*/group/assignmentScheduleRequests' -and
            $bodyObject.action -eq 'selfActivate' -and $bodyObject.accessId -eq 'member' -and
            $bodyObject.groupId -eq $group -and $bodyObject.principalId -eq $principal -and
            $bodyObject.scheduleInfo.expiration.duration -eq 'PT4H' -and
            $bodyObject.justification -eq 'Activated via powershell function call' -and
            $Headers.Authorization -eq 'Bearer in-memory-test-token'
        }
        Should -Invoke Get-PimInteractiveToken -Times 1 -ParameterFilter {
            $Scopes -like '*PrivilegedEligibilitySchedule.Read.AzureADGroup*' -and
            $Scopes -like '*PrivilegedAssignmentSchedule.ReadWrite.AzureADGroup*' -and $AuthContext -eq 'c1'
        }
    }

    It 'supports explicit group ownership' {
        $script:assignments[0].accessId = 'owner'
        pim-group $group owner
        Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter {
            $Method -eq 'Post' -and ($Body | ConvertFrom-Json).accessId -eq 'owner'
        }
    }

    It 'activates each group separately using <InputForm>' -ForEach @(
        @{ InputForm = 'comma-separated arguments' }
        @{ InputForm = 'an array variable' }
    ) {
        $script:assignments += $script:assignments[0].PSObject.Copy()
        $script:assignments[1].groupId = $fixtureSubId
        if ($InputForm -eq 'comma-separated arguments') {
            pim-group $group,$fixtureSubId member -Hours 2 -Justification 'Batch maintenance' -TenantId $tenant -ClientId $roleId -AuthContext c2
        }
        else {
            $groups = @($group, $fixtureSubId)
            pim-group -GroupId $groups -Role member -Hours 2 -Justification 'Batch maintenance' -TenantId $tenant -ClientId $roleId -AuthContext c2
        }
        foreach ($expectedGroup in $group, $fixtureSubId) {
            Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
                if ($Method -ne 'Post') { return $false }
                $request = $Body | ConvertFrom-Json
                $request.groupId -eq $expectedGroup -and $request.accessId -eq 'member' -and
                $request.scheduleInfo.expiration.duration -eq 'PT2H' -and
                $request.justification -eq 'Batch maintenance'
            }
        }
        Should -Invoke Invoke-RestMethod -Times 2 -Exactly -ParameterFilter { $Method -eq 'Post' }
        Should -Invoke Get-PimInteractiveToken -Times 1 -Exactly -ParameterFilter {
            $Account.tenantId -eq $tenant -and $ClientId -eq $roleId -and $AuthContext -eq 'c2'
        }
    }

    It 'does not sign in or activate any group under batch WhatIf' {
        pim-group $group,$fixtureSubId owner -WhatIf
        Should -Invoke Get-PimInteractiveToken -Times 0
        Should -Invoke Invoke-RestMethod -Times 0
    }

    It 'never reuses a group token in a new call, including after failure' {
        pim-group $group member
        { pim-group $group owner } | Should -Throw '*found 0*'
        pim-group $group member
        Should -Invoke Get-PimInteractiveToken -Times 3 -Exactly
    }

    It 'validates every group ID before starting a batch' {
        { pim-group $group,'not-a-guid' member } | Should -Throw
        Should -Invoke Get-PimInteractiveToken -Times 0
        Should -Invoke Invoke-RestMethod -Times 0
    }

    It 'stops a group batch on an activation failure' {
        Mock Invoke-RestMethod { throw 'Policy or consent denied' }
        { pim-group $group,$fixtureSubId member } | Should -Throw '*Policy or consent denied*'
        Should -Invoke Get-PimInteractiveToken -Times 1 -Exactly
    }

    It 'preserves the Entra eligibility scope and supplied duration and reason' {
        pim-entra 'Groups Administrator' -Hours 2 -Justification 'Planned maintenance'
        Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
            if ($Method -ne 'Post') { return $false }
            $bodyObject = $Body | ConvertFrom-Json
            $Method -eq 'Post' -and $Uri -like '*/directory/roleAssignmentScheduleRequests' -and
            $bodyObject.directoryScopeId -eq '/administrativeUnits/example' -and
            $bodyObject.roleDefinitionId -eq $roleId -and
            $bodyObject.scheduleInfo.expiration.duration -eq 'PT2H' -and
            $bodyObject.justification -eq 'Planned maintenance'
        }
    }

    It 'accepts role-definition IDs and preserves app scopes' {
        $script:assignments[0].directoryScopeId = $null
        $script:assignments[0] | Add-Member appScopeId '/example-app'
        pim-entra $roleId
        Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter {
            $Method -eq 'Post' -and ($Body | ConvertFrom-Json).appScopeId -eq '/example-app'
        }
    }

    It 'rejects absent eligibility without posting a request' {
        { pim-group $group owner } | Should -Throw '*found 0*'
        Should -Invoke Invoke-RestMethod -Times 0 -ParameterFilter { $Method -eq 'Post' }
    }

    It 'refuses ambiguous Entra scopes' {
        $script:assignments += $script:assignments[0].PSObject.Copy()
        $script:assignments[1].directoryScopeId = '/'
        { pim-entra $roleId } | Should -Throw '*found 2*'
        pim-entra $roleId -DirectoryScopeId '/'
        Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter {
            $Method -eq 'Post' -and ($Body | ConvertFrom-Json).directoryScopeId -eq '/'
        }
    }

    It 'follows Graph pagination' {
        Mock Invoke-RestMethod {
            if ($Method -eq 'Post') { @{ status = 'Granted' } }
            elseif ($Uri -like '*page=2') { @{ value = $script:assignments } }
            else { @{ value = @(); '@odata.nextLink' = 'https://graph.microsoft.com/v1.0/example?page=2' } }
        }
        pim-entra $roleId
        Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter { $Uri -like '*page=2' }
        Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter { $Method -eq 'Post' }
    }

    It 'does not forward the token to an unexpected pagination host' {
        Mock Invoke-RestMethod { @{ value = @(); '@odata.nextLink' = 'https://example.invalid/page' } }
        { pim-entra $roleId } | Should -Throw '*pagination URL*'
        Should -Invoke Invoke-RestMethod -Times 1 -Exactly
    }

    It 'does not authenticate or activate under WhatIf' {
        pim-group $group member -WhatIf
        pim-entra $roleId -WhatIf
        Should -Invoke Get-PimInteractiveToken -Times 0
        Should -Invoke Invoke-RestMethod -Times 0
    }

    It 'surfaces API policy and permission failures' {
        Mock Invoke-RestMethod { throw 'Policy or consent denied' }
        { pim-entra $roleId } | Should -Throw '*Policy or consent denied*'
    }

    It 'rejects unsupported group roles and durations' {
        { pim-group $group administrator } | Should -Throw
        { pim-entra $roleId -Hours 0 } | Should -Throw
        { pim-entra $roleId -Hours 25 } | Should -Throw
        Should -Invoke Get-PimInteractiveToken -Times 0
    }

    It 'honors an explicit tenant and approved client' {
        pim-entra $roleId -TenantId $tenant -ClientId $roleId -AuthContext 'c2'
        Should -Invoke Get-PimInteractiveToken -Times 1 -ParameterFilter {
            $Account.tenantId -eq $tenant -and $ClientId -eq $roleId -and $AuthContext -eq 'c2'
        }
    }

    It 'rejects a CLI token for a different tenant before interactive sign-in' {
        $otherPayload = @{ oid = $principal; tid = $group } | ConvertTo-Json -Compress
        $script:otherToken = 'header.' + [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($otherPayload)) + '.signature'
        Mock az {
            $global:LASTEXITCODE = 0
            if ($args[1] -eq 'show') { @{ tenantId = $tenant } | ConvertTo-Json }
            else { $script:otherToken }
        }
        { pim-entra $roleId } | Should -Throw '*target tenant*'
        Should -Invoke Get-PimInteractiveToken -Times 0
    }
}

Describe 'Interactive PIM sign-in' {
    BeforeEach {
        $script:invalidState = $false
        $script:invalidIdentity = $false
        $script:client = [Net.Http.HttpClient]::new()
        Mock Start-Process {
            $script:query = @{}
            ([uri]$FilePath).Query.TrimStart('?') -split '&' | ForEach-Object {
                $key, $value = $_ -split '=', 2
                $script:query[$key] = [uri]::UnescapeDataString($value)
            }
            $callbackState = if ($script:invalidState) { 'wrong-state' } else { $script:query.state }
            # Only a synthetic loopback callback; no browser, Azure, or Graph requests.
            $script:callback = $script:client.GetAsync("$($script:query.redirect_uri)?code=test-code&state=$callbackState")
        }
        Mock Invoke-RestMethod {
            $claims = @{
                oid = if ($script:invalidIdentity) { $group } else { $principal }
                tid = $tenant
                aud = $script:query.client_id
                nonce = $script:query.nonce
                exp = [DateTimeOffset]::UtcNow.AddMinutes(5).ToUnixTimeSeconds()
            } | ConvertTo-Json -Compress
            $idToken = 'header.' + [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($claims)) + '.signature'
            @{ access_token = 'opaque-graph-access-token'; id_token = $idToken }
        }
    }

    AfterEach {
        $script:client.Dispose()
    }

    It 'uses PKCE and an ID token to validate identity without parsing the Graph access token' {
        $result = Get-PimInteractiveToken -Account @{ tenantId = $tenant; user = @{ name = 'user@example.invalid' } } -PrincipalId $principal
        $result | Should -Be 'opaque-graph-access-token'
        $script:query.code_challenge_method | Should -Be 'S256'
        $script:query.prompt | Should -Be 'login'
        Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter {
            $Method -eq 'Post' -and $Body.code -eq 'test-code' -and
            $Body.code_verifier.Length -ge 43 -and $Body.scope -like '*openid profile'
        }
    }

    It 'rejects an incorrect callback state without exchanging the code' {
        $script:invalidState = $true
        { Get-PimInteractiveToken -Account @{ tenantId = $tenant; user = @{} } -PrincipalId $principal } | Should -Throw '*unexpected state*'
        Should -Invoke Invoke-RestMethod -Times 0
    }

    It 'rejects sign-in as a different user' {
        $script:invalidIdentity = $true
        { Get-PimInteractiveToken -Account @{ tenantId = $tenant; user = @{} } -PrincipalId $principal } | Should -Throw '*unexpected identity*'
    }
}

Describe 'Existing Azure resource PIM' {
    BeforeEach {
        Mock az {
            $global:LASTEXITCODE = 0
            if ($args[1] -eq 'list') {
                @{ id = $fixtureSubId; tenantId = $tenant; name = 'example-subscription'; user = @{} } | ConvertTo-Json
            }
            else { $fakeToken }
        }
        Mock Get-PimInteractiveToken { 'in-memory-test-token' }
        Mock Invoke-RestMethod {
            if ($Method -eq 'Put') { @{ properties = @{ status = 'Granted' } } }
            else {
                @{ value = @(@{ properties = @{
                    scope = '/providers/Microsoft.Management/managementGroups/example'
                    roleDefinitionId = "/providers/Microsoft.Authorization/roleDefinitions/$roleId"
                    roleEligibilityScheduleId = 'example-eligibility'
                    expandedProperties = @{ roleDefinition = @{ displayName = 'Example Contributor' } }
                } }) }
            }
        }
    }

    It 'preserves subscription request shape and four-hour duration after extracting sign-in' {
        pim 'example-subscription' -Role 'Example Contributor'
        Should -Invoke Get-PimInteractiveToken -Times 1
        Should -Invoke Invoke-RestMethod -Times 1 -ParameterFilter {
            if ($Method -ne 'Put') { return $false }
            $properties = ($Body | ConvertFrom-Json).properties
            $properties.principalId -eq $principal -and
            $properties.requestType -eq 'SelfActivate' -and
            $properties.scheduleInfo.expiration.duration -eq 'PT4H' -and
            $Uri -like "*/subscriptions/$fixtureSubId/providers/Microsoft.Authorization/roleAssignmentScheduleRequests/*" -and
            $Headers.Authorization -eq 'Bearer in-memory-test-token'
        }
    }

    It 'does not sign in or activate under WhatIf' {
        pim 'example-subscription' -Role 'Example Contributor' -WhatIf
        Should -Invoke Get-PimInteractiveToken -Times 0
        Should -Invoke Invoke-RestMethod -Times 0 -ParameterFilter { $Method -eq 'Put' }
    }

    It 'activates each subscription separately using <InputForm>' -ForEach @(
        @{ InputForm = 'comma-separated arguments' }
        @{ InputForm = 'an array variable' }
    ) {
        Mock az {
            $global:LASTEXITCODE = 0
            if ($args[1] -eq 'list') {
                if (($args -join ' ') -like '*second-subscription*') {
                    @{ id = $group; tenantId = $tenant; name = 'second-subscription'; user = @{} } | ConvertTo-Json
                }
                else {
                    @{ id = $fixtureSubId; tenantId = $tenant; name = 'example-subscription'; user = @{} } | ConvertTo-Json
                }
            }
            else { $fakeToken }
        }
        if ($InputForm -eq 'comma-separated arguments') {
            pim example-subscription,second-subscription -Role 'Example Contributor' -Hours 2 -Justification 'Batch maintenance' -AuthContext c2
        }
        else {
            $subscriptions = @('example-subscription', 'second-subscription')
            pim -Subscription $subscriptions -Role 'Example Contributor' -Hours 2 -Justification 'Batch maintenance' -AuthContext c2
        }
        foreach ($expectedSub in $fixtureSubId, $group) {
            Should -Invoke Invoke-RestMethod -Times 1 -Exactly -ParameterFilter {
                if ($Method -ne 'Put') { return $false }
                $properties = ($Body | ConvertFrom-Json).properties
                $Uri -like "*/subscriptions/$expectedSub/providers/Microsoft.Authorization/roleAssignmentScheduleRequests/*" -and
                $properties.roleDefinitionId -eq "/subscriptions/$expectedSub/providers/Microsoft.Authorization/roleDefinitions/$roleId" -and
                $properties.scheduleInfo.expiration.duration -eq 'PT2H' -and
                $properties.justification -eq 'Batch maintenance'
            }
        }
        Should -Invoke Invoke-RestMethod -Times 2 -Exactly -ParameterFilter { $Method -eq 'Put' }
        Should -Invoke Get-PimInteractiveToken -Times 1 -Exactly -ParameterFilter { $AuthContext -eq 'c2' }
    }

    It 'does not sign in or activate any subscription under batch WhatIf' {
        pim example-subscription,second-subscription -Role 'Example Contributor' -WhatIf
        Should -Invoke Get-PimInteractiveToken -Times 0
        Should -Invoke Invoke-RestMethod -Times 0 -ParameterFilter { $Method -eq 'Put' }
    }

    It 'never reuses a subscription token in a new call' {
        pim example-subscription,second-subscription -Role 'Example Contributor'
        pim example-subscription,second-subscription -Role 'Example Contributor'
        Should -Invoke Get-PimInteractiveToken -Times 2 -Exactly
        Should -Invoke Invoke-RestMethod -Times 4 -Exactly -ParameterFilter { $Method -eq 'Put' }
    }

    It 'signs in separately when the <ChangedContext> changes within a subscription batch' -ForEach @(
        @{ ChangedContext = 'tenant' }
        @{ ChangedContext = 'principal' }
    ) {
        $script:changedContext = $ChangedContext
        $script:lookupCount = 0
        Mock az {
            $global:LASTEXITCODE = 0
            if ($args[1] -eq 'list') {
                $script:lookupCount++
                $accountTenant = if ($script:changedContext -eq 'tenant' -and $script:lookupCount -eq 2) { $group } else { $tenant }
                @{ id = $fixtureSubId; tenantId = $accountTenant; name = "subscription-$script:lookupCount"; user = @{} } | ConvertTo-Json
            }
            else {
                $tokenTenant = if ($script:changedContext -eq 'tenant' -and $script:lookupCount -eq 2) { $group } else { $tenant }
                $tokenPrincipal = if ($script:changedContext -eq 'principal' -and $script:lookupCount -eq 2) { $roleId } else { $principal }
                $payload = @{ oid = $tokenPrincipal; tid = $tokenTenant } | ConvertTo-Json -Compress
                'header.' + [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($payload)) + '.signature'
            }
        }
        pim example-subscription,second-subscription -Role 'Example Contributor'
        Should -Invoke Get-PimInteractiveToken -Times 2 -Exactly
        Should -Invoke Invoke-RestMethod -Times 2 -Exactly -ParameterFilter { $Method -eq 'Put' }
    }

    It 'continues to the next subscription when a role is already active' {
        Mock Invoke-RestMethod {
            if ($Method -eq 'Put') {
                $exception = [Management.Automation.ErrorRecord]::new(
                    [Exception]::new('Already active'), 'RoleAssignmentExists',
                    [Management.Automation.ErrorCategory]::InvalidOperation, $null)
                $exception.ErrorDetails = [Management.Automation.ErrorDetails]::new('{"error":{"code":"RoleAssignmentExists"}}')
                throw $exception
            }

            @{ value = @(@{ properties = @{
                scope = '/providers/Microsoft.Management/managementGroups/example'
                roleDefinitionId = "/providers/Microsoft.Authorization/roleDefinitions/$roleId"
                roleEligibilityScheduleId = 'example-eligibility'
                expandedProperties = @{ roleDefinition = @{ displayName = 'Example Contributor' } }
            } }) }
        }
        pim example-subscription,second-subscription -Role 'Example Contributor'
        Should -Invoke Invoke-RestMethod -Times 2 -Exactly -ParameterFilter { $Method -eq 'Put' }
        Should -Invoke Get-PimInteractiveToken -Times 1 -Exactly
    }

    It 'stops a subscription batch on an activation failure' {
        Mock Get-PimInteractiveToken { throw 'Sign-in failed' }
        { pim example-subscription,second-subscription -Role 'Example Contributor' } | Should -Throw '*Sign-in failed*'
        Should -Invoke Get-PimInteractiveToken -Times 1 -Exactly
        Should -Invoke Invoke-RestMethod -Times 0 -ParameterFilter { $Method -eq 'Put' }
    }
}

Describe 'PIM batch token lifetime' {
    It 'clears the <Command> cache on completion and failure' -ForEach @(
        @{ Command = 'pim'; Helper = 'Invoke-SubscriptionPimActivation'; TargetParameter = 'Subscription'; Target = 'example-subscription' }
        @{ Command = 'pim-group'; Helper = 'Invoke-GraphPimActivation'; TargetParameter = 'GroupId'; Target = '33333333-3333-4333-8333-333333333333' }
    ) {
        $script:failActivation = $false
        Mock $Helper {
            $script:capturedCache = $BatchTokens
            $BatchTokens['test-key'] = 'test-token'
            if ($script:failActivation) { throw 'Activation failed' }
        }
        $parameters = @{ $TargetParameter = $Target; Role = 'member' }
        & $Command @parameters
        $script:capturedCache.Count | Should -Be 0
        $firstCache = $script:capturedCache

        $script:failActivation = $true
        { & $Command @parameters } | Should -Throw '*Activation failed*'
        $script:capturedCache.Count | Should -Be 0
        [object]::ReferenceEquals($firstCache, $script:capturedCache) | Should -BeFalse
    }
}
