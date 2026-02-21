#!/bin/bash

apt install -y arch-install-scripts 

# AJUSTE CONFORME SEU DISCO
SYSTEM_PART="/dev/sda2"   # /boot ext4
EFI_PART="/dev/sda3"      # EFI vfat
ROOT_PART="/dev/sda4"     # root ext4

ROOT_LABEL="Linux"
SYSTEM_LABEL="BOOT"
EFI_LABEL="ESP"

BTRFS_OPTS="noatime,ssd,compress-force=zstd:3,space_cache=v2,commit=120,discard=async,autodefrag"
NIX_OPTS="noatime,ssd,compress-force=zstd:3,space_cache=v2,commit=20,discard=async,autodefrag"
BTRFS_OPTS2="noatime,ssd,compress-force=zstd:3,space_cache=v2,commit=120,discard=async,autodefrag"  # uniformizei


MNT="/mnt"

echo "[+] Criando diretórios..."

mount -o $BTRFS_OPTS2,subvol=@root /dev/disk/by-label/$ROOT_LABEL $MNT
mount -o $BTRFS_OPTS,subvol=@home /dev/disk/by-label/$ROOT_LABEL $MNT/home
mount -o $BTRFS_OPTS,subvol=@opt /dev/disk/by-label/$ROOT_LABEL $MNT/opt
mount -o $BTRFS_OPTS,subvol=@gdm /dev/disk/by-label/$ROOT_LABEL $MNT/var/lib/gdm
mount -o $BTRFS_OPTS,subvol=@libvirt /dev/disk/by-label/$ROOT_LABEL $MNT/var/lib/libvirt
mount -o $BTRFS_OPTS2,subvol=@log /dev/disk/by-label/$ROOT_LABEL $MNT/var/log
mount -o $NIX_OPTS,subvol=@nix /dev/disk/by-label/$ROOT_LABEL $MNT/nix
mount -o $BTRFS_OPTS,subvol=@spool" "/dev/disk/by-label/$ROOT_LABEL" $MNT/var/spool
mount -o $BTRFS_OPTS2,subvol=@tmp" "/dev/disk/by-label/$ROOT_LABEL" $MNT/var/tmp
mount -o $BTRFS_OPTS,subvol=@apt" "/dev/disk/by-label/$ROOT_LABEL" $MNT/var/cache/apt
mount -o $BTRFS_OPTS,subvol=@snapshots" "/dev/disk/by-label/$ROOT_LABEL" $MNT/.snapshots
mount -o $BTRFS_OPTS2,subvol=@swap /dev/disk/by-label/$ROOT_LABEL $MNT/swap
mount /dev/disk/by-label/$SYSTEM_LABEL $MNT/boot
mount -t vfat -o defaults,noatime,nodiratime /dev/disk/by-label/$EFI_LABEL $MNT/boot/efi



# udevadm trigger
# mkdir -p $MOUNTPOINT/{proc,sys,dev/pts}
# mount -t proc     proc      $MOUNTPOINT/proc
# mount -t sysfs    sysfs     $MOUNTPOINT/sys
# mount --rbind     /dev      $MOUNTPOINT/dev
# mount -t devpts   devpts    $MOUNTPOINT/dev/pts
# mount -t efivarfs efivarfs  $MOUNTPOINT/sys/firmware/efi/efivars

# echo "[+] Copiando resolv.conf..."
# cp /etc/resolv.conf $MNT/etc/resolv.conf

