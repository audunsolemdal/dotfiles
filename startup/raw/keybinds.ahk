#Requires AutoHotkey v2.0
#SingleInstance Force

SetCapsLockState "AlwaysOff"
SetScrollLockState "AlwaysOff"

; Suspend AutoHotkey hotkeys
CapsLock & p::Suspend()

; Google Search highlighted text
CapsLock & Space::{
    Send "^c"
    Sleep 50
    Run "https://www.google.com/search?q=" . A_Clipboard
}

; Rebind the pipe key to braces
+|::{
    Send "{RAlt down}7{RAlt up}"
    Send "{RAlt down}0{RAlt up}"
}

; Scroll tabs forward and back
CapsLock & WheelDown::Send "^{Tab}"
CapsLock & WheelUp::Send "^+{Tab}"

#n::{
    if WinExist("Untitled - Notepad") || WinExist("*Untitled - Notepad") {
        WinActivate()
        Send "{Enter 2}"
    } else {
        Run "notepad.exe"
    }
}

; Right Control clicks
RCtrl::Click()

#c::{
    Send "^c"
    ClipWait()
    A_Clipboard := A_Clipboard . ""
}
