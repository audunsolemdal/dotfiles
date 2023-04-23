# cp ./startup/raw/profile.ps1 $PROFILE.AllUsersAllHosts

# Default folder
$env:HOME = "C:\Appl"

# Hold control to skip import of modules, credit @VladimirReshetnikov
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName PresentationCore
if (-not [Windows.Input.Keyboard]::IsKeyDown([System.Windows.Input.Key]::LeftCtrl)) {
    # Critical Modules
    Import-Module "Terminal-icons"
    Set-PoshPrompt -Theme C:\appl\repos\dotfiles\startup\oh-my-posh\agnoster-customized.json
}

Set-PSReadLineOption -PredictionSource HistoryAndPlugin

# Alias

Set-Alias grep select-string
Set-Alias d docker
Set-Alias doc docker-compose
Set-Alias k kubectl.exe
Set-Alias he helm.exe
New-Alias which get-command

# Bash functionality

function TouchFile ($name) {
    New-Item -Path . -Name $name
}

Set-Alias -name touch -Value TouchFile

# Azure handy

# Containers

function KUp($name) {
    $m = kubectl get deployments --all-namespaces | Select-String -Pattern $name -SimpleMatch -NoEmphasis | Out-String | % { $_.split(" ")[0] }
    $n = $m.Substring(2)

    kubectl scale deployments -n $n --replicas=1 --all
}

function KDown($name) {
    $m = kubectl get deployments --all-namespaces | Select-String -Pattern $name -SimpleMatch -NoEmphasis | Out-String | % { $_.split(" ")[0] }
    $n = $m.Substring(2)

    kubectl scale deployments -n $n --replicas=0 --all
}

function KRe($name) {
    $m = kubectl get deployments --all-namespaces | Select-String -Pattern $name -SimpleMatch -NoEmphasis | Out-String | % { $_.split(" ")[0] }
    $n = $m.Substring(2)

    kubectl scale deployments -n $n --replicas=0 --all
    kubectl scale deployments -n $n --replicas=1 --all
}

function KCon($con) {
    $o = "sdpaks-$con-k8s"
    kubectl config use-context $o

    if ($?) {
        Write-host "Currently in " -NoNewline
        Write-Host $con -ForegroundColor Green -NoNewline
        Write-Host " cluster" -ForegroundColor Yellow
    }
}

function KNs($name) {
    # always returns true.. nneed workaround
    kubectl config set-context --current --namespace=$name
    if ($?) {
        $con = kubectl config current-context  
        Write-host "Currently at " -NoNewline -ForegroundColor Yellow
        Write-Host  $name -ForegroundColor Cyan -NoNewline
        Write-Host " namespace in "  -ForegroundColor Yellow -NoNewline
        Write-Host $con -ForegroundColor Green -NoNewline
        Write-Host " cluster" -ForegroundColor Yellow
    }
}


function dup() {
    [CmdletBinding()]
    param (
        [string] $name
    )
    docker-compose up $name -d
}

Set-Alias doup docup

function ddown() {
    [CmdletBinding()]
    param (
        [string] $name
    )
    docker-compose down $name
}

function kexec() {
    [CmdletBinding()]
    param (
        [string] $name
    )
    try {
        kubectl exec -it $name bash
    }
    catch {
        kubectl exec -it $name sh
    }
}

function FSync() {
    fluxctl.exe sync --k8s-fwd-ns flux
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
New-BashStyleAlias cl "cd $$" # cd to last argument of previous folder

# Git commands
New-BashStyleAlias log "git log --oneline"
New-BashStyleAlias gdiff "git diff"
New-BashStyleAlias branch "git branch -a"
New-BashStyleAlias status "git status"
New-BashStyleAlias stash "git stash"
New-BashStyleAlias pop "git stash pop"
New-BashStyleAlias reset "git reset --soft"
New-BashStyleAlias fetch "git fetch"
New-BashStyleAlias push "git push origin head"
New-BashStyleAlias pull "git pull"
New-BashStyleAlias recent "git for-each-ref --sort -committerdate refs/heads/"
New-BashStyleAlias glog "git log --graph --pretty --oneline --abbrev-commit --decorate"

# CD to Specific folders
New-BashStyleAlias home 'cd ~'
New-BashStyleAlias appl 'cd c:/appl'
New-BashStyleAlias repos 'cd c:/appl/repos'
New-BashStyleAlias path 'cd c:/appl/path'
New-BashStyleAlias certs 'cd c:/appl/certs'
New-BashStyleAlias dotfiles 'cd c:/appl/repos/dotfiles'

# Speical commands

New-BashStyleAlias prev "Get-Content (Get-PSReadlineOption).HistorySavePath"

function Authenticate-Databricks {
    $env:DATABRICKS_AAD_TOKEN = (az account get-access-token --resource 2ff814a6-3304-4ab8-85cb-cd0e6f879c1d) | convertfrom-json | Select-Object accessToken -ExpandProperty accessToken
    databricks configure --host https://xxx.azuredatabricks.net --aad-token --jobs-api-version 2.1
}


function reset() {
    [CmdletBinding()]
    param (
        [Parameter(ParameterSetName = "Default", Position = 0)]
        $Mode = "soft"
    )
    $branch = (git rev-parse --abbrev-ref HEAD)
    git reset --$Mode origin/$branch
    git restore --staged .
    status
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

function reset() {
    [CmdletBinding()]
    param (
        [Parameter(ParameterSetName = "Mode", Position = 0)]
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

# Open current repo and branch on Github
function remote() {

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false, ParameterSetName = "Default", Position = 0)]
        [switch] $Repo,
        [Parameter(Mandatory = $false, ParameterSetName = "Default", Position = 1)]
        [switch] $LastCommit
    )

    $rawurl = git remote get-url --all origin

    if ($rawurl -like "*.git") {
        $url = $rawurl.Substring(0, $rawurl.lastIndexOf('.'))

    }
    else {
        $url = $rawurl
    }

    $branch = git rev-parse --abbrev-ref HEAD
    $head = git rev-parse --short HEAD

    if ($Repo) { $1 = "$url/tree/$branch" }
    $2 = "$url/commits/$branch"
    if ($LastCommit) { $3 = "$url/commit/$head" }

    Start-Process chrome.exe $1, $2, $3
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

# Others
New-BashStyleAlias editgit "code %homepath%/.gitconfig" # ~ not working
New-BashStyleAlias editbash "code %homepath%/.bashrc" 
New-BashStyleAlias editzsh "code %homepath%/.zshrc"
New-BashStyleAlias editba "code %homepath%/.bash_aliases"
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

function cc { 
    
    Invoke-History | Set-Clipboard

}

# Forward docker and docker-compose from WSL to Windows. Which exact index needs to be split may vary based on your distro and even local machine.
$ifconfig = wsl ifconfig eth0
$env:DOCKER_HOST = $ifconfig[1].Split(" ")[9]

function dockerd {
    wsl sudo dockerd -H $env:DOCKER_HOST
}

function pkill { wsl sudo pkill $args }

function docker-compose { wsl docker-compose -H $env:DOCKER_HOST $args }
function docker { wsl docker -H $env:DOCKER_HOST $args }

Set-Alias d docker
Set-Alias doc docker-compose