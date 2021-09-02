#!/bin/bash
PREVIOUS_PWD="$1"
if [ "$(jq -r ".configurations.debug" "${PREVIOUS_PWD}"/bootstrap/unix-settings.json)" == true ]; then
    set +e
else
    set -e
fi
defaultfolder="$(jq -r ".personal.defaultfolder" "${PREVIOUS_PWD}"/bootstrap/unix-settings.json)"
echo "

# Extra to path
PATH=$PATH:~/path

# Custom functions

# git functions

function com(){
    git commit -m $1
}

function gadd(){
    git add $1
}

function acom(){
    git add $1
    git commit -m $2
}

# ALIASES
# container aliases
alias d="docker"
alias doc="docker-compose"
alias k="kubectl"
#alias fsync ="fluxctl sync --k8s-fwd-ns flux"


# ls aliases
alias la="ls -al"
alias ls="ls -h --color --group-directories-first" # flat view w/ directories first
alias l="ls -h --color --group-directories-first" # same as above
alias ll="ls -lv --group-directories-first" # non-flat view
alias lm="ll | more"

# Quick parent-directory aliases
alias ..="cd .."
alias ...="cd ../.."
alias ....="cd ../../.."
alias .....="cd ../../../.."
alias cl="cd $_" # cd to last argument in previous command

#CD to Specific folders

alias home="cd ~"
alias appl="cd /mnt/c/appl"
alias repos="cd /mnt/c/appl/repos"
alias progs="cd /mnt/c/appl/progs"
alias certs="cd /mnt/c/appl/certs"
alias dotfiles="cd /mnt/c/appl/repos/dotfiles"
alias kne="cd /mnt/c/appl/repos/Dhhr.Kneik"
alias kneik="cd /mnt/c/appl/repos/Dhhr.Kneik"

# Git commands
alias log="git log --oneline"
alias gdiff="git diff"
alias branch="git branch -a"
alias status="git status"
alias reset="git reset --soft"
alias fetch="git fetch"
alias stash="git stash"
alias push="git push origin head"
alias pull="git pull"
alias recent="git for-each-ref --sort -committerdate refs/heads/"
alias glog="git log --graph --pretty oneline --abbrev-commit --decorate"
alias add="gadd"
alias com="gcom"
alias clone="git clone"
alias merge="git merge"

# Others
alias editbash="nano ${HOME}/.bashrc"
alias editzsh="nano ${HOME}/.zshrc"
alias editba="nano ${HOME}/.bash_aliases"
alias resource="source ${HOME}/.bashrc"
alias hosts="nano /mnt/c/Windows/System32/drivers/etc/hosts"
alias code="code ."
alias np="cmd.exe /c notepad"

" >>"${HOME}"/.zshrc

        if [[ ! "$(uname -r)" =~ "Microsoft$" ]]; then
            {
                # Alias to run Windows cmd.exe from WSL
                alias cmd="/mnt/c/Windows/System32/cmd.exe"
                alias cmdc="/mnt/c/Windows/System32/cmd.exe /c"
            } >>"${HOME}"/.zshrc
        fi

        prompt_k8s(){
            k8s_current_context=$(kubectl config current-context 2> /dev/null)
            if [[ $? -eq 0 ]] ; then echo -e "(${k8s_current_context}) "; fi

            IFS='-' read -ra ADDR <<< "$IN"
                for i in "${ADDR[@]}"; do
                    # process "$i"
                done
        }
            
            
            PS1+='$(prompt_k8s)'