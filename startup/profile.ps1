# cp ./startup/profile.ps1 $PSHOME\Profile.ps1 (all users, allhosts)

# Default folder
cd "C:\Appl\repos"

# Critical Modules

Import-Module 'C:\tools\poshgit\dahlbyk-posh-git-9bda399\src\posh-git.psd1'

# Alias

set-alias grep select-string
#Set-Alias doc docker.exe
#Set-Alias dock docker-compose.exe
Set-Alias k kubectl.exe
Set-Alias he helm.exe
#Set-Alias flux fluxctl.exe sync --k8s-fwd-ns flux

# Bash functionality

function TouchFile ($name)
{
    New-Item -Path . -Name $name
}

Set-alias -name touch -Value TouchFile

# Azure handy

function AzLogin()
{
    az login
}

function AzSub()
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

function KubeUp($name)
{
    $m = kubectl get deployments --all-namespaces | Select-String -Pattern $name -SimpleMatch -CaseSensitive | Out-String | %{$_.split(" ")[0]}
    $n = $m.Substring(2)

    kubectl scale deployments -n $n --replicas=1 --all
}

function KubeDown($name)
{
    $m = kubectl get deployments --all-namespaces | Select-String -Pattern $name -SimpleMatch -CaseSensitive | Out-String | %{$_.split(" ")[0]}
    $n = $m.Substring(2)

    kubectl scale deployments -n $n --replicas=0 --all
}

function KubeCon($con)
{
    $o = "sdpaks-$con-k8s"
    kubectl config use-context $o

    if ($?){
    Write-host "Currently in " -NoNewline
    Write-Host $con -ForegroundColor Green -NoNewline
    Write-Host " cluster" -ForegroundColor Yellow
    }
}

function KubeNs($name)
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