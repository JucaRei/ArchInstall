#!/bin/sh

#### Update and install needed packages ####
apt update && apt install arch-install-scripts debootstrap btrfs-progs lsb-release wget -y

#### Umount drive, if it's mounted ####
umount -Rv /dev/nvme0n1


###############################
#### Enviroments variables ####
###############################
PARTITION="/dev/nvme0n1p3"
INSTALL_PARTITION="/dev/disk/by-label/Debian"
BOOT_PARTITION="/dev/disk/by-label/BOOTLOADER"
SWAP_PARTITION="/dev/disk/by-label/SWAP"
BTRFS_OPTS="noatime,ssd,compress-force=zstd:5,space_cache=v2,nodatacow,commit=120,discard=async"
BTRFS_OPTS_COMPRESSED="noatime,ssd,compress-force=zstd:15,space_cache=v2,nodatacow,commit=120,discard=async"
Debian_ARCH="amd64"


## Make directories for mount ##
mount -o $BTRFS_OPTS,subvol=@rootsystem $INSTALL_PARTITION /mnt

## Mount btrfs subvolumes ##
mount -o $BTRFS_OPTS_COMPRESSED,subvol=@home $INSTALL_PARTITION /mnt/home
mount -o $BTRFS_OPTS_COMPRESSED,subvol=@apt $INSTALL_PARTITION /mnt/var/cache/apt
mount -o $BTRFS_OPTS,subvol=@logs $INSTALL_PARTITION /mnt/var/log
mount -o $BTRFS_OPTS_COMPRESSED,subvol=@tmp $INSTALL_PARTITION /mnt/var/tmp
# mount -o $BTRFS_OPTS,subvol=@swap $INSTALL_PARTITION /mnt/var/swap
mount -o $BTRFS_OPTS_COMPRESSED,subvol=@snapshots $INSTALL_PARTITION /mnt/var/snapshots
mount -t vfat -o noatime,nodiratime $BOOT_PARTITION /mnt/boot


#for dir in dev proc sys run; do
#    mount --rbind /$dir /mnt/$dir
#    mount --make-rslave /mnt/$dir
#done

