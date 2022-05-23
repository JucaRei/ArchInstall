#!/bin/bash

xdg-user-dirs-update

sleep 3

mkdir -pv ~/.cache/xdgr

sudo chmod 0700 ~/.cache/xdgr

sudo hwclock --systohc

sudo firewall-cmd --add-port=1025-65535/tcp --permanent
sudo firewall-cmd --add-port=1025-65535/udp --permanent
sudo firewall-cmd --reload

# reflector -c Brazil -a 12 --sort rate --save /etc/pacman.d/mirrorlist
sudo pacman -Syy

# Xorg Packages
paru -S xorg-server xorg-font-util xorg-fonts-encodings xorg-fonts-alias-misc xorg-fonts-misc xorg-setxkbmap xorg-xauth xorg-mkfontscale xorg-xsetroot xorg-xinit libxrandr libxft libinput libinput-gestures xorg-xrdb libxinerama xorg-xbacklight xorg-xcursorgen xorg-xdpyinfo xorg-xdriinfo xorg-xev xorg-xhost xorg-xkbcomp xorg-xkbevd xorg-xkbutils xorg-xkill xorg-xlsclients xorg-xmodmap xorg-xprop xorg-xset xorg-xsetroot xorg-xvinfo xorg-xwininfo

paru -S bspwm arandr numlockx firefox-bin glow sxhkd wmctrl polybar rofi-calc flatpak light-locker playerctl lua dmenu nitrogen feh unclutter picom-ibhagwan-git zathura neovim rofi dunst scrot archlinux-wallpaper lxappearance lightdm lightdm-runit web-greeter lightdm-settings light-locker ncmpcpp mpc neofetch htop geany

# Terminals
paru -S xfce4-terminal kitty rxvt-unicode-truecolor-wide-glyphs

# File manager
paru -S pcmanfm libfm lxqt_wallet ffmpegthumbnailer gst-libav gst-plugins-ugly file-roller xarchiver
chmod -R 750 ~/.config/libfm
chmod -R 640 ~/.config/libfm/libfm.conf
# paru -S nemo nemo-audio-tab nemo-emblems nemo-fileroller nemo-image-converter nemo-pastebin nemo-preview nemo-seahorse nemo-share nemo-terminal folder-color-nemo nemo-compare

touch $HOME/.config/starship.toml
mkdir -p $HOME/Documents/workspace/{Github,Builds,Others,Customizations,Configs,Tests,Composes}
mkdir -p ~/.urxvt/ext
mkdir -p ~/.conky
mkdir -p ~/.ncmpcpp
mkdir -p ~/.config/mpd
mkdir -p ~/.runit
mkdir -p $HOME/.bin
mkdir -p $HOME/local/.bin
mkdir -p $HOME/local/share/fonts
mkdir -p $HOME/local/share/applications
mkdir -p $HOME/.config/{conky,bspwm,mpd,sxhkd,picom,dunst,rofi,mpv,zathura}
# mkdir -pv ~/Pictures/Wallpapers
cd ~/.config/mpd
touch database mpd.conf mpd.fifo mpd.log mpdstate

cd ~/Documents/workspace/Configs
git clone --depth 1 https://github.com/JucaRei/ArchInstall
cd /Documents/workspace/Configs/ArchInstall/Dots-WM/Bspwm-Nitro-Artix/
cp -rf /home/junior/Documents/workspace/Configs/ArchInstall/Dots-WM/Bspwm-Nitro-Artix/bashrc ~/.bashrc
cd 
cp -rf ~/Documents/workspace/Configs/ArchInstall/wallpapers ~/Pictures/Wallpapers

cp -f ~/Documents/workspace/Configs/ArchInstall/Dots-WM/mpd/mpd.conf ~/.config/mpd
cp -f ~/Documents/workspace/Configs/ArchInstall/Dots-WM/ncmpcpp/config ~/.ncmpcpp

cd
cp -f ~/Documents/workspace/Configs/ArchInstall/wallpapers ~/Pictures/Wallpapers
cp -f ~/Documents/workspace/Configs/ArchInstall/Dots-WM/Bspwm-Nitro/fehauto.sh ~/.local/bin
cp -f ~/Documents/workspace/Configs/ArchInstall/Dots-WM/Bspwm-Nitro/xprofile-vm ~/.xprofile
cp -f ~/Documents/workspace/Configs/ArchInstall/Dots-WM/Bspwm-Nitro/rxvt/vtwhell ~/.urxvt/ext
cp -f ~/Documents/workspace/Configs/ArchInstall/Dots-WM/Bspwm-Nitro/rxvt/config-reload ~/.urxvt/ext
cp -f ~/Documents/workspace/Configs/ArchInstall/Dots-WM/Bspwm-Nitro/dualbsp-VM.sh ~/.bin
cp -f ~/Documents/workspace/Configs/ArchInstall/Dots-WM/Bspwm-Nitro/DualMonPolybar-VM.sh ~/.bin
sudo cp -f ~/Documents/workspace/Configs/ArchInstall/Dots-WM/Bspwm-Nitro/Dual-DM-VM.sh /etc/lightdm
cp -f /etc/dunst/ ~/.config/dunst/

# install -Dm755 /usr/share/doc/bspwm/examples/bspwmrc ~/.config/bspwm/bspwmrc
# install -Dm644 /usr/share/doc/bspwm/examples/sxhkdrc ~/.config/sxhkd/sxhkdrc
cp -f ~/Documents/workspace/Configs/ArchInstall/Dots-WM/Bspwm-Nitro/polybar/ ~/.config/
chmod +x ~/.config/polybar/launch.sh
cp -f ~/Documents/workspace/Configs/ArchInstall/Dots-WM/Bspwm-Nitro/starship/starship2.toml ~/.config/starship.toml
cp -f ~/Documents/workspace/Configs/ArchInstall/Dots-WM/Bspwm-Nitro/Xresources ~/.Xresources
cp -f ~/Documents/workspace/Configs/ArchInstall/Dots-WM/Bspwm-Nitro/zathura/ ~/.config/
cp -f ~/Documents/workspace/Configs/ArchInstall/Dots-WM/Bspwm-Nitro/sxhkd/ ~/.config/
cp -f ~/Documents/workspace/Configs/ArchInstall/Dots-WM/Bspwm-Nitro/picom/ ~/.config/
cp -f ~/Documents/workspace/Configs/ArchInstall/Dots-WM/Bspwm-Nitro/themes/ ~/.themes/
cp -f ~/Documents/workspace/Configs/ArchInstall/Dots-WM/Bspwm-Nitro/icons/ ~/.icons/
cp -f ~/Documents/workspace/Configs/ArchInstall/Dots-WM/Bspwm-Nitro/rofi/ ~/.config/
cp -f ~/Documents/workspace/Configs/ArchInstall/Dots-WM/Bspwm-Nitro/nano/ ~/.config/
cp -f ~/Documents/workspace/Configs/ArchInstall/Dots-WM/Bspwm-Nitro/mpv/ ~/.config/
cp -f ~/Documents/workspace/Configs/ArchInstall/Dots-WM/Bspwm-Nitro/conky/ ~/.conky/
cp -f ~/Documents/workspace/Configs/ArchInstall/Dots-WM/Bspwm-Nitro/bspwm/ ~/.config/
chmod +x ~/.config/bspwm/bspwmrc
cp -f ~/Documents/workspace/Configs/ArchInstall/Dots-WM/geany/ ~/.config/
cp -f ~/Documents/workspace/Configs/ArchInstall/Dots-WM/Bspwm-Nitro/dunst ~/.config/
chmod +x ~/.config/dunst/dunstrc

#cp /usr/share/doc/bspwm/examples/bspwmrc .config/bswpm
#cp /usr/share/doc/bspwm/examples/sxhkdrc .config/sxhkd

#echo "setxkbmap br &" >>$HOME/.config/bspwm/bspwmrc
# echo "/usr/bin/numlockx on &" >>$HOME/.config/bspwm/bspwmrc
#echo "picom &" >>$HOME/.config/bspwm/bspwmrc

cd $HOME/Documents/workspace/Configs
git clone https://github.com/JucaRei/rofi

cd

# Install Fonts
cd $HOME/Documents/workspace/Configs/ArchInstall/fonts/fonts && cp *.ttf *.otf $HOME/.local/share/fonts/
fc-cache -fv



cp -r $HOME/workspace/Configs/ArchInstall/Dots-WM/mpd/mpd.conf $HOME/.config/mpd/
cp -r $HOME/workspace/Configs/ArchInstall/Dots-WM/ncmpcpp/config $HOME/.ncmpcpp/

printf "\e[1;32mCHANGE NECESSARY FILES BEFORE REBOOT\e[0m"
printf "\e[1;32mLIGHTDM CONFIG (SEAT: GREETER-SESSION TO lightdm-slick greeter)\e[0m"
printf "\e[1;32mLIGHTDM CONFIG (USER-SESSION: bspwm)\e[0m"
printf "\e[1;32mRunit Services\e[0m"
