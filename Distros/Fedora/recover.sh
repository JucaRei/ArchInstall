#!/bin/sh

DRIVE="/dev/sda"
BTRFS_OPTS="noatime,ssd,compress-force=zstd:15,space_cache=v2,nodatacow,commit=120,discard=async"

### Mount subvolumes
mount -o $BTRFS_OPTS,subvol=@ /dev/disk/by-label/Fedora /mnt
mount -o $BTRFS_OPTS,subvol=@home /dev/disk/by-label/Fedora /mnt/home
mount -o $BTRFS_OPTS,subvol=@images /dev/disk/by-label/Fedora /mnt/var/lib/libvirt/images
mount -o $BTRFS_OPTS,subvol=@log /dev/disk/by-label/Fedora /mnt/var/log
mount -o $BTRFS_OPTS,subvol=@cache /dev/disk/by-label/Fedora /mnt/var/cache
mount -o $BTRFS_OPTS,subvol=@snapshots /dev/disk/by-label/Fedora /mnt/.snapshots
mount /dev/disk/by-label/BOOT /mnt/boot
mount -t vfat -o defaults,noatime,nodiratime /dev/disk/by-label/SYS /mnt/boot/efi

udevadm trigger
mount -t proc proc /mnt/proc
mount -t sysfs sys /mnt/sys
mount -B /dev /mnt/dev
# mount -t /devpts /mnt/dev/pts
