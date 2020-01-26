cd C:\appl\repos\dotfiles
git pull

copy ".\startup\keybinds.ahk" "%USERPROFILE%\Start Menu\Programs\Startup" /Y

copy ".\startup\profile.ps1" "C:\Windows\System32\WindowsPowerShell\v1.0\Profile.ps1" /Y
copy ".\startup\profiles.json" "%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\profiles.json" /Y

#PowerShell -Command "Set-ExecutionPolicy RemoteSigned"
PowerShell -Command "& {c:\appl\repos\dotfiles\startup\start.ps1}"


exit