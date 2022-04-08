#!/bin/bash

sudo hwclock --systohc

sudo firewall-cmd --add-port=1025-65535/tcp --permanent
sudo firewall-cmd --add-port=1025-65535/udp --permanent
sudo firewall-cmd --reload

# reflector -c Brazil -a 12 --sort rate --save /etc/pacman.d/mirrorlist
sudo pacman -Syy

# Xorg Packages
paru -S xorg-server xorg-font-util xorg-fonts-encondings xorg-setxkbmap xorg-xauth xorg-mkfontscale xorg-xsetroot xorg-xinit libxrandr libxft libinput libinput-gestures xorg-xrdb libxinerama xorg-xbacklight xorg-xcursorgen xorg-xdpyinfo xorg-xdriinfo xorg-xev xorg-xhost xorg-xkbcomp xorg-xkbevd xorg-xkbutils xorg-xkill xorg-xlsclients xorg-xmodmap xorg-xprop xorg-xset xorg-xsetroot xorg-xvinfo xorg-xwininfo

paru -S bspwm arandr firefox-esr-bin glow sxhkd polybar flatpak light-locker playerctl dmenu nitrogen feh unclutter picom-ibhagwan-git zathura neovim rofi dunst scrot archlinux-wallpaper lxappearance lightdm lightdm-runit web-greeter lightdm-settings light-locker ncmpcpp mpc neofetch htop geany

# Terminals
paru -S xfce4-terminal rxvt-unicode-truecolor-wide-glyphs

# File manager
paru -S nemo nemo-audio-tab nemo-emblems nemo-fileroller nemo-image-converter nemo-pastebin nemo-preview nemo-seahorse nemo-share nemo-terminal folder-color-nemo nemo-compare

touch $HOME/.config/starship.toml
mkdir -p ~/.urxvt/ext
mkdir -p ~/.config/mpd
mkdir -p ~/.ncmpcpp
mkdir -p $HOME/.bin
mkdir -p $HOME/local/.bin
mkdir -p $HOME/local/share/applications
mkdir -p $HOME/.config/{bspwm,sxhkd,dunst,rofi}
mkdir -pv ~/Pictures/Wallpapers
cd ~/.config/mpd
touch database mpd.conf mpd.fifo mpd.log mpdstate

cp -f ~/Documents/workspace/Configs/ArchInstall/Dots-WM/mpd/mpd.conf ~/.config/mpd
cp -f ~/Documents/workspace/Configs/ArchInstall/Dots-WM/ncmpcpp/config ~/.ncmpcpp

cd
cp -f ~/Documents/workspace/Configs/ArchInstall/wallpapers ~/Pictures/Wallpapers
cp -rf ~/Documents/workspace/Configs/ArchInstall/Dotw-WM/Bspwm-Nitro/polybar ~/.config
cp -f ~/Documents/workspace/Configs/ArchInstall/Dots-WM/Xresources ~/.Xresources
cp -f ~/Documents/workspace/Configs/ArchInstall/Dots-WM/Bspwm-Nitro/fehauto.sh ~/.local/bin
cp -f ~/Documents/workspace/Configs/ArchInstall/Dots-WM/Bspwm-Nitro/xprofile-vm ~/.xprofile
cp -f ~/Documents/workspace/Configs/ArchInstall/Dots-WM/Bspwm-Nitro/rxvt/vtwhell ~/.urxvt/ext
cp -f ~/Documents/workspace/Configs/ArchInstall/Dots-WM/Bspwm-Nitro/rxvt/config-reload ~/.urxvt/ext
cp -f ~/Documents/workspace/Configs/ArchInstall/Dots-WM/Bspwm-Nitro/dualbsp-VM.sh ~/.bin
cp -f ~/Documents/workspace/Configs/ArchInstall/Dots-WM/Bspwm-Nitro/DualMonPolybar-VM.sh ~/.bin
sudo cp -f ~/Documents/workspace/Configs/ArchInstall/Dots-WM/Bspwm-Nitro/Dual-DM-VM.sh /etc/lightdm
cp -f /etc/dunst/dunstrc ~/.config/dunst/

install -Dm755 /usr/share/doc/bspwm/examples/bspwmrc ~/.config/bspwm/bspwmrc
install -Dm644 /usr/share/doc/bspwm/examples/sxhkdrc ~/.config/sxhkd/sxhkdrc
# cp $HOME/ArchInstall/bspwm-old/bspwmrc $HOME/.config/bspwm/
# cp $HOME/ArchInstall/bspwm-old/sxhkdrc $HOME/.config/sxhkd/

cp /etc/dunst/dunstrc $HOME/.config/dunst

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

#Rofi
cd $HOME/Documents/workspace/Configs/rofi
chmod +x setup.sh
./setup.sh

cd

#POLYBAR
#cd $HOME/Documents/workspace/Configs/polybar-themes
#chmod +x setup.sh
#./setup.sh
#cd

# sxhkdrc Config your terminal
# picom conf remove vsync

#cp /etc/X11/xinit/xinitrc .xinitrc
#cp /etc/X11/xinit/xserverrc .xserverrc

cd $HOME/ArchInstall/BSPWM

mkdir -p ~/.config/mpd && cd ~/.config/mpd
touch database mpd.conf mpd.fifo mpd.log mpdstate

cd

cp $HOME/workspace/Configs/ArchInstall/Dots-WM/mpd/mpd.conf $HOME/.config/mpd/
cp $HOME/workspace/Configs/ArchInstall/Dots-WM/ncmpcpp/config $HOME/.config/ncmpcpp/

###   POLYBAR
# mv dotfiles/polybar $HOME/.config
# mv dotfiles/Xresources $HOME/.Xresources


sudo ln -s /etc/runit/sv/lightdm /run/runit/service

printf "\e[1;32mCHANGE NECESSARY FILES BEFORE REBOOT\e[0m"
printf "\e[1;32mLIGHTDM CONFIG (SEAT: GREETER-SESSION TO lightdm-slick greeter)\e[0m"
printf "\e[1;32mLIGHTDM CONFIG (USER-SESSION: bspwm)\e[0m"
printf "\e[1;32mRunit Services\e[0m"
