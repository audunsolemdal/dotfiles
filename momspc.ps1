$Privacy = Read-Host -Prompt "`n Do you care about privacy? (Y/n)"
if ([string]::IsNullOrWhiteSpace($Privacy) -Or $Privacy -eq 'Y' -Or $Privacy -eq 'y') {
    Write-Output "`n [ START ] Protecting Privacy"
    $StopWatch = [System.Diagnostics.Stopwatch]::StartNew()
    #Disables Windows Feedback Experience
    Write-Output " [ DOING ] Disabling Windows Feedback Experience program"
    $Advertising = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo"
    If (Test-Path $Advertising) {
        Set-ItemProperty $Advertising Enabled -Value 0 
    }
    #Stops Cortana from being used as part of your Windows Search Function
    Write-Output " [ DOING ] Stopping Cortana from being used as part of your Windows Search Function"
    $Search = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"
    If (Test-Path $Search) {
        Set-ItemProperty $Search AllowCortana -Value 0 
    }
    #Disables Web Search in Start Menu
    Write-Output " [ DOING ] Disabling Bing Search in Start Menu"
    $WebSearch = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"
    Set-ItemProperty "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search" BingSearchEnabled -Value 0 
    If (!(Test-Path $WebSearch)) {
        New-Item $WebSearch
    }
    New-ItemProperty -Path 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search' -Name DisableWebSearch -Type DWORD -Value 1
    Set-ItemProperty $WebSearch DisableWebSearch -Value 1
    #Stops the Windows Feedback Experience from sending anonymous data
    Write-Output " [ DOING ] Stopping the Windows Feedback Experience program"
    $Period = "HKCU:\Software\Microsoft\Siuf\Rules"
    If (!(Test-Path $Period)) { 
        New-Item $Period
    }
    Set-ItemProperty $Period PeriodInNanoSeconds -Value 0 
    #Prevents bloatware applications from returning and removes Start Menu suggestions               
    Write-Output " [ DOING ] Adding Registry key to prevent bloatware apps from returning"
    $registryPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent"
    $registryOEM = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
    If (!(Test-Path $registryPath)) { 
        New-Item $registryPath
    }
    Set-ItemProperty $registryPath DisableWindowsConsumerFeatures -Value 1 
    If (!(Test-Path $registryOEM)) {
        New-Item $registryOEM
    }
    Set-ItemProperty $registryOEM  ContentDeliveryAllowed -Value 0 
    Set-ItemProperty $registryOEM  OemPreInstalledAppsEnabled -Value 0 
    Set-ItemProperty $registryOEM  PreInstalledAppsEnabled -Value 0 
    Set-ItemProperty $registryOEM  PreInstalledAppsEverEnabled -Value 0 
    Set-ItemProperty $registryOEM  SilentInstalledAppsEnabled -Value 0 
    Set-ItemProperty $registryOEM  SystemPaneSuggestionsEnabled -Value 0          
    #Preping mixed Reality Portal for removal    
    Write-Output " [ DOING ] Setting Mixed Reality Portal value to 0 so that you can uninstall it in Settings"
    $Holo = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Holographic"    
    If (Test-Path $Holo) {
        Set-ItemProperty $Holo  FirstRunSucceeded -Value 0 
    }
    #Disables Wi-fi Sense
    Write-Output " [ DOING ] Disabling Wi-Fi Sense"
    $WifiSense1 = "HKLM:\SOFTWARE\Microsoft\PolicyManager\default\WiFi\AllowWiFiHotSpotReporting"
    $WifiSense2 = "HKLM:\SOFTWARE\Microsoft\PolicyManager\default\WiFi\AllowAutoConnectToWiFiSenseHotspots"
    $WifiSense3 = "HKLM:\SOFTWARE\Microsoft\WcmSvc\wifinetworkmanager\config"
    If (!(Test-Path $WifiSense1)) {
        New-Item $WifiSense1
    }
    Set-ItemProperty $WifiSense1  Value -Value 0 
    If (!(Test-Path $WifiSense2)) {
        New-Item $WifiSense2
    }
    Set-ItemProperty $WifiSense2  Value -Value 0 
    Set-ItemProperty $WifiSense3  AutoConnectAllowedOEM -Value 0 
    #Disables live tiles
    Write-Output " [ DOING ] Disabling live tiles"
    $Live = "HKCU:\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\PushNotifications"    
    If (!(Test-Path $Live)) {      
        New-Item $Live
    }
    Set-ItemProperty $Live  NoTileApplicationNotification -Value 0 
    #Turns off Data Collection via the AllowTelemtry key by changing it to 0
    Write-Output " [ DOING ] Turning off Data Collection"
    $DataCollection1 = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection"
    $DataCollection2 = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
    $DataCollection3 = "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Policies\DataCollection"    
    If (Test-Path $DataCollection1) {
        Set-ItemProperty $DataCollection1  AllowTelemetry -Value 0 
    }
    If (Test-Path $DataCollection2) {
        Set-ItemProperty $DataCollection2  AllowTelemetry -Value 0 
    }
    If (Test-Path $DataCollection3) {
        Set-ItemProperty $DataCollection3  AllowTelemetry -Value 0 
    }
    #Disabling Location Tracking
    Write-Output " [ DOING ] Disabling Location Tracking"
    $SensorState = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Sensor\Overrides\{BFA794E4-F964-4FDB-90F6-51056BFE4B44}"
    $LocationConfig = "HKLM:\SYSTEM\CurrentControlSet\Services\lfsvc\Service\Configuration"
    If (!(Test-Path $SensorState)) {
        New-Item $SensorState
    }
    Set-ItemProperty $SensorState SensorPermissionState -Value 0 
    If (!(Test-Path $LocationConfig)) {
        New-Item $LocationConfig
    }
    Set-ItemProperty $LocationConfig Status -Value 0 
    #Disables People icon on Taskbar
    Write-Output " [ DOING ] Disabling People icon on Taskbar"
    $People = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced\People"    
    If (!(Test-Path $People)) {
        New-Item $People
    }
    Set-ItemProperty $People  PeopleBand -Value 0 
    #Disables scheduled tasks that are considered unnecessary 
    Write-Output " [ DOING ] Disabling scheduled tasks"
    Get-ScheduledTask  XblGameSaveTaskLogon | Disable-ScheduledTask
    Get-ScheduledTask  XblGameSaveTask | Disable-ScheduledTask
    Get-ScheduledTask  Consolidator | Disable-ScheduledTask
    Get-ScheduledTask  UsbCeip | Disable-ScheduledTask
    Get-ScheduledTask  DmClient | Disable-ScheduledTask
    Get-ScheduledTask  DmClientOnScenarioDownload | Disable-ScheduledTask
    Write-Output " [ DOING ] Stopping and disabling WAP Push Service"
    #Stop and disable WAP Push Service
    Stop-Service "dmwappushservice"
    Set-Service "dmwappushservice" -StartupType Disabled
    Write-Output " [ DOING ] Stopping and disabling Diagnostics Tracking Service"
    #Disabling the Diagnostics Tracking Service
    Stop-Service "DiagTrack"
    Set-Service "DiagTrack" -StartupType Disabled
    $StopWatch.Stop()
    $StopWatchElapsed = $StopWatch.Elapsed.TotalSeconds
    Write-Output " [ DONE ] Protecting Privacy ... $StopWatchElapsed seconds`n"
}
$WindowsConfig = Read-Host -Prompt "`n Do wish configure Windows? (Y/n)"
if ([string]::IsNullOrWhiteSpace($WindowsConfig) -Or $WindowsConfig -eq 'Y' -Or $WindowsConfig -eq 'y') {
    Write-Output "`n [ DOING ] Setting network category to private"
    Set-NetConnectionProfile -NetworkCategory Private
    Set-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced HideFileExt "0"
    #--- File Explorer Settings ---
    Write-Output "`n [ DOING ] Opens PC to This PC, not quick access"
    Set-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name LaunchTo -Value 1
    Write-Output "`n [ DOING ] Taskbar where window is open for multi-monitor"
    Set-ItemProperty -Path HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced -Name MMTaskbarMode -Value 0
    Write-Output "`n [ DOING ] Enable Quick Access: Recent Files"
    Set-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer -Name ShowRecent -Type DWord -Value 1
    Write-Output "`n [ DOING ] Enable Quick Access: Frequent Folders"
    Set-ItemProperty -Path HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer -Name ShowFrequent -Type DWord -Value 1
    Write-Output "`n [ DOING ] Removing 3D Objects folder"
    Remove-Item -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{0DB7E03F-FC29-4DC6-9020-FF41B59E513A}\'
    # videos
    Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{35286a68-3c57-41a1-bbb1-0eae73d76c95}\PropertyBag' -Name Thispcpolicy "Hide"
    Stop-Process -processName: Explorer -force # This will restart the Explorer service to make this work.
    # music
    Set-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{a0c69a99-21c8-4671-8703-7934162fcf1d}\PropertyBag' -Name Thispcpolicy "Hide"
    Stop-Process -processName: Explorer -force # This will restart the Explorer service to make this work.

}
Write-Output "`n [ START ] Unistall Windows10 Unnecessary and Blotware Apps"
$StopWatch = [System.Diagnostics.Stopwatch]::StartNew()
$AppXApps = @(
    "*Microsoft.BingNews*"
    "*Microsoft.Messaging*"
    "*Microsoft.Microsoft3DViewer*"
    "*Microsoft.MicrosoftOfficeHub*"
    "*Microsoft.MicrosoftSolitaireCollection*"
    "*Microsoft.NetworkSpeedTest*"
    "*Microsoft.Office.Sway*"
    "*Microsoft.OneConnect*"
    "*Microsoft.People*"
    "*Microsoft.Print3D*"
    "*Microsoft.CommsPhone*"
    "*Microsoft.WindowsAlarms*"
    "*Microsoft.WindowsCamera*"
    "*microsoft.windowscommunicationsapps*"
    "*Microsoft.WindowsFeedbackHub*"
    "*Microsoft.WindowsMaps*"
    "*Microsoft.WindowsSoundRecorder*"
    "*Microsoft.Xbox.TCUI*"
    "*Microsoft.XboxApp*"
    "*Microsoft.XboxGameOverlay*"
    "*Microsoft.XboxIdentityProvider*"
    "*Microsoft.XboxSpeechToTextOverlay*"
    "*Microsoft.ZuneMusic*"
    "*Microsoft.People*"
    "*Microsoft.ZuneVideo*"
    #Sponsored Windows 10 AppX Apps
    #Add sponsored/featured apps to remove in the "*AppName*" format
    "*EclipseManager*"
    "*Autodesk*"
    "*BubbleWitch*"
    "*MarchofEmpires*"
    "*McAfee*"
    "*Minecraft*"
    "*Netflix*"
    "*ActiproSoftwareLLC*"
    "*AdobeSystemsIncorporated.AdobePhotoshopExpress*"
    "*Duolingo-LearnLanguagesforFree*"
    "*PandoraMediaInc*"
    "*CandyCrush*"
    "*Wunderlist*"
    "*Flipboard*"
    "*Twitter*"
    "*Facebook*"
    "*Spotify*"
    #Optional: Typically not removed but you can if you need to for some reason
    #"*Microsoft.Advertising.Xaml_10.1712.5.0_x64__8wekyb3d8bbwe*"
    #"*Microsoft.Advertising.Xaml_10.1712.5.0_x86__8wekyb3d8bbwe*"
    #"*Microsoft.BingWeather*"
    #"*Microsoft.MSPaint*"
    #"*Microsoft.MicrosoftStickyNotes*"
    #"*Microsoft.Windows.Photos*"
    #"*Microsoft.WindowsCalculator*"
    #"*Microsoft.WindowsStore*"
)
foreach ($App in $AppXApps) {
    Write-Output " [ DOING ] Removing $App from registry"
    Get-AppxPackage -Name $App | Remove-AppxPackage -ErrorAction SilentlyContinue
    Get-AppxPackage -Name $App -AllUsers | Remove-AppxPackage -AllUsers -ErrorAction SilentlyContinue
    Get-AppxProvisionedPackage -Online | Where-Object DisplayName -like $App | Remove-AppxProvisionedPackage -Online -ErrorAction SilentlyContinue
}
[regex]$WhitelistedApps = 'Microsoft.Paint3D|Microsoft.WindowsCalculator|Microsoft.WindowsStore|Microsoft.Windows.Photos|CanonicalGroupLimited.UbuntuonWindows|Microsoft.XboxGameCallableUI|Microsoft.XboxGamingOverlay|Microsoft.Xbox.TCUI|Microsoft.XboxGamingOverlay|Microsoft.XboxIdentityProvider|Microsoft.MicrosoftStickyNotes|Microsoft.MSPaint*'
Get-AppxPackage -AllUsers | Where-Object { $_.Name -NotMatch $WhitelistedApps } | Remove-AppxPackage
Get-AppxPackage | Where-Object { $_.Name -NotMatch $WhitelistedApps } | Remove-AppxPackage
Get-AppxProvisionedPackage -Online | Where-Object { $_.PackageName -NotMatch $WhitelistedApps } | Remove-AppxProvisionedPackage -Online
$StopWatch.Stop()
$StopWatchElapsed = $StopWatch.Elapsed.TotalSeconds
Write-Output " [ DONE ] Unistall Windows10 Unnecessary and Blotware Apps ... $StopWatchElapsed seconds`n"
Write-Output "`n [ START ] Remove Unnecessary Windows Registries"
$StopWatch = [System.Diagnostics.Stopwatch]::StartNew()

ForEach ($Key in $Keys) {
    Write-Output " [ DOING ] Removing $Key from registry"
    Remove-Item $Key -Recurse
}
$StopWatch.Stop()
$StopWatchElapsed = $StopWatch.Elapsed.TotalSeconds
Write-Output " [ DONE ] Remove Unnecessary Windows Registries ... $StopWatchElapsed seconds`n"