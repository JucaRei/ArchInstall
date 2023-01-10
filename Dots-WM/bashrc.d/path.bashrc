# If not running interactively, don't do anything
[[ $- != *i* ]] && return

### PATH
if [ -d "$HOME/.bin" ]; then
    PATH="$HOME/.bin:$PATH"
fi

if [ -d "$HOME/.local/bin" ]; then
    PATH="$HOME/.local/bin:$PATH"
fi

if [ -d "$HOME/Applications" ]; then
    PATH="$HOME/Applications:$PATH"
fi

export EDITOR='nvim'
export VISUAL='nvim'
export HISTCONTROL=ignoreboth:erasedups
export PAGER='most'

# Ignore case on auto-completion
# Note: bind used instead of sticking these in .inputrc
if [[ $iatest > 0 ]]; then bind "set completion-ignore-case on"; fi

# Disable the bell
if [[ $iatest > 0 ]]; then bind "set bell-style visible"; fi

# xdg runtime for apps (remember to create folder
# export XDG_RUNTIME_DIR=$PATH:~/.cache/xdgr

export TERM="xterm-256color"                        # getting proper colors
export HISTCONTROL=ignoredups:erasedups:ignorespace # no duplicate entries
# export ALTERNATE_EDITOR=""                        # setting for emacsclient
# export EDITOR="emacsclient -t -a ''"              # $EDITOR use Emacs in terminal
# export VISUAL="emacsclient -c -a emacs"           # $VISUAL use Emacs in GUI mode

### "bat" as manpager (batcat on debian|ubuntu)
export MANPAGER="sh -c 'col -bx | bat -l man -p'"

## Use a default width of 80 for manpages for more convenient reading
export MANWIDTH=${MANWIDTH:-80}

LESS="-R -i"

# Show auto-completion list automatically, without double tab
if [[ $iatest > 0 ]]; then bind 'set show-all-if-ambiguous on'; fi
bind 'TAB:menu-complete'

# Add sbin directories to PATH.  This is useful on systems that have sudo
echo $PATH | grep -Eq "(^|:)/sbin(:|)" || PATH=$PATH:/sbin
echo $PATH | grep -Eq "(^|:)/usr/sbin(:|)" || PATH=$PATH:/usr/sbin

### CHANGE TITLE OF TERMINALS
case ${TERM} in
xterm* | rxvt* | Eterm* | aterm | kitty | kterm | gnome* | alacritty | st | konsole*)
    PROMPT_COMMAND='echo -ne "\033]0;${USER}@${HOSTNAME%%.*}:${PWD/#$HOME/\~}\007"'
    ;;
screen*)
    PROMPT_COMMAND='echo -ne "\033_${USER}@${HOSTNAME%%.*}:${PWD/#$HOME/\~}\033\\"'
    ;;
esac

PROMPT_COMMAND='history -a'

### SHOPT
shopt -s autocd  # change to named directory
shopt -s cdspell # autocorrects cd misspellings
shopt -s cmdhist # save multi-line commands in history as single line
shopt -s dotglob
shopt -s histappend     # do not overwrite history
shopt -s expand_aliases # expand aliases
shopt -s checkwinsize   # checks term size when bash regains control

### PROMPT
# This is commented out if using starship prompt
PS1='[\u@\h \W]\$ '

# ASDF
. /home/$USER/.asdf/asdf.sh
. /home/$USER/.asdf/completions/asdf.bash

# export PATH="$HOME/scripts/fontpreview:$PATH"

### RANDOM COLOR SCRIPT ###
# Get this script from my GitLab: gitlab.com/dwt1/shell-color-scripts
# Or install it from the Arch User Repository: shell-color-scripts
colorscript random

### BASH INSULTER (works in zsh though) ###
if [ -f /etc/bash.command-not-found ]; then
    . /etc/bash.command-not-found
fi

### SETTING THE STARSHIP PROMPT ###
eval "$(starship init bash)"
