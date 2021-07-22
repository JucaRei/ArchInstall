#!/bin/bash

sudo timedatectl set-ntp true
sudo hwclock --systohc

sudo firewall-cmd --add-port=1025-65535/tcp --permanent
sudo firewall-cmd --add-port=1025-65535/udp --permanent
sudo firewall-cmd --reload

reflector -c Brazil -a 12 --sort rate --save /etc/pacman.d/mirrorlist
sudo pacman -Syy

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
sudo pikaur -S xorg-server1.19-git xorg-xinit lxde leafpad gtkmm3 archlinux-wallpaper openbox ttf-dejavu ttf-liberation vlc xed xreader metacity gnome-shell firefox-developer-edition vivaldi vivaldi-ffmpeg-codecs vivaldi-widevine vivaldi-update-ffmpeg-hook visual-studio-code-bin zsh pacman-contrib ttf-consolas-ligaturized ttf-fira-code ttf-jetbrains-mono font-victor-mono optimus-manager optimus-manager-qt qimgv-light appimagelauncher grub-customizer breeze-hacked-cursor-theme suru-plus-dark-git

#Enable LXDE
sudo systemctl enable lxdm

/bin/echo -e "\e[1;32mREBOOTING IN 5..4..3..2..1..\e[0m"
sleep 5
reboot
