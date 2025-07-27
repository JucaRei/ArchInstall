#!/usr/bin/env bash

# Variables
hostname="vmtest"
name="Reinaldo P JR"
username="juca"
Architecture="amd64"
# DRIVE="/dev/sda"
DRIVE="/dev/vda"
SYSTEM_PART="${DRIVE}2"
EFI_PART="${DRIVE}3"
ROOT_PART="${DRIVE}4"
HOME_PART="${DRIVE}5"
WINDOWS_PART="${DRIVE}7"
MISC_PART="${DRIVE}8"

# MAPPER_NAME="secure_btrfs"
MOUNTPOINT="/mnt"
ROOT_LABEL="Debian"
HOME_LABEL="home"
SWAP_LABEL="swap" 
EFI_LABEL="ESP"
SYSTEM_LABEL="SYSTEM"
WINDOWS_LABEL="Windows 11"
MISC_LABEL="SharedData"
BTRFS_OPTS="noatime,ssd,compress-force=zstd:8,space_cache=v2,nodatacow,commit=120,discard=async"
BTRFS_OPTS_HOME="noatime,ssd,compress-force=zstd:15,space_cache=v2,nodatacow,commit=120,discard=async"
TMPFS="ssd,noatime,mode=1777,nosuid,nodev,compress-force=zstd:3,discard=async,space_cache=v2,commit=60"

mount -o $BTRFS_OPTS,subvol=@root /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT
mount -o $BTRFS_OPTS_HOME,subvol=@home /dev/disk/by-label/$HOME_LABEL $MOUNTPOINT/home
mount -o $BTRFS_OPTS_HOME,subvol=@nix /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/nix
mount -o $BTRFS_OPTS,subvol=@opt /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/opt
mount -o $BTRFS_OPTS,subvol=@gdm /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/var/lib/gdm
mount -o $BTRFS_OPTS,subvol=@libvirt /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/var/lib/libvirt
mount -o $BTRFS_OPTS,subvol=@log /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/var/log
mount -o $BTRFS_OPTS,subvol=@spool /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/var/spool
mount -o $TMPFS,subvol=@tmp /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/var/tmp
mount -o $BTRFS_OPTS,subvol=@cache /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/var/cache
mount -o $BTRFS_OPTS,subvol=@snapshots /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/.snapshots
mount /dev/disk/by-label/$SYSTEM_LABEL $MOUNTPOINT/boot
mount -t vfat -o defaults,noatime,nodiratime /dev/disk/by-label/$EFI_LABEL $MOUNTPOINT/boot/efi

for dir in dev proc sys run; do
    mount --rbind /$dir /mnt/$dir
    mount --make-rslave /mnt/$dir
done
