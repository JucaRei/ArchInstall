#!/bin/bash

# Arch Linux

pacman -Sy archlinux-keyring --noconfirm

# Enable pacman Color
sed -i '1n; /^#UseSyslog/i ILoveCandy' /etc/pacman.conf
sed -i '/Color/s/^#//' /etc/pacman.conf
sed -i '3n; /^#UseSyslog/i DisableDownloadTimeout' /etc/pacman.conf
sed -i 's/#ParallelDownloads = 5/ParallelDownloads = 4/g' /etc/pacman.conf

cat <<\ EOF >> /etc/pacman.conf

[liquorix]
Server = https://liquorix.net/archlinux/$repo/$arch

EOF

pacman -Syyy


#####################
###### OldMac #######
#####################

# if [ -d /sys/firmware/efi ]; then UEFI=true; else UEFI=false; fi
if [ -d /sys/firmware/efi ]; then UEFI=false; else UEFI=false; fi

pacman -Sy
pacman -S --noconfirm --needed --noprogressbar --quiet reflector
reflector -l 3 --sort rate --save /etc/pacman.d/mirrorlist

pacman -S --noconfirm --needed --noprogressbar --quiet awk

DRIVE="/dev/sda"

if [ $UEFI == false ]
then
  parted -s -a optimal ${DRIVE} -- mklabel msdos \
       mkpart primary ext4 1MiB 100MiB \
       set 1 boot on \
       mkpart primary linux-swap 100MiB 6GiB\
    #    mkpart primary ext4 8GiB 55% \
    #    mkpart primary ext4 55% 100% 
       mkpart primary btrfs 6GiB 100% \ 
       align-check ${DRIVE}
else
  parted -s ${DRIVE} -- mklabel gpt \
      mkpart primary ext4 0% 1GiB \
      set 1 boot on \
      mkpart primary linux-swap 1GiB 16GiB \
      mkpart primary ext4 16GiB 55% \
      mkpart primary ext4 55% 100%  
fi

mkfs.vfat -F32 ${DRIVE}1 -n "BOOT"
mkswap ${DRIVE}2 -L "SWAP"
mkfs.btrfs ${DRIVE}3 -f -L "Archlinux"


mount -t btrfs /dev/disk/by-label/Archlinux /mnt

btrfs su cr /mnt/@
btrfs su cr /mnt/@pacman
btrfs su cr /mnt/@snapshots
btrfs su cr /mnt/@var_log
# btrfs su cr /mnt/@swap
btrfs su cr /mnt/@tmp
btrfs su cr /mnt/@cache
btrfs su cr /mnt/@home

umount -v /mnt

set -e
BTRFS_OPTS="noatime,ssd,compress-force=zstd:8,space_cache=v2,commit=120,discard=async"

## Mount partitions (Oldmac)
mount -o $BTRFS_OPTS,subvol=@ /dev/disk/by-label/Archlinux /mnt
mkdir -pv /mnt/{home,.snapshots,boot/grub,var/log,var/tmp,var/cache,var/lib/pacman}

# Swap Optional
# mkdir -pv /mnt/var/swap

mount -o $BTRFS_OPTS,subvol=@home /dev/disk/by-label/Archlinux /mnt/home
mount -o $BTRFS_OPTS,subvol=@snapshots /dev/disk/by-label/Archlinux /mnt/.snapshots
mount -o $BTRFS_OPTS,subvol=@var_log /dev/disk/by-label/Archlinux /mnt/var/log
mount -o $BTRFS_OPTS,subvol=@cache /dev/disk/by-label/Archlinux /mnt/var/cache
mount -o $BTRFS_OPTS,subvol=@tmp /dev/disk/by-label/Archlinux /mnt/var/tmp
# mount -o $BTRFS_OPTS,subvol=@swap /dev/disk/by-label/Archlinux /mnt/var/swap
mount -o $BTRFS_OPTS,subvol=@pacman /dev/disk/by-label/Archlinux /mnt/var/lib/pacman
mount -t vfat -o defaults,noatime,nodiratime /dev/disk/by-label/BOOT /mnt/boot
swapon /dev/disk/by-label/SWAP

### Old Mac
# pacstrap /mnt base base-devel linux linux-headers linux-firmware intel-ucode btrfs-progs archlinux-keyring git neovim nano reflector dropbear duf exa fzf ripgrep pacman-contrib --ignore vi openssh
pacstrap /mnt base base-devel linux-lts linux-lts-headers linux-firmware intel-ucode btrfs-progs archlinux-keyring git dropbear duf pacman-contrib --ignore vi openssh linux linux-headers

# Generate fstab
genfstab -U /mnt >>/mnt/etc/fstab
