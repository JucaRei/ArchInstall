#!/bin/sh

umount -R /mnt
sgdisk -Z /dev/vda
parted -s -a optimal /dev/vda mklabel gpt
sgdisk -n 0:0:512MiB /dev/vda
sgdisk -n 0:0:0 /dev/vda
sgdisk -t 1:ef00 /dev/vda
sgdisk -t 2:8300 /dev/vda
sgdisk -c 1:GRUB /dev/vda
sgdisk -c 2:Voidlinux /dev/vda
parted /dev/vda -- set 1 esp on
sgdisk -p /dev/vda

mkfs.vfat -F32 /dev/vda1 -n "GRUB"
mkfs.btrfs /dev/vda2 -f -L "Voidlinux"

BTRFS_OPTS="rw,noatime,ssd,compress-force=zstd:15,space_cache=v2,nodatacow,commit=120,autodefrag,discard=async"
mount -o $BTRFS_OPTS /dev/vda2 /mnt
btrfs su cr /mnt/@root
btrfs su cr /mnt/@home
btrfs su cr /mnt/@snapshots
btrfs su cr /mnt/@var_log
btrfs su cr /mnt/@var_cache_xbps
btrfs su cr /mnt/@tmp
# btrfs su cr /mnt/@swap
umount -R /mnt

mount -o $BTRFS_OPTS,subvol="@root" /dev/disk/by-label/Voidlinux /mnt
mkdir -pv /mnt/{boot/efi,home,.snapshots,var/log,var/tmp,var/cache/xbps,var/swap}
mount -o $BTRFS_OPTS,subvol="@home" /dev/disk/by-label/Voidlinux /mnt/home
mount -o $BTRFS_OPTS,subvol="@snapshots" /dev/disk/by-label/Voidlinux /mnt/.snapshots
# mount -o $BTRFS_OPTS,subvol=@swap /dev/disk/by-label/Voidlinux /mnt/var/swap
mount -o $BTRFS_OPTS,subvol="@tmp" /dev/disk/by-label/Voidlinux /mnt/var/tmp
mount -o $BTRFS_OPTS,subvol="@var_log" /dev/disk/by-label/Voidlinux /mnt/var/log
mount -o $BTRFS_OPTS,subvol="@var_cache_xbps" /dev/disk/by-label/Voidlinux /mnt/var/cache/xbps
mount -t vfat -o rw,defaults,noatime,nodiratime /dev/disk/by-label/GRUB /mnt/boot/efi

# for dir in dev proc sys run; do
#    mount --rbind /$dir /mnt/$dir
#    mount --make-rslave /mnt/$dir
# done

# UEFI_UUID=$(blkid -s UUID -o value /dev/vda1)
# ROOT_UUID=$(blkid -s UUID -o value /dev/vda2)
