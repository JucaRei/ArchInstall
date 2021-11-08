#!/bin/bash

#Options
aur_helper=true

sudo timedatectl set-ntp true
sudo hwclock --systohc

sudo firewall-cmd --add-port=1025-65535/tcp --permanent
sudo firewall-cmd --add-port=1025-65535/udp --permanent
sudo firewall-cmd --reload

if [[ $aur_helper = true ]]; then
  cd /tmp
  git clone https://aur.archlinux.org/paru.git
  cd paru/
  makepkg -si --noconfirm
  cd
fi

# reflector -c Brazil -a 12 --sort rate --save /etc/pacman.d/mirrorlist
paru -Syyy

paru -S xf86-video-intel xorg --ignore xorg-server-xdmx
paru -S nvidia-lts nvidia-utils nvidia-settings

# KDE
paru -S xorg sddm sddm-runit plasma konsole kdialog plasma5-applets-eventcalendar wget curl dolphin okular smb4k ark kate kwrite kcalc spectacle krunner partitionmanager firefox-developer-edition microsoft-edge-stable-bin pavucontrol celluloid stacer papirus-icon-theme materia-kde visual-studio-code-bin zsh pacman-contrib ttf-consolas-ligaturized ttf-fira-code ttf-jetbrains-mono font-victor-mono qimgv-light plasma5-applets-virtual-desktop-bar-git kvantum-qt5 grub-customizer breeze-hacked-cursor-theme

#ferdi freezer
# sudo snap install beekeeper-studio postbird

# Enable KDE
sudo ln -s /etc/runit/sv/sddm /run/runit/service

#Enable Cinnamon
# sudo systemctl enable lightdm

/bin/echo -e "\e[1;32mREBOOTING IN 5..4..3..2..1..\e[0m"
sleep 5
reboot
