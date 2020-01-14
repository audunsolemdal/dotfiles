IfWinActive, Adminstrator: Windows Powershell
{
::ssh::ssh -l auls 
return
}

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
    Run, calc.exe
    return
}

return

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