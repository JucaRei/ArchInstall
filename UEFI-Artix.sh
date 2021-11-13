#!/bin/bash

ln -sf /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime
hwclock --systohc
sed -i '177s/.//' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" >>/etc/locale.conf
echo "KEYMAP=br-abnt2" >>/etc/vconsole.conf
# echo "KEYMAP=us-intl" >>/etc/vconsole.conf
# echo "KEYMAP=mac-us" >>/etc/vconsole.conf
echo "archnitro" >>/etc/hostname
echo "127.0.0.1 localhost" >>/etc/hosts
echo "::1       localhost" >>/etc/hosts
echo "127.0.1.1 archnitro.localdomain archnitro" >>/etc/hosts
echo root:200291 | chpasswd

pacman -S artix-archlinux-support

# ADD Repos

echo "[extra]" >>/etc/pacman.conf
echo "Include = /etc/pacman.d/mirrorlist-arch" >>/etc/pacman.conf

echo "[community]" >>/etc/pacman.conf
echo "Include = /etc/pacman.d/mirrorlist-arch" >>/etc/pacman.conf

echo "[multilib]" >>/etc/pacman.conf
echo "Include = /etc/pacman.d/mirrorlist-arch" >>/ehwtc/pacman.conf

echo "[universe]" >>/etc/pacman.conf
echo "Server = https://universe.artixlinux.org/$arch" >>/etc/pacman.conf
echo "Server = https://mirror1.artixlinux.org/universe/$arch" >>/etc/pacman.conf
echo "Server = https://mirror.pascalpuffke.de/artix-universe/$arch" >>/etc/pacman.conf
echo "Server = https://artixlinux.qontinuum.space:4443/universe/os/$arch" >>/etc/pacman.conf
echo "Server = https://mirror.alphvino.com/artix-universe/$arch" >>/etc/pacman.conf

echo "[omniverse]" >>/etc/pacman.conf
echo "Server = http://omniverse.artixlinux.org/$arch" >>/etc/pacman.conf

pacman-key --populate archlinux

pacman -S grub grub-btrfs efibootmgr networkmanager networkmanager-runit network-manager-applet ntp ntp-runit dialog wpa_supplicant wpa_supplicant-runit pacman-contrib avahi avahi-runit xdg-user-dirs xdg-utils gvfs gvfs-smb nfs-utils inetutils dnsutils bluez bluez-runit bluez-utils pulseaudio-bluetooth pulseaudio-alsa pulseaudio-equalizer pulseaudio-jack alsa-utils alsa-utils-runit bash-completion exfat-utils cups cups-runit hplip openssh openssh-runit rsync rsync-runit acpi acpid acpi_call tlp tlp-runit virt-manager qemu qemu-guest-agent-runit qemu-arch-extra vde2 edk2-ovmf bridge-utils dnsmasq dnsmasq-runit vde2 ebtables openbsd-netcat iptables-nft ipset firewalld firewalld-runit flatpak sof-firmware nss-mdns acpid-runit os-prober ntfs-3g

# pacman -S xf86-video-intel xorg --ignore xorg-server-xdmx

# pacman -S reflector
# pacman -S nvidia-lts nvidia-utils nvidia-settings

grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

ln -s /etc/runit/sv/NetworkManager /run/runit/service
ln -s /etc/runit/sv/sshd /run/runit/service
ln -s /etc/runit/sv/acpid /run/runit/service
ln -s /etc/runit/sv/ntpd /run/runit/service
ln -s /etc/runit/sv/bluetoothd /run/runit/service
ln -s /etc/runit/sv/wpa_supplicant /run/runit/service
ln -s /etc/runit/sv/avahi-daemon /run/runit/service
ln -s /etc/runit/sv/alsa /run/runit/service
ln -s /etc/runit/sv/cupsd /run/runit/service
ln -s /etc/runit/sv/tlp /run/runit/service

useradd -m junior
echo junior:200291 | chpasswd
usermod -aG libvirt junior

echo "junior ALL=(ALL) ALL" >>/etc/sudoers.d/junior

printf "\e[1;32mDone! Type exit, umount -a and reboot.\e[0m"
