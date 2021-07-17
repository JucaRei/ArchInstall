#!/bin/bash

ln -sf /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime
hwclock --systohc
sed -i '177s/.//' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" >>/etc/locale.conf
echo "KEYMAP=br-abnt" >>/etc/vconsole.conf
echo "archnitro" >>/etc/hostname
echo "127.0.0.1 localhost" >>/etc/hosts
echo "::1       localhost" >>/etc/hosts
echo "127.0.1.1 archnitro.localdomain archnitro" >>/etc/hosts
echo root:200291 | chpasswd

# You can add xorg to the installation packages, I usually add it at the DE or WM install script
# You can remove the tlp package if you are installing on a desktop or vm
# not working correctely - pipewire pipewire-alsa pipewire-pulse pipewire-jack
pacman -S grub grub-btrfs efibootmgr networkmanager network-manager-applet dialog wpa_supplicant linux-zen-headers base-devel avahi xdg-user-dirs xdg-utils gvfs gvfs-smb nfs-utils inetutils dnsutils bluez bluez-utils alsa-utils pipewire pipewire-alsa pipewire-pulse pipewire-jack bash-completion cups hplip openssh rsync acpi acpi_call tlp virt-manager qemu qemu-arch-extra edk2-ovmf bridge-utils dnsmasq vde2 openbsd-netcat iptables-nft ipset firewalld flatpak sof-firmware nss-mdns acpid os-prober ntfs-3g

# pacman -S --noconfirm xf86-video-amdgpu
pacman -S xf86-video-intel

# nvidia if you are using common linux kernel
pacman -S nvidia-dkms nvidia-utils nvidia-settings

grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

systemctl enable NetworkManager
systemctl enable bluetooth
systemctl enable cups.service
systemctl enable sshd
systemctl enable avahi-daemon
systemctl enable tlp # You can comment this command out if you didn't install tlp, see above
systemctl enable reflector.timer
systemctl enable fstrim.timer
systemctl enable libvirtd
systemctl enable firewalld
systemctl enable acpid

useradd -m junior
echo junior:200291 | chpasswd
usermod -aG libvirt junior

echo "junior ALL=(ALL) ALL" >>/etc/sudoers.d/junior

printf "\e[1;32mDone! Type exit, umount -a and reboot.\e[0m"
