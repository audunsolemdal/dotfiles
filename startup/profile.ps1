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

function Global:prompt {
    $colours = @{
        Cyan   = 0, 255, 255
        Green  = 128, 255, 0
        Blue   = 51, 153, 255
        Red    = 255, 0, 0
        White  = 255, 255, 255
        Grey   = 224, 224, 224
        Purple = 178, 102, 204
    }

    function Write-ColourfulString {
        param (
            [String]$Colour = 'None',

            [String]$String,

            [Boolean]$If = $true,

            [Ref]$Length = (Get-Variable LengthRef -Scope 1 -ValueOnly -ErrorAction SilentlyContinue)
        )

        if ($String -and $If) {
            $Length.Value += $String.Length

            if ($Colour -eq 'None') {
                $String
            } else {
                $rgb = $colours[$Colour]

                "{0}[38;2;{1};{2};{3}`m{4}{0}[0m" -f @(
                    ([Char]27)
                    $rgb[0]
                    $rgb[1]
                    $rgb[2]
                    $String
                )
            }
        } else {
            ''
        }
    }

    function Get-VcsRootName {
        $path = $executionContext.SessionState.Path.CurrentLocation
        if ($path.Provider.Name -ne 'FileSystem') {
            return
        }
        $path = Get-Item $path.Path
        while (-not [String]::IsNullOrWhiteSpace($path)) {
            if (Test-Path (Join-Path $path.FullName '.git') -PathType Container) {
                return $path.Name
            } else {
                $path = $path.Parent
            }
        }
    }

    function Get-VcsStatus {
        $gitStatusOutput = (git status -s -b 2>$null) -split '\r?\n'
        if ($gitStatusOutput[0] -match '^## (?<local>[^.]+)(\.{3}(?<remote>\S+))?(?: \[)?(?:ahead (?<ahead>\d+))?(?:, )?(?:behind (?<behind>\d+))?' -or
            $gitStatusOutput[0] -match '^## HEAD \(no branch\)') {

            if (-not $matches['local']) {
                $matches['local'] = git rev-parse --short HEAD
            }

            $status = [PSCustomObject]@{
                RootName      = Get-VcsRootName
                BranchName    = $matches['local']
                AheadBy       = [Int]$matches['ahead']
                BehindBy      = [Int]$matches['behind']

                StagedCount   = 0
                Staged        = [PSCustomObject]@{
                    Added    = 0
                    Deleted  = 0
                    Modified = 0
                }
                UnstagedCount = 0
                Unstaged      = [PSCustomObject]@{
                    Added    = 0
                    Deleted  = 0
                    Modified = 0
                }
                UnmergedCount = 0
            }

            foreach ($entry in $gitStatusOutput) {
                switch -Regex ($entry) {
                    '^[ADM]'        { $status.StagedCount++ }
                    '^A'            { $status.Staged.Added++; break }
                    '^D '           { $status.Staged.Deleted++; break }
                    '^M '           { $status.Staged.Modified++; break }
                    '^( [DM]|\?\?)' { $status.UnstagedCount++ }
                    '^\?\?'         { $status.Unstaged.Added++; break }
                    '^ D'           { $status.Unstaged.Deleted++; break }
                    '^ M'           { $status.Unstaged.Modified++; break }
                    '^UU'           { $status.UnmergedCount++; break }
                }
            }

            $status
        }
    }

    $Path = $executionContext.SessionState.Path.CurrentLocation.Path

    $status = Get-VcsStatus
    $length = 0
    $lengthRef = [Ref]$length
    $prompt = ''
    if ($status) {
        $length += 6
        $prompt = "<{0} [{1} {2}]> " -f @(
            Write-ColourfulString -Colour Green -String $status.RootName
            Write-ColourfulString -Colour Cyan -String $status.BranchName
            -join @(
                Write-ColourfulString -Colour Cyan -String ([Char]8801) -If ($status.BehindBy -eq 0 -and $status.AheadBy -eq 0)
                Write-ColourfulString -Colour Red -String ('{0}{1}' -f ([Char]8595), $status.BehindBy) -If ($status.BehindBy -gt 0)
                Write-ColourfulString -Colour None -String ' ' -If ($status.BehindBy -gt 0 -and $status.AheadBy -gt 0)
                Write-ColourfulString -Colour Green -String ('{0}{1}' -f ([Char]8593), $status.AheadBy) -If ($status.AheadBy -gt 0)
                Write-ColourfulString -Colour Green -String (' +{0} ~{1} -{2}' -f @(
                    $status.Staged.Added
                    $status.Staged.Modified
                    $status.Staged.Deleted
                )) -If ($status.StagedCount -gt 0)
                Write-ColourfulString -Colour White -String ' |' -If ($status.StagedCount -gt 0 -and ($status.UnstagedCount -gt 0 -or $status.UnmergedCount -gt 0))
                Write-ColourfulString -Colour Red -String (' +{0} ~{1} -{2}' -f @(
                    $status.Unstaged.Added
                    $status.Unstaged.Modified
                    $status.Unstaged.Deleted
                )) -If ($status.UnstagedCount -gt 0 -or $status.UnmergedCount -gt 0)
                Write-ColourfulString -Colour Red -String (' !{0}' -f $status.UnmergedCount) -If ($status.UnmergedCount -gt 0)
                Write-ColourfulString -Colour Red -String ' !' -If ($status.UnstagedCount -gt 0 -or $status.UnmergedCount -gt 0)
            )
        )
    }

    $maximumPathLength = $host.UI.RawUI.WindowSize.Width - $length - 22
    if ($Path.Length -gt $maximumPathLength) {
        $Path = '...{0}' -f $Path.Substring($Path.Length - $maximumPathLength, $maximumPathLength)
    }
    $prompt = "{0}[{1}] " -f @(
        $prompt
        Write-ColourfulString -Colour Blue -String $Path
    )

    if ($lastCommand = Get-History -Count 1) {
        $timeTaken = '{0:N2}' -f ($lastCommand.EndExecutionTime - $lastCommand.StartExecutionTime).TotalMilliseconds
        $offset = $host.UI.RawUI.WindowSize.Width - $timeTaken.Length - 4

        $prompt = "{0}{1}[{2}G[{3} ms]" -f @(
            $prompt
            ([Char]27)
            $offset
            Write-ColourfulString -Colour Purple -String $timeTaken
        )

        "`n{0}`n{1}|auls@local> " -f $prompt, ($lastCommand.Id + 1)
    } else {
        "`n{0}`n1|auls@local> " -f $prompt
    }

}