#!/bin/bash

sudo timedatectl set-ntp true
sudo hwclock --systohc

sudo firewall-cmd --add-port=1025-65535/tcp --permanent
sudo firewall-cmd --add-port=1025-65535/udp --permanent
sudo firewall-cmd --reload

reflector -c Brazil -a 12 --sort rate --save /etc/pacman.d/mirrorlist

git clone https://aur.archlinux.org/pikaur.git
cd pikaur/
makepkg -si --noconfirm

# pikaur -S --noconfirm system76-power
# sudo systemctl enable --now system76-power
# sudo system76-power graphics integrated
# pikaur -S --noconfirm auto-cpufreq
# sudo systemctl enable --now auto-cpufreq

# sudo mkdir /etc/pacman.d/hooks
# sudo touch /etc/pacman.d/hooks/50-bootbackup.hook
# sudo echo "[Trigger]" >> /etc/pacman.d/hooks/50-bootbackup.hook
# sudo echo "Operation = Upgrade" >> /etc/pacman.d/hooks/50-bootbackup.hook
# sudo echo "Operation = Install" >> /etc/pacman.d/hooks/50-bootbackup.hook
# sudo echo "Operation = Remove" >> /etc/pacman.d/hooks/50-bootbackup.hook
# sudo echo "Type = Path" >> /etc/pacman.d/hooks/50-bootbackup.hook
# sudo echo "Target = boot/*" >> /etc/pacman.d/hooks/50-bootbackup.hook
# sudo echo "[Action]" >> /etc/pacman.d/hooks/50-bootbackup.hook
# sudo echo "Depends = rsync" >> /etc/pacman.d/hooks/50-bootbackup.hook
# sudo echo "Description = Backing up /boot..." >> /etc/pacman.d/hooks/50-bootbackup.hook
# sudo echo "When = PreTransaction" >> /etc/pacman.d/hooks/50-bootbackup.hook
# sudo echo "Exec = /usr/bin/rsync -a --delete /boot /.bootbackup" >> /etc/pacman.d/hooks/50-bootbackup.hook

# sudo touch /etc/pacman.d/hooks/clean_cache.hook
# sudo echo "[Trigger]" >> /etc/pacman.d/hooks/clean_cache.hook
# sudo echo "Operation = Upgrade" >> /etc/pacman.d/hooks/clean_cache.hook
# sudo echo "Operation = Install" >> /etc/pacman.d/hooks/clean_cache.hook
# sudo echo "Operation = Remove" >> /etc/pacman.d/hooks/clean_cache.hook
# sudo echo "Type = Package" >> /etc/pacman.d/hooks/clean_cache.hook
# sudo echo "Target = *" >> /etc/pacman.d/hooks/clean_cache.hook

# sudo echo "[Action]" >> /etc/pacman.d/hooks/clean_cache.hook
# sudo echo "Description = Cleaning pacman cache..." >> /etc/pacman.d/hooks/clean_cache.hook
# sudo echo "When = PostTransaction" >> /etc/pacman.d/hooks/clean_cache.hook
# sudo echo "Exec = /usr/bin/paccache -rk 1" >> /etc/pacman.d/hooks/clean_cache.hook

# sudo touch /etc/pacman.d/hooks/nvidia.hook
# sudo echo "[Trigger]" >> /etc/pacman.d/hooks/nvidia.hook
# sudo echo "Operation=Install" >> /etc/pacman.d/hooks/nvidia.hook
# sudo echo "Operation=Upgrade" >> /etc/pacman.d/hooks/nvidia.hook
# sudo echo "Operation=Remove" >> /etc/pacman.d/hooks/nvidia.hook
# sudo echo "Type=Package" >> /etc/pacman.d/hooks/nvidia.hook
# sudo echo "Target=nvidia-dkms" >> /etc/pacman.d/hooks/nvidia.hook
# sudo echo "Target=linux-zen" >> /etc/pacman.d/hooks/nvidia.hook
# sudo echo "# Change the linux part above and in the Exec line if a different kernel is used" >> /etc/pacman.d/hooks/nvidia.hook

# sudo echo "[Action]" >> /etc/pacman.d/hooks/nvidia.hook
# sudo echo "Description=Update Nvidia module in initcpio" >> /etc/pacman.d/hooks/nvidia.hook
# sudo echo "Depends=mkinitcpio" >> /etc/pacman.d/hooks/nvidia.hook
# sudo echo "When=PostTransaction" >> /etc/pacman.d/hooks/nvidia.hook
# sudo echo "NeedsTargets" >> /etc/pacman.d/hooks/nvidia.hook
# sudo echo "Exec=/bin/sh -c 'while read -r trg; do case $trg in linux) exit 0; esac; done; /usr/bin/mkinitcpio -P'" >> /etc/pacman.d/hooks/nvidia.hook

# visual-studio-code-git zsh pacman-contrib snapper snapper-gui-git snap-pac-grub rsync 

sudo pikaur -S xorg sddm plasma konsole wget curl dolphin ark kate kwrite kcalc spectacle krunner partitionmanager firefox vlc papirus-icon-theme materia-kde 



# sudo systemctl enable --now snapper-timeline.timer
# sudo systemctl enable --now snapper-cleanup.timer



sudo systemctl enable sddm
/bin/echo -e "\e[1;32mREBOOTING IN 5..4..3..2..1..\e[0m"
sleep 5
reboot
