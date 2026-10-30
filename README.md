# Changes in this fork

Most changes in the folder ./startup.
If you want to use the startup settings I suggest you fork this repo, make your changes, then run this command:
`cp ./startup/script/boot.cmd shell:startup`

This will make everything in the startup folder be used at startup.

## PowerShell profile

`startup/raw/profile.ps1` is installed to `$PROFILE.CurrentUserAllHosts` by the boot scripts.

- Hold `Ctrl` while the shell starts to skip oh-my-posh and Terminal-Icons.
- Terminal-Icons is imported once the prompt is idle, so it does not delay startup.
- Tab completion for `kubectl`/`k`, `helm`/`he`, `flux` and `gh` is generated on first
  `<Tab>` and cached in `%LOCALAPPDATA%\pwsh-completions`. The cache refreshes when the
  executable is updated; delete the folder to force a refresh.

### Azure portal and PIM

These helpers require PowerShell 7 and an authenticated Azure CLI. Examples use
placeholders: keep real tenant, subscription, group, and app IDs in local context,
not in this repository.

```powershell
azp 'example-subscription'                  # Exact subscription name or ID; opens resource groups in Edge
pim 'example-subscription'                  # Existing Azure resource-role activation
pim t-tstsp1,t-tstsp2                        # Separate activation per subscription
pim -Subscription $subscriptions            # Or pass a PowerShell array of names/IDs
pim-group -GroupId $groupId -Role member     # Explicit member or owner; no default role
pim-group -GroupId $groupId,$otherGroupId -Role member
pim-entra -Role 'Groups Administrator'       # Exact eligible role name or role-definition ID
pim-entra -Role $roleId -DirectoryScopeId $scopeId -Hours 2 -Justification 'Planned maintenance'
```

`azp` resolves the subscription and tenant from `az account list --all`, refuses
ambiguous names, and does not change the active CLI subscription.

`pim` accepts a PowerShell array of subscription names/IDs, and `pim-group` accepts
an array of group GUIDs. Use comma-separated arguments (not a single quoted
comma-separated string), or pass an array variable. Each target gets its own
activation request, with the same role, duration, and justification.
Within one command invocation, targets with the same tenant and signed-in user
reuse the interactive step-up token. Tokens are held only in a local in-memory
batch cache, cleared on completion or error, and **never reused by a new call**.
Different tenants or users require separate sign-ins; tenant policy can still
require additional MFA. `-WhatIf` and `-Confirm` apply separately to each target.
A terminating error stops the batch; earlier requests are not rolled back.

`pim-group` and `pim-entra` request **self-activation of existing eligibilities**,
not new privileges. Both default to four hours and the justification
`Activated via powershell function call`; the role is mandatory. They use the
current CLI tenant unless `-TenantId` is supplied. Group IDs must be GUIDs;
Entra scope is copied from the eligible assignment, never widened to tenant scope.
Use `-DirectoryScopeId` if the same Entra role is eligible at multiple scopes.
`-WhatIf` previews without opening sign-in or requesting activation.

Every invocation uses an interactive OAuth/PKCE browser sign-in. Elevated tokens
are held only in memory, not persisted in the CLI cache. The existing `pim`
authentication context default (`c1`) also applies to the new helpers; override
`-AuthContext` with the context configured by your tenant's PIM policy.
The new helpers use the Microsoft Graph PowerShell public client by default
(no SDK installation needed); `-ClientId` can select an approved public-client app
with a `http://localhost` redirect URI.

Microsoft Graph delegated permissions and tenant/admin consent are required:

| Helper | Permissions |
| --- | --- |
| `pim-group` | `PrivilegedEligibilitySchedule.Read.AzureADGroup`, `PrivilegedAssignmentSchedule.ReadWrite.AzureADGroup` |
| `pim-entra` | `RoleEligibilitySchedule.Read.Directory`, `RoleAssignmentSchedule.ReadWrite.Directory` |

If consent or client use is blocked, ask your tenant administrator to approve the
client/permissions; these helpers do not change app registrations or grant consent
on your behalf. Tenant policies still govern MFA, approval, activation duration,
and any ticket requirements. Errors are surfaced rather than shortening the
duration or bypassing policy. A returned request status may mean pending approval,
not active access. Subscription/resource-role PIM remains separate from Graph PIM.

Offline regression checks (no login, browser, or real activation):
`Invoke-Pester .\startup\tests\profile.Tests.ps1`.

## PowerShell GitHub helpers

The helpers in `startup/raw/profile.ps1` require an authenticated `gh` CLI and use
its current repository context.

- `ghrun` opens the newest Actions run, regardless of status, whose start time is
  within the last two minutes, excluding CodeQL and Copilot review workflows by name or path.
  The start time, not creation time, is used so reruns are handled correctly.
- `ghrule` opens the settings editor for each repository-owned branch ruleset
  whose name starts with `Default branch:`. Inherited organization rulesets are
  excluded. Changes are made and saved manually in the browser.

## Todo

- some kind of sync/deployment of files in this repo to my hosts?
- Window/tile manager
- better sync, YADM?
- sync settings to remote servers
- gitconfig?

Done:

- Personal settings and preferences

- WIP: keybinds.ahk - Global keybinds to stop bad habits, increase productivity
- global powershell profile for productivity 
- windows terminal settings sync
- "autoupdates" via startup script
- bash-like aliases in powershell
- personal aliases for WSL
- Zsh + autosuggestions in wsl (needs verification from scratch install)