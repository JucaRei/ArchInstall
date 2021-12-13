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


### ZEN KERNEL

sudo mkdir -pv /etc/pacman.d/hooks
sudo cat << EOF > /etc/pacman.d/hooks/50-bootbackup.hook
[Trigger]
Operation = Upgrade
Operation = Install
Operation = Remove
Type = Path
Target = boot/*
[Action]
Depends = rsync
Description = Backing up /boot...
When = PreTransaction
Exec = /usr/bin/rsync -a --delete /boot /.bootbackup
EOF

sudo cat << EOF > /etc/pacman.d/hooks/clean_cache.hook
[Trigger]
Operation = Upgrade
Operation = Install
Operation = Remove
Type = Package
Target = *
[Action]
Description = Cleaning pacman cache...
When = PostTransaction
Exec = /usr/bin/paccache -rk 1
EOF


sudo cat << EOF > /etc/pacman.d/hooks/90-mkinitcpio-dkms-linux.hook
[Trigger]
Operation=Install 
Operation=Upgrade 
Operation=Remove 
Type=Package
Target=nvidia-dkms 
Target=linux-zen
# Change the linux part above and in the Exec line if a different kernel is used 
[Action] 
Description=Update nvidia dkms modules in Linux initcpio
Depends=mkinitcpio
When=PostTransaction 
NeedsTargets
Exec=/bin/sh -c while read -r trg; do case $trg in linux-zen) exit 0; esac; done; /usr/bin/mkinitcpio -p linux-zen
Exec=/bin/sh -c while read -r trg; do case $trg in linux-zen) exit 0; esac; done; /usr/bin/mkinitcpio -p linux-zen
EOF

# KDE
sudo pikaur -S xorg sddm plasma glow konsole kdialog plasma5-applets-eventcalendar wget curl snapd dolphin okular smb4k ark kate kwrite kcalc spectacle krunner partitionmanager firefox-developer-edition pavucontrol vlc stacer papirus-icon-theme materia-kde visual-studio-code-bin zsh pacman-contrib ttf-consolas-ligaturized ttf-fira-code ttf-jetbrains-mono font-victor-mono qimgv-light plasma5-applets-virtual-desktop-bar-git kvantum-qt5 grub-customizer exa bat duf microsoft-edge-stable-bin

#ferdi freezer
# sudo snap install beekeeper-studio postbird

# Cinnamon
#sudo pikaur -S xorg lightdm lightdm-gtk-greeter lightdm-gtk-greeter-settings arc-gtk-theme arc-icon-theme vlc xed xreader metacity gnome-shell firefox-developer-edition vivaldi vivaldi-ffmpeg-codecs vivaldi-widevine vivaldi-update-ffmpeg-hook visual-studio-code-bin zsh pacman-contrib ttf-consolas-ligaturized ttf-fira-code ttf-jetbrains-mono font-victor-mono optimus-manager optimus-manager-qt qimgv-light appimagelauncher grub-customizer breeze-hacked-cursor-theme suru-plus-dark-git

# if you want to install snapper to create snapshots for backup
# sudo pikaur -S snapper snapper-gui-git snap-pac-grub rsync

# if you want to install timeshift to create snapshots for backup
# sudo pikaur -S timeshift-bin timeshift-autosnap

# sudo systemctl enable --now snapper-timeline.timer
# sudo systemctl enable --now snapper-cleanup.timer

# Enable KDE
sudo systemctl enable sddm

#Enable Cinnamon
# sudo systemctl enable lightdm

/bin/echo -e "\e[1;32mREBOOTING IN 5..4..3..2..1..\e[0m"
#sleep 5
#reboot
