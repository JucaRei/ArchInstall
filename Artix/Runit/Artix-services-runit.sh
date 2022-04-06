#!/bin/bash

xdg-user-dirs-update

sleep 3

mkdir -pv Documents/workspace/{Github,Configs}

git clone --depth=1 https://github.com/JucaRei/ArchInstall $HOME/Documents/workspace/Configs/ArchInstall

cd $HOME/Documents/workspace/Configs/ArchInstall/Arch/Arch_pkgs
sudo pacman -U paru**.zst
sudo pacman -U hfsprogs**.zst
sudo pacman -U nosystemd-boot**.zst

paru -Syu

cd

paru -S netmount-runit zramen-runit fusesmb

# paru -S nvidia-tweaks nvidia-prime xf86-video-intel

sudo sed -i "s/#export ZRAM_COMP_ALGORITHM='lz4'/export ZRAM_COMP_ALGORITHM='zstd'/g" /etc/runit/sv/zramen/conf
sudo sed -i 's/#export ZRAM_SIZE=25/export ZRAM_SIZE=100/g' /etc/runit/sv/zramen/conf

sudo ln -s /etc/runit/sv/netmount /run/runit/service
sudo ln -s /etc/runit/sv/zramen /run/runit/service
