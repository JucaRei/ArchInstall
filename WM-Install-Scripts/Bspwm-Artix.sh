#!/bin/bash

xdg-user-dirs-update

sleep 3

mkdir -pv $HOME/.cache/xdgr

sudo chmod 0700 $HOME/.cache/xdgr

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
chmod -R 750 $HOME/.config/libfm
chmod -R 640 $HOME/.config/libfm/libfm.conf
# paru -S nemo nemo-audio-tab nemo-emblems nemo-fileroller nemo-image-converter nemo-pastebin nemo-preview nemo-seahorse nemo-share nemo-terminal folder-color-nemo nemo-compare

touch $HOME/.config/starship.toml
mkdir -p $HOME/Documents/workspace/{Github,Builds,Others,Customizations,Configs,Tests,Composes}
mkdir -p $HOME/.urxvt/ext
mkdir -p $HOME/.conky
mkdir -p $HOME/.ncmpcpp
mkdir -p $HOME/.config/mpd
mkdir -p $HOME/.runit
mkdir -p $HOME/.bin
mkdir -p $HOME/.local/bin
mkdir -p $HOME/.local/share/fonts
mkdir -p $HOME/.local/share/applications
mkdir -p $HOME/.config/{conky,bspwm,mpd,sxhkd,picom,dunst,rofi,mpv,zathura}
# mkdir -pv $HOME/Pictures/Wallpapers
cd $HOME/.config/mpd
touch database mpd.conf mpd.fifo mpd.log mpdstate

cd $HOME/Documents/workspace/Configs
git clone --depth 1 https://github.com/JucaRei/ArchInstall
cd /Documents/workspace/Configs/ArchInstall/Dots-WM/Bspwm-Nitro-Artix/
cp -rf $HOME/Documents/workspace/Configs/ArchInstall/Dots-WM/Bspwm-Nitro-Artix/bashrc $HOME/.bashrc
cp -rf $HOME/Documents/workspace/Configs/ArchInstall/Dots-WM/Bspwm-Nitro-Artix/{bspwm/,sxhkd/,picom/,nano/,dunst/,polybar/,rofi/,mpv/,zathura/} $HOME/.config/
cp -rf $HOME/Documents/workspace/Configs/ArchInstall/Dots-WM/Bspwm-Nitro-Artix/conky/ $HOME/.conky/
cd 
cp -rf $HOME/Documents/workspace/Configs/ArchInstall/wallpapers $HOME/Pictures/Wallpapers

cp -f $HOME/Documents/workspace/Configs/ArchInstall/Dots-WM/mpd/mpd.conf $HOME/.config/mpd/
cp -f $HOME/Documents/workspace/Configs/ArchInstall/Dots-WM/ncmpcpp/config $HOME/.ncmpcpp/

cd
cp -f $HOME/Documents/workspace/Configs/ArchInstall/wallpapers $HOME/Pictures/Wallpapers
cp -rf $HOME/Documents/workspace/Configs/ArchInstall/Dots-WM/Bspwm-Nitro-Artix/local/bin/** $HOME/.local/bin
cp -f $HOME/Documents/workspace/Configs/ArchInstall/Dots-WM/Bspwm-Nitro-Artix/xprofile-vm $HOME/.xprofile
cp -f $HOME/Documents/workspace/Configs/ArchInstall/Dots-WM/Bspwm-Nitro-Artix/rxvt/vtwhell $HOME/.urxvt/ext
cp -f $HOME/Documents/workspace/Configs/ArchInstall/Dots-WM/Bspwm-Nitro-Artix/rxvt/config-reload $HOME/.urxvt/ext
cp -rf $HOME/Documents/workspace/Configs/ArchInstall/Dots-WM/Bspwm-Nitro-Artix/bin/** $HOME/.bin/

chmod +x $HOME/.config/polybar/launch.sh
cp -f $HOME/Documents/workspace/Configs/ArchInstall/Dots-WM/Bspwm-Nitro-Artix/starship/starship2.toml $HOME/.config/starship.toml
cp -f $HOME/Documents/workspace/Configs/ArchInstall/Dots-WM/Bspwm-Nitro-Artix/Xresources $HOME/.Xresources
cp -f $HOME/Documents/workspace/Configs/ArchInstall/Dots-WM/Bspwm-Nitro-Artix/themes/ $HOME/.themes/
cp -f $HOME/Documents/workspace/Configs/ArchInstall/Dots-WM/Bspwm-Nitro-Artix/icons/ $HOME/.icons/
# cp -f $HOME/Documents/workspace/Configs/ArchInstall/Dots-WM/Bspwm-Nitro-Artix/rofi/ $HOME/.config/
# cp -f $HOME/Documents/workspace/Configs/ArchInstall/Dots-WM/Bspwm-Nitro-Artix/nano/ $HOME/.config/
# cp -f $HOME/Documents/workspace/Configs/ArchInstall/Dots-WM/Bspwm-Nitro-Artix/mpv/ $HOME/.config/
# cp -f $HOME/Documents/workspace/Configs/ArchInstall/Dots-WM/Bspwm-Nitro-Artix/conky/ $HOME/.conky/
# cp -f $HOME/Documents/workspace/Configs/ArchInstall/Dots-WM/Bspwm-Nitro-Artix/bspwm/ $HOME/.config/
chmod +x $HOME/.config/bspwm/bspwmrc
cp -f $HOME/Documents/workspace/Configs/ArchInstall/Dots-WM/geany/ $HOME/.config/
# cp -f $HOME/Documents/workspace/Configs/ArchInstall/Dots-WM/Bspwm-Nitro-Artix/dunst $HOME/.config/
chmod +x $HOME/.config/dunst/dunstrc

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
