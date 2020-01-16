# cp ./startup/profile.ps1 $PSHOME\Profile.ps1 (all users, allhosts)

# Default folder
cd "C:\Appl\repos"

# Critical Modules

Import-Module 'C:\tools\poshgit\dahlbyk-posh-git-9bda399\src\posh-git.psd1'

# Alias

Set-Alias grep select-string
#Set-Alias doc docker.exe
#Set-Alias dock docker-compose.exe
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
New-BashStyleAlias dotfiles 'cd c:/appl/repos/dotfiles'
New-BashStyleAlias sdp-flux 'cd c:/appl/repos/sdp-flux'
New-BashStyleAlias sdp-aks 'cd c:/appl/repos/sdp-aks'

# Git commands
New-BashStyleAlias log "git log --oneline"
New-BashStyleAlias gdiff "git diff"
New-BashStyleAlias branch "git branch"
New-BashStyleAlias status "git status"
New-BashStyleAlias fetch "git fetch"
New-BashStyleAlias push "git push origin head"
New-BashStyleAlias pull "git pull"
New-BashStyleAlias recent "git for-each-ref --sort -committerdate refs/heads/"
New-BashStyleAlias gadd "git add -A"
New-BashStyleAlias glog "git log --graph --pretty oneline --abbrev-commit --decorate"

function gcom(){
    [CmdletBinding()]
    param (
          [string] $message
    )
   git commit -m $message
}

set-alias gcmon gcom

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

#Testing