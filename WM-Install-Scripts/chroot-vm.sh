#!/bin/bash

pacman -Sy archlinux-keyring --noconfirm

# Enable pacman Color
sed -i '1n; /^#UseSyslog/i ILoveCandy' /etc/pacman.conf
sed -i '/Color/s/^#//' /etc/pacman.conf
sed -i '3n; /^#UseSyslog/i DisableDownloadTimeout' /etc/pacman.conf
sed -i 's/#ParallelDownloads = 5/ParallelDownloads = 5/g' /etc/pacman.conf

# VERIFY BOOT MODE
# efi_boot_mode(){
#     [[ -d /sys/firmware/efi/efivars ]] && return 0
#     return 1
# }

# Artix

# parted -s -a optimal /dev/vda mklabel gpt
# parted -s -a optimal /dev/vda mkpart primary fat32 1 200MiB
# parted -s -a optimal /dev/vda mkpart primary 200MiB 7GiB
# parted -s -a optimal -- /dev/vda mkpart primary btrfs 7GiB -2048s

# mkfs.vfat -F32 /dev/vda1 -n "ArtixBoot"
# mkfs.btrfs /dev/vda2 -f -L "ArtixRoot"
# mkfs.btrfs /dev/vda3 -f -L "ArtixHome"

#Arch

parted -s -a optimal /dev/vda mklabel gpt
parted -s -a optimal /dev/vda mkpart primary fat32 1 200MiB
parted -s -a optimal /dev/vda mkpart primary 200MiB 7GiB
parted -s -a optimal -- /dev/vda mkpart primary btrfs 7GiB -2048s

    ### SGDISK ###

# Print partition table
# sgdisk -p /dev/vda 


# Delete partition x
# sgdisk -d -1 /dev/vda 


# Create a new partition numbered x, starting at y and ending at z:
# sgdisk -n 1:1MiB:2MiB /dev/vda
# sgdisk -n 0:0MiB:600MiB /dev/vda

# Change the name of partition x to y:
# sgdisk -c 1:grub /dev/vda


# Change the type of partition x to y:
# sgdisk -t 1:ef02 /dev/vda


# List the partition type codes:
# sgdisk --list-types


# Destroy all partitions
# sgdisk --zap-all /dev/vda 
# sgdisk -Zop /dev/vda

# IN_DEVICE=/dev/vda
# BOOT_SIZE=512M
# SWAP_SIZE=2G
# ROOT_SIZE=6.5G
# HOME_SIZE= -2048s

# BOOT_DEVICE="${IN_DEVICE}1"
# ROOT_DEVICE="${IN_DEVICE}2"
# SWAP_DEVICE="${IN_DEVICE}3"
# HOME_DEVICE="${IN_DEVICE}3"



# if $(efi_boot_mode); then
#     sgdisk -Z "$IN_DEVICE"
#     sgdisk -n 1::+"$EFI_SIZE" -t 1:ef00 -c 1:EFI "$IN_DEVICE"
#     sgdisk -n 2::+"$ROOT_SIZE" -t 2:8300 -c 2:ROOT "$IN_DEVICE"
#     # sgdisk -n 3::+"$SWAP_SIZE" -t 3:8200 -c 3:SWAP "$IN_DEVICE"
#     sgdisk -n 3 -c 3:HOME "$IN_DEVICE"
# fi

mkfs.vfat -F32 /dev/vda1 -n "ArchBoot"
mkfs.btrfs /dev/vda2 -f -L "ArchRoot"
mkfs.btrfs /dev/vda3 -f -L "ArchHome"

# OldMac

# parted -s -a optimal /dev/vda mklabel gpt
# parted -s -a optimal /dev/vda mkpart primary fat32 1 200MiB
# parted -s -a optimal /dev/vda mkpart primary 200MiB 7GiB
# parted -s -a optimal -- /dev/vda mkpart primary btrfs 7GiB -2048s

# mkfs.vfat -F32 /dev/sda1
# mkfs.btrfs /dev/sda2 -f
# mkfs.btrfs /dev/sda3 -f

set -e
BTRFS_OPTS="noatime,ssd,compress-force=zstd:16,space_cache=v2,commit=120,autodefrag,discard=async"

# Nitro
mount -o $BTRFS_OPTS /dev/vda2 /mnt

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
# btrfs su cr /mnt/@swap

# Remove partition
umount -v /mnt

# Nitro mount home
mount -o $BTRFS_OPTS /dev/vda3 /mnt
btrfs su cr /mnt/@home
umount -v /mnt

# OldMac mount home
# mount -o $BTRFS_OPTS /dev/sda3 /mnt
# btrfs su cr /mnt/@home
# umount -v /mnt

# Mount partitions (Nitro)
mount -o $BTRFS_OPTS,subvol=@ /dev/vda2 /mnt
# mkdir -pv /mnt/{home,.snapshots,boot/efi,var/log,var/tmp,var/cache,var/swap}
mkdir -pv /mnt/{home,.snapshots,root,srv,usr/local,boot/efi,var/log,var/opt,var/tmp,var/cache}
mkdir -pv /mnt/var/lib/containers
mkdir -pv /mnt/var/lib/containers/storage/overlay
mkdir -pv /mnt/var/lib/pacman
mkdir -pv /mnt/var/lib/libvirt
mkdir -pv /mnt/var/lib/lxd

mount -o $BTRFS_OPTS,subvol=@root /dev/vda2 /mnt/root
mount -o $BTRFS_OPTS,subvol=@home /dev/vda3 /mnt/home
mount -o $BTRFS_OPTS,subvol=@srv /dev/vda2 /mnt/srv
# mount -o $BTRFS_OPTS,subvol=@var /dev/vda2 /mnt/var
mount -o $BTRFS_OPTS,subvol=@pacman /dev/vda2 /mnt/var/lib/pacman
mount -o $BTRFS_OPTS,subvol=@libvirt /dev/vda2 /mnt/var/lib/libvirt
mount -o $BTRFS_OPTS,subvol=@lxd /dev/vda2 /mnt/var/lib/lxd
mount -o $BTRFS_OPTS,subvol=@snapshots /dev/vda2 /mnt/.snapshots
mount -o $BTRFS_OPTS,subvol=@usr_local /dev/vda2 /mnt/usr/local
mount -o $BTRFS_OPTS,subvol=@var_log /dev/vda2 /mnt/var/log
mount -o $BTRFS_OPTS,subvol=@var_opt /dev/vda2 /mnt/var/opt
# mount -o $BTRFS_OPTS,subvol=@swap /dev/vda2 /mnt/var/swap
mount -o $BTRFS_OPTS,subvol=@cache /dev/vda2 /mnt/var/cache
mount -o $BTRFS_OPTS,subvol=@tmp /dev/vda2 /mnt/var/tmp
mount -o $BTRFS_OPTS,subvol=@containers /dev/vda2 /mnt/var/lib/containers
mkdir -pv /mnt/var/lib/containers/storage/overlay
mount -o $BTRFS_OPTS,subvol=@overlay /dev/vda2 /mnt/var/lib/containers/storage/overlay
mount -t vfat -o defaults,noatime,nodiratime /dev/vda1 /mnt/boot/efi
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
#fstabgen -U /mnt >> /mnt/etc/fstab