#!/bin/bash

# Variables
country=Brazil
kbmap=br-abnt2
output=Virtual-1
resolution=1920x1080

#Options
aur_helper=true
install_ly=true
gen_xprofile=false

sudo timedatectl set-ntp true
sudo hwclock --systohc

sudo firewall-cmd --add-port=1025-65535/tcp --permanent
sudo firewall-cmd --add-port=1025-65535/udp --permanent
sudo firewall-cmd --reload

reflector -c Brazil -a 12 --sort rate --save /etc/pacman.d/mirrorlist
sudo pacman -Syy

if [[ $aur_helper = true ]]; then
  cd /tmp
  git clone https://aur.archlinux.org/paru.git
  cd paru/
  makepkg -si --noconfirm
  cd
fi

paru -S xf86-video-intel xorg --ignore xorg-server-xdmx
paru -S nvidia-lts nvidia-utils nvidia-settings

paru -S bspwm arandr xorg-server xorg-xsetroot xorg-xinit libxrandr libxft xorg-xrdb libxinerama pcmanfm-gtk3 sxhkd polybar rxvt-unicode alacritty dmenu nitrogen feh unclutter xclio libinput libinput-gestures picom evince-no-gnome neovim rofi dunst scrot archlinux-wallpaper lxappearance ligthdm lightdm-runit light-slick-greeter light-locker mpd ncmpcpp mpc neofetch htop geany

mkdir -p $HOME/.config/{bspwm,sxhkd,dunst,rofi}
mkdir -p $HOME/Documents/workspace/{Configs,Github}

install -Dm755 /usr/share/doc/bspwm/examples/bspwmrc ~/.config/bspwm/bspwmrc
install -Dm644 /usr/share/doc/bspwm/examples/sxhkdrc ~/.config/sxhkd/sxhkdrc

mkdir .config/bswpm
mkdir .config/sxhkd

cp /usr/share/doc/bspwm/examples/bspwmrc .config/bswpm
cp /usr/share/doc/bspwm/examples/sxhkdrc .config/sxhkd

cd $HOME/Documents/workspace/Configs
git clone https://github.com/JucaRei/fonts
git clone https://github.com/JucaRei/dotfiles
git clone https://github.com/JucaRei/polybar-themes
git clone https://github.com/JucaRei/rofi

cd

# Install Fonts
cd $HOME/Documents/workspace/Configs/fonts/fonts && cp *.ttf *.otf $HOME/.local/share/fonts/
fc-cache -fv

#Rofi
cd $HOME/Documents/workspace/Configs/rofi
chmod +x setup.sh
./setup.sh

cd

#POLYBAR
cd $HOME/Documents/workspace/Configs/polybar-themes
chmod +x setup.sh
cd

# sxhkdrc Config your terminal
# picom conf remove vsync

#cp /etc/X11/xinit/xinitrc .xinitrc
#cp /etc/X11/xinit/xserverrc .xserverrc

cd $HOME/ArchInstall/BSPWM

mkdir -p ~/.config/mpd && cd ~/.config/mpd
touch database mpd.conf mpd.fifo mpd.log mpdstate

cd $HOME/ArchInstall/BSPWM

cp mdp/mdp.conf ~/.config/mdp/
cp ncmpcpp/config ~/.ncmpcpp/

###   POLYBAR
# mv dotfiles/polybar $HOME/.config
# mv dotfiles/Xresources $HOME/.Xresources

feh --no-fehbg --bg-scale '$HOME/Pictures/wallpaper.jpg'

#bspwmrc
echo "xrdb ${HOME}/.Xresources" >>~/.config/bspwm/bspwmrc
echo "$HOME/.config/polybar/launch.sh --forest &" >>~/.config/bspwm/bspwmrc
echo "$HOME/.fehbg" >>~/.config/bspwm/bspwmrc

#echo "setxkbmap br &" >> ~/.xinitrc
#echo "$HOME/.screenlayout/display.sh" >> ~/.xinitrc
#echo "nitrogen --restore &" >> ~/.xinitrc
#echo "xsetroot -cursor_name left_ptr &" >> ~/.xinitrc
#echo "picom -f &" >> ~/.xinitrc
#echo "exec bspwm" >> ~/.xinitrc

#sudo ln -s /etc/runit/sv/lightdm /run/runit/service

printf "\e[1;32mCHANGE NECESSARY FILES BEFORE REBOOT\e[0m"
