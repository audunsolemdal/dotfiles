;Startup script for starting up two virtual desktops and placing Windows
#SingleInstance force

; Open apps in work desktop
Run code
WinMaximize
WinMove, 1920, 0 ; Code on left monitor
Run chrome.exe google.com portal.azure.com https://github.com/equinor/sdp-flux/tree/dev git.equinor.com https://stackoverflow.com/search?q= youtube.com 
WinMove, 3840, 0 ; Chrome on right monitor

; Run wt `; new-tab -p "pwsh" -d C:\appl; new-tab -p "pwsh" -d C:\appl; new-tab -p "Bash"; new-tab -p "Bash"; new-tab -p "Bash"; focus-tab -t 0
WinMove, 0, 0 ; Terminal on laptop screen (left)
Sleep 10000

Process, Wait, code.exe
WinMaximize

;switch to next virtual desktop
Send ^#{Right}

; Opening apps on communication desktop

run outlook.exe
Run slack://
run lync.exe ; Skype for Business
Process, Wait, outlook.exe
WinMaximize

Sleep 9000

;switch to default virtual desktop
Send ^#{Left}

Send ^#{Left}
Process, Close, cmd.exe
Process, Close, conhost.exe