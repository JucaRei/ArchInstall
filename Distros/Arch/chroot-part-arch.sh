#!/bin/bash

# Arch Linux

pacman -Sy archlinux-keyring --noconfirm

# Enable pacman Color
sed -i '1n; /^#UseSyslog/i ILoveCandy' /etc/pacman.conf
sed -i '/Color/s/^#//' /etc/pacman.conf
sed -i '3n; /^#UseSyslog/i DisableDownloadTimeout' /etc/pacman.conf
sed -i 's/#ParallelDownloads = 5/ParallelDownloads = 4/g' /etc/pacman.conf

# cat <<\ EOF >> /etc/pacman.conf

# [liquorix]
# Server = https://liquorix.net/archlinux/$repo/$arch

# EOF
# Get Best Mirrors
# reflector --protocol https --country "Brazil" --latest 10 --sort rate --save /etc/pacman.d/mirrorlist

pacman -Syyy

# =======================================================================================================================================================

### Change depending on the machine

#####################
###### Nitro 5 ######
#####################

mkfs.vfat -F32 /dev/sda4 -n "Grubarch"
mkfs.btrfs /dev/sda5 -f -L "ArchRoot"

mount -t btrfs /dev/sda5 /mnt

btrfs su cr /mnt/@
btrfs su cr /mnt/@pacman
btrfs su cr /mnt/@snapshots
btrfs su cr /mnt/@var_log
btrfs su cr /mnt/@tmp
btrfs su cr /mnt/@cache
btrfs su cr /mnt/@home

# btrfs su cr /mnt/@swap

umount -v /

set -e
BTRFS_OPTS="noatime,ssd,compress-force=zstd:11,space_cache=v2,commit=120,autodefrag,discard=async"

## Mount partitions (Nitro)
mount -o $BTRFS_OPTS,subvol=@ /dev/sda5 /mnt
mkdir -pv /mnt/{home,.snapshots,boot/efi,var/log,var/tmp,var/cache,var/lib/pacman}

# Swap Optional
# mkdir -pv /mnt/var/swap

mount -o $BTRFS_OPTS,subvol=@pacman /dev/sda5 /mnt/var/lib/pacman
mount -o $BTRFS_OPTS,subvol=@home /dev/sda5 /mnt/home
mount -o $BTRFS_OPTS,subvol=@snapshots /dev/sda5 /mnt/.snapshots
mount -o $BTRFS_OPTS,subvol=@var_log /dev/sda5 /mnt/var/log
mount -o $BTRFS_OPTS,subvol=@cache /dev/sda5 /mnt/var/cache
mount -o $BTRFS_OPTS,subvol=@tmp /dev/sda5 /mnt/var/tmp
mount -t vfat -o defaults,noatime,nodiratime /dev/sda4 /mnt/boot/efi

# mount -o $BTRFS_OPTS,subvol=@swap /dev/sda5 /mnt/var/swap

# Base packages LTS kernel
pacstrap /mnt base base-devel linux-lts linux-lts-headers linux-firmware archlinux-keyring man-db perl sysfsutils python python-pip git man-pages dropbear git nano neovim intel-ucode fzf duf reflector mtools ansible dosfstools btrfs-progs pacman-contrib nfs-utils --ignore linux vi openssh

# Base packages Liquorix Kernel
pacstrap /mnt base base-devel linux-lqx linux-lqx-headers linux-firmware archlinux-keyring man-db perl sysfsutils python python-pip git man-pages dropbear git nano neovim intel-ucode fzf duf reflector mtools ansible dosfstools btrfs-progs pacman-contrib nfs-utils --ignore linux vi

# Generate fstab
genfstab -U /mnt >>/mnt/etc/fstab


# =======================================================================================================================================================

#####################
###### OldMac #######
#####################

# Systemd boot (shared with Apple )
# mkfs.vfat -F32 /dev/sda1 -n "Archmac"
mkfs.btrfs /dev/sda4 -f -L "Arch"

mount -t btrfs /dev/sda4 /mnt

btrfs su cr /mnt/@
btrfs su cr /mnt/@pacman
btrfs su cr /mnt/@snapshots
btrfs su cr /mnt/@var_log
btrfs su cr /mnt/@swap
btrfs su cr /mnt/@tmp
btrfs su cr /mnt/@cache
btrfs su cr /mnt/@home

umount -v /mnt

set -e
BTRFS_OPTS="noatime,ssd,compress-force=zstd:8,space_cache=v2,commit=120,autodefrag,discard=async"

parted -s /dev/sda mklabel msdos

## Mount partitions (Oldmac)
mount -o $BTRFS_OPTS,subvol=@ /dev/sda4 /mnt
mkdir -pv /mnt/{home,.snapshots,boot/grub,var/log,var/tmp,var/cache,var/lib/pacman}

# Swap Optional
mkdir -pv /mnt/var/swap

mount -o $BTRFS_OPTS,subvol=@home /dev/sda4 /mnt/home
mount -o $BTRFS_OPTS,subvol=@snapshots /dev/sda4 /mnt/.snapshots
mount -o $BTRFS_OPTS,subvol=@var_log /dev/sda4 /mnt/var/log
mount -o $BTRFS_OPTS,subvol=@cache /dev/sda4 /mnt/var/cache
mount -o $BTRFS_OPTS,subvol=@tmp /dev/sda4 /mnt/var/tmp
mount -o $BTRFS_OPTS,subvol=@swap /dev/sda4 /mnt/var/swap
mount -o $BTRFS_OPTS,subvol=@pacman /dev/sda4 /mnt/var/lib/pacman
mount -t vfat -o defaults,noatime,nodiratime /dev/sda1 /mnt/boot

### Old Mac
# pacstrap /mnt base base-devel linux linux-headers linux-firmware intel-ucode btrfs-progs archlinux-keyring git neovim nano reflector dropbear duf exa fzf ripgrep pacman-contrib --ignore vi openssh
pacstrap /mnt base base-devel linux-lts linux-lts-headers linux-firmware intel-ucode btrfs-progs archlinux-keyring git neovim nano reflector dropbear duf exa fzf ripgrep pacman-contrib --ignore vi openssh linux linux-headers

# Generate fstab
genfstab -U /mnt >>/mnt/etc/fstab

# =======================================================================================================================================================

#####################
##### oldmacAir #####
#####################


DRIVE="/dev/sda"

sgdisk -Z $DRIVE
# parted $DRIVE mklabel gpt
# parted $DRIVE mkpart primary 2048s 100%
parted --script --fix --align optimal $DRIVE mklabel gpt
parted --script --fix --align optimal $DRIVE mkpart primary fat32 1MiB 512MiB
parted --script $DRIVE -- set 1 boot on

# parted --script --align optimal -- $DRIVE mkpart primary 600MB 100%
# parted --script --align optimal --fix -- $DRIVE mkpart primary linux-swap -2GiB -1s
parted --script --align optimal --fix -- $DRIVE mkpart primary 512MiB -6GiB
parted --script --align optimal --fix -- $DRIVE mkpart primary -6GiB 100%

# parted --script align-check 1 $DRIVE

sgdisk -c 1:"EFI FileSystem partition" ${DRIVE}
sgdisk -c 2:"Archlinux FileSystem" ${DRIVE}
sgdisk -c 3:"Archlinux Swap" ${DRIVE}
sgdisk -p ${DRIVE}

BOOT_PARTITION="${DRIVE}1"
ROOT_PARTITION="${DRIVE}2"
SWAP_PARTITION="${DRIVE}3"

#####################################
##########  FileSystem  #############
#####################################

#######################
#### real hardware ####
#######################

# mkswap /dev/sda4 -L "LinuxSwap"
# swapon /dev/sda4
# mkfs.btrfs /dev/sda5 -f -L "LinuxSystem"

mkfs.vfat -F32 $BOOT_PARTITION -n "EFI"
mkfs.btrfs $ROOT_PARTITION -f -L "Archsys"
mkswap /dev/sda3 -L "SWAP"
swapon /dev/disk/by-label/SWAP

###############################
#### Enviroments variables ####
###############################

## btrfs options ##
BTRFS_OPTS="noatime,ssd,compress-force=zstd:15,space_cache=v2,commit=120,discard=async"

## fstab real hardware ##
UEFI_UUID=$(blkid -s UUID -o value $BOOT_PARTITION)
ROOT_UUID=$(blkid -s UUID -o value $ROOT_PARTITION)
SWAP_UUID=$(blkid -s UUID -o value $SWAP_PARTITION)


###########################################
#### Mount and create Btrfs Subvolumes ####
###########################################

#######################
#### real hardware ####
#######################
mount -o $BTRFS_OPTS $ROOT_PARTITION /mnt
btrfs su cr /mnt/@
btrfs su cr /mnt/@home
btrfs su cr /mnt/@snapshots
btrfs su cr /mnt/@var_log
btrfs su cr /mnt/@pacman
btrfs su cr /mnt/@cache
btrfs su cr /mnt/@tmp
btrfs su cr /mnt/@swap
umount -v /mnt
## Make directories for mount ##
mount -o $BTRFS_OPTS,subvol=@ $ROOT_PARTITION /mnt
mkdir -pv /mnt/boot
mkdir -pv /mnt/boot/efi
mkdir -pv /mnt/home
mkdir -pv /mnt/.snapshots
mkdir -pv /mnt/var/log
mkdir -pv /mnt/var/swap
mkdir -pv /mnt/var/tmp
mkdir -pv /mnt/var/cache
mkdir -pv /mnt/var/lib/pacman

## Mount btrfs subvolumes ##
mount -o $BTRFS_OPTS,subvol=@home $ROOT_PARTITION /mnt/home
mount -o $BTRFS_OPTS,subvol=@snapshots $ROOT_PARTITION /mnt/.snapshots
mount -o $BTRFS_OPTS,subvol=@var_log $ROOT_PARTITION /mnt/var/log
mount -o $BTRFS_OPTS,subvol=@tmp $ROOT_PARTITION /mnt/var/tmp
mount -o $BTRFS_OPTS,subvol=@pacman $ROOT_PARTITION /mnt/var/lib/pacman
mount -o $BTRFS_OPTS,subvol=@cache $ROOT_PARTITION /mnt/var/cache
# mount -o $BTRFS_OPTS,subvol=@pacman $ROOT_PARTITION /mnt/var/swap
mount -t vfat -o noatime,nodiratime $BOOT_PARTITION /mnt/boot/efi

### oldmacAIR
pacstrap /mnt base base-devel linux-zen linux-zen-headers linux-firmware archlinux-keyring lm_sensors man-db perl sysfsutils  git dropbear git nano intel-ucode duf reflector mtools dosfstools btrfs-progs pacman-contrib nfs-utils --ignore linux vi openssh

# Generate fstab
genfstab -U /mnt >>/mnt/etc/fstab
