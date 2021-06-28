#!/bin/bash

sudo timedatectl set-ntp true
sudo hwclock --systohc

sudo reflector -c Brazil -a 6 --sort rate --save /etc/pacman.d/mirrorlist

sudo firewall-cmd --add-port=1025-65535/tcp --permanent
sudo firewall-cmd --add-port=1025-65535/udp --permanent
sudo firewall-cmd --reload

#git clone https://aur.archlinux.org/pikaur.git
#cd pikaur/
#makepkg -s i--noconfirm

#pikaur -S --noconfirm system76-power
#sudo systemctl enable --now system76-power
#sudo system76-power graphics integrated
#pikaur -S --noconfirm auto-cpufreq
#sudo systemctl enable --now auto-cpufreq

sudo pacman -S --noconfirm xorg sddm plasma kate okular dolphin dolphin-plugins
ark gwenview filelight kdeconnect kdf kdialog keditbookmarks kfind kio-extras
kipi-plugins kmag kmix kompare konqueror korganizer krdc kwalletmanager zsh
kdenetwork-filesharing firefox konsole simplescreenrecorder vlc papirus-icon-theme
materia-kde markdownpart gparted partitionmanager spectacle stacer svgpart
yakuake zeroconf-ioslave

# sudo flatpak install -y spotify

sudo systemctl enable sddm
/bin/echo -e "\e[1;32mREBOOTING IN 5..4..3..2..1..\e[0m"
sleep 5
reboot
