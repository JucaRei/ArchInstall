#!/bin/bash

# General
ln -sf /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime
hwclock --systohc
sed -i '171s/.//' /etc/locale.gen
locale-gen
# echo "LANG=en_US.UTF-8" >>/etc/locale.conf
# echo "KEYMAP=us-intl" >>/etc/vconsole.conf
# echo "KEYMAP=mac-us" >>/etc/vconsole.conf
echo "oldarch" >>/etc/hostname
echo "127.0.0.1 localhost" >>/etc/hosts
echo "::1       localhost" >>/etc/hosts
echo "127.0.1.1 oldarch.localdomain oldarch" >>/etc/hosts
echo root:200291 | chpasswd

# Some pacman confs
sed -i '1n; /^#UseSyslog/i ILoveCandy' /etc/pacman.conf
sed -i '3n; /^#UseSyslog/i DisableDownloadTimeout' /etc/pacman.conf
sed -i '/Color/s/^#//' /etc/pacman.conf
sed -i 's/#ParallelDownloads = 5/ParallelDownloads = 8/g' /etc/pacman.conf

# Enable multilib repo
sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf
sed -i "/\[lib32\]/,/Include/"'s/^#//' /etc/pacman.conf

# Setting package signing option to require signature
sed -i '/\[core\]/a SigLevel\ =\ PackageRequired' /etc/pacman.conf
sed -i '/\[multilib\]/a SigLevel\ =\ PackageRequired' /etc/pacman.conf
sed -i '/\[community\]/a SigLevel\ =\ PackageRequired' /etc/pacman.conf
sed -i '/\[extra\]/a SigLevel\ =\ PackageRequired' /etc/pacman.conf

pacman -Syyw

# Add Chaotic repo
pacman-key --recv-key FBA220DFC880C036 --keyserver keyserver.ubuntu.com
pacman-key --lsign-key FBA220DFC880C036
pacman -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst' --noconfirm

# Add Liquorix
pacman-key --keyserver hkps://keyserver.ubuntu.com --recv-keys 9AE4078033F8024D
pacman-key --lsign-key 9AE4078033F8024D

# Add Andontie Repo
pacman-key --recv-key B545E9B7CD906FE3
pacman-key --lsign-key B545E9B7CD906FE3

cat <<\EOF >>/etc/pacman.conf
#[liquorix]
#Server = https://liquorix.net/archlinux/

[chaotic-aur]
Include = /etc/pacman.d/chaotic-mirrorlist

EOF

sed -i -e '$a [andontie-aur]' /etc/pacman.conf
sed -i -e '$a Server = https://aur.andontie.net/$arch' /etc/pacman.conf

pacman -Sy

# OLDMAC INSTALL BASE
pacman -S archlinux-keyring
pacman -Syyy
pacman -S grub grub-btrfs efibootmgr exfat-utils intel-ucode networkmanager networkmanager-iwd iwd wireless_tools dialog mtools dosfstools bluez bluez-utils pulseaudio pulseaudio-bluetooth alsa-utils xdg-utils xdg-user-dirs bash-completion ntfs-3g firewalld rsync acpi acpi_call sof-firmware acpid gvfs gvfs-smb nfs-utils inetutils dnsutils nss-mdns
# pacman -S grub grub-btrfs efibootmgr exfat-utils intel-ucode networkmanager network-manager-applet wireless_tools dialog mtools dosfstools bluez bluez-utils pulseaudio pulseaudio-bluetooth alsa-utils xdg-utils xdg-user-dirs bash-completion ntfs-3g firewalld rsync acpi acpi_call sof-firmware acpid gvfs gvfs-smb nfs-utils inetutils dnsutils nss-mdns

# apci & tlp
pacman -S acpi acpi_call-lts acpid acpilight --noconfirm

#Open-Source Drivers (Oldpc)
# pacman -S xf86-video-nouveau

# sudo pacman -S xf86-video-nouveau xf86-video-intel xorg-server xorg-server-common
# pacman -S xf86-video-intel xf86-video-nouveau
# pacman -S nvidia-340xx-lts-dkms xf86-video-intel

# Old pc only works with xorg-server1.19-git and max kernel 5.4
# sudo pacman -S nvidia-304xx

# Create config file to make NetworkManager use iwd as the Wi-Fi backend instead of wpa_supplicant
mkdir -pv /etc/NetworkManager/conf.d/
touch /etc/NetworkManager/conf.d/wifi_backend.conf
cat <<EOF >>/etc/NetworkManager/conf.d/wifi_backend.conf
[device]
wifi.backend=iwd
wifi.iwd.autoconnect=yes
EOF

# Config iwd
mkdir -pv /etc/iwd
touch /etc/iwd/main.conf
cat <<EOF >main.conf
[General]
EnableNetworkConfiguration=true

[Network]
NameResolvingService=systemd
RouterPriorityOffset=30
EOF

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
usermod -aG wheel juca
echo "juca ALL=(ALL) ALL" >>/etc/sudoers.d/juca
echo "juca ALL=(ALL) NOPASSWD: ALL" >>/etc/sudoers.d/juca

### systemctl
mkdir -pv /etc/sysctl.d
touch /etc/sysctl.d/00-sysctl.conf
cat <<\EOF >/etc/sysctl.d/00-sysctl.conf
vm.vfs_cache_pressure=500
vm.swappiness=100
vm.dirty_background_ratio=1
vm.dirty_ratio=50
dev.i915.perf_stream_paranoid=0
net.ipv4.ping_group_range=0 $MAX_GID
EOF

pacman -Rs linux acpi_call --noconfirm

pacman -S acpi_call-lts --noconfirm

mkinitcpio -P linux-lts

# choose which you want
# cd ArchInstall/Arch/Arch_pkgs
# pacman -U pikaur-1.9-1-any.pkg.tar.zst
# mkdir -p /var/cache/pikaur
# pikaur -Syu --noconfirm
# pikaur -S bat dust yt-dlp btop zramd --noconfirm
# systemctl enable zramd
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

# Grub
grub-install --target=x86_64-efi --bootloader-id=Arch --efi-directory=/boot --no-nvram --removable --recheck
grub-mkconfig -o /boot/grub/grub.cfg
sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet"/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=2 quiet apci_osi=Darwin acpi_mask_gpe=0x06 udev.log_level=0 acpi_backlight=video gpt acpi=force intel_pstate=active init_on_alloc=0 console=tty2 zswap.enabled=1 zswap.compressor=lz4hc zswap.max_pool_percent=10 zswap.zpool=z3fold mitigations=off nowatchdog msr.allow_writes=on pcie_aspm=force module.sig_unenforce intel_idle.max_cstate=1 cryptomgr.notests initcall_debug nvidia-drm.modeset=1 intel_iommu=on,igfx_off net.ifnames=0 no_timer_check noreplace-smp page_alloc.shuffle=1 rcupdate.rcu_expedited=1 tsc=reliable"/g' /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg

# Systemd-Boot
# bootctl --path=/boot install
# echo "default arch.conf" >>/boot/loader/loader.conf
# touch /boot/loader/entries/arch.conf

# cat <<EOF >/boot/loader/entries/arch.conf
# title   Arch Linux
# linux   /vmlinuz-linux-lts
# initrd  /intel-ucode.img
# initrd  /initramfs-linux-lts.img
# options root=/dev/sda2 rootflags=subvol=@ rw quiet loglevel=0 console=tty2 acpi_osi=Darwin acpi_mask_gpe=0x06 udev.log_level=0 mitigations=off nowatchdog msr.allow_writes=on pcie_aspm=force module.sig_unenforce intel_idle.max_cstate=1 cryptomgr.notests initcall_debug net.ifnames=0 no_timer_check noreplace-smp page_alloc.shuffle=1 rcupdate.rcu_expedited=1 tsc=reliable
# EOF
# options root=/dev/sda2 rootflags=subvol=@ rw quiet splash loglevel=3 mitigations=off nowatchdog msr.allow_writes=on pcie_aspm=force module.sig_unenforce  vt.global_cursor_default=0 intel_idle.max_cstate=1 zswap.enabled=1 zswap.compressor=zstd zswap.max_pool_percent=10 zswap.zpool=zsmalloc cryptomgr.notests initcall_debug intel_iommu=igfx_off net.ifnames=0 no_timer_check noreplace-smp page_alloc.shuffle=1 rcupdate.rcu_expedited=1 tsc=reliable

paccache -rk0

printf "\e[1;32mDone! Type exit, umount -a and reboot.\e[0m"
