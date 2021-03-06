#!/bin/bash

# Variables
country=Brazil
kbmap=br-abnt2
output=Virtual-1
resolution=1920x1080

#Options
#ur_helper=true
#install_ly=true
#gen_xprofile=false


sudo timedatectl set-ntp true
sudo hwclock --systohc

sudo firewall-cmd --add-port=1025-65535/tcp --permanent
sudo firewall-cmd --add-port=1025-65535/udp --permanent
sudo firewall-cmd --reload

reflector -c Brazil -a 12 --sort rate --save /etc/pacman.d/mirrorlist
sudo pacman -Syy

# if [[ $aur_helper = true ]]; then
#   cd /tmp
#   git clone https://aur.archlinux.org/paru.git
#   cd paru/
#   makepkg -si 
#   cd
# fi

# sudo rm -rf /tmp/paru


#paru -S xf86-video-intel xorg --ignore xorg-server-xdmx
#paru -S nvidia-lts nvidia-utils nvidia-settings
#paru -S xorg-server xorg-xsetroot xorg-xinit libxrandr libxft xorg-xrdb libxinerama

pikaur -S bspwm pcmanfm sxhkd glow ranger polybar rxvt-unicode rxvt-unicode-terminfo urxvt-perls urxvt-resize-font-git urxvt-tabbedex light-locker playerctl awesome-terminal-fonts ttf-font-awesome nitrogen feh unclutter xclip libinput libinput-gestures picom-ibhagwan-git evince neovim rofi dunst scrot archlinux-wallpaper lxappearance lightdm web-greeter lightdm-gtk-greeter lightdm-gtk-greeter-settings lightdm-webkit-theme-aether lightdm-webkit2-greeter lightdm-settings ttc-iosevka ttf-icomoon-feather light-locker mpd ncmpcpp neofetch htop geany

# xorg packages
#pikaur -S arandr xorg-xprop xorg-font-util xorg-xkbevd xorg-fonts-75dpi xorg-fonts-100dpi xorg-fonts-encodings xorg-xev xorg-xkill xorg-xcmsdb xorg-xset xorg-xbacklight xorg-mkfontscale xorg-xkbevd xorg-xkbutils xorg-xkbcomp xorg-setxkbmap xdotool libinput libxft mesa-demos libxrandr libxinerama xorg-xrdb xorg-server xorg-xrandr

pikaur -S arandr xorg 

# video for Xorg
pikaur -S xf86-video-vesa 

xdg-user-dirs-update

mkdir -p ${HOME}/.config/{bspwm,sxhkd,dunst,rofi}
mkdir -p ${HOME}/Documents/workspace/{Configs,Github}

install -Dm755 /usr/share/doc/bspwm/examples/bspwmrc ~/.config/bspwm/bspwmrc
install -Dm644 /usr/share/doc/bspwm/examples/sxhkdrc ~/.config/sxhkd/sxhkdrc
#cp ${HOME}/ArchInstall/bspwm-old/bspwmrc ${HOME}/.config/bspwm/
#cp ${HOME}/ArchInstall/bspwm-old/sxhkdrc ${HOME}/.config/sxhkd/

sudo cp /etc/dunst/dunstrc ${HOME}/.config/dunst

#cp /usr/share/doc/bspwm/examples/bspwmrc .config/bswpm
#cp /usr/share/doc/bspwm/examples/sxhkdrc .config/sxhkd

mkdir -p ${HOME}/Documents/workspace/{Configs,Github}

install -Dm755 /usr/share/doc/bspwm/examples/bspwmrc ~/.config/bspwm/bspwmrc
install -Dm644 /usr/share/doc/bspwm/examples/sxhkdrc ~/.config/sxhkd/sxhkdrc
#cp ${HOME}/ArchInstall/bspwm-old/bspwmrc ${HOME}/.config/bspwm/
#cp ${HOME}/ArchInstall/bspwm-old/sxhkdrc ${HOME}/.config/sxhkd/

sudo cp /etc/dunst/dunstrc ${HOME}/.config/dunst

#cp /usr/share/doc/bspwm/examples/bspwmrc .config/bswpm
#cp /usr/share/doc/bspwm/examples/sxhkdrc .config/sxhkd

#echo "setxkbmap br &" >>${HOME}/.config/bspwm/bspwmrc
#echo "/usr/bin/numlockx on &" >>${HOME}/.config/bspwm/bspwmrc
#echo "picom &" >>${HOME}/.config/bspwm/bspwmrc

cd ${HOME}/Documents/workspace/Configs
git clone https://github.com/JucaRei/fonts
git clone https://github.com/JucaRei/dotfiles
git clone https://github.com/JucaRei/polybar-themes
git clone https://github.com/JucaRei/rofi

cd

# Install Fonts
cd ${HOME}/Documents/workspace/Configs/fonts/fonts && cp *.ttf *.otf ${HOME}/.local/share/fonts/
fc-cache -fv

#Rofi
cd ${HOME}/Documents/workspace/Configs/rofi
chmod +x setup.sh
./setup.sh

cd

#echo "setxkbmap br &" >>${HOME}/.config/bspwm/bspwmrc
echo "/usr/bin/numlockx on &" >>${HOME}/.config/bspwm/bspwmrc
#echo "picom &" >>${HOME}/.config/bspwm/bspwmrc

cd ${HOME}/Documents/workspace/Configs
git clone https://github.com/JucaRei/fonts
git clone https://github.com/JucaRei/dotfiles
git clone https://github.com/JucaRei/polybar-themes
git clone https://github.com/JucaRei/rofi

cd

# Install Fonts
cd ${HOME}/Documents/workspace/Configs/fonts/fonts && cp *.ttf *.otf ${HOME}/.local/share/fonts/
fc-cache -fv

#Rofi
cd ${HOME}/Documents/workspace/Configs/rofi
chmod +x setup.sh
./setup.sh

cd

#POLYBAR
#cd ${HOME}/Documents/workspace/Configs/polybar-themes
#chmod +x setup.sh
#./setup.sh
#cd

# sxhkdrc Config your terminal
# picom conf remove vsync

#cp /etc/X11/xinit/xinitrc .xinitrc
#cp /etc/X11/xinit/xserverrc .xserverrc

cd ${HOME}/ArchInstall/BSPWM

mkdir -p ~/.config/{mpd,ncmpcpp} && cd ~/.config/mpd
touch database mpd.conf mpd.fifo mpd.log mpdstate

cd

cp -f ${HOME}/ArchInstall/BSPWM/mpd/mpd.conf ~/.config/mpd
cp -f ${HOME}/ArchInstall/BSPWM/ncmpcpp/config ~/.config/ncmpcpp

###   POLYBAR
# mv dotfiles/polybar ${HOME}/.config
# mv dotfiles/Xresources ${HOME}/.Xresources

cp ${HOME}/Documents/workspace/Configs/dotfiles/wallpaper.jpg ${HOME}/Pictures
feh --no-fehbg --bg-scale '${HOME}/Pictures/wallpaper.jpg'

#bspwmrc
cd ${HOME}/ArchInstall/BSPWM/
cp .Xresources ~/.Xresources
echo "xrdb ${HOME}/.Xresources" >>~/.config/bspwm/bspwmrc

#echo "${HOME}/.config/polybar/launch.sh --forest &" >>~/.config/bspwm/bspwmrc
echo "${HOME}/.fehbg" >>~/.config/bspwm/bspwmrc

#echo "setxkbmap br &" >> ~/.xinitrc
#echo "${HOME}/.screenlayout/display.sh" >> ~/.xinitrc
#echo "nitrogen --restore &" >> ~/.xinitrc
#echo "xsetroot -cursor_name left_ptr &" >> ~/.xinitrc
#echo "picom -f &" >> ~/.xinitrc
#echo "exec bspwm" >> ~/.xinitrc


printf "\e[1;32mCHANGE NECESSARY FILES BEFORE REBOOT\e[0m"
printf "\e[1;32mLIGHTDM CONFIG (SEAT: GREETER-SESSION TO lightdm-slick greeter)\e[0m"
printf "\e[1;32mLIGHTDM CONFIG (USER-SESSION: bspwm)\e[0m"
printf "\e[1;32mRunit Services\e[0m"
