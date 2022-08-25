#!/bin/sh

df -h
umount /target/boot/efi
umount /target/home/
umount /target/
mount /dev/sda6 /mnt

cd /mnt
ls

btrfs su cr /mnt/@snapshots
btrfs su cr /mnt/@var_log
btrfs su cr /mnt/@tmp
btrfs su cr /mnt/@cache
btrfs su cr /mnt/@swap
ls
btrfs subvol list .
cd ..

umount /mnt
mount /dev/sda7 /

cd /mnt
ls
btrfs su cr /mnt/@home
cd ..

umount /mnt
mount /dev/sda6 /mnt

cd /mnt
set -e
BTRFS_OPTS="noatime,ssd,compress-force=zstd:16,space_cache=v2,commit=120,autodefrag,discard=async"

mount -o $BTRFS_OPTS,subvol=@rootfs /dev/sda6 /target

mkdir -pv /target/home
mkdir -pv /target/.snapshots
mkdir -pv /target/boot/efi
mkdir -pv /target/var/log
mkdir -pv /target/var/tmp
mkdir -pv /target/var/swap
mkdir -pv /target/var/cache
mount -o $BTRFS_OPTS,subvol=@home /dev/sda7 /target/home
mount -o $BTRFS_OPTS,subvol=@snapshots /dev/sda6 /target/.snapshots
mount -o $BTRFS_OPTS,subvol=@var_log /dev/sda6 /target/var/log
mount -o $BTRFS_OPTS,subvol=@tmp /dev/sda6 /target/var/tmp
# mount -o $BTRFS_OPTS,subvol=@swap /dev/sda7 /target/var/swap
mount -o $BTRFS_OPTS,subvol=@cache /dev/sda6 /target/var/cache
mount -t vfat -o defaults,noatime,nodiratime /dev/sda5 /target/boot/efi


# SWAP

# touch /target/var/swap/swapfile
# truncate -s 0 /target/var/swap/swapfile
# chattr +C /target/var/swap/swapfile
# btrfs property set /target/var/swap/swapfile compression none
# chmod 600 /target/var/swap/swapfile
# dd if=/dev/zero of=/target/var/swap/swapfile bs=1M count=3072 status=progress
# mkswap /target/var/swap/swapfile
# swapon /target/var/swap/swapfile

# fstab

UEFI_UUID=$(blkid -s UUID -o value /dev/sda5)
ROOT_UUID=$(blkid -s UUID -o value /dev/sda6)
HOME_UUID=$(blkid -s UUID -o value /dev/sda7)
echo $UEFI_UUID
echo $ROOT_UUID
echo $HOME_UUID


# Add to fstab
# set -e
# SWAP_UUID=$(blkid -s UUID -o value /dev/sda6)
# echo $SWAP_UUID
# echo " " >> etc/fstab
# echo "# Swap" >> /etc/fstab
# echo "UUID=$SWAP_UUID /var/swap btrfs defaults,noatime,subvol=@swap 0 0" >> /etc/fstab
# echo "/var/swap/swapfile none swap sw 0 0" >> /etc/fstab

cat <<EOF > /target/etc/fstab
#
# See fstab(5).
#
# <file system> <dir> <type> <options> <dump> <pass>

# ROOTFS
UUID=$ROOT_UUID /               btrfs rw,noatime,ssd,compress-force=zstd:18,space_cache=v2,commit=120,discard=async,subvol=@rootfs         0 1
UUID=$ROOT_UUID /.snapshots     btrfs rw,noatime,ssd,compress-force=zstd:18,space_cache=v2,commit=120,discard=async,subvol=@snapshots      0 2
UUID=$ROOT_UUID /var/log        btrfs rw,noatime,ssd,compress-force=zstd:18,space_cache=v2,commit=120,discard=async,subvol=@var_log        0 2
UUID=$ROOT_UUID /var/tmp        btrfs rw,noatime,ssd,compress-force=zstd:18,space_cache=v2,commit=120,discard=async,subvol=@tmp            0 2
UUID=$ROOT_UUID /var/cache      btrfs rw,noatime,ssd,compress-force=zstd:18,space_cache=v2,commit=120,discard=async,subvol=@cache          0 2

#HOME_FS
UUID=$HOME_UUID /home           btrfs rw,noatime,ssd,compress-force=zstd:18,space_cache=v2,commit=120,discard=async,subvol=@home           0 2

# EFI
UUID=$UEFI_UUID /boot/efi vfat rw,noatime,nodiratime,fmask=0022,dmask=0022,codepage=437,iocharset=iso8859-1,shortname=mixed,utf8,errors=remount-ro 0 2

tmpfs /tmp tmpfs defaults,noatime,nosuid,nodev,mode=1777 0 0
EOF


# Add to fstab
# set -e
# SWAP_UUID=$(blkid -s UUID -o value /dev/sda6)
# echo $SWAP_UUID
# echo " " >> etc/fstab
# echo "# Swap" >> /etc/fstab
# echo "UUID=$SWAP_UUID /var/swap btrfs defaults,noatime,subvol=@swap 0 0" >> /etc/fstab
# echo "/var/swap/swapfile none swap sw 0 0" >> /etc/fstab

# Systemd-Boot
# bootctl --path=/boot install
# bootctl --path=/boot/efi install
# echo "default arch.conf" >> /boot/loader/loader.conf


