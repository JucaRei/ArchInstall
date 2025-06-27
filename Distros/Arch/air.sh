#!/bin/bash

DRIVE="/dev/sda"

pacman -Sy archlinux-keyring --noconfirm

# Enable pacman Color
sed -i '1n; /^#UseSyslog/i ILoveCandy' /etc/pacman.conf
sed -i '/Color/s/^#//' /etc/pacman.conf
sed -i '3n; /^#UseSyslog/i DisableDownloadTimeout' /etc/pacman.conf
sed -i 's/#ParallelDownloads = 5/ParallelDownloads = 4/g' /etc/pacman.conf

# cat <<\EOF >> /etc/pacman.conf

# [liquorix]
# Server = https://liquorix.net/archlinux/$repo/$arch
# EOF

# Get Best Mirrors
# reflector --protocol https --country "Brazil" --latest 10 --sort rate --save /etc/pacman.d/mirrorlist

# Add Liquorix
pacman-key --init
pacman-key --keyserver hkps://keyserver.ubuntu.com --recv-keys 9AE4078033F8024D
pacman-key --lsign-key 9AE4078033F8024D
pacman-key --populate

pacman -Syyy

# kernel-lts

# [kernel-lts]
# Server = https://repo.m2x.dev/current/$repo/$arch

# pacman-key --keyserver hkps://keyserver.ubuntu.com --recv-key 76C6E477042BFE985CC220BD9C08A255442FAFF0
# sudo pacman-key --lsign 76C6E477042BFE985CC220BD9C08A255442FAFF0

# chaotic

pacman-key --keyserver hkps://keyserver.ubuntu.com --recv-keys FBA220DFC880C036
pacman-key --lsign-key FBA220DFC880C036
pacman-key --populate

pacman -Syyy


# =======================================================================================================================================================

umount -R /mnt

sgdisk -Z ${DRIVE}
sgdisk -n 0:0:512MiB ${DRIVE}
sgdisk -n 0:0:0 ${DRIVE}
sgdisk -t 1:ef00 ${DRIVE}
sgdisk -t 2:8300 ${DRIVE}
sgdisk -c 1:EFI ${DRIVE}
sgdisk -c 2:Archlinux ${DRIVE}
sgdisk -p ${DRIVE}

mkfs.vfat -F32 ${DRIVE}1 -n "Grub"
mkfs.btrfs ${DRIVE}2 -f -L "Archsys"

mount -t btrfs ${DRIVE}2 /mnt

btrfs su cr /mnt/@
btrfs su cr /mnt/@pacman
btrfs su cr /mnt/@snapshots
btrfs su cr /mnt/@var_log
btrfs su cr /mnt/@tmp
btrfs su cr /mnt/@cache
btrfs su cr /mnt/@home

# btrfs su cr /mnt/@swap

umount -Rv /

set -e
BTRFS_OPTS="noatime,ssd,compress-force=zstd:15,space_cache=v2,commit=120,discard=async"

## Mount partitions (Nitro)
mount -o $BTRFS_OPTS,subvol=@ ${DRIVE}2 /mnt
mkdir -pv /mnt/{home,.snapshots,boot/efi,var/log,var/tmp,var/cache,var/lib/pacman,swap}

# Swap Optional
# mkdir -pv /mnt/var/swap

mount -o $BTRFS_OPTS,subvol=@pacman ${DRIVE}2 /mnt/var/lib/pacman
mount -o $BTRFS_OPTS,subvol=@home ${DRIVE}2 /mnt/home
mount -o $BTRFS_OPTS,subvol=@snapshots ${DRIVE}2 /mnt/.snapshots
mount -o $BTRFS_OPTS,subvol=@var_log ${DRIVE}2 /mnt/var/log
mount -o $BTRFS_OPTS,subvol=@cache ${DRIVE}2 /mnt/var/cache
mount -o $BTRFS_OPTS,subvol=@tmp ${DRIVE}2 /mnt/var/tmp
# mount -o $BTRFS_OPTS,subvol=@swap ${DRIVE}2 /mnt/swap
mount -t vfat -o defaults,noatime,nodiratime ${DRIVE}1 /mnt/boot/efi


# Base packages LTS kernel
# pacstrap /mnt base base-devel linux-lts linux-lts-headers linux-firmware archlinux-keyring man-db perl sysfsutils python python-pip git man-pages dropbear git nano neovim intel-ucode fzf duf reflector mtools ansible dosfstools btrfs-progs pacman-contrib nfs-utils --ignore linux vi openssh

# Base packages Liquorix Kernel
pacstrap /mnt base base-devel linux-lts54  linux-lts54-headers linux-firmware archlinux-keyring man-db perl sysfsutils python git man-pages dropbear git nano intel-ucode duf reflector mtools dosfstools btrfs-progs pacman-contrib nfs-utils --ignore linux vi

pacstrap /mnt base base-devel linux linux-firmware archlinux-keyring man-db perl sysfsutils python git man-pages dropbear git nano neovim intel-ucode duf reflector mtools dosfstools btrfs-progs pacman-contrib nfs-utils --ignore vi

# Generate fstab
genfstab -U /mnt >>/mnt/etc/fstab

for dir in dev proc sys run; do
        mount --rbind /$dir /mnt/$dir
        mount --make-rslave /mnt/$dir
done


chroot /mnt ln -sf /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime
chroot /mnt hwclock --systohc
chroot /mnt sed -i '171s/.//' /etc/locale.gen
chroot /mnt sed -i '391s/.//' /etc/locale.gen
chroot /mnt locale-gen
# echo "LANG=en_US.UTF-8" >>/etc/locale.conf
# echo "KEYMAP=us-intl" >>/etc/vconsole.conf
# echo "KEYMAP=mac-us" >>/etc/vconsole.conf
chroot /mnt echo "air" >>/etc/hostname
chroot /mnt echo "127.0.0.1 localhost" >>/etc/hosts
chroot /mnt echo "::1       localhost" >>/etc/hosts
chroot /mnt echo "127.0.1.1 air.localdomain air" >>/etc/hosts
chroot /mnt echo root:200291 | chpasswd

# Enable pacman Color
sed -i '1n; /^#UseSyslog/i ILoveCandy' /mnt/etc/pacman.conf
sed -i '3n; /^#UseSyslog/i DisableDownloadTimeout' /mnt/etc/pacman.conf
sed -i '/Color/s/^#//' /mnt/etc/pacman.conf
sed -i 's/#ParallelDownloads = 5/ParallelDownloads = 3/g' /mnt/etc/pacman.conf

# Enable multilib repo
sed -i "/\[multilib\]/,/Include/"'s/^#//' /mnt/etc/pacman.conf
sed -i "/\[lib32\]/,/Include/"'s/^#//' /mnt/etc/pacman.conf

# Setting package signing option to require signature
sed -i '/\[core\]/a SigLevel\ =\ PackageRequired' /mnt/etc/pacman.conf
sed -i '/\[multilib\]/a SigLevel\ =\ PackageRequired' /mnt/etc/pacman.conf
sed -i '/\[community\]/a SigLevel\ =\ PackageRequired' /mnt/etc/pacman.conf
sed -i '/\[extra\]/a SigLevel\ =\ PackageRequired' /mnt/etc/pacman.conf

# Add Chaotic repo
chroot /mnt pacman-key --init
#chroot /mnt pacman-key --recv-key FBA220DFC880C036 --keyserver keyserver.ubuntu.com
#chroot /mnt pacman-key --lsign-key FBA220DFC880C036
#chroot /mnt pacman -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst' --noconfirm

# Add Liquorix
chroot /mnt pacman-key --keyserver hkps://keyserver.ubuntu.com --recv-keys 9AE4078033F8024D
chroot /mnt pacman-key --lsign-key 9AE4078033F8024D
pacman-key --populate

# Add Andontie Repo
#chroot /mnt pacman-key --recv-key B545E9B7CD906FE3
#chroot /mnt pacman-key --lsign-key B545E9B7CD906FE3

cat << EOF >>/mnt/etc/pacman.conf

# [chaotic-aur]
# Include = /etc/pacman.d/chaotic-mirrorlist

EOF

# sed -i -e '$a [andontie-aur]' /mnt/etc/pacman.conf
# sed -i -e '$a Server = https://aur.andontie.net/$arch' /mnt/etc/pacman.conf

chroot /mnt pacman -Syu

mkdir -p /mnt/media

cat <<EOF >>/mnt/etc/fstab

# tmpfs /tmp tmpfs defaults,nosuid,nodev,noatime 0 0
tmpfs /tmp tmpfs noatime,mode=1777 0 0
EOF

chroot /mnt pacman -Syyy
chroot /mnt pacman -S efibootmgr chrony irqbalance htop networkmanager-iwd opendoas network-manager-applet dialog avahi xdg-user-dirs xdg-utils gvfs gvfs-smb nfs-utils inetutils dnsutils bluez bluez-utils pulseaudio-bluetooth pulseaudio-alsa pulseaudio-equalizer pulseaudio-jack alsa-utils bash-completion exfat-utils rsync firewalld flatpak sof-firmware nss-mdns os-prober ntfs-3g
# ananicy-cpp preload

# Virt-manager & lxd
chroot /mnt pacman -S lxd distrobuilder virt-manager virt-viewer qemu qemu-arch-extra bridge-utils dnsmasq vde2 ebtables openbsd-netcat vde2 edk2-ovmf iptables-nft ipset libguestfs

# apci & tlp
chroot /mnt pacman -S acpi acpi_call-dkms acpid tlp

#Open-Source Drivers (Oldpc)
# pacman -S xf86-video-nouveau

# sudo pacman -S xf86-video-nouveau xf86-video-intel xorg-server xorg-server-common
# pacman -S xf86-video-intel xf86-video-nouveau
# pacman -S nvidia-340xx-lts-dkms xf86-video-intel

# Old pc only works with xorg-server1.19-git and max kernel 5.4
# sudo pacman -S nvidia-304xx

#grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=Arch
#grub-mkconfig -o /boot/grub/grub.cfg

chroot /mnt systemctl enable NetworkManager
chroot /mnt systemctl enable bluetooth
chroot /mnt systemctl enable iwd
# chroot /mnt systemctl enable dropbear
chroot /mnt systemctl enable irqbalance
# chroot /mnt systemctl enable preload
# chroot /mnt systemctl enable ananicy-cpp
chroot /mnt systemctl enable smbd
chroot /mnt systemctl enable nmbd
chroot /mnt systemctl enable chronyd
#chroot /mnt systemctl enable cups.service
chroot /mnt systemctl enable sshd
chroot /mnt systemctl enable dropbear
chroot /mnt systemctl enable avahi-daemon
# You can comment this command out if you didn't install tlp, see above
chroot /mnt systemctl enable tlp
chroot /mnt systemctl enable reflector.timer
chroot /mnt systemctl enable fstrim.timer
# OLDPC don`t need it
chroot /mnt systemctl enable libvirtd
chroot /mnt systemctl enable firewalld
chroot /mnt systemctl enable acpid

chroot /mnt useradd -m juca
chroot /mnt echo juca:200291 | chpasswd

echo "juca ALL=(ALL) ALL" >>/mnt/etc/sudoers.d/juca
echo "junior ALL=(ALL) NOPASSWD: ALL" >>/mnt/etc/sudoers.d/junior

mkinitcpio -P linux-lqx

touch /mnt/etc/rc.local
cat <<EOF >/mnt/etc/rc.local
# PowerTop
powertop --auto-tune

# echo 60000 > /sys/bus/usb/devices/2-1.5/power/autosuspend_delay_ms
# echo 60000 > /sys/bus/usb/devices/2-1.6/power/autosuspend_delay_ms
# echo 60000 > /sys/bus/usb/devices/3-1.5/power/autosuspend_delay_ms
# echo 60000 > /sys/bus/usb/devices/3-1.6/power/autosuspend_delay_ms
# echo 60000 > /sys/bus/usb/devices/4-1.5/power/autosuspend_delay_ms
# echo 60000 > /sys/bus/usb/devices/4-1.6/power/autosuspend_delay_ms

# Preload
# preload
EOF

#Samba
mkdir -p /mnt/etc/samba
cat <<EOF >/mnt/etc/samba/smb.conf
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
mkdir -pv /mnt/etc/sysctl.d
touch /mnt/etc/sysctl.d/00-sysctl.conf
cat <<EOF >/mnt/etc/sysctl.d/00-sysctl.conf
vm.vfs_cache_pressure=500
vm.swappiness=100
vm.dirty_background_ratio=1
vm.dirty_ratio=50
dev.i915.perf_stream_paranoid=0
EOF
#Fix mount external HD
mkdir -pv /mnt/etc/udev/rules.d
cat << EOF >/mnt/etc/udev/rules.d/99-udisks2.rules
# UDISKS_FILESYSTEM_SHARED
# ==1: mount filesystem to a shared directory (/media/VolumeName)
# ==0: mount filesystem to a private directory (/run/media/$USER/VolumeName)
# See udisks(8)
ENV{ID_FS_USAGE}=="filesystem|other|crypto", ENV{UDISKS_FILESYSTEM_SHARED}="1"
EOF

# Not asking for password

mkdir -pv /mnt/etc/polkit-1/rules.d
cat << EOF >/mnt/etc/polkit-1/rules.d/10-udisks2.rules
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

cat <<EOF >/mnt/etc/polkit-1/rules.d/00-mount-internal.rules
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
cat <<EOF >/mnt/etc/doas.conf
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

chroot /mnt chown -c root:root /etc/doas.conf

touch /mnt/etc/modprobe.d/i915.conf
cat <<EOF >/mnt/etc/modprobe.d/i915.conf
options i915 enable_guc=2 enable_dc=4 enable_hangcheck=0 error_capture=0 enable_dp_mst=0 fastboot=1
EOF

# MakeSwap
touch /mnt/swapfile
chroot /mnt chmod 600 /swapfile
chroot /mnt chattr +C /swapfile
chroot /mnt lsattr /swapfile
chroot /mnt dd if=/dev/zero of=/swapfile bs=1M count=6144 status=progress
chroot /mnt mkswap /swapfile
chroot /mnt swapon /swapfile

# # Add to fstab
chroot /mnt echo " " >> /etc/fstab
chroot /mnt echo "# Swap" >> /etc/fstab
chroot /mnt echo "/swapfile      none     swap      defaults  0 0" >> /etc/fstab

# Mkinitcpio
chroot /mnt sed -i 's/MODULES=()/MODULES=(btrfs i915 crc32c-intel)/g' /etc/mkinitcpio.conf
chroot /mnt sed -i 's/HOOKS=(base udev autodetect modconf block filesystems keyboard fsck)/HOOKS=(base udev autodetect modconf block filesystems keyboard resume fsck btrfs)/g' /etc/mkinitcpio.conf
# chroot /mnt sed -i 's/HOOKS=(base udev autodetect modconf block filesystems keyboard fsck)/HOOKS=(base udev autodetect modconf block filesystems keyboard resume fsck btrfs systemd)/g' /etc/mkinitcpio.conf
# chroot /mnt sed -i 's/#COMPRESSION="xz"/COMPRESSION="xz"/g' /etc/mkinitcpio.conf

# Systemd-Boot
chroot /mnt bootctl --path=/boot install
chroot /mnt echo "default arch.conf" >>/boot/loader/loader.conf
touch /mnt/boot/loader/entries/arch.conf

cat <<EOF >/mnt/boot/loader/entries/arch.conf
title   Arch Linux
linux   /vmlinuz-linux-lqx
initrd  /intel-ucode.img
initrd  /initramfs-linux-lqx.img
options root=/dev/sda2 rootflags=subvol=@ rw quiet loglevel=0 console=tty2 acpi_osi=Darwin acpi_mask_gpe=0x06 udev.log_level=0 mitigations=off nowatchdog msr.allow_writes=on pcie_aspm=force module.sig_unenforce intel_idle.max_cstate=1 cryptomgr.notests initcall_debug net.ifnames=0 no_timer_check noreplace-smp page_alloc.shuffle=1 rcupdate.rcu_expedited=1 tsc=reliable
EOF
# options root=/dev/sda2 rootflags=subvol=@ rw quiet splash loglevel=3 mitigations=off nowatchdog msr.allow_writes=on pcie_aspm=force module.sig_unenforce  vt.global_cursor_default=0 intel_idle.max_cstate=1 zswap.enabled=1 zswap.compressor=zstd zswap.max_pool_percent=10 zswap.zpool=zsmalloc cryptomgr.notests initcall_debug intel_iommu=igfx_off net.ifnames=0 no_timer_check noreplace-smp page_alloc.shuffle=1 rcupdate.rcu_expedited=1 tsc=reliable

mkinitcpio -p linux-lqx

usermod -aG libvirt juca
usermod -aG storage juca

paccache -rk0

printf "\e[1;32mDone! Type exit, umount -a and reboot.\e[0m"
