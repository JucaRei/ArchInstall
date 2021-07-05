#!/bin/bash

sudo timedatectl set-ntp true
sudo hwclock --systohc

sudo firewall-cmd --add-port=1025-65535/tcp --permanent
sudo firewall-cmd --add-port=1025-65535/udp --permanent
sudo firewall-cmd --reload

git clone https://aur.archlinux.org/pikaur.git
cd pikaur/
makepkg -si --noconfirm

pikaur -S --noconfirm system76-power
sudo systemctl enable --now system76-power
sudo system76-power graphics integrated
pikaur -S --noconfirm auto-cpufreq
sudo systemctl enable --now auto-cpufreq


sudo pacman -S --noconfirm xorg sddm plasma konsole wget curl dolphin ark kate kwrite kcalc spectacle krunner partitionmanager firefox vlc papirus-icon-theme materia-kde

sudo systemctl enable sddm
/bin/echo -e "\e[1;32mREBOOTING IN 5..4..3..2..1..\e[0m"
sleep 5
reboot
