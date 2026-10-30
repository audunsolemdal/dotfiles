# Copy-Item ./startup/raw/profile.ps1 $PROFILE.CurrentUserAllHosts

$DotfilesRoot = "C:\appl\repos\personal\dotfiles"

# Default folder
$env:HOME = "C:\Appl"
# HOME override makes oh-my-posh look for C:\Appl\.azure; az CLI uses USERPROFILE
$env:AZURE_CONFIG_DIR = "$env:USERPROFILE\.azure"

if (($env:PATH -split ';') -notcontains "C:\appl") {
    $env:PATH += ";C:\appl"
}

# Hold control to skip import of modules, credit @VladimirReshetnikov
Add-Type -AssemblyName System.Windows.Forms
if (-not ([System.Windows.Forms.Control]::ModifierKeys -band [System.Windows.Forms.Keys]::Control)) {
    oh-my-posh init pwsh --config "$DotfilesRoot\startup\oh-my-posh\agnoster-customized.json" | Invoke-Expression

    # Terminal-Icons only affects Get-ChildItem formatting and takes ~0.7s to import,
    # so load it once the prompt is idle instead of blocking startup
    $null = Register-EngineEvent -SourceIdentifier PowerShell.OnIdle -MaxTriggerCount 1 -Action {
        Import-Module Terminal-Icons -Global
    }
}

# Native CLI tab completion. Completer scripts are generated into a cache on first <Tab>
# (and again whenever the executable is updated), so they add nothing to startup time.
$CompletionCommands = @{
    kubectl = "completion", "powershell"
    helm    = "completion", "powershell"
    flux    = "completion", "powershell"
    gh      = "completion", "-s", "powershell"
}
$CompletionBlocks = @{}

function Get-CachedCompleter([string]$Command) {
    if ($CompletionBlocks.ContainsKey($Command)) { return $CompletionBlocks[$Command] }

    $exe = Get-Command $Command -CommandType Application -ErrorAction Ignore | Select-Object -First 1
    if (-not $exe) { return }

    $cacheDir = Join-Path $env:LOCALAPPDATA "pwsh-completions"
    $cache = Join-Path $cacheDir "$Command.ps1"
    if (-not (Test-Path $cache) -or (Get-Item $cache).LastWriteTime -lt (Get-Item $exe.Source).LastWriteTime) {
        $null = New-Item -ItemType Directory -Path $cacheDir -Force
        # Helper functions must be global, since the script is dot-sourced inside this function
        & $exe.Source @($CompletionCommands[$Command]) 2>$null |
        ForEach-Object { $_ -replace '^(\s*)(function|filter) (?!global:)', '$1$2 global:' } |
        Set-Content -Path $cache -Encoding utf8
    }

    . $cache
    $CompletionBlocks[$Command] = Get-Variable -Name "__${Command}CompleterBlock" -ValueOnly -ErrorAction Ignore
    $CompletionBlocks[$Command]
}

Register-ArgumentCompleter -Native -CommandName ([string[]]$CompletionCommands.Keys + "k", "he") -ScriptBlock {
    param($wordToComplete, $commandAst, $cursorPosition)
    $name = $commandAst.GetCommandName()
    if ($alias = Get-Alias $name -ErrorAction Ignore) { $name = $alias.Definition }
    if ($block = Get-CachedCompleter ([IO.Path]::GetFileNameWithoutExtension($name))) {
        & $block $wordToComplete $commandAst $cursorPosition
    }
}

$PSDefaultParameterValues["Out-Default:OutVariable"] = "__" # $__ = last output
if ($Host.Name -eq "ConsoleHost" -and $Host.UI.SupportsVirtualTerminal -and -not [Console]::IsOutputRedirected -and (Get-Command Set-PSReadLineOption -ErrorAction Ignore)) {
    Set-PSReadLineOption -PredictionSource HistoryAndPlugin -HistoryNoDuplicates -HistorySearchCursorMovesToEnd
    # Up/Down only walk history entries that start with what is already typed
    Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
    Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
}

# Alias

Set-Alias grep Select-String
Set-Alias d docker
Set-Alias doc docker-compose
Set-Alias k kubectl.exe
Set-Alias he helm.exe
Set-Alias which Get-Command

# Bash functionality

function touch {
    param (
        [Parameter(Mandatory, ValueFromRemainingArguments)]
        [string[]] $Path
    )
    foreach ($p in $Path) {
        if (Test-Path -LiteralPath $p) {
            (Get-Item -LiteralPath $p).LastWriteTime = Get-Date
        }
        else {
            $null = New-Item -ItemType File -Path $p
        }
    }
}

function WingetRun {
    param (
        [string]$packageName
    )
    
    Start-Process microsoft-edge:https://winget.run/search?query=$packageName 
}

# Azure handy

function azp {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, Position = 0)][ValidateNotNullOrEmpty()][string] $Subscription
    )

    $accounts = az account list --all -o json
    if ($LASTEXITCODE -ne 0) { throw "Could not read subscriptions. Run 'az login'." }
    $matches = @($accounts | ConvertFrom-Json | Where-Object { $_.name -eq $Subscription -or $_.id -eq $Subscription })
    if ($matches.Count -ne 1) { throw "Expected one subscription matching '$Subscription'; found $($matches.Count). Use a subscription ID if the name is ambiguous." }
    $sub = $matches[0]
    if (-not $sub.tenantId -or -not $sub.id) { throw 'Subscription context is missing its tenant or subscription ID.' }
    $tenant = [uri]::EscapeDataString($sub.tenantId)
    $id = [uri]::EscapeDataString($sub.id)
    Start-Process "microsoft-edge:https://portal.azure.com/#@$tenant/resource/subscriptions/$id/resourceGroups"
}

# Containers

# Resolve the namespace of a deployment (or the namespace itself) matching $Name.
# Refuses to guess when several namespaces match, since callers scale everything in it.
function Get-KDeploymentNamespace {
    param (
        [Parameter(Mandatory)][string] $Name
    )
    $namespaces = @(kubectl get deployments --all-namespaces --no-headers -o 'custom-columns=NS:.metadata.namespace,NAME:.metadata.name' |
        Where-Object { $_ -like "*$Name*" } |
        ForEach-Object { ($_ -split '\s+')[0] } |
        Select-Object -Unique)

    if ($namespaces -contains $Name) { return $Name }
    if ($namespaces.Count -eq 1) { return $namespaces[0] }
    if ($namespaces.Count -eq 0) {
        Write-Warning "No deployment or namespace matching '$Name'."
    }
    else {
        Write-Warning "'$Name' matches several namespaces: $($namespaces -join ', '). Be more specific."
    }
}

function KUp($name) {
    if ($n = Get-KDeploymentNamespace $name) {
        kubectl scale deployments -n $n --replicas=1 --all
    }
}

function KDown($name) {
    if ($n = Get-KDeploymentNamespace $name) {
        kubectl scale deployments -n $n --replicas=0 --all
    }
}

# Rolling restart keeps the current replica count and avoids downtime
function KRe($name) {
    if ($n = Get-KDeploymentNamespace $name) {
        kubectl rollout restart deployments -n $n
    }
}

function KNs {
    param (
        [Parameter(Mandatory)][string] $Namespace
    )
    $con = kubectl config current-context
    # set-context succeeds for any name, so check the namespace exists first
    kubectl get namespace $Namespace -o name *> $null
    if ($LASTEXITCODE -ne 0) {
        Write-Warning "Namespace '$Namespace' not found in $con."
        return
    }

    kubectl config set-context --current --namespace=$Namespace | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Currently at " -NoNewline -ForegroundColor Yellow
        Write-Host $Namespace -ForegroundColor Cyan -NoNewline
        Write-Host " namespace in " -ForegroundColor Yellow -NoNewline
        Write-Host $con -ForegroundColor Green -NoNewline
        Write-Host " cluster" -ForegroundColor Yellow
    }
}

function Get-KNamespaceName {
    # Run detached with a hard timeout: auth plugins (kubelogin) can block forever waiting
    # for an interactive login, which would freeze tab completion
    $psi = [System.Diagnostics.ProcessStartInfo]::new((Get-Command kubectl -CommandType Application -ErrorAction Stop | Select-Object -First 1).Source)
    'get', 'namespaces', '--no-headers', '-o', 'custom-columns=NAME:.metadata.name', '--request-timeout=5s' |
    ForEach-Object { $psi.ArgumentList.Add($_) }
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.RedirectStandardInput = $true
    $psi.CreateNoWindow = $true
    $p = [System.Diagnostics.Process]::Start($psi)
    $p.StandardInput.Close()
    $p.StandardError.ReadToEndAsync() | Out-Null
    $out = $p.StandardOutput.ReadToEndAsync()
    if (-not $p.WaitForExit(6000)) {
        $p.Kill($true)
        return
    }
    $out.Result -split "`r?`n" | Where-Object { $_ }
}

Register-ArgumentCompleter -CommandName KNs -ParameterName Namespace -ScriptBlock {
    param($commandName, $parameterName, $wordToComplete)
    Get-KNamespaceName | Where-Object { $_ -like "$wordToComplete*" }
}

# kubectx/kubens ship no PowerShell completion
Register-ArgumentCompleter -Native -CommandName kubectx, kubens -ScriptBlock {
    param($wordToComplete, $commandAst, $cursorPosition)
    $names = if ($commandAst.GetCommandName() -match 'kubens') {
        Get-KNamespaceName
    }
    else {
        kubectl config get-contexts -o name 2>$null
    }
    $names | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}

function dup() {
    [CmdletBinding()]
    param (
        [string] $name
    )
    docker-compose up $name -d
}

Set-Alias doup dup

function ddown() {
    [CmdletBinding()]
    param (
        [string] $name
    )
    docker-compose down $name
}

# Prefer bash, fall back to sh for minimal images
function kexec {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory, Position = 0)][string] $Pod,
        [Parameter(Position = 1)][string] $Namespace
    )
    $nsArgs = if ($Namespace) { "-n", $Namespace } else { @() }
    kubectl exec -it @nsArgs $Pod -- sh -c 'command -v bash >/dev/null 2>&1 && exec bash || exec sh'
}

function FSync() {
    flux reconcile kustomization flux-system --with-source
}

# General bash-style aliases

function New-BashStyleAlias([string]$name, [string]$command) {
    $sb = [scriptblock]::Create($command)
    New-Item "Function:\global:$name" -Value $sb -Force | Out-Null
}

# Quick Folder movement
New-BashStyleAlias .. 'cd ..'
New-BashStyleAlias ... "cd ../../"
New-BashStyleAlias .... "cd ../../../"
New-BashStyleAlias ..... "cd ../../../../"
New-BashStyleAlias cl 'cd $$' # cd to last argument of previous command

# Git commands
New-BashStyleAlias log "git log --oneline"
New-BashStyleAlias gdiff "git diff"
New-BashStyleAlias branch "git branch -a"
New-BashStyleAlias status "git status"
New-BashStyleAlias stash "git stash"
New-BashStyleAlias pop "git stash pop"
New-BashStyleAlias fetch "git fetch"
New-BashStyleAlias push "git push origin HEAD"
New-BashStyleAlias pull "git pull"
New-BashStyleAlias recent "git for-each-ref --sort -committerdate refs/heads/"
New-BashStyleAlias glog "git log --graph --pretty --oneline --abbrev-commit --decorate"

# CD to Specific folders
New-BashStyleAlias home 'cd ~'
New-BashStyleAlias appl 'cd c:/appl'
New-BashStyleAlias repos 'cd c:/appl/repos'
New-BashStyleAlias path 'cd c:/appl/path'
New-BashStyleAlias certs 'cd c:/appl/certs'
New-BashStyleAlias dotfiles "cd $DotfilesRoot"

# paths

New-BashStyleAlias mdir 'cd c:/appl/repos/miljodir/iac'
New-BashStyleAlias adb 'cd c:/appl/repos/adb'

New-BashStyleAlias waf 'cd c:/appl/repos/miljodir/iac/cp-ne1waf'
New-BashStyleAlias net 'cd c:/appl/repos/miljodir/iac/cp-ne1net'
New-BashStyleAlias ygg 'cd c:/appl/repos/miljodir/iac/cp-yggdrasil'
New-BashStyleAlias aks 'cd c:/appl/repos/miljodir/iac/cp-aks'

# Speical commands

New-BashStyleAlias prev "Get-Content (Get-PSReadlineOption).HistorySavePath"

function Authenticate-Databricks {
    $env:DATABRICKS_AAD_TOKEN = az account get-access-token --resource 2ff814a6-3304-4ab8-85cb-cd0e6f879c1d --query accessToken -o tsv
    databricks configure --host https://xxx.azuredatabricks.net --aad-token --jobs-api-version 2.1
}

# Activate an eligible PIM role (default MAP Admin Contributor) separately for each subscription.
# Every activation requires an interactive step-up sign-in (Conditional Access authentication context).
function pim {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory, Position = 0)][ValidateNotNullOrEmpty()][string[]] $Subscription,
        [string] $Role = 'MAP Admin Contributor',
        [ValidateRange(1, 24)][int] $Hours = 4,
        [string] $Justification = 'Activated via powershell function call',
        [string] $AuthContext = 'c1'
    )

    $activationParameters = @{} + $PSBoundParameters
    foreach ($item in $Subscription) {
        $activationParameters.Subscription = $item
        Invoke-SubscriptionPimActivation @activationParameters
    }
}

function Invoke-SubscriptionPimActivation {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory, Position = 0)][string] $Subscription,
        [string] $Role = 'MAP Admin Contributor',
        [ValidateRange(1, 24)][int] $Hours = 4,
        [string] $Justification = 'Activated via powershell function call',
        # Authentication context ID required by the PIM activation policy
        [string] $AuthContext = 'c1'
    )

    $sub = az account list --all --query "[?name=='$Subscription' || id=='$Subscription'] | [0]" -o json | ConvertFrom-Json
    if (-not $sub) {
        Write-Warning "Subscription '$Subscription' not found. Run 'az account list --all' or 'az login'."
        return
    }

    # Regular (non-elevated) token: only used to read eligibilities and identify the user
    $getToken = {
        $t = az account get-access-token --tenant $sub.tenantId --query accessToken -o tsv
        if ($LASTEXITCODE -ne 0 -or -not $t) { throw "Could not get an ARM token from az. Run 'az login'." }
        $t
    }
    $token = & $getToken
    $claims = $token.Split('.')[1].Replace('-', '+').Replace('_', '/')
    $claims = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($claims.PadRight($claims.Length + (4 - $claims.Length % 4) % 4, '='))) | ConvertFrom-Json
    $headers = @{ Authorization = "Bearer $token" }
    $arm = 'https://management.azure.com'

    $eligible = @((Invoke-RestMethod -Headers $headers "$arm/providers/Microsoft.Authorization/roleEligibilityScheduleInstances?api-version=2020-10-01&`$filter=asTarget()").value.properties |
        Where-Object { $_.expandedProperties.roleDefinition.displayName -eq $Role })
    # Eligibility is inherited from a management group/root; the API rejects it if it doesn't cover the subscription
    $eligibility = $eligible | Where-Object scope -NotLike '/subscriptions/*' | Select-Object -First 1
    if (-not $eligibility) {
        $where = ($eligible.expandedProperties.scope.displayName | Sort-Object -Unique) -join ', '
        Write-Warning "No '$Role' eligibility covering '$($sub.name)'. Eligible at: $(if ($where) { $where } else { 'nothing' })"
        return
    }

    $scope = "/subscriptions/$($sub.id)"
    $body = @{
        properties = @{
            principalId                     = $claims.oid
            roleDefinitionId                = "$scope/providers/Microsoft.Authorization/roleDefinitions/$(Split-Path $eligibility.roleDefinitionId -Leaf)"
            requestType                     = 'SelfActivate'
            linkedRoleEligibilityScheduleId = $eligibility.roleEligibilityScheduleId
            justification                   = $Justification
            scheduleInfo                    = @{ expiration = @{ type = 'AfterDuration'; duration = "PT${Hours}H" } }
        }
    } | ConvertTo-Json -Depth 5

    if (-not $PSCmdlet.ShouldProcess($sub.name, "Activate '$Role' for $Hours h")) { return }

    $stepUp = Get-PimInteractiveToken -Account $sub -PrincipalId $claims.oid -AuthContext $AuthContext
    $uri = "$arm$scope/providers/Microsoft.Authorization/roleAssignmentScheduleRequests/$([guid]::NewGuid())?api-version=2020-10-01"
    try {
        $res = Invoke-RestMethod -Method Put -Headers @{ Authorization = "Bearer $stepUp" } -Uri $uri -Body $body -ContentType 'application/json'
    }
    catch {
        $err = ($_.ErrorDetails.Message | ConvertFrom-Json -ErrorAction Ignore).error
        if ($err.code -eq 'RoleAssignmentExists') {
            Write-Host "'$Role' is already active on $($sub.name)" -ForegroundColor DarkGray
            return
        }
        throw "PIM activation failed: $(if ($err) { "$($err.code): $($err.message)" } else { $_ })"
    }
    finally {
        $stepUp = $null
    }
    Write-Host "'$Role' on " -NoNewline
    Write-Host $sub.name -ForegroundColor Green -NoNewline
    Write-Host " for $Hours h: $($res.properties.status)" -ForegroundColor Yellow
}

# Elevated tokens stay in memory and are never added to the Azure CLI token cache.
function Get-PimInteractiveToken {
    param (
        [Parameter(Mandatory)] $Account,
        [Parameter(Mandatory)][string] $PrincipalId,
        [string] $AuthContext = 'c1',
        [string] $ClientId = '04b07795-8ddb-461a-bbee-02f9e1bf7b46',
        [string] $Scopes = 'https://management.core.windows.net//.default openid profile'
    )

    $claimsRequest = @{ access_token = @{ acrs = @{ essential = $true; value = $AuthContext } } } | ConvertTo-Json -Depth 3 -Compress
    $b64url = { param($bytes) [Convert]::ToBase64String($bytes).TrimEnd('=').Replace('+', '-').Replace('/', '_') }
    $verifier = & $b64url ([Security.Cryptography.RandomNumberGenerator]::GetBytes(32))
    $state = [guid]::NewGuid().ToString('N')
    $nonce = [guid]::NewGuid().ToString('N')
    $tcp = [Net.Sockets.TcpListener]::new([Net.IPAddress]::Loopback, 0); $tcp.Start(); $port = $tcp.LocalEndpoint.Port; $tcp.Stop()
    $redirect = "http://localhost:$port/"
    $authority = "https://login.microsoftonline.com/$($Account.tenantId)/oauth2/v2.0"
    $query = [ordered]@{
        client_id             = $clientId
        response_type         = 'code'
        redirect_uri          = $redirect
        scope                 = $scopes
        state                 = $state
        nonce                 = $nonce
        code_challenge        = & $b64url ([Security.Cryptography.SHA256]::HashData([Text.Encoding]::ASCII.GetBytes($verifier)))
        code_challenge_method = 'S256'
        claims                = $claimsRequest
        login_hint            = $Account.user.name
        prompt                = 'login'
    }
    $authorizeUrl = "$authority/authorize?" + (($query.GetEnumerator() | ForEach-Object { "$($_.Key)=$([uri]::EscapeDataString($_.Value))" }) -join '&')

    $listener = [Net.HttpListener]::new()
    $listener.Prefixes.Add($redirect)
    try {
        $listener.Start()
        Write-Host "Step-up sign-in for PIM: complete sign-in and any required MFA in the browser..." -ForegroundColor Yellow
        Start-Process $authorizeUrl
        $pending = $listener.GetContextAsync()
        $deadline = (Get-Date).AddMinutes(5)
        while (-not $pending.Wait(500)) {
            if ((Get-Date) -gt $deadline) { throw "Step-up sign-in timed out." }
        }
        $ctx = $pending.Result
        $reply = [ordered]@{}
        $ctx.Request.Url.Query.TrimStart('?') -split '&' | Where-Object { $_ } | ForEach-Object {
            $k, $v = $_ -split '=', 2; $reply[$k] = [uri]::UnescapeDataString("$v".Replace('+', ' '))
        }
        $page = [Text.Encoding]::UTF8.GetBytes("<html><body style='font-family:sans-serif'><h3>PIM sign-in $(if ($reply.code) { 'complete' } else { 'failed' }). You can close this tab.</h3></body></html>")
        $ctx.Response.ContentType = 'text/html'
        $ctx.Response.OutputStream.Write($page, 0, $page.Length)
        $ctx.Response.Close()
    }
    finally {
        $listener.Close()
    }
    if ($reply.state -ne $state) { throw "Step-up sign-in returned an unexpected state. Aborting." }
    if (-not $reply.code) { throw "Step-up sign-in failed: $($reply.error) $($reply.error_description)" }
    $tokenResponse = Invoke-RestMethod -Method Post -Uri "$authority/token" -ErrorAction Stop -Body @{
            client_id     = $clientId
            grant_type    = 'authorization_code'
            code          = $reply.code
            redirect_uri  = $redirect
            code_verifier = $verifier
            scope         = $scopes
        }
    if (-not $tokenResponse.access_token -or -not $tokenResponse.id_token) { throw 'Sign-in did not return the required tokens.' }

    # Graph access tokens can be opaque; identify the user using the OIDC ID token instead.
    $p = $tokenResponse.id_token.Split('.')[1].Replace('-', '+').Replace('_', '/')
    $stepUpClaims = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($p.PadRight($p.Length + (4 - $p.Length % 4) % 4, '='))) | ConvertFrom-Json
    if ($stepUpClaims.oid -ne $PrincipalId -or $stepUpClaims.tid -ne $Account.tenantId -or
        $stepUpClaims.aud -ne $ClientId -or $stepUpClaims.nonce -ne $nonce -or
        $stepUpClaims.exp -le [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()) {
        throw 'Step-up sign-in returned an unexpected identity or invalid ID token. Aborting.'
    }
    $tokenResponse.access_token
}

Register-ArgumentCompleter -CommandName pim, azp -ParameterName Subscription -ScriptBlock {
    param($commandName, $parameterName, $wordToComplete)
    az account list --all --query '[].name' -o tsv 2>$null | Where-Object { $_ -like "$wordToComplete*" } |
    ForEach-Object { if ($_ -match '\s') { "'$_'" } else { $_ } }
}

function pim-group {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory, Position = 0)][ValidateNotNullOrEmpty()][guid[]] $GroupId,
        [Parameter(Mandatory, Position = 1)][ValidateSet('member', 'owner')][string] $Role,
        [ValidateRange(1, 24)][int] $Hours = 4,
        [ValidateNotNullOrEmpty()][string] $Justification = 'Activated via powershell function call',
        [guid] $TenantId,
        [string] $AuthContext = 'c1',
        # Microsoft Graph PowerShell public client; can be overridden with a tenant-approved public client.
        [guid] $ClientId = '14d82eec-204b-4c2f-b7e8-296a70dab67e'
    )
    $activationParameters = @{} + $PSBoundParameters
    foreach ($item in $GroupId) {
        $activationParameters.GroupId = $item
        Invoke-GraphPimActivation -Kind Group @activationParameters
    }
}

function pim-entra {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory, Position = 0)][ValidateNotNullOrEmpty()][string] $Role,
        [ValidateRange(1, 24)][int] $Hours = 4,
        [ValidateNotNullOrEmpty()][string] $Justification = 'Activated via powershell function call',
        [guid] $TenantId,
        [string] $DirectoryScopeId,
        [string] $AuthContext = 'c1',
        [guid] $ClientId = '14d82eec-204b-4c2f-b7e8-296a70dab67e'
    )
    Invoke-GraphPimActivation -Kind Entra @PSBoundParameters
}

function Invoke-GraphPimActivation {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [ValidateSet('Group', 'Entra')][string] $Kind,
        [string] $Role,
        [guid] $GroupId,
        [int] $Hours = 4,
        [string] $Justification = 'Activated via powershell function call',
        [guid] $TenantId,
        [string] $DirectoryScopeId,
        [string] $AuthContext = 'c1',
        [guid] $ClientId = '14d82eec-204b-4c2f-b7e8-296a70dab67e'
    )

    $accountJson = az account show -o json
    if ($LASTEXITCODE -ne 0) { throw "Could not read Azure CLI context. Run 'az login'." }
    $account = $accountJson | ConvertFrom-Json
    if ($TenantId -and $TenantId -ne [guid]::Empty) { $account.tenantId = $TenantId.ToString() }
    if (-not $account.tenantId) { throw 'Azure CLI context has no tenant ID.' }
    $target = if ($Kind -eq 'Group') { "$GroupId ($Role)" } else { "$Role ($($account.tenantId))" }
    if (-not $PSCmdlet.ShouldProcess($target, "Request PIM activation for $Hours h")) { return }

    # Use az only to identify the signed-in user, never to obtain the elevated Graph token.
    $identityToken = az account get-access-token --tenant $account.tenantId --query accessToken -o tsv
    if ($LASTEXITCODE -ne 0 -or -not $identityToken) { throw "Could not identify the user. Run 'az login' for the target tenant." }
    $payload = $identityToken.Split('.')[1].Replace('-', '+').Replace('_', '/')
    $identity = [Text.Encoding]::UTF8.GetString([Convert]::FromBase64String($payload.PadRight($payload.Length + (4 - $payload.Length % 4) % 4, '='))) | ConvertFrom-Json
    if (-not $identity.oid -or $identity.tid -ne $account.tenantId -or $identity.idtyp -eq 'app') {
        throw 'PIM self-activation requires a signed-in user in the target tenant.'
    }

    $graph = 'https://graph.microsoft.com/v1.0'
    $path, $permissions = if ($Kind -eq 'Group') {
        'identityGovernance/privilegedAccess/group', 'PrivilegedEligibilitySchedule.Read.AzureADGroup PrivilegedAssignmentSchedule.ReadWrite.AzureADGroup'
    }
    else {
        'roleManagement/directory', 'RoleEligibilitySchedule.Read.Directory RoleAssignmentSchedule.ReadWrite.Directory'
    }
    $scopes = (($permissions -split ' ' | ForEach-Object { "https://graph.microsoft.com/$_" }) -join ' ') + ' openid profile'
    $token = $null
    $headers = $null
    try {
        $token = Get-PimInteractiveToken -Account $account -PrincipalId $identity.oid -AuthContext $AuthContext -ClientId $ClientId -Scopes $scopes
        $headers = @{ Authorization = "Bearer $token" }
        $collection = if ($Kind -eq 'Group') { 'eligibilityScheduleInstances' } else { 'roleEligibilityScheduleInstances' }
        $filter = [uri]::EscapeDataString("principalId eq '$($identity.oid)'")
        $uri = "$graph/$path/${collection}?`$filter=$filter"
        if ($Kind -eq 'Entra') { $uri += '&$expand=roleDefinition' }
        $eligible = @(
            do {
                if (-not $uri.StartsWith("$graph/", [StringComparison]::Ordinal)) { throw 'Unexpected Graph pagination URL.' }
                $page = Invoke-RestMethod -Headers $headers -Uri $uri -ErrorAction Stop
                $page.value
                $uri = $page.'@odata.nextLink'
            } while ($uri)
        )
        $matches = @($eligible | Where-Object {
            $_.principalId -eq $identity.oid -and
            (($Kind -eq 'Group' -and $_.groupId -eq $GroupId.ToString() -and $_.accessId -eq $Role) -or
            ($Kind -eq 'Entra' -and ($_.roleDefinition.displayName -eq $Role -or $_.roleDefinitionId -eq $Role) -and
            (-not $DirectoryScopeId -or $_.directoryScopeId -eq $DirectoryScopeId)))
        })
        if ($matches.Count -ne 1) {
            throw "Expected one eligible assignment for '$Role'; found $($matches.Count). Check the role/group and tenant; use -DirectoryScopeId to disambiguate scoped Entra roles."
        }
        $eligibility = $matches[0]
        $body = @{
            action = 'selfActivate'
            principalId = $identity.oid
            justification = $Justification
            scheduleInfo = @{
                startDateTime = [DateTime]::UtcNow.ToString('o')
                expiration = @{ type = 'afterDuration'; duration = "PT${Hours}H" }
            }
        }
        if ($Kind -eq 'Group') {
            $body.groupId = $eligibility.groupId
            $body.accessId = $eligibility.accessId
            $requests = 'assignmentScheduleRequests'
        }
        else {
            $body.roleDefinitionId = $eligibility.roleDefinitionId
            if ($eligibility.directoryScopeId) { $body.directoryScopeId = $eligibility.directoryScopeId }
            elseif ($eligibility.appScopeId) { $body.appScopeId = $eligibility.appScopeId }
            else { throw 'Eligible Entra role has no scope. Aborting.' }
            $requests = 'roleAssignmentScheduleRequests'
        }
        $result = Invoke-RestMethod -Method Post -Headers $headers -Uri "$graph/$path/$requests" -Body ($body | ConvertTo-Json -Depth 5) -ContentType 'application/json' -ErrorAction Stop
        Write-Host "PIM request for '$Role' for $Hours h: $($result.status)" -ForegroundColor Yellow
    }
    finally {
        $token = $null
        $headers = $null
    }
}

function gcom() {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = "Default", Position = 0)]
        [string] $message
    )
    git commit -m $message
}

set-alias gcmon gcom
set-alias com gcom

function gadd() {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = "Default", Position = 0)]
        [string] $name
    )
    git add $name
    git status
}

set-alias add gadd

function gaddcom() {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = "Default", Position = 0)]
        [string] $Name,
        [Parameter(Mandatory = $true, ParameterSetName = "Default", Position = 1)]
        [string] $Message
    )
    git add $Name
    git commit -m $Message
    git --no-pager log --pretty=oneline -n3 --oneline
}

set-alias acom gaddcom

# Reset the current branch to its origin counterpart (soft by default)
function reset() {
    [CmdletBinding()]
    param (
        [Parameter(ParameterSetName = "Mode", Position = 0)]
        [ValidateSet("soft", "mixed", "hard", "merge", "keep")]
        $Mode = "soft"
    )
    $branch = (git rev-parse --abbrev-ref HEAD)
    git reset --$Mode origin/$branch
    git restore --staged .
    " `r`n "
    git --no-pager log --pretty=oneline -n3 --oneline
    " `r`n "
    status
}

function merge() {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = "Default", Position = 0)]
        [string] $Name
    )
    git merge $Name
}

function clone() {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = "Default", Position = 0)]
        [string] $Name
    )
    git clone $Name
}

function ghrun {
    [CmdletBinding()]
    param ()

    $now = [DateTimeOffset]::UtcNow
    # Filter server-side; paginating every run takes minutes in busy repos
    $since = $now.AddMinutes(-2).ToString('yyyy-MM-ddTHH:mm:ssZ', [cultureinfo]::InvariantCulture)
    $response = gh api "repos/{owner}/{repo}/actions/runs?per_page=100&created=%3E%3D$since"
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to list workflow runs with gh."
    }

    $run = ($response | ConvertFrom-Json).workflow_runs |
    Where-Object {
        $_.run_started_at -and
        [DateTimeOffset]$_.run_started_at -ge $now.AddMinutes(-2) -and
        [DateTimeOffset]$_.run_started_at -le $now -and
        "$($_.name) $($_.path)" -notmatch 'codeql|copilot.*review'
    } |
    Sort-Object { [DateTimeOffset]$_.run_started_at } -Descending |
    Select-Object -First 1

    if (-not $run) {
        Write-Warning "No matching workflow started within the last two minutes."
        return
    }

    gh run view $run.id --web
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to open workflow run $($run.id) with gh."
    }
}

# Let a team bypass the repo's "Default branch: ..." rulesets. -Web opens them in the browser instead.
function ghrule {
    [CmdletBinding(SupportsShouldProcess)]
    param (
        [string] $Team = 'aks-admins',
        [ValidateSet('always', 'pull_request', 'exempt')]
        [string] $BypassMode = 'always',
        [switch] $Web
    )

    $pages = gh api 'repos/{owner}/{repo}/rulesets?includes_parents=false&per_page=100' --paginate --slurp
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to list repository rulesets with gh."
    }

    $rulesets = @($pages | ConvertFrom-Json | ForEach-Object { $_ } |
        Where-Object { $_.target -eq 'branch' -and $_.name -like 'Default branch:*' })

    if ($rulesets.Count -eq 0) {
        Write-Warning "No repository branch rulesets named 'Default branch: ...' were found."
        return
    }

    if ($Web) {
        $repoUrl = gh repo view --json url --jq .url
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to resolve the repository URL with gh."
        }

        foreach ($ruleset in $rulesets) {
            Start-Process "$repoUrl/settings/rules/$($ruleset.id)" -ErrorAction Stop
        }
        return
    }

    $teamId = gh api "orgs/{owner}/teams/$Team" --jq .id
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to look up team '$Team' in the repository owner's organization."
    }
    $teamId = [long]$teamId

    foreach ($ruleset in $rulesets) {
        $full = gh api "repos/{owner}/{repo}/rulesets/$($ruleset.id)" | ConvertFrom-Json
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to read ruleset $($ruleset.id) with gh."
        }

        $isTeam = { $_.actor_type -eq 'Team' -and $_.actor_id -eq $teamId }
        $current = @($full.bypass_actors | Where-Object $isTeam)
        if ($current.Count -and $current[0].bypass_mode -eq $BypassMode) {
            Write-Host "'$($full.name)': $Team already bypasses ($BypassMode)" -ForegroundColor DarkGray
            continue
        }

        $actors = @($full.bypass_actors | Where-Object { -not (& $isTeam) }) +
        [pscustomobject]@{ actor_id = $teamId; actor_type = 'Team'; bypass_mode = $BypassMode }

        if ($PSCmdlet.ShouldProcess($full.name, "Allow team '$Team' to bypass ($BypassMode)")) {
            @{ bypass_actors = $actors } | ConvertTo-Json -Depth 5 -Compress |
            gh api -X PUT "repos/{owner}/{repo}/rulesets/$($ruleset.id)" --input - --silent
            if ($LASTEXITCODE -ne 0) {
                throw "Failed to update ruleset '$($full.name)'."
            }
            Write-Host "'$($full.name)': $Team can now bypass ($BypassMode)" -ForegroundColor Green
        }
    }
}

# Open current repo and branch on Github
function remote() {
    [CmdletBinding()]
    param (
        [switch] $Repo,
        [switch] $LastCommit
    )

    # Normalise SSH remotes (git@host:owner/repo.git, ssh://git@host/...) to https
    $url = (git remote get-url origin) -replace '^ssh://git@', 'https://' -replace '^git@([^:]+):', 'https://$1/' -replace '\.git$', ''
    if (-not $url) { return }

    $branch = git rev-parse --abbrev-ref HEAD
    $urls = @()
    if ($Repo) { $urls += "$url/tree/$branch" }
    $urls += "$url/commits/$branch"
    if ($LastCommit) { $urls += "$url/commit/$(git rev-parse HEAD)" }

    $urls | ForEach-Object { Start-Process $_ }
}

## Git branch switching
New-BashStyleAlias master "git checkout master"
New-BashStyleAlias main "git checkout main"
New-BashStyleAlias mainp "git checkout main && pull"
New-BashStyleAlias prod "git checkout production"
New-BashStyleAlias prodp "git checkout production && pull"
New-BashStyleAlias dev "git checkout dev"
New-BashStyleAlias production "git checkout production"
New-BashStyleAlias development "git checkout development"

# Others ($env:HOME is overridden above, so use USERPROFILE instead of ~)
New-BashStyleAlias editgit 'code "$env:USERPROFILE\.gitconfig"'
New-BashStyleAlias editbash 'code "$env:USERPROFILE\.bashrc"'
New-BashStyleAlias editzsh 'code "$env:USERPROFILE\.zshrc"'
New-BashStyleAlias editba 'code "$env:USERPROFILE\.bash_aliases"'
New-BashStyleAlias editprofile 'code $PROFILE.CurrentUserAllHosts'
New-BashStyleAlias np "cmd.exe /c notepad"

#Testing / remote inspiration
# "Some functions copied from github users @devblackops @scrthq and @timsneath

# Find out if the current user identity is elevated (has admin rights)

$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal $identity
$isAdmin = $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)


$Host.UI.RawUI.WindowTitle = "PowerShell {0}" -f $PSVersionTable.PSVersion.Major.ToString()
if ($isAdmin) {
    $Host.UI.RawUI.WindowTitle += " [ADMIN]"
}

function dirs {
    if ($args.Count -gt 0) {
        Get-ChildItem -Recurse -Include "$args" | Foreach-Object FullName
    }
    else {
        Get-ChildItem -Recurse | Foreach-Object FullName
    }
}

# Copy the previous command's output ($__) to the clipboard without re-running it
function cc {
    ($global:__ | Out-String).Trim() | Set-Clipboard
}

# Forward docker and docker-compose to a dockerd running in WSL (no Docker Desktop).
# Only wired up when there is no native docker CLI and a WSL distro is registered;
# the WSL IP is resolved on first use instead of on every shell start.
if ((Get-ChildItem "HKCU:\Software\Microsoft\Windows\CurrentVersion\Lxss" -ErrorAction Ignore) -and
    -not (Get-Command docker.exe -CommandType Application -ErrorAction Ignore)) {

    function Get-WslDockerHost {
        if (-not $env:DOCKER_HOST) {
            $ip = "$(wsl hostname -I)".Trim().Split(" ")[0]
            if (-not $ip) { throw "Could not resolve the WSL IP address." }
            $env:DOCKER_HOST = "tcp://${ip}:2375"
        }
        $env:DOCKER_HOST
    }

    function dockerd { wsl sudo dockerd -H (Get-WslDockerHost) }
    function pkill { wsl sudo pkill $args }
    function docker-compose { wsl docker-compose -H (Get-WslDockerHost) $args }
    function docker { wsl docker -H (Get-WslDockerHost) $args }
}

function close {
    # Map each PID to its parent in one query, then walk up from this shell
    $parentOf = @{}
    Get-CimInstance Win32_Process -Property ProcessId, ParentProcessId |
    ForEach-Object { $parentOf[[uint32]$_.ProcessId] = [uint32]$_.ParentProcessId }

    $keep = [System.Collections.Generic.HashSet[uint32]]::new()
    $cur = [uint32]$PID
    while ($cur -and $keep.Add($cur)) { $cur = $parentOf[$cur] }

    # Close Explorer folder windows directly; Explorer itself is left running
    (New-Object -ComObject Shell.Application).Windows() | ForEach-Object { $_.Quit() }

    $targets = Get-Process | Where-Object {
        $_.MainWindowHandle -ne 0 -and -not $keep.Contains([uint32]$_.Id) -and $_.ProcessName -ne 'explorer'
    }
    $targets | Stop-Process -Force -ErrorAction SilentlyContinue
}
