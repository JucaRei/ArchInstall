# Add an "alert" alias for long running commands.  Use like so:
#   sleep 10; alert
which notify-send &>/dev/null && alias alert='notify-send --urgency=low -i "$([ $? = 0 ] && echo terminal || echo error)" "$(history|tail -n1|sed -e '\''s/^\s*[0-9]\+\s*//;s/[;&|]\s*alert$//'\'')"'

# Dietpi
alias dietpi="ssh dietpi@192.168.1.200"
alias dietroot="ssh root@192.168.1.200"

# GPG encryption
#gpg
#verify signature for isos
alias gpg-check="gpg2 --keyserver-options auto-key-retrieve --verify"
alias fix-gpg-check="gpg2 --keyserver-options auto-key-retrieve --verify"
alias gpg-retrieve="gpg2 --keyserver-options auto-key-retrieve --receive-keys"
alias fix-gpg-retrieve="gpg2 --keyserver-options auto-key-retrieve --receive-keys"
alias fix-keyserver="[ -d ~/.gnupg ] || mkdir ~/.gnupg ; cp /etc/pacman.d/gnupg/gpg.conf ~/.gnupg/ ; echo 'done'"

# Aliases for software managment
alias rankmirrors='sudo netselect-apt -c Brazil -t 15 -a amd64 -n testing'
alias update="sudo apt update && dpkg --get-selections | xargs apt-cache policy {} | grep -1 Installed | sed -r 's/(:|Installed: |Candidate: )//' | uniq -u | tac | sed '/--/I,+1 d' | tac | sed '$d' | sed -n 1~2p"
alias upgrade='sudo apt upgrade -y'
alias cleanup='yes | sudo apt autoremove && sudo apt autoclean'
alias install='sudo apt install -y'
alias info='sudo apt-cache show'

#Recent Installed Packages
alias rip='comm -12 <(apt-mark showmanual | sort) <(grep " install " /var/log/dpkg.log | cut -d " " -sf4 | grep -o "^[^:]*" | sort)'
alias ripver="dpkg --get-selections | awk '/php/{print $1}' | xargs dpkg-query --show $1"
alias rip2='zcat -f /var/log/dpkg.log* | grep " install " | sort > /tmp/dpkg.log
grep -F "`comm -12 <(apt-mark showmanual | sort) <(cat /tmp/dpkg.log | cut -d " " -sf4 | grep -o "^[^:]*" | sort)`" /tmp/dpkg.log | grep \<none\>'

#clear
alias clean="clear; seq 1 $(tput cols) | sort -R | sparklines | lolcat"

#Others
alias tarnow='tar -acf'
alias untar='tar -zxvf'
alias psmem='ps auxf | sort -nr -k 4'
alias psmem10='ps auxf | sort -nr -k 4 | head -10'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'
alias ......='cd ../../../../..'
alias dir='dir --color=auto'
alias vdir='vdir --color=auto'
alias cat='bat --pager=never --theme=ansi'
alias catf='bat --theme=ansi'

#systeminfo
alias probe="sudo -E hw-probe -all -upload"
alias sysfailed="systemctl list-units --failed"

#btrfs aliases
alias btrfsfs="sudo btrfs filesystem df /"
alias btrfsli="sudo btrfs su li / -t"s

#grub update
alias update-grub="sudo grub-mkconfig -o /boot/grub/grub.cfg"

# Search command line history
alias h="history | grep "
alias comused="history | awk '{print $2}' | sort | uniq -c | sort -nr | head -5"
alias top10='print -l ${(o)history%% *} | uniq -c | sort -nr | head -n 10'

#know what you do in these files
alias nlxdm="sudo $EDITOR /etc/lxdm/lxdm.conf"
alias nlightdm="sudo $EDITOR /etc/lightdm/lightdm.conf"
alias ngrub="sudo $EDITOR /etc/default/grub"
alias nmirrorlist="sudo $EDITOR /etc/pacman.d/mirrorlist"
alias nsddm="sudo $EDITOR /etc/sddm.conf"
alias nsddmk="sudo $EDITOR /etc/sddm.conf.d/kde_settings.conf"
alias nfstab="sudo $EDITOR /etc/fstab"
alias nnsswitch="sudo $EDITOR /etc/nsswitch.conf"
alias nsamba="sudo $EDITOR /etc/samba/smb.conf"
alias nhosts="sudo $EDITOR /etc/hosts"
alias nb="$EDITOR ~/.bashrc"
alias nz="$EDITOR ~/.zshrc"
alias nf="$EDITOR ~/.config/fish/config.fish"

# Alias's to show disk space and space used in a folder
alias diskspace="du -S | sort -n -r |more"
alias folders='du -h --max-depth=1'
alias folderssort='find . -maxdepth 1 -type d -print0 | xargs -0 du -sk | sort -rn'
alias tree='tree -CAhF --dirsfirst'
alias treed='tree -CAFd'
alias mountedinfo='df -hT'

# Alias's for archives
alias mktar='tar -cvf'
alias mkbz2='tar -cvjf'
alias mkgz='tar -cvzf'

#skim
alias sk="sk --ansi -c 'grep -rI --color=always --line-number "{}" .'"

#give the list of all installed desktops - xsessions desktops
alias xd="ls /usr/share/xsessions"

#check vulnerabilities microcode
alias microcode='grep . /sys/devices/system/cpu/vulnerabilities/*'

# Zswap
alias zswap='grep . /sys/module/zswap/parameters/*'

#hardware info --short
alias hw="hwinfo --short"

#add new fonts
alias update-fc='sudo fc-cache -fv'

# switch between shells
# I do not recommend switching default SHELL from bash.
alias tobash="sudo chsh $USER -s /bin/bash && echo 'Now log out.'"
alias tozsh="sudo chsh $USER -s /bin/zsh && echo 'Now log out.'"
alias tofish="sudo chsh $USER -s /bin/fish && echo 'Now log out.'"

# termbin
alias tb="nc termbin.com 9999"

#free
alias free="free -mt"

#continue download
alias wget="wget -c"

#userlist
alias userlist="cut -d: -f1 /etc/passwd"

#search content with ripgrep
alias rg="rg --sort path"

# Changing "ls" to "exa"
alias ls='exa -al --color=always --group-directories-first' # my preferred listing
alias la='exa -a --color=always --group-directories-first'  # all files and dirs
alias ll='exa -l --color=always --group-directories-first'  # long format
alias lt='exa -aT --color=always --group-directories-first' # tree listing
alias l.='exa -a | egrep "^\."'

#alias ls='ls --color=auto'
alias desligar="sudo shutdown -h now"
alias reiniciar="sudo reboot"
alias internetPCI="sudo lshw -class network -short"
alias limpar="sudo vpm cleanup && sudo vpm autoremove"
alias atualizar="sudo vpm sync && sudo vpm upgrade"
alias sxorg="export DISPLAY=:0.0"

# Colorize grep output (good for log files)
alias grep='grep --color=auto'
alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'

# confirm before overwriting something
alias cp="cp -i"
alias mv='mv -i'
alias rm='rm -i'

#cp without confirm overwrint something
alias cpy="yes | cp -rf"
alias mvy="yes | mv -rf"
alias rmy="yes | rm -rf"

#keyboard
alias give-me-abnt-br="sudo localectl set-x11-keymap br"
alias give-me-qwerty-us="sudo localectl set-x11-keymap us"

# adding flags
alias df='df -Th'    # human-readable sizes
alias free='free -m' # show sizes in MB
# alias lynx='lynx -cfg=~/.lynx/lynx.cfg -lss=~/.lynx/lynx.lss -vikeys'  # Vim broser
# alias vifm='./.config/vifm/scripts/vifmrun'
alias ncmpcpp='ncmpcpp ncmpcpp_directory=$HOME/.config/ncmpcpp/'
# alias mocp='mocp -M "$XDG_CONFIG_HOME"/moc -O MOCDir="$XDG_CONFIG_HOME"/moc' #lastfm

# ps
alias psa="ps auxf"
alias psgrep="ps aux | grep -v grep | grep -i -e VSZ -e"
alias psmem='ps auxf | sort -nr -k 4'
alias pscpu='ps auxf | sort -nr -k 3'

# get error messages from journalctl
alias jctl="journalctl -p 3 -xb"

# Merge Xresources
alias merge='xrdb -merge ~/.Xresources'

# Arp get all devices on lan
alias localdevices="sudo arp-scan --interface=eth0 --localnet"

# Neovim aliases
alias vim="nvim"
alias vi="nvim"
alias nlxdm="sudo nvim /etc/lxdm/lxdm.conf"
alias nlightdm="sudo nvim /etc/lightdm/lightdm.conf"
alias npacman="sudo nvim /etc/pacman.conf"
alias ngrub="sudo nvim /etc/default/grub"
# alias nconfgrub="sudo nvim /boot/grub/grub.cfg"
alias nmkinitcpio="sudo nvim /etc/mkinitcpio.conf"
alias nmirrorlist="sudo nvim /etc/pacman.d/mirrorlist"
# alias narcomirrorlist='sudo nano /etc/pacman.d/arcolinux-mirrorlist'
alias nsddm="sudo nvim /etc/sddm.conf"
alias nsddmk="sudo nvim /etc/sddm.conf.d/kde_settings.conf"
alias nfstab="sudo nvim /etc/fstab"
alias nnsswitch="sudo nvim /etc/nsswitch.conf"
alias nsamba="sudo nvim /etc/samba/smb.conf"
alias ngnupgconf="sudo nano /etc/pacman.d/gnupg/gpg.conf"
alias nb="nvim ~/.bashrc"
alias nz="nvim ~/.zshrc"

# alias to show the date
alias da='date "+%Y-%m-%d %A %T %Z"'

# Count all files (recursively) in the current folder
alias countfiles="for t in files links directories; do echo \`find . -type \${t:0:1} | wc -l\` \$t; done 2> /dev/null"

# Remove a directory and all files
alias rmd='/bin/rm  --recursive --force --verbose '

alias top='htop'
alias cat='bat --pager=never --theme=ansi'
alias catf='bat --theme=ansi'
