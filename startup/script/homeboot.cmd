cd /d C:\appl\repos\personal\dotfiles
git pull

copy ".\startup\raw\keybinds.ahk" "%USERPROFILE%\Start Menu\Programs\Startup" /Y

pwsh -NoProfile -Command "Copy-Item '.\startup\raw\profile.ps1' $PROFILE.CurrentUserAllHosts -Force"
copy ".\startup\raw\terminal\settings.json" "%LOCALAPPDATA%\Packages\Microsoft.WindowsTerminal_8wekyb3d8bbwe\LocalState\settings.json" /Y

