#!/usr/bin/env bash
set -euo pipefail

########################################
# CONFIG
########################################

DRIVE="/dev/sda"
MNT="/mnt"

EFI_PART="${DRIVE}1"
BOOT_PART="${DRIVE}2"
ROOT_PART="${DRIVE}3"
SWAP_PART="${DRIVE}4"

ROOT_OPTS="noatime,ssd,space_cache=v2,compress=zstd:3"
HOME_OPTS="noatime,ssd,space_cache=v2,compress=zstd:3"
NIX_OPTS="noatime,ssd,space_cache=v2,compress=zstd:15"

########################################
# CLEAN OLD MOUNTS (if any)
########################################

echo "Unmounting old mounts..."
umount -R "$MNT" 2>/dev/null || true
swapoff "$SWAP_PART" 2>/dev/null || true

########################################
# MOUNT ROOT SUBVOLUME
########################################

echo "Mounting BTRFS root..."
mount -o ${ROOT_OPTS},subvol=@ "$ROOT_PART" "$MNT"

########################################
# CREATE MOUNTPOINTS
########################################

mkdir -pv "$MNT"/{boot,boot/efi,home,nix,var/log,var/cache,.snapshots}

########################################
# MOUNT OTHER PARTITIONS
########################################

mount "$BOOT_PART" "$MNT/boot"
mount "$EFI_PART" "$MNT/boot/efi"

mount -o ${HOME_OPTS},subvol=@home "$ROOT_PART" "$MNT/home"
# mount -o ${NIX_OPTS},subvol=@nix "$ROOT_PART" "$MNT/nix"
mount -o noatime,ssd,compress=none,subvol=@var_log "$ROOT_PART" "$MNT/var/log"
mount -o noatime,ssd,compress=none,subvol=@var_cache "$ROOT_PART" "$MNT/var/cache"
mount -o ${ROOT_OPTS},subvol=@snapshots "$ROOT_PART" "$MNT/.snapshots"

########################################
# ENABLE SWAP
########################################

swapon "$SWAP_PART"

########################################
# BIND SYSTEM DIRECTORIES
########################################

mount --bind /dev  "$MNT/dev"
mount --bind /proc "$MNT/proc"
mount --bind /sys  "$MNT/sys"
mount --bind /run  "$MNT/run"

########################################
# EFI VARIABLES (CRITICAL FOR GRUB)
########################################

mount -t efivarfs efivarfs "$MNT/sys/firmware/efi/efivars" || true

########################################
# READY FOR CHROOT
########################################

echo "System mounted successfully."
echo "Enter with:"
echo "chroot $MNT /bin/bash"