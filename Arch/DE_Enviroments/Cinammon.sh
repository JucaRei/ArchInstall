#!/bin/bash

# sudo timedatectl set-ntp true
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
# sudo touch /etc/pacman.d/hooks/50-bootbackup.hook
# sudo bash -c 'echo "[Trigger]" >> /etc/pacman.d/hooks/50-bootbackup.hook'
# sudo bash -c 'echo "Operation = Upgrade" >> /etc/pacman.d/hooks/50-bootbackup.hook'
# sudo bash -c 'echo "Operation = Install" >> /etc/pacman.d/hooks/50-bootbackup.hook'
# sudo bash -c 'echo "Operation = Remove" >> /etc/pacman.d/hooks/50-bootbackup.hook'
# sudo bash -c 'echo "Type = Path" >> /etc/pacman.d/hooks/50-bootbackup.hook'
# sudo bash -c 'echo "Target = boot/*" >> /etc/pacman.d/hooks/50-bootbackup.hook'
# sudo bash -c 'echo "[Action]" >> /etc/pacman.d/hooks/50-bootbackup.hook'
# sudo bash -c 'echo "Depends = rsync" >> /etc/pacman.d/hooks/50-bootbackup.hook'
# sudo bash -c 'echo "Description = Backing up /boot..." >> /etc/pacman.d/hooks/50-bootbackup.hook'
# sudo bash -c 'echo "When = PreTransaction" >> /etc/pacman.d/hooks/50-bootbackup.hook'
# sudo bash -c 'echo "Exec = /usr/bin/rsync -a --delete /boot /.bootbackup" >> /etc/pacman.d/hooks/50-bootbackup.hook'

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
# sudo bash -c 'echo "[Trigger]" >> /etc/pacman.d/hooks/90-mkinitcpio-dkms-linux.hook'
# sudo bash -c 'echo "Operation=Install" >> /etc/pacman.d/hooks/90-mkinitcpio-dkms-linux.hook'
# sudo bash -c 'echo "Operation=Upgrade" >> /etc/pacman.d/hooks/90-mkinitcpio-dkms-linux.hook'
# sudo bash -c 'echo "Operation=Remove" >> /etc/pacman.d/hooks/90-mkinitcpio-dkms-linux.hook'
# sudo bash -c 'echo "Type=Package" >> /etc/pacman.d/hooks/90-mkinitcpio-dkms-linux.hook'
# sudo bash -c 'echo "Target=nvidia-dkms" >> /etc/pacman.d/hooks/90-mkinitcpio-dkms-linux.hook'
# sudo bash -c 'echo "Target=linux-zen" >> /etc/pacman.d/hooks/90-mkinitcpio-dkms-linux.hook'
# sudo bash -c 'echo "# Change the linux part above and in the Exec line if a different kernel is used" >> /etc/pacman.d/hooks/90-mkinitcpio-dkms-linux.hook'
# sudo bash -c 'echo "[Action]" >> /etc/pacman.d/hooks/90-mkinitcpio-dkms-linux.hook'
# sudo bash -c 'echo "Description=Update nvidia dkms modules in Linux initcpio" >> /etc/pacman.d/hooks/90-mkinitcpio-dkms-linux.hook'
# sudo bash -c 'echo "Depends=mkinitcpio" >> /etc/pacman.d/hooks/90-mkinitcpio-dkms-linux.hook'
# sudo bash -c 'echo "When=PostTransaction" >> /etc/pacman.d/hooks/90-mkinitcpio-dkms-linux.hook'
# sudo bash -c 'echo "NeedsTargets" >> /etc/pacman.d/hooks/90-mkinitcpio-dkms-linux.hook'
# sudo bash -c 'echo \"Exec=/bin/sh -c "while read -r trg; do case $trg in linux-zen) exit 0; esac; done; /usr/bin/mkinitcpio -p linux-zen"\" >> /etc/pacman.d/90-mkinitcpio-dkms-linux'
# sudo bash -c 'echo Exec=/bin/sh -c "\"while read -r trg; do case $trg in linux-zen) exit 0; esac; done; /usr/bin/mkinitcpio -p linux-zen"\" >> /etc/pacman.d/hooks/90-mkinitcpio-dkms-linux.hook'
# sudo bash -c 'echo Exec=sh -c "\"/usr/bin/mkinitcpio -p linux-zen"\" >> /etc/pacman.d/hooks/nvidia.hook'
# sudo bash -c 'echo Exec=sh -c "\"/usr/bin/mkinitcpio -p linux-zen && /usr/bin/mkinitcpio -p linux"\" >> /etc/pacman.d/hooks/nvidia.hook'

#ferdi freezer
# sudo snap install beekeeper-studio postbird

# Cinnamon
pikaur -S xorg-server xorg-xrdb xorg-xsetroot xorg-xprop xorg-xrefresh xorg-fonts xorg-xdpyinfo xorg-xclipboard xorg-xcursorgen xorg-mkfontdir xorg-mkfontscale xorg-xcmsdb libxinerama xf86-input-libinput libinput-gestures xorg-setxkbmap xorg-xauth xorg-xrandr xorg-fonts-misc terminus-font  btop
# pikaur -S xorg lightdm lightdm-gtk-greeter lightdm-gtk-greeter-settings arc-gtk-theme arc-icon-theme mpv xed xreader metacity gnome-shell firefox-developer-edition vivaldi vivaldi-ffmpeg-codecs vivaldi-widevine vivaldi-update-ffmpeg-hook visual-studio-code-bin zsh ttf-consolas-ligaturized ttf-fira-code ttf-jetbrains-mono font-victor-mono optimus-manager optimus-manager-qt appimagelauncher grub-customizer breeze-hacked-cursor-theme suru-plus-dark-git
pikaur -S cinnamon zramd gnome-terminal lightdm lightdm-slick-greeter gedit gedit-plugins gnome-system-monitor rhythmbox nemo-fileroller nemo-terminal nemo-preview pix faenza-icon-theme arc-gtk-theme arc-icon-theme gnome-mpv xreader firefox-esr vivaldi vivaldi-ffmpeg-codecs vivaldi-widevine vivaldi-update-ffmpeg-hook visual-studio-code-bin optimus-manager optimus-manager-qt appimagelauncher grub-customizer breeze-hacked-cursor-theme suru-plus-dark-git

sudo sed -i 's/#greeter-session=example-gtk-gnome/greeter-session=lightdm-slick-greeter/g' /etc/lightdm/lightdm.conf


# Nvidia card
pikaur -S --needed nvidia-dkms nvidia-utils lib32-nvidia-utils nvidia-settings vulkan-icd-loader lib32-vulkan-icd-loader nvidia-tweaks

# Intel
pikaur -S --needed lib32-mesa vulkan-intel lib32-vulkan-intel vulkan-icd-loader lib32-vulkan-icd-loader

# if you want to install snapper to create snapshots for backup
# sudo pikaur -S snapper snapper-gui-git snap-pac-grub rsync

# if you want to install timeshift to create snapshots for backup
# sudo pikaur -S timeshift-bin timeshift-autosnap

# sudo systemctl enable --now snapper-timeline.timer
# sudo systemctl enable --now snapper-cleanup.timer

#Enable Cinnamon
sudo systemctl enable lightdm

/bin/echo -e "\e[1;32mREBOOTING IN 5..4..3..2..1..\e[0m"
# sleep 5
# reboot
