#!/bin/bash
PREVIOUS_PWD="$1"
if [ "$(jq -r '.configurations.debug' "${PREVIOUS_PWD}"/bootstrap/unix-settings.json)" == true ]; then
  set +e
else
  set -e
fi
{
  # Get the Git branch
  parse_git_branch() {
    git branch 2>/dev/null | sed -e "/^[^*]/d" -e "s/* \(.*\)/ (\1)/"
  }

# Make Git branch a variable
branch="$(git branch | sed -n -e "s/^\* \(.*\)/\1/p")"

# Git commands
alias log="git log"
alias wut='git log master...${branch} --oneline'
alias diff="git diff"
alias branch="git branch"
alias status="git status"
alias fetch="git fetch"
alias push="git push origin head"
alias pull="git pull"
alias recent="git for-each-ref --sort=-committerdate refs/heads/"
alias branch_new="git for-each-ref --sort=-committerdate refs/heads/ --format=%(refname:short)"
alias gadd="git add -A"
alias gl="git log --graph --pretty=oneline --abbrev-commit --decorate"

## Git branch switching
alias master="git co master"
alias master="git co main"
alias prod="git co prod"
alias dev="git co dev"
alias ghp="git co gh-pages"

# Others
alias editgit="code ~/.gitconfig"
} >>"${HOME}"/./bashrc
