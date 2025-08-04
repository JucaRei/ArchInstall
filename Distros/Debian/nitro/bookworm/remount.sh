#!/usr/bin/env bash

# Variables
hostname="nitro"
name="Reinaldo P JR"
username="juca"
Architecture="amd64"
CODENAME=bookworm #$(lsb_release --codename --short) # or CODENAME=bookworm
# DRIVE="/dev/sda"
DRIVE="/dev/nvme0n1"
SYSTEM_PART="${DRIVE}p2"
EFI_PART="${DRIVE}p3"
ROOT_PART="${DRIVE}p4"
WINDOWS_PART="${DRIVE}p6"
MISC_PART="${DRIVE}p7"
# HOME_PART="${DRIVE}p5"
# WINDOWS_PART="${DRIVE}p7"
# MISC_PART="${DRIVE}p8"

# MAPPER_NAME="secure_btrfs"
MOUNTPOINT="/mnt"
ROOT_LABEL="Debian"
# HOME_LABEL="home"
SWAP_LABEL="swap" 
EFI_LABEL="ESP"
SYSTEM_LABEL="SYSTEM"
WINDOWS_LABEL="Windows 11"
MISC_LABEL="SharedData"
BTRFS_OPTS="noatime,ssd,compress-force=zstd:8,space_cache=v2,nodatacow,commit=120,discard=async"
BTRFS_OPTS_HOME="noatime,ssd,compress-force=zstd:15,space_cache=v2,nodatacow,commit=120,discard=async"

mount -o $BTRFS_OPTS,subvol=@root /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT
mount -o $BTRFS_OPTS,subvol=@home /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/home
mount -o $BTRFS_OPTS_HOME,subvol=@nix /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/nix
mount -o $BTRFS_OPTS_HOME,subvol=@opt /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/opt
mount -o $BTRFS_OPTS,subvol=@gdm /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/var/lib/gdm
mount -o $BTRFS_OPTS_HOME,subvol=@libvirt /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/var/lib/libvirt
mount -o $BTRFS_OPTS,subvol=@log /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/var/log
mount -o $BTRFS_OPTS,subvol=@spool /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/var/spool
mount -o $BTRFS_OPTS,subvol=@tmp /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/var/tmp
mount -o $BTRFS_OPTS,subvol=@cache /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/var/cache
mount -o $BTRFS_OPTS_HOME,subvol=@snapshots /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/.snapshots
mount /dev/disk/by-label/$SYSTEM_LABEL $MOUNTPOINT/boot
mount -t vfat -o defaults,noatime,nodiratime /dev/disk/by-label/$EFI_LABEL $MOUNTPOINT/boot/efi

# Bind essential virtual filesystems
for dir in dev proc sys run; do
    mount --rbind /$dir /mnt/$dir
    mount --make-rslave /mnt/$dir
done

# Ensure devpts is mounted for pseudo-terminal support
mount -t devpts devpts /mnt/dev/pts

grub-install --target=x86_64-efi --bootloader-id="Debian" --efi-directory=/boot/efi --removable --recheck
