#!/usr/bin/env bash
DRIVE="/dev/sda"
BTRFS_OPTS="noatime,ssd,compress-force=zstd:15,space_cache=v2,commit=120,discard=async"

swapon /dev/disk/by-label/SWAP
mount -o $BTRFS_OPTS,subvol=@ /dev/disk/by-label/Archsys /mnt
mount -o $BTRFS_OPTS,subvol=@pacman /dev/disk/by-label/Archsys /mnt/var/lib/pacman
mount -o $BTRFS_OPTS,subvol=@home /dev/disk/by-label/Archsys /mnt/home
mount -o $BTRFS_OPTS,subvol=@snapshots /dev/disk/by-label/Archsys /mnt/.snapshots
mount -o $BTRFS_OPTS,subvol=@var_log /dev/disk/by-label/Archsys /mnt/var/log
# mount -o $BTRFS_OPTS,subvol=@cache /dev/disk/by-label/Archsys /mnt/var/cache
mount -o $BTRFS_OPTS,subvol=@tmp /dev/disk/by-label/Archsys /mnt/var/tmp
# mount -o $BTRFS_OPTS,subvol=@swap /dev/disk/by-label/Archsys /mnt/swap
mount -t vfat -o defaults,noatime,nodiratime /dev/disk/by-label/EFI /mnt/boot/efi
