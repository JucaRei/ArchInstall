#!/usr/bin/env bash

dnf install -y gdisk arch-install-scripts

# 🧭 Drive + partition paths
DRIVE="/dev/sda"
SYSTEM_PART="${DRIVE}2"
EFI_PART="${DRIVE}3"
ROOT_PART="${DRIVE}4"
HOME_PART="${DRIVE}5"
WINDOWS_PART="${DRIVE}7"
MISC_PART="${DRIVE}8"


# 🔖 Labels
ROOT_LABEL="Fedora"
HOME_LABEL="HOME"
# SWAP_LABEL="SWAP"
SYSTEM_LABEL="BOOT"
EFI_LABEL="ESP"
# WINDOWS_LABEL="Windows_11"
# MISC_LABEL="SharedData"

# ⚙️ Btrfs options
BTRFS_OPTS="noatime,nodatasum,nodatacow,ssd,compress-force=zstd:8,space_cache=v2,nodatacow,commit=120,discard=async"
BTRFS_OPTS_HOME="noatime,nodatasum,nodatacow,ssd,compress-force=zstd:15,space_cache=v2,nodatacow,commit=120,discard=async"


mount -o $BTRFS_OPTS,subvol=@root           /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT
mount -o $BTRFS_OPTS_HOME,subvol=@home      /dev/disk/by-label/$HOME_LABEL $MOUNTPOINT/home
mount -o $BTRFS_OPTS,subvol=@opt            /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/opt
mount -o $BTRFS_OPTS,subvol=@gdm            /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/var/lib/gdm
mount -o $BTRFS_OPTS,subvol=@libvirt        /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/var/lib/libvirt
mount -o $BTRFS_OPTS,subvol=@log            /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/var/log
mount -o $BTRFS_OPTS,subvol=@nix            /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/nix
mount -o $BTRFS_OPTS,subvol=@spool          /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/var/spool
mount -o $BTRFS_OPTS,subvol=@tmp            /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/var/tmp
mount -o $BTRFS_OPTS,subvol=@cache          /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/var/cache
mount -o $BTRFS_OPTS,subvol=@snapshots      /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/.snapshots

echo "⏏️ Mounting boot and EFI..."
mount /dev/disk/by-label/$SYSTEM_LABEL $MOUNTPOINT/boot
mount -t vfat -o defaults,noatime,nodiratime /dev/disk/by-label/$EFI_LABEL $MOUNTPOINT/boot/efi

echo "🔧 Mounting system filesystems..."
udevadm trigger
mkdir -p $MOUNTPOINT/{proc,sys,dev/pts}
mount -t proc   proc     $MOUNTPOINT/proc
mount -t sysfs  sysfs    $MOUNTPOINT/sys
mount --rbind   /dev     $MOUNTPOINT/dev
mount -t devpts devpts   $MOUNTPOINT/dev/pts
