#!/bin/bash

sudo timedatectl set-ntp true
sudo hwclock --systohc

sudo firewall-cmd --add-port=1025-65535/tcp --permanent
sudo firewall-cmd --add-port=1025-65535/udp --permanent
sudo firewall-cmd --reload

reflector -c Brazil -a 12 --sort rate --save /etc/pacman.d/mirrorlist
sudo pacman -Syyy

git clone https://aur.archlinux.org/pikaur.git
cd pikaur/
makepkg -si --noconfirm

# pikaur -S --noconfirm system76-power
# sudo systemctl enable --now system76-power
# sudo system76-power graphics integrated
# pikaur -S --noconfirm auto-cpufreq
# sudo systemctl enable --now auto-cpufreq

#ferdi freezer
# sudo snap install beekeeper-studio postbird

# LXDE
sudo pikaur -S xorg lightdm xfce4 xfce4-goodies menulibre libcanberra firefox-developer-edition ttf-droid ttf-dejavu ttf-consolas-ligaturized ttf-fira-code ttf-jetbrains-mono font-victor-mono breeze-hacked-cursor-theme

# sudo cp /etc/x11/xinit/xinitrc ~/.xinitrc

#Enable LXDE
sudo systemctl enable lightdm

/bin/echo -e "\e[1;32mREBOOTING IN 5..4..3..2..1..\e[0m"
sleep 5
reboot
