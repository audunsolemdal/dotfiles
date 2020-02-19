cd C:\appl\repos\dotfiles
git pull

copy ".\startup\raw\keybinds.ahk" "%USERPROFILE%\Start Menu\Programs\Startup" /Y
copy ".\startup\raw\windowmanager.ahk" "%USERPROFILE%\Start Menu\Programs\Startup" /Y

copy ".\startup\raw\profile.ps1" "C:\Windows\System32\WindowsPowerShell\v1.0\Profile.ps1" /Y
copy ".\startup\raw\profiles.json" "%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\profiles.json" /Y

exit