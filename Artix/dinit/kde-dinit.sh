#!/bin/bash

#Options
aur_helper=true

#sudo timedatectl set-ntp true
hwclock --systohc

firewall-cmd --add-port=1025-65535/tcp --permanent
firewall-cmd --add-port=1025-65535/udp --permanent
firewall-cmd --reload

if [[ $aur_helper = true ]]; then
 cd /tmp
 git clone https://aur.archlinux.org/paru.git
 cd paru/
 makepkg -si --noconfirm
 cd ..
 rm -rf paru/
 cd
fi

# reflector -c Brazil -a 12 --sort rate --save /etc/pacman.d/mirrorlist
#paru -Syyy

#paru -S xf86-video-intel vulkan-intel mesa 
#paru -S nvidia-tweaks nvidia-settings


paru -Syu xorg-server xorg-server-xdmx xorg-xrdb xorg-xsetroot xorg-xprop xorg-xrefresh  xorg-fonts xorg-xdpyinfo xorg-xclipboard xorg-xcursorgen xorg-mkfontdir xorg-mkfontscale xorg-xcmsdb ttf-dejavu libxinerama xf86-input-libinput libinput-gestures xorg-setxkbmap exfat-utils xorg-xauth xorg-xrandr xorg-fonts-misc terminus-font dejavu-fonts-ttf btop

# KDE
#paru -S sddm sddm-dinit plasma-meta wsdd2 glow konsole exa duf kdialog plasma5-applets-eventcalendar wget curl dolphin okular wsdd2 ark kate kwrite kcalc spectacle krunner partitionmanager firefox-developer-edition microsoft-edge-stable-bin pavucontrol mpv brave-bin stacer papirus-icon-theme materia-kde visual-studio-code-bin zsh pacman-contrib ttf-consolas-ligaturized ttf-fira-code ttf-jetbrains-mono font-victor-mono qimgv-light plasma5-applets-virtual-desktop-bar-git kvantum-qt5 grub-customizer breeze-hacked-cursor-theme

paru -S xorg lightdm lightdm-dinit lightdm-slick-greeter lightdm-gtk-greeter-settings xfce4 xfce4-goodies vivaldi vivaldi-ffmpeg-codecs vivaldi-widevine vivaldi-update-ffmpeg-hook firefox-esr visual-studio-code-bin


# Nvidia card
paru -S --needed nvidia-dkms nvidia-utils lib32-nvidia-utils nvidia-settings vulkan-icd-loader lib32-vulkan-icd-loader nvidia-tweaks

# Intel
paru -S --needed lib32-mesa vulkan-intel lib32-vulkan-intel vulkan-icd-loader lib32-vulkan-icd-loader

#ferdi freezer
# sudo snap install beekeeper-studio postbird

# Enable KDE
#ln -s /etc/dinit.d/sddm /etc/dinit.d/boot.d/
ln -s /etc/dinit.d/lightdm /etc/dinit.d/boot.d/

#Enable Cinnamon
# sudo systemctl enable lightdm

/bin/echo -e "\e[1;32mREBOOTING IN 5..4..3..2..1..\e[0m"
#sleep 5
#reboot


#btrfs i915 crc32c-intel nvidia nvidia_modeset nvidia_uvm nvidia_drm
