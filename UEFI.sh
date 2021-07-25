#!/bin/bash

ln -sf /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime
hwclock --systohc
sed -i '177s/.//' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" >>/etc/locale.conf
echo "KEYMAP=br-abnt" >>/etc/vconsole.conf
# echo "KEYMAP=us-intl" >>/etc/vconsole.conf
# echo "KEYMAP=mac-us" >>/etc/vconsole.conf
echo "archnitro" >>/etc/hostname
echo "127.0.0.1 localhost" >>/etc/hosts
echo "::1       localhost" >>/etc/hosts
echo "127.0.1.1 archnitro.localdomain archnitro" >>/etc/hosts
echo root:200291 | chpasswd

# You can add xorg to the installation packages, I usually add it at the DE or WM install script
# You can remove the tlp package if you are installing on a desktop or vm
# not working correctely - pipewire pipewire-alsa pipewire-pulse pipewire-jack
pacman -S grub grub-btrfs efibootmgr networkmanager network-manager-applet dialog wpa_supplicant linux-zen-headers pacman-contrib base-devel avahi xdg-user-dirs xdg-utils gvfs gvfs-smb nfs-utils inetutils dnsutils bluez bluez-utils alsa-utils pipewire pipewire-alsa pipewire-pulse pipewire-jack bash-completion cups hplip openssh rsync acpi acpi_call tlp virt-manager qemu qemu-arch-extra vde2 edk2-ovmf bridge-utils dnsmasq vde2 ebtables openbsd-netcat iptables-nft ipset firewalld flatpak sof-firmware nss-mdns acpid os-prober ntfs-3g

# OLDMAC INSTALL BASE
# pacman -S efibootmgr networkmanager network-manager-applet wireless_tools wpa_supplicant dialog mtools dosfstools base-devel pacman-contrib reflector bluez bluez-utils pulseaudio pulseaudio-bluetooth alsa-utils xdg-utils xdg-user-dirs bash-completion zsh ntfs-3g firewalld cups tlp rsync acpi acpi_call sof-firmware acpid gvfs gvfs-smb nfs-utils inetutils dnsutils

# pacman -S --noconfirm xf86-video-amdgpu
pacman -S xf86-video-intel

#Open-Source Drivers (Oldpc)
# pacman -S xf86-video-nouveau

# nvidia if you are using common linux kernel
pacman -S nvidia-dkms nvidia-utils nvidia-settings

# OLDMAC (late 2008) lts kernel nvidia-340xx-lts-dkms
# sudo pacman -S xf86-video-nouveau xf86-video-intel xorg-server xorg-server-common
# pacman -S nvidia-340xx-lts
# pacman -S xf86-video-intel xf86-video-nouveau

# Old pc only works with xorg-server1.19-git and max kernel 5.4
# sudo pacman -S nvidia-304xx

# OLDPC don`t need it
grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

systemctl enable NetworkManager
systemctl enable bluetooth
systemctl enable cups.service
# OLDPC don`t need it
systemctl enable sshd
# OLDPC don`t need it
systemctl enable avahi-daemon
systemctl enable tlp # You can comment this command out if you didn't install tlp, see above
systemctl enable reflector.timer
systemctl enable fstrim.timer
# OLDPC don`t need it
systemctl enable libvirtd
systemctl enable firewalld
systemctl enable acpid

useradd -m junior
echo junior:200291 | chpasswd
usermod -aG libvirt junior

echo "junior ALL=(ALL) ALL" >>/etc/sudoers.d/junior

printf "\e[1;32mDone! Type exit, umount -a and reboot.\e[0m"
