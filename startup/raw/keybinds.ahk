#SingleInstance force

; Default state of lock keys
SetCapsLockState, AlwaysOff
SetScrollLockState, AlwaysOff
return

; Suspend AutoHotKey
CapsLock & p::Suspend ; 
return

; Always on Top
^SPACE:: Winset, Alwaysontop, , A ; ctrl + space
Return

; Google Search highlighted text
CapsLock & Space::
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


; Mouse click with useless key (right ctrl)
RCtrl::
{
    Click
    Return
}