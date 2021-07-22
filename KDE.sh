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

sudo mkdir /etc/pacman.d/hooks
sudo touch /etc/pacman.d/hooks/50-bootbackup.hook
sudo bash -c 'echo "[Trigger]" >> /etc/pacman.d/hooks/50-bootbackup.hook'
sudo bash -c 'echo "Operation = Upgrade" >> /etc/pacman.d/hooks/50-bootbackup.hook'
sudo bash -c 'echo "Operation = Install" >> /etc/pacman.d/hooks/50-bootbackup.hook'
sudo bash -c 'echo "Operation = Remove" >> /etc/pacman.d/hooks/50-bootbackup.hook'
sudo bash -c 'echo "Type = Path" >> /etc/pacman.d/hooks/50-bootbackup.hook'
sudo bash -c 'echo "Target = boot/*" >> /etc/pacman.d/hooks/50-bootbackup.hook'
sudo bash -c 'echo "[Action]" >> /etc/pacman.d/hooks/50-bootbackup.hook'
sudo bash -c 'echo "Depends = rsync" >> /etc/pacman.d/hooks/50-bootbackup.hook'
sudo bash -c 'echo "Description = Backing up /boot..." >> /etc/pacman.d/hooks/50-bootbackup.hook'
sudo bash -c 'echo "When = PreTransaction" >> /etc/pacman.d/hooks/50-bootbackup.hook'
sudo bash -c 'echo "Exec = /usr/bin/rsync -a --delete /boot /.bootbackup" >> /etc/pacman.d/hooks/50-bootbackup.hook'

sudo touch /etc/pacman.d/hooks/clean_cache.hook
sudo bash -c 'echo "[Trigger]" >> /etc/pacman.d/hooks/clean_cache.hook'
sudo bash -c 'echo "Operation = Upgrade" >> /etc/pacman.d/hooks/clean_cache.hook'
sudo bash -c 'echo "Operation = Install" >> /etc/pacman.d/hooks/clean_cache.hook'
sudo bash -c 'echo "Operation = Remove" >> /etc/pacman.d/hooks/clean_cache.hook'
sudo bash -c 'echo "Type = Package" >> /etc/pacman.d/hooks/clean_cache.hook'
sudo bash -c 'echo "Target = *" >> /etc/pacman.d/hooks/clean_cache.hook'
sudo bash -c 'echo "[Action]" >> /etc/pacman.d/hooks/clean_cache.hook'
sudo bash -c 'echo "Description = Cleaning pacman cache..." >> /etc/pacman.d/hooks/clean_cache.hook'
sudo bash -c 'echo "When = PostTransaction" >> /etc/pacman.d/hooks/clean_cache.hook'
sudo bash -c 'echo "Exec = /usr/bin/paccache -rk 1" >> /etc/pacman.d/hooks/clean_cache.hook'

# sudo touch /etc/pacman.d/hooks/nvidia.hook
sudo touch /etc/pacman.d/hooks/90-mkinitcpio-dkms-linux.hook
sudo bash -c 'echo "[Trigger]" >> /etc/pacman.d/hooks/90-mkinitcpio-dkms-linux.hook'
sudo bash -c 'echo "Operation=Install" >> /etc/pacman.d/hooks/90-mkinitcpio-dkms-linux.hook'
sudo bash -c 'echo "Operation=Upgrade" >> /etc/pacman.d/hooks/90-mkinitcpio-dkms-linux.hook'
sudo bash -c 'echo "Operation=Remove" >> /etc/pacman.d/hooks/90-mkinitcpio-dkms-linux.hook'
sudo bash -c 'echo "Type=Package" >> /etc/pacman.d/hooks/90-mkinitcpio-dkms-linux.hook'
sudo bash -c 'echo "Target=nvidia-dkms" >> /etc/pacman.d/hooks/90-mkinitcpio-dkms-linux.hook'
sudo bash -c 'echo "Target=linux-zen" >> /etc/pacman.d/hooks/90-mkinitcpio-dkms-linux.hook'
sudo bash -c 'echo "# Change the linux part above and in the Exec line if a different kernel is used" >> /etc/pacman.d/hooks/90-mkinitcpio-dkms-linux.hook'
sudo bash -c 'echo "[Action]" >> /etc/pacman.d/hooks/90-mkinitcpio-dkms-linux.hook'
sudo bash -c 'echo "Description=Update nvidia dkms modules in Linux initcpio" >> /etc/pacman.d/hooks/90-mkinitcpio-dkms-linux.hook'
sudo bash -c 'echo "Depends=mkinitcpio" >> /etc/pacman.d/hooks/90-mkinitcpio-dkms-linux.hook'
sudo bash -c 'echo "When=PostTransaction" >> /etc/pacman.d/hooks/90-mkinitcpio-dkms-linux.hook'
sudo bash -c 'echo "NeedsTargets" >> /etc/pacman.d/hooks/90-mkinitcpio-dkms-linux.hook'
sudo bash -c  'echo \"Exec=/bin/sh -c "while read -r trg; do case $trg in linux-zen) exit 0; esac; done; /usr/bin/mkinitcpio -p linux-zen"\" >> /etc/pacman.d/90-mkinitcpio-dkms-linux'
sudo bash -c 'echo Exec=/bin/sh -c "\"while read -r trg; do case $trg in linux-zen) exit 0; esac; done; /usr/bin/mkinitcpio -p linux-zen"\" >> /etc/pacman.d/hooks/90-mkinitcpio-dkms-linux.hook'
# sudo bash -c 'echo Exec=sh -c "\"/usr/bin/mkinitcpio -p linux-zen"\" >> /etc/pacman.d/hooks/nvidia.hook'
# sudo bash -c 'echo Exec=sh -c "\"/usr/bin/mkinitcpio -p linux-zen && /usr/bin/mkinitcpio -p linux"\" >> /etc/pacman.d/hooks/nvidia.hook'

# KDE
sudo pikaur -S xorg sddm plasma konsole kdialog wget curl snapd dolphin okular smb4k ark kate kwrite kcalc spectacle krunner partitionmanager firefox-developer-edition vivaldi vivaldi-ffmpeg-codecs vivaldi-widevine vivaldi-update-ffmpeg-hook pavucontrol vlc stacer papirus-icon-theme materia-kde visual-studio-code-bin zsh pacman-contrib ttf-consolas-ligaturized ttf-fira-code ttf-jetbrains-mono font-victor-mono qimgv-light plasma5-applets-virtual-desktop-bar-git kvantum-qt5 grub-customizer breeze-hacked-cursor-theme

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
