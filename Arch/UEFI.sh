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

# Enable pacman Color
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

pacman -S archlinux-keyring --noconfirm
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

mkdir -p /media

cat <<EOF >>/etc/fstab

# tmpfs /tmp tmpfs defaults,nosuid,nodev,noatime 0 0
tmpfs /tmp tmpfs noatime,mode=1777 0 0
EOF

# You can add xorg to the installation packages, I usually add it at the DE or WM install script
# You can remove the tlp package if you are installing on a desktop or vm
# not working correctely - pipewire pipewire-alsa pipewire-pulse pipewire-jack
pacman -Sy grub grub-btrfs efibootmgr chrony preload irqbalance ananicy-cpp bat exa fzf ripgrep htop btop networkmanager-iwd opendoas network-manager-applet dialog avahi xdg-user-dirs xdg-utils gvfs gvfs-smb nfs-utils inetutils dnsutils bluez bluez-utils pulseaudio-bluetooth pulseaudio-alsa pulseaudio-equalizer pulseaudio-jack alsa-utils bash-completion exfat-utils dropbear rsync firewalld flatpak sof-firmware nss-mdns os-prober ntfs-3g

# Virt-manager & lxd
pacman -S lxd distrobuilder virt-manager virt-viewer qemu qemu-arch-extra bridge-utils dnsmasq vde2 ebtables openbsd-netcat vde2 edk2-ovmf iptables-nft ipset libguestfs

# apci & tlp
pacman -S acpi acpi_call-lts acpid tlp

#Printer
pacman -S cups hplip

# OLDMAC INSTALL BASE
# pacman -S archlinux-keyring
# pacman -Syyy
# pacman -S efibootmgr exfat-utils networkmanager network-manager-applet wireless_tools wpa_supplicant dialog mtools dosfstools base-devel pacman-contrib reflector bluez bluez-utils pulseaudio pulseaudio-bluetooth alsa-utils xdg-utils xdg-user-dirs bash-completion zsh ntfs-3g firewalld rsync acpi acpi_call sof-firmware acpid gvfs gvfs-smb nfs-utils inetutils dnsutils nss-mdns

# pacman -S xf86-video-intel mesa vulkan-intel

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

# Create config file to make NetworkManager use iwd as the Wi-Fi backend instead of wpa_supplicant
# mkdir -pv /etc/NetworkManager/conf.d/
# cat <<EOF >>/mnt/etc/NetworkManager/conf.d/wifi_backend.conf
# [device]
# wifi.backend=iwd
# wifi.iwd.autoconnect=yes
# EOF

sudo sed -i 's/#GRUB_DISABLE_OS_PROBER=true/GRUB_DISABLE_OS_PROBER=false/g' /etc/default/grub
# sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet"/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=2 quiet udev.log_level=0 i915.fastboot=1 i915.enable_guc=2 acpi_backlight=vendor console=tty2 zswap.enabled=1 zswap.compressor=zstd zswap.max_pool_percent=10 zswap.zpool=zsmalloc mitigations=off nowatchdog msr.allow_writes=on pcie_aspm=force module.sig_unenforce intel_idle.max_cstate=1 i915.enable_dc=0 ahci.mobile_lpm_policy=1 cryptomgr.notests initcall_debug nvidia-drm.modeset=1 intel_iommu=on,igfx_off net.ifnames=0 no_timer_check noreplace-smp page_alloc.shuffle=1 rcupdate.rcu_expedited=1 tsc=reliable"/g' /etc/default/grub
# sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet"/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=2 quiet udev.log_level=0 i915.fastboot=1 i915.enable_guc=2 acpi_backlight=vendor console=tty2 zswap.enabled=1 zswap.compressor=zstd zswap.max_pool_percent=10 zswap.zpool=zsmalloc mitigations=off nowatchdog msr.allow_writes=on pcie_aspm=force module.sig_unenforce intel_idle.max_cstate=1 ahci.mobile_lpm_policy=1 cryptomgr.notests initcall_debug nvidia-drm.modeset=1 intel_iommu=on,igfx_off net.ifnames=0 no_timer_check noreplace-smp page_alloc.shuffle=1 rcupdate.rcu_expedited=1 tsc=reliable"/g' /etc/default/grub
sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet"/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=2 quiet apci_osi=Linux udev.log_level=0 acpi_backlight=video gpt acpi=force intel_pstate=active init_on_alloc=0 console=tty2 zswap.enabled=1 zswap.compressor=zstd zswap.max_pool_percent=10 zswap.zpool=zsmalloc mitigations=off nowatchdog msr.allow_writes=on pcie_aspm=force module.sig_unenforce intel_idle.max_cstate=1 cryptomgr.notests initcall_debug nvidia-drm.modeset=1 intel_iommu=on,igfx_off net.ifnames=0 no_timer_check noreplace-smp page_alloc.shuffle=1 rcupdate.rcu_expedited=1 tsc=reliable"/g' /etc/default/grub
# sudo sed -i 's/GRUB_COLOR_NORMAL="light-blue/black"/GRUB_COLOR_NORMAL="red/black"/g'
# sudo sed -i 's/#GRUB_COLOR_HIGHLIGHT="light-cyan/blue"/GRUB_COLOR_HIGHLIGHT="yellow/black"/g'
sudo sed -i 's/#GRUB_DISABLE_OS_PROBER=true/GRUB_DISABLE_OS_PROBER=false/g' /etc/default/grub
# OLDPC don`t need it
grub-install --target=x86_64-efi --bootloader-id=Arch --efi-directory=/boot/efi --no-nvram --removable
# grub-install --target=x86_64-efi --bootloader-id=Arch --efi-directory=/boot/efi --no-nvram --removable --recheck --no-rs-codes --modules="btrfs zstd part_gpt part_msdos"
# grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=Arch --recheck
grub-mkconfig -o /boot/grub/grub.cfg

systemctl enable NetworkManager
systemctl enable bluetooth
systemctl enable iwd
systemctl enable dropbear
systemctl enable irqbalance
systemctl enable preload
systemctl enable ananicy-cpp
systemctl enable smbd
systemctl enable nmbd
systemctl enable chronyd
#systemctl enable cups.service
# OLDPC don`t need it
#systemctl enable sshd
systemctl enable dropbear
# OLDPC don`t need it
systemctl enable avahi-daemon
# You can comment this command out if you didn't install tlp, see above
systemctl enable tlp
systemctl enable reflector.timer
systemctl enable fstrim.timer
# OLDPC don`t need it
systemctl enable libvirtd
systemctl enable firewalld
systemctl enable acpid

useradd -m junior
echo junior:200291 | chpasswd
usermod -aG wheel junior

echo "junior ALL=(ALL) ALL" >>/etc/sudoers.d/junior
echo "junior ALL=(ALL) NOPASSWD: ALL" >>/etc/sudoers.d/junior

# Power top
touch /etc/rc.local
cat <<EOF >/etc/rc.local
# PowerTop
powertop --auto-tune

# echo 60000 > /sys/bus/usb/devices/2-1.5/power/autosuspend_delay_ms
# echo 60000 > /sys/bus/usb/devices/2-1.6/power/autosuspend_delay_ms
# echo 60000 > /sys/bus/usb/devices/3-1.5/power/autosuspend_delay_ms
# echo 60000 > /sys/bus/usb/devices/3-1.6/power/autosuspend_delay_ms
# echo 60000 > /sys/bus/usb/devices/4-1.5/power/autosuspend_delay_ms
# echo 60000 > /sys/bus/usb/devices/4-1.6/power/autosuspend_delay_ms

# Preload
preload
EOF

#Samba
mkdir -p /etc/samba
cat <<EOF >/etc/samba/smb.conf
[global]
   workgroup = WORKGROUP
   dns proxy = no
   log file = /var/log/samba/%m.log
   max log size = 1000
   client min protocol = NT1
   server role = standalone server
   passdb backend = tdbsam
   obey pam restrictions = yes
   unix password sync = yes
   passwd program = /usr/bin/passwd %u
   passwd chat = *New*UNIX*password* %n\n *ReType*new*UNIX*password* %n\n *passwd:*all*authentication*tokens*updated*successfully*
   pam password change = yes
   map to guest = Bad Password
   usershare allow guests = yes
   name resolve order = lmhosts bcast host wins
   security = user
   guest account = nobody
   usershare path = /var/lib/samba/usershare
   usershare max shares = 100
   usershare owner only = yes
   force create mode = 0070
   force directory mode = 0070

[homes]
   comment = Home Directories
   browseable = no
   read only = yes
   create mask = 0700
   directory mask = 0700
   valid users = %S

[printers]
   comment = All Printers
   browseable = no
   path = /var/spool/samba
   printable = yes
   guest ok = no
   read only = yes
   create mask = 0700

[print$]
   comment = Printer Drivers
   path = /var/lib/samba/printers
   browseable = yes
   read only = yes
   guest ok = no
EOF

### systemctl
mkdir -pv /etc/sysctl.d
touch /etc/sysctl.d/00-sysctl.conf
cat <<EOF >/etc/sysctl.d/00-sysctl.conf
vm.vfs_cache_pressure=500
vm.swappiness=100
vm.dirty_background_ratio=1
vm.dirty_ratio=50
dev.i915.perf_stream_paranoid=0
EOF
#Fix mount external HD
mkdir -pv /etc/udev/rules.d
cat <<\EOF >/etc/udev/rules.d/99-udisks2.rules
# UDISKS_FILESYSTEM_SHARED
# ==1: mount filesystem to a shared directory (/media/VolumeName)
# ==0: mount filesystem to a private directory (/run/media/$USER/VolumeName)
# See udisks(8)
ENV{ID_FS_USAGE}=="filesystem|other|crypto", ENV{UDISKS_FILESYSTEM_SHARED}="1"
EOF

# Not asking for password

mkdir -pv /etc/polkit-1/rules.d
cat <<\EOF >/etc/polkit-1/rules.d/10-udisks2.rules
// Allow udisks2 to mount devices without authentication
// for users in the "wheel" group.
polkit.addRule(function(action, subject) {
    if ((action.id == "org.freedesktop.udisks2.filesystem-mount-system" ||
         action.id == "org.freedesktop.udisks2.filesystem-mount") &&
        subject.isInGroup("wheel")) {
        return polkit.Result.YES;
    }
});
EOF

cat <<\EOF >/etc/polkit-1/rules.d/00-mount-internal.rules
polkit.addRule(function(action, subject) {
   if ((action.id == "org.freedesktop.udisks2.filesystem-mount-system" &&
      subject.local && subject.active && subject.isInGroup("storage")))
      {
         return polkit.Result.YES;
      }
});
EOF

# usermod -aG storage junior

# Doas Set user permition
cat <<EOF >/etc/doas.conf
# allow user but require password
permit keepenv :junior

# allow user and dont require a password to execute commands as root
permit nopass keepenv :junior

# mount drives
permit nopass :junior cmd mount
permit nopass :junior cmd umount

# musicpd service start and stop
#permit nopass :$USER cmd service args musicpd onestart
#permit nopass :$USER cmd service args musicpd onestop

# pkg update
#permit nopass :$USER cmd vpm args update

# run personal scripts as root without prompting for a password,
# requires entering the full path when running with doas
#permit nopass :$USER cmd /home/username/bin/somescript

# root as root
#permit nopass keepenv root as root
EOF

chown -c root:root /etc/doas.conf

touch /etc/modprobe.d/i915.conf
cat <<\EOF >/etc/modprobe.d/i915.conf
options i915 enable_guc=2 enable_dc=4 enable_hangcheck=0 error_capture=0 enable_dp_mst=0 fastboot=1
EOF

# SWAP

# touch var/swap/swapfile
# truncate -s 0 /var/swap/swapfile
# chattr +C /var/swap/swapfile
# btrfs property set /var/swap/swapfile compression none
# chmod 600 /var/swap/swapfile
# dd if=/dev/zero of=/var/swap/swapfile bs=1M count=8192 status=progress
# mkswap /var/swap/swapfile
# swapon /var/swap/swapfile

# Add to fstab
# set -e
# SWAP_UUID=$(blkid -s UUID -o value /dev/sda6)
# echo $SWAP_UUID
# echo " " >> etc/fstab
# echo "# Swap" >> /etc/fstab
# echo "UUID=$SWAP_UUID /var/swap btrfs defaults,noatime,subvol=@swap 0 0" >> /etc/fstab
# echo "/var/swap/swapfile none swap sw 0 0" >> /etc/fstab

# Mkinitcpio
sudo sed -i 's/MODULES=()/MODULES=(btrfs i915 crc32c-intel nvidia nvidia_modeset nvidia_uvm nvidia_drm)/g' /etc/mkinitcpio.conf
sudo sed -i 's/HOOKS=(base udev autodetect modconf block filesystems keyboard fsck)/HOOKS=(base udev autodetect modconf block filesystems keyboard resume fsck btrfs grub-btrfs-overlayfs)/g' /etc/mkinitcpio.conf
sudo sed -i 's/#COMPRESSION="xz"/COMPRESSION="xz"/g' /etc/mkinitcpio.conf

mkinitcpio -P linux-lts

# Resume
# mkdir -pv /tmp/btrfs
# wget -c https://raw.githubusercontent.com/osandov/osandov-linux/master/scripts/btrfs_map_physical.c
# gcc -O2 -o btrfs_map_physical btrfs_map_physical.c
# ./btrfs_map_physical /var/swap/swapfile >btrfs_map_physical.txt
# filefrag -v /var/swap/swapfile | awk '$1=="0:" {print substr($4, 1, length($4)-2)}' >resume.txt
# set -e
# RESUME_OFFSET=$(cat /tmp/resume.txt)
# ROOT_UUID=$(blkid -s UUID -o value /dev/sda6)
# export ROOT_UUID
# export RESUME_OFFSET
# sed -i 's/GRUB_CMDLINE_LINUX=""/GRUB_CMDLINE_LINUX="'"resume=UUID=$ROOT_UUID resume_offset=$RESUME_OFFSET"'"/g' /etc/default/grub

grub-mkconfig -o /boot/grub/grub.cfg

usermod -aG libvirt junior

paccache -rk1

# pikaur -S powertop-auto-tune zramd
printf "\e[1;32mDone! Type exit, umount -a and reboot.\e[0m"
