#!/bin/sh

# export DRIVE="sdb"
# export DRIVE2="sda"
export BOOT_PARTITION="sdb5"
export ROOT_PARTITION="sdb6"
export HOME_PARTITION="sda2"

umount -R /mnt
sgdisk -Z /dev/$ROOT_PARTITION
parted -s -a optimal /dev/$ROOT_PARTITION mklabel gpt
parted -s -a optimal /dev/$HOME_PARTITION mklabel gpt
parted -s -a optimal /dev/$BOOT_PARTITION mklabel gpt
sgdisk -t 5:ef00 /dev/$BOOT_PARTITION
sgdisk -t 6:8300 /dev/$ROOT_PARTITION
sgdisk -t 2:8302 /dev/$HOME_PARTITION
sgdisk -c 5:GRUB /dev/$BOOT_PARTITION
sgdisk -c 6:VOID /dev/$ROOT_PARTITION
sgdisk -c 2:VoidHome /dev/$HOME_PARTITION
parted /dev/$ROOT_PARTITION -- set 1 esp on
sgdisk -p /dev/sdb
sgdisk -p /dev/sda

mkfs.vfat -F32 /dev/$BOOT_PARTITION -n "GRUB"
mkfs.btrfs /dev/$ROOT_PARTITION -f -L "VOID"
# mkfs.xfs /dev/$HOME_PARTITION -f -L "VoidHome"
mkfs.xfs /dev/sda2 -f -L "VoidHome"

BTRFS_OPTS="rw,noatime,ssd,compress-force=zstd:8,space_cache=v2,commit=120,autodefrag,discard=async"
mount -o $BTRFS_OPTS -L VOID /mnt
btrfs su cr /mnt/@
btrfs su cr /mnt/@snapshots
btrfs su cr /mnt/@var_log
btrfs su cr /mnt/@var_cache_xbps
btrfs su cr /mnt/@tmp
# btrfs su cr /mnt/@swap
umount -R /mnt

# mount -o $BTRFS_OPTS,subvol="@root" NIXOS /mnt
mount -o $BTRFS_OPTS,subvol="@" -L VOID /mnt
mkdir -pv /mnt/boot/efi
mkdir -pv /mnt/home
mkdir -pv /mnt/.snapshots
mkdir -pv /mnt/var/log
mkdir -pv /mnt/var/tmp
mkdir -pv /mnt/var/cache/xbps


mount -o $BTRFS_OPTS,subvol="@snapshots" -L VOID /mnt/.snapshots
mount -o $BTRFS_OPTS,subvol="@tmp" -L VOID /mnt/var/tmp
mount -o $BTRFS_OPTS,subvol="@var_log" -L VOID /mnt/var/log
mount -o $BTRFS_OPTS,subvol="@var_cache_xbps" -L VOID /mnt/var/cache/xbps
mount -L VoidHome /mnt/home
mount -t vfat -o rw,defaults,noatime,nodiratime -L GRUB /mnt/boot/efi
