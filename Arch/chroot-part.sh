#!/bin/bash


# Nitro
# mkfs.vfat -F32 /dev/sda5
# mkfs.btrfs /dev/sda6 -f
# mkfs.btrfs /dev/sda7 -f

# OldMac
mkfs.btrfs /dev/sda3 -f
mkfs.btrfs /dev/sda4 -f

set -e
BTRFS_OPTS="noatime,ssd,compress-force=zstd:18,space_cache=v2,commit=120,discard=async"

# Nitro
#mount -o $BTRFS_OPTS /dev/sda6 /mnt

# OldMac
mount -o $BTRFS_OPTS /dev/sda3 /mnt

#Create Subvolumes

btrfs su cr /mnt/@
btrfs su cr /mnt/@snapshots
btrfs su cr /mnt/@var_log

# Remove partition
umount -v /mnt

# Nitro mount home
# mount -o $BTRFS_OPTS /dev/sda7 /mnt
# btrfs su cr /mnt/@home
# umount -v /mnt

# OldMac mount home
mount -o $BTRFS_OPTS /dev/sda4 /mnt
btrfs su cr /mnt/@home
umount -v /mnt

# Mount partitions (Nitro)
# mount -o $BTRFS_OPTS,subvol=@ /dev/sda6 /mnt
# mkdir -pv /mnt/{home,.snapshots,boot/efi,var/log}
# mount -o $BTRFS_OPTS /dev/sda7 /mnt/home
# mount -o $BTRFS_OPTS,subvol=@snapshots /dev/sda6 /mnt/.snapshots
# mount -o $BTRFS_OPTS,subvol=@var_log /dev/sda6 /mnt/var/log
# mount -t vfat -o defaults,noatime,nodiratime /dev/sda5 /mnt/boot/efi

# Mount partitions (Oldmac) | W/Systemd-Boot 
mount -o $BTRFS_OPTS,subvol=@ /dev/sda3 /mnt
mkdir -pv /mnt/{home,.snapshots,boot,var/log}
mount -o $BTRFS_OPTS /dev/sda4 /mnt/home
mount -o $BTRFS_OPTS,subvol=@snapshots /dev/sda3 /mnt/.snapshots
mount -o $BTRFS_OPTS,subvol=@var_log /dev/sda3 /mnt/var/log
mount -t vfat -o defaults,noatime,nodiratime /dev/sda1 /mnt/boot

############    ARCH     ############

### Nitro
# pacstrap /mnt base linux-lts linux-lts-headers linux-firmware git nano vim intel-ucode reflector mtools dosfstools btrfs-progs pacman-contrib

# Generate fstab
# genfstab -U /mnt >> /mnt/etc/fstab

### Old Mac
pacstrap /mnt base linux linux-headers linux-firmware intel-ucode git vim nano

# Generate fstab
genfstab -U /mnt >> /mnt/etc/fstab

############    Artix    ############

### Nitro
# basestrap /mnt base base-devel linux-lts linux-lts-headers runit elogind-runit linux-firmware git vim intel-ucode mtools dosfstools btrfs-progs

# Generate fstab
# fstabgen -U /mnt >> /mnt/etc/fstab