# Copy file with a progress bar
cpp() {
    set -e
    strace -q -ewrite cp -- "${1}" "${2}" 2>&1 |
        awk '{
	count += $NF
	if (count % 10 == 0) {
		percent = count / total_size * 100
		printf "%3d%% [", percent
		for (i=0;i<=percent;i++)
			printf "="
			printf ">"
			for (i=percent;i<100;i++)
				printf " "
				printf "]\r"
			}
		}
	END { print "" }' total_size="$(stat -c '%s' "${1}")" count=0
}

# Copy and go to the directory
cpg() {
    if [ -d "$2" ]; then
        cp $1 $2 && cd $2
    else
        cp $1 $2
    fi
}

# Move and go to the directory
mvg() {
    if [ -d "$2" ]; then
        mv $1 $2 && cd $2
    else
        mv $1 $2
    fi
}

# Create and go to the directory
mkdirg() {
    mkdir -p $1
    cd $1
}

# Goes up a specified number of directories  (i.e. up 4)
up() {
    local d=""
    limit=$1
    for ((i = 1; i <= limit; i++)); do
        d=$d/..
    done
    d=$(echo $d | sed 's/^\///')
    if [ -z "$d" ]; then
        d=..
    fi
    cd $d
}

memusage() {
    ps aux | awk '{if (NR > 1) print $5;
                  if (NR > 2) print "+"}
                  END { print "p" }' | dc
}

## Settings for umask
if ((EUID == 0)); then
    umask 002
else
    umask 022
fi

# enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
if [ -f /etc/bash_completion ] && ! shopt -oq posix; then
    . /etc/bash_completion
fi

# enable bash completion in interactive shells
if ! shopt -oq posix; then
    if [ -f /usr/share/bash-completion/bash_completion ]; then
        . /usr/share/bash-completion/bash_completion
    elif [ -f /etc/bash_completion ]; then
        . /etc/bash_completion
    fi
fi

# Show auto-completion list automatically, without double tab
if [[ $iatest > 0 ]]; then bind 'set show-all-if-ambiguous on'; fi
bind 'TAB:menu-complete'

### ARCHIVE EXTRACTION
# usage: ex <file>
ex() {
    if [ -f "$1" ]; then
        case $1 in
        *.tar.bz2) tar xjf $1 ;;
        *.tar.gz) tar xzf $1 ;;
        *.bz2) bunzip2 $1 ;;
        *.rar) unrar x $1 ;;
        *.gz) gunzip $1 ;;
        *.tar) tar xf $1 ;;
        *.tbz2) tar xjf $1 ;;
        *.tgz) tar xzf $1 ;;
        *.zip) unzip $1 ;;
        *.Z) uncompress $1 ;;
        *.7z) 7z x $1 ;;
        *.deb) ar x $1 ;;
        *.tar.xz) tar xf $1 ;;
        *.tar.zst) unzstd $1 ;;
        *) echo "'$1' cannot be extracted via ex()" ;;
        esac
    else
        echo "'$1' is not a valid file"
    fi
}

# navigation
up() {
    local d=""
    local limit="$1"

    # Default to limit of 1
    if [ -z "$limit" ] || [ "$limit" -le 0 ]; then
        limit=1
    fi

    for ((i = 1; i <= limit; i++)); do
        d="../$d"
    done

    # perform cd. Show error if cd fails
    if ! cd "$d"; then
        echo "Couldn't go up $limit dirs."
    fi
}
