cd C:\appl\repos\dotfiles
git pull

copy ".\startup\keybinds.ahk" "%USERPROFILE%\Start Menu\Programs\Startup" /Y

copy ".\startup\raw\profile.ps1" "C:\Program Files\PowerShell\7\Profile.ps1" /Y
copy ".\startup\profiles.json" "%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\profiles.json" /Y

exit