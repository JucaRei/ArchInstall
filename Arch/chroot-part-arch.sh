#!/bin/bash

# Arch Linux

pacman -Sy archlinux-keyring --noconfirm

# Enable pacman Color
sed -i '1n; /^#UseSyslog/i ILoveCandy' /etc/pacman.conf
sed -i '/Color/s/^#//' /etc/pacman.conf
sed -i '3n; /^#UseSyslog/i DisableDownloadTimeout' /etc/pacman.conf
sed -i 's/#ParallelDownloads = 5/ParallelDownloads = 5/g' /etc/pacman.conf

pacman -Syyy

#Arch
mkfs.vfat -F32 /dev/sda4 -n "ArchBoot"
mkfs.btrfs /dev/sda6 -f -L "ArchRoot"
mkfs.btrfs /dev/sda6 -f -L "ArchHome"

# OldMac
# mkfs.vfat -F32 /dev/sda1 -n "Archmac"
# mkfs.btrfs /dev/sda2 -f -L "Archfs"
# mkfs.btrfs /dev/sda3 -f -L "Archome"

set -e
BTRFS_OPTS="noatime,ssd,compress-force=zstd:18,space_cache=v2,commit=120,autodefrag,discard=async"

mount -t btrfs /dev/sda6 /mnt

# Nitro
# mount -o $BTRFS_OPTS /dev/sda6 /mnt

# OldMac
# mount -o $BTRFS_OPTS /dev/sda2 /mnt

#Create Subvolumes

btrfs su cr /mnt/@
btrfs su cr /mnt/@root
btrfs su cr /mnt/@srv
# btrfs su cr /mnt/@var
btrfs su cr /mnt/@pacman
btrfs su cr /mnt/@snapshots
btrfs su cr /mnt/@containers
btrfs su cr /mnt/@libvirt
btrfs su cr /mnt/@lxd
btrfs su cr /mnt/@overlay
btrfs su cr /mnt/@var_log
btrfs su cr /mnt/@usr_local
btrfs su cr /mnt/@var_opt
btrfs su cr /mnt/@tmp
btrfs su cr /mnt/@cache
btrfs su cr /mnt/@home
# btrfs su cr /mnt/@swap

# Remove partition
umount -v /mnt

# Nitro mount home on separated partition
# mount -o $BTRFS_OPTS /dev/sda6 /mnt
# btrfs su cr /mnt/@home
# umount -v /mnt

# OldMac mount home
# mount -o $BTRFS_OPTS /dev/sda3 /mnt
# btrfs su cr /mnt/@home
# umount -v /mnt

# Mount partitions (Nitro)
mount -o $BTRFS_OPTS,subvol=@ /dev/sda6 /mnt
# mkdir -pv /mnt/{home,.snapshots,boot/efi,var/log,var/tmp,var/cache,var/swap}
mkdir -pv /mnt/{home,.snapshots,root,srv,usr/local,boot/efi,var/log,var/opt,var/tmp,var/cache}
mkdir -pv /mnt/var/lib/containers
mkdir -pv /mnt/var/lib/containers/storage/overlay
mkdir -pv /mnt/var/lib/pacman
mkdir -pv /mnt/var/lib/libvirt
mkdir -pv /mnt/var/lib/lxd

mount -o $BTRFS_OPTS,subvol=@root /dev/sda6 /mnt/root
mount -o $BTRFS_OPTS,subvol=@home /dev/sda6 /mnt/home
mount -o $BTRFS_OPTS,subvol=@srv /dev/sda6 /mnt/srv
# mount -o $BTRFS_OPTS,subvol=@var /dev/sda6 /mnt/var
mount -o $BTRFS_OPTS,subvol=@pacman /dev/sda6 /mnt/var/lib/pacman
mount -o $BTRFS_OPTS,subvol=@libvirt /dev/sda6 /mnt/var/lib/libvirt
mount -o $BTRFS_OPTS,subvol=@lxd /dev/sda6 /mnt/var/lib/lxd
mount -o $BTRFS_OPTS,subvol=@snapshots /dev/sda6 /mnt/.snapshots
mount -o $BTRFS_OPTS,subvol=@usr_local /dev/sda6 /mnt/usr/local
mount -o $BTRFS_OPTS,subvol=@var_log /dev/sda6 /mnt/var/log
mount -o $BTRFS_OPTS,subvol=@var_opt /dev/sda6 /mnt/var/opt
# mount -o $BTRFS_OPTS,subvol=@swap /dev/sda6 /mnt/var/swap
mount -o $BTRFS_OPTS,subvol=@cache /dev/sda6 /mnt/var/cache
mount -o $BTRFS_OPTS,subvol=@tmp /dev/sda6 /mnt/var/tmp
mount -o $BTRFS_OPTS,subvol=@containers /dev/sda6 /mnt/var/lib/containers
mkdir -pv /mnt/var/lib/containers/storage/overlay
mount -o $BTRFS_OPTS,subvol=@overlay /dev/sda6 /mnt/var/lib/containers/storage/overlay
mount -t vfat -o defaults,noatime,nodiratime /dev/sda4 /mnt/boot/efi

# Mount partitions (Oldmac) | W/Systemd-Boot
# mount -o $BTRFS_OPTS,subvol=@ /dev/sda2 /mnt
# mkdir -pv /mnt/{home,.snapshots,boot,var/log}
# mount -o $BTRFS_OPTS,subvol=@home /dev/sda3 /mnt/home
# mount -o $BTRFS_OPTS,subvol=@snapshots /dev/sda2 /mnt/.snapshots
# mount -o $BTRFS_OPTS,subvol=@var_log /dev/sda2 /mnt/var/log
# mount -t vfat -o defaults,noatime,nodiratime /dev/sda1 /mnt/boot

############    ARCH     ############

### Nitro
pacstrap /mnt base base-devel linux-lts linux-lts-headers linux-firmware archlinux-keyring man-db perl sysfsutils python python-pip git man-pages dropbear git nano neovim intel-ucode fzf duf reflector mtools ansible dosfstools btrfs-progs pacman-contrib mkinitcpio-nfs-utils nfs-utils --ignore linux openssh

# Generate fstab
genfstab -U /mnt >>/mnt/etc/fstab

### Old Mac
# pacstrap /mnt base base-devel linux-lts linux-lts-headers linux-firmware btrfs-progs git neovim nano reflector duf exa fzf ripgrep pacman-contrib --ignore linux

# Generate fstab
# genfstab -U /mnt >> /mnt/etc/fstab
