#!/usr/bin/env bash

# Variables
hostname="nitro"
name="Reinaldo P JR"
username="juca"
Architecture="amd64"
CODENAME=bookworm #$(lsb_release --codename --short) # or CODENAME=bookworm
# DRIVE="/dev/sda"
DRIVE="/dev/vda"
EFI_PART="${DRIVE}2"
ROOT_PART="${DRIVE}4"

MOUNTPOINT="/mnt"
ROOT_LABEL="Debian"
SWAP_LABEL="SWAP" 
EFI_LABEL="ESP"
BTRFS_OPTS="noatime,ssd,compress-force=zstd:8,space_cache=v2,nodatacow,commit=120,discard=async"
BTRFS_OPTS_HOME="noatime,ssd,compress-force=zstd:15,space_cache=v2,nodatacow,commit=120,discard=async"

mount -o $BTRFS_OPTS,subvol=@root /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT
swapon /dev/disk/by-label/$SWAP_LABEL
# mount -o $BTRFS_OPTS_HOME,subvol=@home /dev/disk/by-label/$HOME_LABEL $MOUNTPOINT/home
mount -o $BTRFS_OPTS,subvol=@home /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/home
mount -o $BTRFS_OPTS_HOME,subvol=@nix /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/nix
mount -o $BTRFS_OPTS_HOME,subvol=@opt /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/opt
mount -o $BTRFS_OPTS,subvol=@gdm /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/var/lib/gdm
mount -o $BTRFS_OPTS,subvol=@log /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/var/log
mount -o $BTRFS_OPTS,subvol=@spool /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/var/spool
mount -o $BTRFS_OPTS,subvol=@tmp /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/var/tmp
mount -o $BTRFS_OPTS,subvol=@cache /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/var/cache
mount -o $BTRFS_OPTS_HOME,subvol=@snapshots /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/.snapshots
mount -t vfat -o defaults,noatime,nodiratime /dev/disk/by-label/$EFI_LABEL $MOUNTPOINT/boot/efi

# Bind essential virtual filesystems
for dir in dev proc sys run; do
    mount --rbind /$dir /mnt/$dir
    mount --make-rslave /mnt/$dir
done

# Ensure devpts is mounted for pseudo-terminal support
mount -t devpts devpts /mnt/dev/pts

chroot /mnt grub-install --target=x86_64-efi --bootloader-id="${ROOT_LABEL}" --efi-directory=/boot/efi --removable --recheck
grub-install --target=x86_64-efi --bootloader-id=GRUB --efi-directory=/boot/efi --removable --recheck