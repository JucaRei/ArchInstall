#!/bin/bash

# Enable pacman Color
sed -i '1n; /^#UseSyslog/i ILoveCandy' /etc/pacman.conf
sed -i '/Color/s/^#//' /etc/pacman.conf
sed -i '3n; /^#UseSyslog/i DisableDownloadTimeout' /etc/pacman.conf
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

pacman -Syyy

pacman -Sy artix-keyring --noconfirm
pacman-key --populate artix
pacman -Sy artix-archlinux-support --noconfirm
pacman -Sy archlinux-keyring --noconfirm
pacman-key --populate archlinux

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

parted -s -a optimal /dev/vda mklabel gpt
parted -s -a optimal /dev/vda mkpart primary fat32 1 600MiB
parted -s -a optimal /dev/vda mkpart primary 600MiB 7GiB
parted -s -a optimal -- /dev/vda mkpart primary btrfs 7GiB -2048s


# Artix
mkfs.vfat -F32 /dev/vda1 -n "ArtixBoot"
mkfs.btrfs /dev/vda2 -f -L "ArtixRoot"
mkfs.btrfs /dev/vda3 -f -L "ArtixHome"

# OldMac
# mkfs.vfat -F32 /dev/sda1
# mkfs.btrfs /dev/sda2 -f -L "ArtixRoot"
# mkfs.btrfs /dev/sda3 -f -L "ArtixHome"

set -e
BTRFS_OPTS="noatime,ssd,compress-force=zstd:16,space_cache=v2,commit=120,autodefrag,discard=async"

# Nitro
mount -o $BTRFS_OPTS /dev/vda2 /mnt

# OldMac
# mount -o $BTRFS_OPTS /dev/sda2 /mnt


#Create Subvolumes

btrfs su cr /mnt/@
btrfs su cr /mnt/@root
btrfs su cr /mnt/@srv
# btrfs su cr /mnt/@var
btrfs su cr /mnt/@pacman
btrfs su cr /mnt/@snapshots
btrfs su cr /mnt/@containers
btrfs su cr /mnt/@libvirt
btrfs su cr /mnt/@lxd
btrfs su cr /mnt/@overlay
btrfs su cr /mnt/@var_log
btrfs su cr /mnt/@usr_local
btrfs su cr /mnt/@var_opt
btrfs su cr /mnt/@tmp
btrfs su cr /mnt/@cache
# btrfs su cr /mnt/@swap

# Remove partition
umount -v /mnt

# Nitro mount home
mount -o $BTRFS_OPTS /dev/vda3 /mnt
btrfs su cr /mnt/@home
umount -v /mnt

# OldMac mount home
# mount -o $BTRFS_OPTS /dev/sda3 /mnt
# btrfs su cr /mnt/@home
# umount -v /mnt

# Mount partitions (Nitro)
mount -o $BTRFS_OPTS,subvol=@ /dev/vda2 /mnt
# mkdir -pv /mnt/{home,.snapshots,boot/efi,var/log,var/tmp,var/cache,var/swap}
mkdir -pv /mnt/{home,.snapshots,root,srv,usr/local,boot/efi,var/log,var/opt,var/tmp,var/cache}
mkdir -pv /mnt/var/lib/containers
mkdir -pv /mnt/var/lib/containers/storage/overlay
mkdir -pv /mnt/var/lib/pacman
mkdir -pv /mnt/var/lib/libvirt
mkdir -pv /mnt/var/lib/lxd

mount -o $BTRFS_OPTS,subvol=@root /dev/vda2 /mnt/root
mount -o $BTRFS_OPTS,subvol=@home /dev/vda3 /mnt/home
mount -o $BTRFS_OPTS,subvol=@srv /dev/vda2 /mnt/srv
# mount -o $BTRFS_OPTS,subvol=@var /dev/vda2 /mnt/var
mount -o $BTRFS_OPTS,subvol=@pacman /dev/vda2 /mnt/var/lib/pacman
mount -o $BTRFS_OPTS,subvol=@libvirt /dev/vda2 /mnt/var/lib/libvirt
mount -o $BTRFS_OPTS,subvol=@lxd /dev/vda2 /mnt/var/lib/lxd
mount -o $BTRFS_OPTS,subvol=@snapshots /dev/vda2 /mnt/.snapshots
mount -o $BTRFS_OPTS,subvol=@usr_local /dev/vda2 /mnt/usr/local
mount -o $BTRFS_OPTS,subvol=@var_log /dev/vda2 /mnt/var/log
mount -o $BTRFS_OPTS,subvol=@var_opt /dev/vda2 /mnt/var/opt
# mount -o $BTRFS_OPTS,subvol=@swap /dev/vda2 /mnt/var/swap
mount -o $BTRFS_OPTS,subvol=@cache /dev/vda2 /mnt/var/cache
mount -o $BTRFS_OPTS,subvol=@tmp /dev/vda2 /mnt/var/tmp
mount -o $BTRFS_OPTS,subvol=@containers /dev/vda2 /mnt/var/lib/containers
mkdir -pv /mnt/var/lib/containers/storage/overlay
mount -o $BTRFS_OPTS,subvol=@overlay /dev/vda2 /mnt/var/lib/containers/storage/overlay
mount -t vfat -o defaults,noatime,nodiratime /dev/vda1 /mnt/boot/efi

# Mount partitions (Oldmac) | W/Systemd-Boot
# mount -o $BTRFS_OPTS,subvol=@ /dev/sda2 /mnt
# mkdir -pv /mnt/{home,.snapshots,boot,var/log}
# mount -o $BTRFS_OPTS,subvol=@home /dev/sda3 /mnt/home
# mount -o $BTRFS_OPTS,subvol=@snapshots /dev/sda2 /mnt/.snapshots
# mount -o $BTRFS_OPTS,subvol=@var_log /dev/sda2 /mnt/var/log
# mount -t vfat -o defaults,noatime,nodiratime /dev/sda1 /mnt/boot

############    Artix    ############

### Artix Runit
basestrap /mnt base base-devel artools-base linux-lts linux-lts-headers man-pages man-db perl artix-keyring archlinux-keyring artix-archlinux-support sysfsutils ansible duf fzf ripgrep-all python python-pip runit elogind-runit linux-firmware git intel-ucode nano neovim mtools dosfstools dropbear dropbear-runit pacman-contrib fzf ripgrep btrfs-progs --ignore linux

# Generate fstab
fstabgen -U /mnt >>/mnt/etc/fstab

### Artix s6
# basestrap /mnt base base-devel artools-base s6-base linux-lts linux-lts-headers elogind-s6 man-pages man-db perl artix-keyring archlinux-keyring artix-archlinux-support sysfsutils ansible duf fzf ripgrep-all python python-pip linux-firmware git intel-ucode nano neovim mtools dosfstools dropbear dropbear-s6 pacman-contrib fzf ripgrep btrfs-progs --ignore linux

# Generate fstab
# fstabgen -U /mnt >> /mnt/etc/fstab

### Artix Dinit
# basestrap /mnt base dinit-base base-devel artools-base linux-lts linux-lts-headers man-pages man-db perl sysfsutils ansible duf fzf artix-keyring archlinux-keyring artix-archlinux-support ripgrep-all python python-pip dinit elogind-dinit linux-firmware git intel-ucode nano neovim mtools dosfstools dropbear dropbear-dinit pacman-contrib fzf ripgrep btrfs-progs --ignore linux

# Generate fstab
# fstabgen -U /mnt >>/mnt/etc/fstab