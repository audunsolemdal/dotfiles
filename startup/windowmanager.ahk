;Startup script for starting up two virtual desktops and placing Windows

; Open apps in work desktop
Run code
WinMaximize
Run chrome.exe google.com portal.azure.com https://github.com/equinor/sdp-flux/tree/dev git.equinor.com https://stackoverflow.com/search?q= youtube.com 
Run powershell.exe
Sleep 2000

Process, Wait, powershell.exe
WinMaximize
Process, Wait, code.exe
WinMaximize


;switch to next virtual desktop
Send ^#{Right}

; Opening apps on communication desktop

Run slack://
run lync.exe
run outlook.exe
Process, Wait, outlook.exe
WinMaximize

Sleep 1000

;switch to default virtual desktop
Send ^#{Left}

Send ^#{Left}
Process, Close, cmd.exe