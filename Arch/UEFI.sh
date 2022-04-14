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

# You can add xorg to the installation packages, I usually add it at the DE or WM install script
# You can remove the tlp package if you are installing on a desktop or vm
# not working correctely - pipewire pipewire-alsa pipewire-pulse pipewire-jack
#pacman -Sy grub grub-btrfs archlinux-keyring efibootmgr networkmanager network-manager-applet dialog wpa_supplicant pacman-contrib base-devel avahi xdg-user-dirs xdg-utils gvfs gvfs-smb nfs-utils inetutils dnsutils bluez bluez-utils pulseaudio-bluetooth pulseaudio-alsa pulseaudio-equalizer pulseaudio-jack alsa-utils bash-completion exfat-utils dropbear rsync firewalld flatpak sof-firmware nss-mdns os-prober ntfs-3g

# Virt-manager
#pacman -S virt-manager virt-viewer qemu qemu-arch-extra bridge-utils dnsmasq vde2 ebtables openbsd-netcat vde2 edk2-ovmf iptables-nft ipset libguestfs

# apci & tlp
# pacman -S acpi acpi_call acpid tlp

#Printer
#pacman -S cups hplip

# OLDMAC INSTALL BASE
pacman -S archlinux-keyring
pacman -Syyy
pacman -S efibootmgr exfat-utils networkmanager network-manager-applet wireless_tools wpa_supplicant dialog mtools dosfstools base-devel pacman-contrib reflector bluez bluez-utils pulseaudio pulseaudio-bluetooth alsa-utils xdg-utils xdg-user-dirs bash-completion zsh ntfs-3g firewalld rsync acpi acpi_call sof-firmware acpid gvfs gvfs-smb nfs-utils inetutils dnsutils nss-mdns

pacman -S xf86-video-intel mesa vulkan-intel

#Open-Source Drivers (Oldpc)
# pacman -S xf86-video-nouveau

# nvidia if you are using zen linux kernel
# pacman -S nvidia-dkms nvidia-utils nvidia-settings

# pacman -S nvidia-tweaks nvidia-settings

# OLDMAC (late 2008) lts kernel nvidia-340xx-lts-dkms
# sudo pacman -S xf86-video-nouveau xf86-video-intel xorg-server xorg-server-common
# pacman -S nvidia-340xx-lts-dkms
# pacman -S xf86-video-intel xf86-video-nouveau

# Old pc only works with xorg-server1.19-git and max kernel 5.4
# sudo pacman -S nvidia-304xx

sudo sed -i 's/#GRUB_DISABLE_OS_PROBER=true/GRUB_DISABLE_OS_PROBER=false/g' /etc/default/grub
# sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet"/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=2 quiet udev.log_level=0 i915.fastboot=1 i915.enable_guc=2 acpi_backlight=vendor console=tty2 zswap.enabled=1 zswap.compressor=zstd zswap.max_pool_percent=10 zswap.zpool=zsmalloc mitigations=off nowatchdog msr.allow_writes=on pcie_aspm=force module.sig_unenforce intel_idle.max_cstate=1 i915.enable_dc=0 ahci.mobile_lpm_policy=1 cryptomgr.notests initcall_debug nvidia-drm.modeset=1 intel_iommu=on,igfx_off net.ifnames=0 no_timer_check noreplace-smp page_alloc.shuffle=1 rcupdate.rcu_expedited=1 tsc=reliable"/g' /etc/default/grub
sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet"/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=2 quiet udev.log_level=0 i915.fastboot=1 i915.enable_guc=2 acpi_backlight=vendor console=tty2 zswap.enabled=1 zswap.compressor=zstd zswap.max_pool_percent=10 zswap.zpool=zsmalloc mitigations=off nowatchdog msr.allow_writes=on pcie_aspm=force module.sig_unenforce intel_idle.max_cstate=1 ahci.mobile_lpm_policy=1 cryptomgr.notests initcall_debug nvidia-drm.modeset=1 intel_iommu=on,igfx_off net.ifnames=0 no_timer_check noreplace-smp page_alloc.shuffle=1 rcupdate.rcu_expedited=1 tsc=reliable"/g' /etc/default/grub

# OLDPC don`t need it
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=Arch
grub-mkconfig -o /boot/grub/grub.cfg

systemctl enable NetworkManager
systemctl enable bluetooth
#systemctl enable cups.service
# OLDPC don`t need it
#systemctl enable sshd
systemctl enable dropbear
# OLDPC don`t need it
systemctl enable avahi-daemon
# You can comment this command out if you didn't install tlp, see above
#systemctl enable tlp
systemctl enable reflector.timer
systemctl enable fstrim.timer
# OLDPC don`t need it
systemctl enable libvirtd
systemctl enable firewalld
systemctl enable acpid

useradd -m junior
echo junior:200291 | chpasswd
usermod -aG libvirt storage junior

echo "junior ALL=(ALL) ALL" >>/etc/sudoers.d/junior
echo "junior ALL=(ALL) NOPASSWD: ALL" >>/etc/sudoers.d/junior

sudo sed -i 's/MODULES=()/MODULES=(btrfs i915 crc32c-intel nvidia nvidia_modeset nvidia_uvm nvidia_drm)/g' /etc/mkinitcpio.conf
sudo sed -i 's/HOOKS=(base udev autodetect modconf block filesystems keyboard fsck)/HOOKS=(base udev autodetect modconf block filesystems keyboard fsck btrfs grub-btrfs-overlayfs)/g' /etc/mkinitcpio.conf
sudo sed -i 's/#COMPRESSION="xz"/COMPRESSION="xz"/g' /etc/mkinitcpio.conf

mkinitcpio -P linux-lts

printf "\e[1;32mDone! Type exit, umount -a and reboot.\e[0m"
