#!/bin/bash

# Enable pacman Color
sed -i '1n; /^#UseSyslog/i ILoveCandy' /etc/pacman.conf
sed -i '/Color/s/^#//' /etc/pacman.conf
sed -i 's/#ParallelDownloads = 5/ParallelDownloads = 5/g' /etc/pacman.conf

# Artix
mkfs.vfat -F32 /dev/sda5 -n "ArtixBoot"
mkfs.btrfs /dev/sda6 -f -L "ArtixRoot"
mkfs.btrfs /dev/sda7 -f -L "ArtixHome"

#Arch
mkfs.vfat -F32 /dev/sda5 -n "ArchBoot"
mkfs.btrfs /dev/sda6 -f -L "ArchRoot"
mkfs.btrfs /dev/sda7 -f -L "ArchHome"

# OldMac
# mkfs.vfat -F32 /dev/sda1
# mkfs.btrfs /dev/sda2 -f
# mkfs.btrfs /dev/sda3 -f

set -e
BTRFS_OPTS="noatime,ssd,compress-force=zstd:16,space_cache=v2,commit=120,autodefrag,discard=async"

# Nitro
mount -o $BTRFS_OPTS /dev/sda6 /mnt

# OldMac
# mount -o $BTRFS_OPTS /dev/sda2 /mnt

#Create Subvolumes

btrfs su cr /mnt/@
btrfs su cr /mnt/@snapshots
btrfs su cr /mnt/@var_log
btrfs su cr /mnt/@tmp
btrfs su cr /mnt/@cache
# btrfs su cr /mnt/@swap

# Remove partition
umount -v /mnt

# Nitro mount home
mount -o $BTRFS_OPTS /dev/sda7 /mnt
btrfs su cr /mnt/@home
umount -v /mnt

# OldMac mount home
# mount -o $BTRFS_OPTS /dev/sda3 /mnt
# btrfs su cr /mnt/@home
# umount -v /mnt

# Mount partitions (Nitro)
mount -o $BTRFS_OPTS,subvol=@ /dev/sda6 /mnt
# mkdir -pv /mnt/{home,.snapshots,boot/efi,var/log,var/tmp,var/cache,var/swap}
mkdir -pv /mnt/{home,.snapshots,boot/efi,var/log,var/tmp,var/cache}
mount -o $BTRFS_OPTS,subvol=@home /dev/sda7 /mnt/home
mount -o $BTRFS_OPTS,subvol=@snapshots /dev/sda6 /mnt/.snapshots
mount -o $BTRFS_OPTS,subvol=@var_log /dev/sda6 /mnt/var/log
# mount -o $BTRFS_OPTS,subvol=@swap /dev/sda6 /mnt/var/swap
mount -o $BTRFS_OPTS,subvol=@cache /dev/sda6 /mnt/var/cache
mount -o $BTRFS_OPTS,subvol=@tmp /dev/sda6 /mnt/var/tmp
mount -t vfat -o defaults,noatime,nodiratime /dev/sda5 /mnt/boot/efi

# Mount partitions (Oldmac) | W/Systemd-Boot
# mount -o $BTRFS_OPTS,subvol=@ /dev/sda2 /mnt
# mkdir -pv /mnt/{home,.snapshots,boot,var/log}
# mount -o $BTRFS_OPTS,subvol=@home /dev/sda3 /mnt/home
# mount -o $BTRFS_OPTS,subvol=@snapshots /dev/sda2 /mnt/.snapshots
# mount -o $BTRFS_OPTS,subvol=@var_log /dev/sda2 /mnt/var/log
# mount -t vfat -o defaults,noatime,nodiratime /dev/sda1 /mnt/boot

############    ARCH     ############

### Nitro
 pacstrap /mnt base base-devel linux-lts linux-lts-headers linux-firmware dropbear git nano neovim intel-ucode fzf duf reflector mtools dosfstools btrfs-progs pacman-contrib --ignore linux openssh

# Generate fstab
 genfstab -U /mnt >> /mnt/etc/fstab

### Old Mac
# pacstrap /mnt base base-devel linux-lts linux-lts-headers linux-firmware btrfs-progs git neovim nano reflector duf exa fzf ripgrep pacman-contrib duf --ignore linux

# Generate fstab
# genfstab -U /mnt >> /mnt/etc/fstab

############    Artix    ############

### Artix Runit
# basestrap /mnt base base-devel artools-base linux-lts linux-lts-headers runit elogind-runit linux-firmware git intel-ucode nano neovim mtools dosfstools dropbear dropbear-runit pacman-contrib fzf ripgrep btrfs-progs --ignore linux

# Generate fstab
# fstabgen -U /mnt >>/mnt/etc/fstab

### Artix s6
#basestrap /mnt base base-devel artools-base s6-base linux-lts linux-lts-headers elogind-s6 linux-firmware git intel-ucode nano neovim mtools dosfstools dropbear dropbear-s6 pacman-contrib fzf ripgrep btrfs-progs --ignore linux

# Generate fstab
#stabgen -U /mnt >> /mnt/etc/fstab