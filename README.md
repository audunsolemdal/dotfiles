# Changes in this fork

Most changes in the folder ./startup.
If you want to use the startup settings I suggest you fork this repo, make your changes, then run this command:
`cp ./startup/boot.cmd shell:startup`

This will make everything in the startup folder be used at startup.

## PowerShell GitHub helpers

The helpers in `startup/raw/profile.ps1` require an authenticated `gh` CLI and use
its current repository context.

- `ghrun` opens the newest in-progress Actions run whose start time is within the
  last 60 seconds, excluding CodeQL and Copilot review workflows by name or path.
  The start time, not creation time, is used so reruns are handled correctly.
- `ghrule` opens the settings editor for each repository-owned branch ruleset
  whose name starts with `Default branch:`. Inherited organization rulesets are
  excluded. Changes are made and saved manually in the browser.

## Todo

- some kind of sync/deployment of files in this repo to my hosts?
- Window/tile manager
- better sync, YADM?
- sync settings to remote servers
- gitconfig?

Done:

- Personal settings and preferences

- WIP: keybinds.ahk - Global keybinds to stop bad habits, increase productivity
- global powershell profile for productivity 
- windows terminal settings sync
- "autoupdates" via startup script
- bash-like aliases in powershell
- personal aliases for WSL
- Zsh + autosuggestions in wsl (needs verification from scratch install)