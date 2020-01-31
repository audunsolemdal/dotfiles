# cp ./startup/profile.ps1 $PSHOME\Profile.ps1 (all users, allhosts)

# Default folder
$env:HOME = "C:\Appl"
cd "C:\Appl\repos"

# Critical Modules

Import-Module "Terminal-icons"

# Alias

Set-Alias grep select-string
Set-Alias d docker
Set-Alias doc docker-compose
Set-Alias k kubectl.exe
Set-Alias he helm.exe

# Bash functionality

function TouchFile ($name)
{
    New-Item -Path . -Name $name
}

Set-Alias -name touch -Value TouchFile

# Azure handy

function AzLogin()
{
    az login
}

function Set-AzSub()
{
    az account set --subscription "SDP Tools"
}

function Get-AzRgContent($rgname)
{
    Get-AzResource -ResourceGroupName $rgname
}

function List-AzRg()
{
    Get-AzResourceGroup | select -Property ResourceGroupName
}

function Get-AKSCredentials()
{
    az aks get-credentials -n sdpaks-prod-k8s -g sdpaks-prod
    az aks get-credentials -n sdpaks-dev-k8s -g sdpaks-dev
}

# Containers

function HelmDel($name)
{
    $m = helm ls | Select-String -Pattern $name -SimpleMatch -CaseSensitive | Out-String
    # $n = $m -replace '(^\s+|\s+$)','' -replace '\s+',' ' | %{$_.split(" ")[10]}

    helm del --purge $name
}

function KUp($name)
{
    $m = kubectl get deployments --all-namespaces | Select-String -Pattern $name -SimpleMatch -CaseSensitive | Out-String | %{$_.split(" ")[0]}
    $n = $m.Substring(2)

    kubectl scale deployments -n $n --replicas=1 --all
}

function KDown($name)
{
    $m = kubectl get deployments --all-namespaces | Select-String -Pattern $name -SimpleMatch -CaseSensitive | Out-String | %{$_.split(" ")[0]}
    $n = $m.Substring(2)

    kubectl scale deployments -n $n --replicas=0 --all
}

function KRe($name)
{
    $m = kubectl get deployments --all-namespaces | Select-String -Pattern $name -SimpleMatch -CaseSensitive | Out-String | %{$_.split(" ")[0]}
    $n = $m.Substring(2)

    kubectl scale deployments -n $n --replicas=0 --all
    kubectl scale deployments -n $n --replicas=1 --all
}

function KCon($con)
{
    $o = "sdpaks-$con-k8s"
    kubectl config use-context $o

    if ($?){
    Write-host "Currently in " -NoNewline
    Write-Host $con -ForegroundColor Green -NoNewline
    Write-Host " cluster" -ForegroundColor Yellow
    }
}

function KNs($name)
{
    # always returns true.. nneed workaround
    kubectl config set-context --current --namespace=$name
    if($?) {
    $con = kubectl config current-context  
    Write-host "Currently at " -NoNewline -ForegroundColor Yellow
    Write-Host  $name -ForegroundColor Cyan -NoNewline
    Write-Host " namespace in "  -ForegroundColor Yellow -NoNewline
    Write-Host $con -ForegroundColor Green -NoNewline
    Write-Host " cluster" -ForegroundColor Yellow
    }
}

function doexec(){
    [CmdletBinding()]
    param (
          [string] $name
    )
   try {
       docker exec -it $name bash
   }
   catch {
    docker exec -it $name sh
   }
}


function docup(){
    [CmdletBinding()]
    param (
          [string] $name
    )
       docker-compose up $name -d
}

Set-Alias doup docup

function dops(){
    [CmdletBinding()]
    param (
          [string] $name
    )
       docker ps
}

function docdown(){
    [CmdletBinding()]
    param (
          [string] $name
    )
       docker-compose down $name
}

Set-Alias dodown docdown

function kexec(){
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

function FSync()
{
    fluxctl.exe sync --k8s-fwd-ns flux
}

# General bash-style aliases

function New-BashStyleAlias([string]$name, [string]$command)
{
    $sb = [scriptblock]::Create($command)
    New-Item "Function:\global:$name" -Value $sb | Out-Null
}

# Quick Folder movement
New-BashStyleAlias .. 'cd ..'
New-BashStyleAlias ... "cd ../../"
New-BashStyleAlias .... "cd ../../../"
New-BashStyleAlias ..... "cd ../../../../"

# CD to Specific folders
New-BashStyleAlias home 'cd ~'
New-BashStyleAlias appl 'cd c:/appl'
New-BashStyleAlias repos 'cd c:/appl/repos'
New-BashStyleAlias progs 'cd c:/appl/progs'
New-BashStyleAlias certs 'cd c:/appl/certs'
New-BashStyleAlias dotfiles 'cd c:/appl/repos/dotfiles'
New-BashStyleAlias sdp-flux 'cd c:/appl/repos/sdp-flux'
New-BashStyleAlias sdp-aks 'cd c:/appl/repos/sdp-aks'

Set-Alias flux sdp-flux
Set-Alias aks sdp-aks

# Git commands
New-BashStyleAlias log "git log --oneline"
New-BashStyleAlias gdiff "git diff"
New-BashStyleAlias branch "git branch -a"
New-BashStyleAlias status "git status"
New-BashStyleAlias stash "git stash"
New-BashStyleAlias pop "git pop"
New-BashStyleAlias reset "git reset --soft"
New-BashStyleAlias fetch "git fetch"
New-BashStyleAlias push "git push origin head"
New-BashStyleAlias pull "git pull"
New-BashStyleAlias recent "git for-each-ref --sort -committerdate refs/heads/"
New-BashStyleAlias glog "git log --graph --pretty oneline --abbrev-commit --decorate"

# Speical commands

New-BashStyleAlias prev "Get-Content (Get-PSReadlineOption).HistorySavePath"


function reset(){
    [CmdletBinding()]
    param (
        [Parameter(ParameterSetName="Default", Position=0)]
        $Mode = "soft"
    )
    $branch = (git rev-parse --abbrev-ref HEAD)
    git reset --$Mode origin/$branch
    git restore --staged .
    status
}

function gcom(){
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, ParameterSetName="Default", Position=0)]
          [string] $message
    )
   git commit -m $message
}

set-alias gcmon gcom
set-alias com gcom

function gadd(){
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true, ParameterSetName="Default", Position=0)]
          [string] $name
    )
   git add $name
   git status
}

set-alias add gadd

function gaddcom(){
    [CmdletBinding()]
    param (
          [Parameter(Mandatory=$true, ParameterSetName="Default", Position=0)]
          [string] $Name,
          [Parameter(Mandatory=$true, ParameterSetName="Default", Position=1)]
          [string] $Message
    )
   git add $Name
   git commit -m $Message
   git --no-pager log --pretty=oneline -n3 --oneline
}

set-alias acom gaddcom

function reset(){
    [CmdletBinding()]
    param (
        [Parameter(ParameterSetName="Mode", Position=0)]
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


## Git branch switching
New-BashStyleAlias master "git checkout master"
New-BashStyleAlias prod "git checkout prod"
New-BashStyleAlias dev "git checkout dev"

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
if ($isAdmin)
{
    $Host.UI.RawUI.WindowTitle += " [ADMIN]"
}

function dirs
{
    if ($args.Count -gt 0)
    {
        Get-ChildItem -Recurse -Include "$args" | Foreach-Object FullName
    }
    else
    {
        Get-ChildItem -Recurse | Foreach-Object FullName
    }
}

#prompt: credit @Chris Dent - indented-automation


}