#!/bin/bash

# Arch Linux

# pacman -Sy archlinux-keyring --noconfirm

# Enable pacman Color
sed -i '1n; /^#UseSyslog/i ILoveCandy' /etc/pacman.conf
sed -i '/Color/s/^#//' /etc/pacman.conf
sed -i 's/#ParallelDownloads = 5/ParallelDownloads = 5/g' /etc/pacman.conf

# ARTIX LINUX
# ADD Repos
cat <<\EOF >>/etc/pacman.conf

[universe]
Server = https://universe.artixlinux.org/$arch
Server = https://mirror1.artixlinux.org/universe/$arch
Server = https://mirror.pascalpuffke.de/artix-universe/$arch
Server = https://artixlinux.qontinuum.space/artixlinux/universe/os/$arch
Server = https://mirror1.cl.netactuate.com/artix/universe/$arch
Server = https://ftp.crifo.org/artix-universe/
EOF


pacman -Sy artix-keyring artix-archlinux-support --noconfirm

pacman -Syyy

cat <<\EOF >>/etc/pacman.conf

### Archlinux Repo's
[extra]
Include = /etc/pacman.d/mirrorlist-arch

[community]
Include = /etc/pacman.d/mirrorlist-arch

[multilib]
Include = /etc/pacman.d/mirrorlist-arch
EOF

pacman -Syyy

# Artix
mkfs.vfat -F32 /dev/sda5 -n "ArtixBoot"
mkfs.btrfs /dev/sda6 -f -L "ArtixRoot"
mkfs.btrfs /dev/sda7 -f -L "ArtixHome"

#Arch
# mkfs.vfat -F32 /dev/sda5 -n "ArchBoot"
# mkfs.btrfs /dev/sda6 -f -L "ArchRoot"
# mkfs.btrfs /dev/sda7 -f -L "ArchHome"

# OldMac
# mkfs.vfat -F32 /dev/sda1
# mkfs.btrfs /dev/sda2 -f
# mkfs.btrfs /dev/sda3 -f

set -e
BTRFS_OPTS="noatime,ssd,compress-force=zstd:14,space_cache=v2,commit=120,autodefrag,discard=async"

# Nitro
mount -o $BTRFS_OPTS /dev/sda6 /mnt

# OldMac
# mount -o $BTRFS_OPTS /dev/sda2 /mnt

#Create Subvolumes

btrfs su cr /mnt/@
btrfs su cr /mnt/@snapshots
btrfs su cr /mnt/@var_log
btrfs su cr /mnt/@tmp
btrfs su cr /mnt/@cache
# btrfs su cr /mnt/@swap

# Remove partition
umount -v /mnt

# Nitro mount home
mount -o $BTRFS_OPTS /dev/sda7 /mnt
btrfs su cr /mnt/@home
umount -v /mnt

# OldMac mount home
# mount -o $BTRFS_OPTS /dev/sda3 /mnt
# btrfs su cr /mnt/@home
# umount -v /mnt

# Mount partitions (Nitro)
mount -o $BTRFS_OPTS,subvol=@ /dev/sda6 /mnt
# mkdir -pv /mnt/{home,.snapshots,boot/efi,var/log,var/tmp,var/cache,var/swap}
mkdir -pv /mnt/{home,.snapshots,boot/efi,var/log,var/tmp,var/cache}
mount -o $BTRFS_OPTS,subvol=@home /dev/sda7 /mnt/home
mount -o $BTRFS_OPTS,subvol=@snapshots /dev/sda6 /mnt/.snapshots
mount -o $BTRFS_OPTS,subvol=@var_log /dev/sda6 /mnt/var/log
# mount -o $BTRFS_OPTS,subvol=@swap /dev/sda6 /mnt/var/swap
mount -o $BTRFS_OPTS,subvol=@cache /dev/sda6 /mnt/var/cache
mount -o $BTRFS_OPTS,subvol=@tmp /dev/sda6 /mnt/var/tmp
mount -t vfat -o defaults,noatime,nodiratime /dev/sda5 /mnt/boot/efi

# Mount partitions (Oldmac) | W/Systemd-Boot
# mount -o $BTRFS_OPTS,subvol=@ /dev/sda2 /mnt
# mkdir -pv /mnt/{home,.snapshots,boot,var/log}
# mount -o $BTRFS_OPTS,subvol=@home /dev/sda3 /mnt/home
# mount -o $BTRFS_OPTS,subvol=@snapshots /dev/sda2 /mnt/.snapshots
# mount -o $BTRFS_OPTS,subvol=@var_log /dev/sda2 /mnt/var/log
# mount -t vfat -o defaults,noatime,nodiratime /dev/sda1 /mnt/boot

############    ARCH     ############

### Nitro
# pacstrap /mnt base base-devel linux-lts linux-lts-headers linux-firmware archlinux-keyring man-db perl sysfsutils python python-pip git man-pages dropbear git nano neovim intel-ucode fzf duf reflector mtools ansible dosfstools btrfs-progs pacman-contrib mkinitcpio-nfs-utils nfs-utils --ignore linux openssh

# Generate fstab
# genfstab -U /mnt >>/mnt/etc/fstab

### Old Mac
# pacstrap /mnt base base-devel linux-lts linux-lts-headers linux-firmware btrfs-progs git neovim nano reflector duf exa fzf ripgrep pacman-contrib --ignore linux

# Generate fstab
# genfstab -U /mnt >> /mnt/etc/fstab

############    Artix    ############

### Artix Runit
basestrap /mnt base base-devel artools-base linux-lts linux-lts-headers man-pages man-db perl sysfsutils ansible duf fzf ripgrep-all python python-pip runit elogind-runit linux-firmware git intel-ucode nano neovim mtools dosfstools dropbear dropbear-runit pacman-contrib fzf ripgrep btrfs-progs --ignore linux

# Generate fstab
fstabgen -U /mnt >>/mnt/etc/fstab

### Artix s6
#basestrap /mnt base base-devel artools-base s6-base linux-lts linux-lts-headers elogind-s6 linux-firmware git intel-ucode nano neovim mtools dosfstools dropbear dropbear-s6 pacman-contrib fzf ripgrep btrfs-progs --ignore linux

# Generate fstab
#fstabgen -U /mnt >> /mnt/etc/fstab
