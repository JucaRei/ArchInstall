#!/bin/bash


# Nitro
# mkfs.vfat -F32 /dev/sda5
# mkfs.btrfs /dev/sda6 -f
# mkfs.btrfs /dev/sda7 -f

# OldMac
mkfs.vfat -F32 /dev/sda1 
mkfs.btrfs /dev/sda2 -f
mkfs.btrfs /dev/sda3 -f

set -e
BTRFS_OPTS="noatime,ssd,compress-force=zstd:18,space_cache=v2,commit=120,autodefrag,discard=async"

# Nitro
#mount -o $BTRFS_OPTS /dev/sda6 /mnt

# OldMac
mount -o $BTRFS_OPTS /dev/sda2 /mnt

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
mount -o $BTRFS_OPTS /dev/sda3 /mnt
btrfs su cr /mnt/@home
umount -v /mnt

# Mount partitions (Nitro)
# mount -o $BTRFS_OPTS,subvol=@ /dev/sda6 /mnt
# mkdir -pv /mnt/{home,.snapshots,boot/efi,var/log}
# mount -o $BTRFS_OPTS,subvol=@home /dev/sda7 /mnt/home
# mount -o $BTRFS_OPTS,subvol=@snapshots /dev/sda6 /mnt/.snapshots
# mount -o $BTRFS_OPTS,subvol=@var_log /dev/sda6 /mnt/var/log
# mount -t vfat -o defaults,noatime,nodiratime /dev/sda5 /mnt/boot/efi

# Mount partitions (Oldmac) | W/Systemd-Boot 
mount -o $BTRFS_OPTS,subvol=@ /dev/sda2 /mnt
mkdir -pv /mnt/{home,.snapshots,boot,var/log}
mount -o $BTRFS_OPTS,subvol=@home /dev/sda3 /mnt/home
mount -o $BTRFS_OPTS,subvol=@snapshots /dev/sda2 /mnt/.snapshots
mount -o $BTRFS_OPTS,subvol=@var_log /dev/sda2 /mnt/var/log
mount -t vfat -o defaults,noatime,nodiratime /dev/sda1 /mnt/boot




############    ARCH     ############

### Nitro
# pacstrap /mnt base linux-lts linux-lts-headers linux-firmware git nano neovim intel-ucode duf reflector mtools dosfstools btrfs-progs pacman-contrib

# Generate fstab
# genfstab -U /mnt >> /mnt/etc/fstab

### Old Mac
pacstrap /mnt base base-devel linux-lts linux-lts-headers linux-firmware btrfs-progs git neovim nano reflector duf exa fzf ripgrep pacman-contrib duf --ignore linux

# Generate fstab
genfstab -U /mnt >> /mnt/etc/fstab

############    Artix    ############

### Artix
# basestrap /mnt base base-devel linux-lts linux-lts-headers runit elogind elogind-runit linux-firmware git neovim mtools dosfstools btrfs-progs --ignore linux

# Generate fstab
# fstabgen -U /mnt >> /mnt/etc/fstab

# Artix
# for dir in dev proc sys run; do mount --rbind /$dir /mnt/$dir; mount --make-rslave /mnt/$dir; done
# mount --bind /sys/firmware/efi/efivars /mnt/sys/firmware/efi/efivars