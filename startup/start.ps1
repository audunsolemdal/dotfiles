#Declare URLs, then open URLs in chrome

$urls = @(
    "https://youtube.com"
    "https://portal.azure.com"
    "https://google.com"
    "https://github.com/equinor/sdp-aks"
    "https://github.com/equinor/sdp-flux"
    "https://git.equinor.com"

)

Start-Process "firefox.exe" $urls

# Bypass UAC admin prompts for the scripts duration
Set-ItemProperty -Path REGISTRY::HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Policies\System -Name ConsentPromptBehaviorAdmin -Value 0 

# Open Termnials + vscode
Start-Process "wsl" -Verb RunAs
Start-Process "powershell" -Verb RunAs 
Start-Process "code" -Verb RunAs
Start-Process shell:appsFolder\Microsoft.WindowsTerminal_8wekyb3d8bbwe!App -Verb RunAs # Windows Terminal

# Re-enable UAC prompts (use value "1" for max validation)
Set-ItemProperty -Path REGISTRY::HKEY_LOCAL_MACHINE\Software\Microsoft\Windows\CurrentVersion\Policies\System -Name ConsentPromptBehaviorAdmin -Value 2