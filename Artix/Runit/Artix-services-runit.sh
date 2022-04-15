#!/bin/bash

xdg-user-dirs-update

sleep 3

mkdir -pv Documents/workspace/{Github,Configs}

mkdir -pv $HOME/.runit/{services,runsvdir}

git clone --depth=1 https://github.com/JucaRei/ArchInstall $HOME/Documents/workspace/Configs/ArchInstall

sleep 5

cd $HOME/Documents/workspace/Configs/ArchInstall/Arch/Arch_pkgs
sudo pacman -U paru**.zst --noconfirm
sudo pacman -U pikaur**.zst --noconfirm
sudo pacman -U hfsprogs**.zst --noconfirm
sudo pacman -U nosystemd-boot**.zst --noconfirm

paru -Syu

cd

# EarlyOOM checks the amount of available memory & swap periodically & kills memory according to the set pre-configured value. You can install it with earlyoom-runit.

# paru -S netmount-runit zramen-runit fusesmb shell-color-scripts starship lxpolkit-git bash-zsh-insulter deadbeef mpv redshift yt-dlp earlyoom earlyoom-runit ananicy-cpp-runit tlp tlp-runit
paru -S netmount-runit fusesmb shell-color-scripts pavucontrol gvfs-smb gvfs-nfs gvfs-goa gvfs-mtp gvfs-afc udevil light gnome-keyring autofs starship lxpolkit-git bash-zsh-insulter deadbeef mpv redshift yt-dlp earlyoom earlyoom-runit ananicy-cpp-runit tlp tlp-runit

paru -S nvidia-tweaks nvidia-settings

sudo sed -i 's/allowed_types = $KNOWN_FILESYSTEMS, file/allowed_types = $KNOWN_FILESYSTEMS, file, cifs, nfs, sshfs, curlftpfs, davfs/g' /etc/udevil/udevil.conf

# paru -S optimus-manager-git optimus-manager-runit bbswitch lightdm-optimus-runit

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

#sudo sed -i "s/#export ZRAM_COMP_ALGORITHM='lz4'/export ZRAM_COMP_ALGORITHM='zstd'/g" /etc/runit/sv/zramen/conf
#sudo sed -i 's/#export ZRAM_SIZE=25/export ZRAM_SIZE=100/g' /etc/runit/sv/zramen/conf

sudo touch /etc/default/earlyoom
sudo cat <<EOF >/etc/default/earlyoom
# Default settings for earlyoom. This file is sourced by /bin/sh from
# /etc/init.d/earlyoom or by systemd from earlyoom.service.

# Options to pass to earlyoom
# EARLYOOM_ARGS="-r 3600 -n --avoid '(^|/)(init|systemd|Xorg|sshd)$'"

EARLYOOM_ARGS=" -m 96,92 -s 99,99 -r 5 -n --avoid '(^|/)(runit|Xorg|sshd)$'" #change the runit according to your init

# Examples:

# Print memory report every second instead of every minute
# EARLYOOM_ARGS="-r 1"

# Available minimum memory 5%
# EARLYOOM_ARGS="-m 5"

# Available minimum memory 15% and free minimum swap 5%
# EARLYOOM_ARGS="-m 15 -s 5"
                                                                                                                       
# Avoid killing processes whose name matches this regexp                                                               
# EARLYOOM_ARGS="--avoid '(^|/)(init|X|sshd|firefox)$'"                                                                
                                                                                                                       
# See more at 'earlyoom -h'  
EOF

sudo chmod +x /etc/runit/sv/ananicy-cpp/run
sudo chmod +x /etc/runit/sv/ananicy-cpp/finish
sudo chmod +x /etc/runit/sv/ananicy-cpp/start

sudo ln -s /etc/runit/sv/netmount /run/runit/service
sudo ln -s /etc/runit/sv/earlyoom /run/runit/service
sudo ln -s /etc/runit/sv/user-services /run/runit/service
# sudo ln -s /etc/runit/sv/zramen /run/runit/service
sudo ln -s /etc/runit/sv/ananicy-cpp /run/runit/service
sudo ln -s /etc/runit/sv/tlp /run/runit/service
# sudo ln -s /etc/runit/sv/optimus-manager /run/runit/service
# sudo ln -s /etc/runit/sv/lightdm-optimus /run/runit/service

sudo sed -i 's/MODULES=()/MODULES=(btrfs i915 crc32c-intel nvidia nvidia_modeset nvidia_uvm nvidia_drm)/g' /etc/mkinitcpio.conf
sudo sed -i 's/HOOKS=(base udev autodetect modconf block filesystems keyboard fsck)/HOOKS=(base udev autodetect modconf block filesystems keyboard fsck btrfs grub-btrfs-overlayfs)/g' /etc/mkinitcpio.conf
sudo sed -i 's/#COMPRESSION="zstd"/COMPRESSION="zstd"/g' /etc/mkinitcpio.conf

sudo mkinitcpio -P linux-lts

cp -r $HOME/Documents/workspace/Configs/ArchInstall/Dots-WM/Bspwm-Nitro/bashrc ~/.bashrc

source ~/.bashrc
