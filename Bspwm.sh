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

paru -S bspwm sxhkd dmenu rxvt-unicode picom nitrogen rofi dunst scrot archlinux-wallpaper lxappearance thunar ligthdm lightdm-runit light-slick-greeter light-locker

mkdir -p .config/{bspwm,sxhkd,dunst}

install -Dm755 /usr/share/doc/bspwm/examples/bspwmrc ~/.config/bspwm/bspwmrc
install -Dm644 /usr/share/doc/bspwm/examples/sxhkdrc ~/.config/sxhkd/sxhkdrc

#sudo ln -s /etc/runit/sv/lightdm /run/runit/service

printf "\e[1;32mCHANGE NECESSARY FILES BEFORE REBOOT\e[0m"
