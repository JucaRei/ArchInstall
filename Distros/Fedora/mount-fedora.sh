#!/usr/bin/env bash

DRIVE="/dev/nvme0n1"
SYSTEM_PART="${DRIVE}p2"
EFI_PART="${DRIVE}p3"
ROOT_PART="${DRIVE}p4"
HOME_PART="${DRIVE}p5"

ROOT_LABEL="Linux"
HOME_LABEL="Data-home"
# SWAP_LABEL="SWAP"
SYSTEM_LABEL="BOOT"
EFI_LABEL="ESP"

MOUNTPOINT="/mnt"

BTRFS_OPTS="noatime,ssd,compress-force=zstd:15,space_cache=v2,commit=120,discard=async"
BTRFS_OPTS2="noatime,ssd,compress-force=zstd:6,space_cache=v2,commit=120,discard=async"
BTRFS_OPTS_HOME="noatime,ssd,compress-force=zstd:15,space_cache=v2,commit=120,discard=async"

mount -o $BTRFS_OPTS,subvol=@ 		    /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT
mount -o $BTRFS_OPTS_HOME,subvol=@home      /dev/disk/by-label/$HOME_LABEL $MOUNTPOINT/home
mount -o $BTRFS_OPTS,subvol=@opt            /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/opt
mount -o $BTRFS_OPTS,subvol=@gdm            /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/var/lib/gdm
mount -o $BTRFS_OPTS,subvol=@libvirt        /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/var/lib/libvirt
mount -o $BTRFS_OPTS2,subvol=@log           /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/var/log
mount -o $BTRFS_OPTS,subvol=@nix            /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/nix
mount -o $BTRFS_OPTS,subvol=@spool          /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/var/spool
mount -o $BTRFS_OPTS2,subvol=@tmp           /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/var/tmp
mount -o $BTRFS_OPTS,subvol=@cache          /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/var/cache
mount -o $BTRFS_OPTS,subvol=@snapshots      /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/.snapshots

mount /dev/disk/by-label/$SYSTEM_LABEL $MOUNTPOINT/boot
mount -t vfat -o defaults,noatime,nodiratime /dev/disk/by-label/$EFI_LABEL $MOUNTPOINT/boot/efi

echo "🔧 Mounting system filesystems..."
udevadm trigger
mkdir -p $MOUNTPOINT/{proc,sys,dev/pts}
mount -t proc   proc     $MOUNTPOINT/proc
mount -t sysfs  sysfs    $MOUNTPOINT/sys
mount --rbind   /dev     $MOUNTPOINT/dev
mount -t devpts devpts   $MOUNTPOINT/dev/pts
mount -t efivarfs efivarfs $MOUNTPOINT/sys/firmware/efi/efivars
