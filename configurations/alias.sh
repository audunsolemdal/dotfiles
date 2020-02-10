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

        function AzLogin()
        {
            az login
        }

        function Set-AzSub()
        {
            az account set --subscription "SDP Tools"
        }

        function kexec(){
            kubectl exec -it $1 bash
        }

        function dexec(){
            docker exec -it $1 bash
        }
        function docup(){
            docker-compose up -d $1
        }
        function docdown(){
            docker-compose down $1
        }

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

        function KCon()
        {
            O="sdpaks-$1-k8s"
            kubectl config use-context $O

            if [ $? -eq 0 ]; then
            echo  "Currently in $1 cluster"
            fi
        }

        function KNs()
        {
            # always returns true.. need workaround
            kubectl config set-context --current --namespace=$1
           
            if [ $? -eq 0 ]; then
            CON=$(kubectl config current-context)  
            echo "Currently at $1 namespace in $CON cluster"
             fi
        }

        alias kns="KNs"
        alias kcon="KCon"

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

        #CD to Specific folders

        alias home="cd ~"
        alias appl="cd /mnt/c/appl"
        alias repos="cd /mnt/c/appl/repos"
        alias progs="cd /mnt/c/appl/progs"
        alias certs="cd /mnt/c/appl/certs"
        alias dotfiles="cd /mnt/c/appl/repos/dotfiles"
        alias sdp-flux="cd /mnt/c/appl/repos/sdp-flux"
        alias sdp-aks="cd /mnt/c/appl/repos/sdp-aks"
        alias flux="cd /mnt/c/appl/repos/sdp-flux"
        alias aks="cd /mnt/c/appl/repos/sdp-aks"

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

        # Others
        alias editbash="nano ${HOME}/.bashrc"
        alias editzsh="nano ${HOME}/.zshrc"
        alias editba="nano ${HOME}/.bash_aliases"
        alias resource="source ${HOME}/.bashrc"
        alias hosts="nano /mnt/c/Windows/System32/drivers/etc/hosts"
        alias code="code ."
        alias np="cmd.exe /c notepad"

        #NetWork
        alias ip="curl ipinfo.io/ip"
        alias ips="ifconfig -a | perl -nle'/(d+.d+.d+.d+)/ && print $1'"
        alias speedtest="wget -O /dev/null http://speedtest.wdc01.softlayer.com/downloads/test100.zip"

        # Handy Extract Program
        function extract()      
        {
            if [ -f $1 ] ; then
                case $1 in
                    *.tar.bz2)   tar xvjf $1     ;;
                    *.tar.gz)    tar xvzf $1     ;;
                    *.bz2)       bunzip2 $1      ;;
                    *.rar)       unrar x $1      ;;
                    *.gz)        gunzip $1       ;;
                    *.tar)       tar xvf $1      ;;
                    *.tbz2)      tar xvjf $1     ;;
                    *.tgz)       tar xvzf $1     ;;
                    *.zip)       unzip $1        ;;
                    *.Z)         uncompress $1   ;;
                    *.7z)        7z x $1         ;;
                    *)           echo "'$1' cannot be extracted via >extract<" ;;
                esac
            else
                echo "'$1' is not a valid file!"
            fi
        }
        
        
        # Make Dir and CD to it
        function mcd ()
        {
            mkdir -p $1
            cd $1
        }
        
        # Switch a File or Folder
        function swap()
        {
            if [ ! -z "$2" ] && [ -e "$1" ] && [ -e "$2" ] && ! [ "$1" -ef "$2" ] && (([ -f "$1" ] && [ -f "$2" ]) || ([ -d "$1" ] && [ -d "$2" ])) ; then
                tmp=$(mktemp -d $(dirname "$1")/XXXXXX)
                mv "$1" "$tmp" && mv "$2" "$1" &&  mv "$tmp"/"$1" "$2"
                rmdir "$tmp"
            else
                echo "Usage: swap file1 file2 or swap dir1 dir2"
            fi
        }
        
        # Creates an archive (*.tar.gz) from given directory.
        function maketar() { tar cvzf "${1%%/}.tar.gz"  "${1%%/}/"; }
        
        # Create a ZIP archive of a file or folder.
        function makezip() { zip -r "${1%%/}.zip" "$1" ; }
        
        # Make your directories and files access rights sane.
        function sanitize() { chmod -R u=rwX,g=rX,o= "$@" ;}

        cd ${defaultfolder}
        " >>"${HOME}"/.zshrc

        if [[ ! "$(uname -r)" =~ "Microsoft$" ]]; then
            {
                # Alias to run Windows cmd.exe from WSL
                alias cmd="/mnt/c/Windows/System32/cmd.exe"
                alias cmdc="/mnt/c/Windows/System32/cmd.exe /c"
            } >>"${HOME}"/.zshrc
        fi
