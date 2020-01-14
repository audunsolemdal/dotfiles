; Default state of lock keys
SetNumlockState, AlwaysOn
;SetCapsLockState, AlwaysOff
SetScrollLockState, AlwaysOff
return

; Suspend AutoHotKey
CapsLock & p::Suspend ; 
return

; Always on Top
^SPACE:: Winset, Alwaysontop, , A ; ctrl + space
Return

; Google Search highlighted text
CapsLock & e::
{
    Send, ^c
    Sleep 50
    Run, http://www.google.com/search?q=%clipboard%
    Return
}

; Rebind useless key to braces
+|::
{
    Send, {RAlt Down}{7}{RAlt Up} 
    Send, {RAlt Down}{0}{RAlt Up}
    return
}


; Scroll tab forward (chrome) 
CapsLock & WheelDown::
{
    Send ^{Tab}
    sleep 50
    return
}

; Scroll tab back (chrome)
CapsLock & WheelUp::
{
    Send, ^+{Tab}
    sleep 50
    return
}


; Save time on ssh commands
IfWinActive, Adminstrator: Windows Powershell
{
::ssh::ssh -l auls 
return
}

; Cleanup for calculators
#c::
if WinExist("Kalkulator") || if WinExist("Calculator")
{
    WinActivate  ; Automatically uses the window found above.
    Send, {Escape}
    Send, {Enter}
    return
}
else 
{
   ; Run, calc.exe
    return
}

#n::
if WinExist("Untitled - Notepad") || if WinExist("*Untitled - Notepad")
{
    WinActivate  ; Automatically uses the window found above.
    Send, {Enter}
    Send, {Enter}
    return
}
else 
{
    Run, notepad.exe
    return
}

; Unused F keys

; Launch VSCODE and create .md file for notes. alternative to notepad
F4::Run, %userprofile%\AppData\Local\Programs\Microsoft VS Code\Code.exe "c:/appl/notes/%A_DD%-%A_MM%-%A_YYYY%.md", max
return
; Launch Slack
F7::Run "%userprofile%\AppData\Local\slack\slack.exe"
return

; Launch Outlook
F8::Run "%programfiles%\Microsoft Office\root\Office16\OUTLOOK.EXE"
return