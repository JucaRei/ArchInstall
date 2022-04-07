#!/bin/bash

xdg-user-dirs-update

sleep 3

mkdir -pv Documents/workspace/{Github,Configs}

git clone --depth=1 https://github.com/JucaRei/ArchInstall $HOME/Documents/workspace/Configs/ArchInstall

cd $HOME/Documents/workspace/Configs/ArchInstall/Arch/Arch_pkgs
sudo pacman -U paru**.zst --noconfirm
sudo pacman -U pikaur**.zst --noconfirm
sudo pacman -U hfsprogs**.zst --noconfirm
sudo pacman -U nosystemd-boot**.zst --noconfirm

paru -Syu

cd

paru -S netmount-runit zramen-runit fusesmb shell-color-scripts starship lxpolkit-git bash-zsh-insulter deadbeef mpv redshift yt-dlp

# sudo pacman -S nvidia-tweaks nvidia-settings optimus-manager-git optimus-manager-runit bbswitch lightdm-optimus-runit

git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.9.0

# paru -S nvidia-tweaks nvidia-prime xf86-video-intel

pikaur -S profile-sync-daemon
git clone --depth=1 https://github.com/madand/runit-services
cd runit-services
sudo mv psd /etc/runit/sv && sudo mv redshift /etc/runit/sv && sudo mv picom /etc/runit/sv && sudo mv colord /etc/runit/sv
sudo ln -sfv /etc/runit/sv/psd /run/runit/service
sudo ln -sfv /etc/runit/sv/picom /run/runit/service
sudo ln -sfv /etc/runit/sv/colord /run/runit/service
sudo ln -sfv /etc/runit/sv/redshift /run/runit/service
# sudo sv start psd
# sudo sv start picom
# sudo sv start redshift
# sudo sv start colord

sudo sed -i "s/#export ZRAM_COMP_ALGORITHM='lz4'/export ZRAM_COMP_ALGORITHM='zstd'/g" /etc/runit/sv/zramen/conf
sudo sed -i 's/#export ZRAM_SIZE=25/export ZRAM_SIZE=100/g' /etc/runit/sv/zramen/conf

sudo ln -s /etc/runit/sv/netmount /run/runit/service
sudo ln -s /etc/runit/sv/zramen /run/runit/service
# sudo ln -s /etc/runit/sv/optimus-manager /run/runit/service
# sudo ln -s /etc/runit/sv/lightdm-optimus /run/runit/service

sudo sed -i 's/MODULES=()/MODULES=(btrfs i915 crc32c-intel nvidia nvidia_modeset nvidia_uvm nvidia_drm)/g' /etc/mkinitcpio.conf
sudo sed -i 's/HOOKS=(base udev autodetect modconf block filesystems keyboard fsck)/HOOKS=(base udev autodetect modconf block filesystems keyboard fsck btrfs grub-btrfs-overlayfs)/g' /etc/mkinitcpio.conf
sudo sed -i 's/#COMPRESSION="zstd"/COMPRESSION="zstd"/g' /etc/mkinitcpio.conf

sudo mkinitcpio -P linux-lts

cp -r $HOME/Documents/workspace/Configs/ArchInstall/Dots-WM/Bspwm-Nitro/bashrc ~/.bashrc

source ~/.bashrc
