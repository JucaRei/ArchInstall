#!/bin/bash

ln -sf /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime
hwclock --systohc
sed -i '177s/.//' /etc/locale.gen
locale-gen
# echo "LANG=en_US.UTF-8" >>/etc/locale.conf
# echo "KEYMAP=us-intl" >>/etc/vconsole.conf
# echo "KEYMAP=mac-us" >>/etc/vconsole.conf
echo "oldarch" >>/etc/hostname
echo "127.0.0.1 localhost" >>/etc/hosts
echo "::1       localhost" >>/etc/hosts
echo "127.0.1.1 oldarch.localdomain oldarch" >>/etc/hosts
echo root:200291 | chpasswd

# OLDMAC INSTALL BASE
pacman -S archlinux-keyring
pacman -Syyy
pacman -S efibootmgr exfat-utils intel-ucode networkmanager network-manager-applet wireless_tools wpa_supplicant dialog mtools dosfstools bluez bluez-utils pulseaudio pulseaudio-bluetooth alsa-utils xdg-utils xdg-user-dirs bash-completion zsh ntfs-3g firewalld rsync acpi acpi_call sof-firmware acpid gvfs gvfs-smb nfs-utils inetutils dnsutils nss-mdns

# apci & tlp
pacman -S acpi acpi_call-lts acpid acpilight --noconfirm

#Open-Source Drivers (Oldpc)
# pacman -S xf86-video-nouveau

# sudo pacman -S xf86-video-nouveau xf86-video-intel xorg-server xorg-server-common
# pacman -S xf86-video-intel xf86-video-nouveau
# pacman -S nvidia-340xx-lts-dkms xf86-video-intel

# Old pc only works with xorg-server1.19-git and max kernel 5.4
# sudo pacman -S nvidia-304xx

#grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=Arch
#grub-mkconfig -o /boot/grub/grub.cfg

systemctl enable NetworkManager
systemctl enable bluetooth
# OLDPC don`t need it
systemctl enable sshd
# OLDPC don`t need it
systemctl enable avahi-daemon
#systemctl enable tlp
systemctl enable reflector.timer
systemctl enable fstrim.timer
systemctl enable firewalld
systemctl enable acpid

useradd -m juca
echo juca:200291 | chpasswd

echo "juca ALL=(ALL) ALL" >>/etc/sudoers.d/juca

pacman -Rs linux acpi_call --noconfirm

pacman -S acpi_call-lts --noconfirm

mkinitcpio -P linux-lts

# choose which you want
cd ArchInstall/Arch/Arch_pkgs
pacman -U pikaur-1.9-1-any.pkg.tar.zst
mkdir -p /var/cache/pikaur
pikaur -Syu --noconfirm
pikaur -S bat dust yt-dlp btop zramd --noconfirm
systemctl enable zramd
#pikaur -S nvidia-340xx-lts-dkms xf86-video-intel
#pikaur -S xf86-video-nouveau xf86-video-intel

# MakeSwap
# touch /swapfile
# chmod 600 /swapfile
# chattr +C /swapfile
# lsattr /swapfile
# dd if=/dev/zero of=/swapfile bs=1M count=8192 status=progress
# mkswap /swapfile
# swapon /swapfile

# # Add to fstab
# echo " " >> /etc/fstab
# echo "# Swap" >> /etc/fstab
# echo "/swapfile      none     swap      defaults  0 0" >> /etc/fstab

# Systemd-Boot
bootctl --path=/boot install
echo "default arch.conf" >>/boot/loader/loader.conf
touch /boot/loader/entries/arch.conf

cat <<EOF >/boot/loader/entries/arch.conf
title   Arch Linux
linux   /vmlinuz-linux-lts
initrd  /intel-ucode.img
initrd  /initramfs-linux-lts.img
options root=/dev/sda2 rootflags=subvol=@ rw quiet loglevel=0 console=tty2 acpi_osi=Darwin acpi_mask_gpe=0x06 udev.log_level=0 mitigations=off nowatchdog msr.allow_writes=on pcie_aspm=force module.sig_unenforce intel_idle.max_cstate=1 cryptomgr.notests initcall_debug net.ifnames=0 no_timer_check noreplace-smp page_alloc.shuffle=1 rcupdate.rcu_expedited=1 tsc=reliable
EOF
# options root=/dev/sda2 rootflags=subvol=@ rw quiet splash loglevel=3 mitigations=off nowatchdog msr.allow_writes=on pcie_aspm=force module.sig_unenforce  vt.global_cursor_default=0 intel_idle.max_cstate=1 zswap.enabled=1 zswap.compressor=zstd zswap.max_pool_percent=10 zswap.zpool=zsmalloc cryptomgr.notests initcall_debug intel_iommu=igfx_off net.ifnames=0 no_timer_check noreplace-smp page_alloc.shuffle=1 rcupdate.rcu_expedited=1 tsc=reliable

printf "\e[1;32mDone! Type exit, umount -a and reboot.\e[0m"
