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
# Get Best Mirrors
reflector --protocol https --country "Brazil" --latest 10 --sort rate --save /etc/pacman.d/mirrorlist

pacman -Syyy

# =======================================================================================================================================================

# DRIVE="/dev/sda"
DRIVE="/dev/vda"

#####################
###### OldMac #######
#####################

parted -s ${DRIVE} mklabel msdos
# sgdisk -n 0:0:-4GiB ${DRIVE}
# parted -s ${DRIVE} mkpart primary ext4 1M 100%
parted -s ${DRIVE} set 1 boot on

mkfs.btrfs ${DRIVE} -f -L "Archlinux"
# mkswap ${DRIVE}1 -L "SWAP"
# swapon /dev/disk/by-label/SWAP

# HD="${DRIVE}"
# BOOT_SIZE=200
# SWAP_SIZE=2000

# # File System das partições
# BOOT_FS=ext4
# ROOT_FS=btrfs

# BOOT_START=1
# BOOT_END=$(($BOOT_START+$BOOT_SIZE))

# SWAP_START=$BOOT_END
# SWAP_END=$(($SWAP_START+$SWAP_SIZE))
# ROOT_START=$SWAP_END
# # HOME_START=$ROOT_END

# echo "Inicializando o HD"
# # Remove qualquer partição antiga
# parted -s $HD rm 1 &> /dev/null
# parted -s $HD rm 2 &> /dev/null
# parted -s $HD rm 3 &> /dev/null
# parted -s $HD rm 4 &> /dev/null
# # Cria partição boot
# echo "Criando partição boot"
# parted -s $HD mkpart primary $BOOT_FS $BOOT_START $BOOT_END 1>/dev/null
# parted -s $HD set 1 boot on 1>/dev/null || ERR=1

# # Cria partição swap
# echo "Criando partição swap"
# parted -s $HD mkpart primary linux-swap $SWAP_START $SWAP_END 1>/dev/null

# # Cria partição root
# echo "Criando partição root"
# # parted -s $HD mkpart primary $ROOT_FS $ROOT_START $ROOT_END -0 1>/dev/null
# parted -s $HD mkpart primary $ROOT_FS $ROOT_START -0 1>/dev/null

# Cria partição home
# echo "Criando partição home"
# parted -s -- $HD mkpart primary $HOME_FS $HOME_START -0 1>/dev/null


mount -t btrfs /dev/disk/by-label/Archlinux /mnt


btrfs su cr /mnt/@
btrfs su cr /mnt/@pacman
btrfs su cr /mnt/@snapshots
btrfs su cr /mnt/@var_log
btrfs su cr /mnt/@srv
btrfs su cr /mnt/@swap
btrfs su cr /mnt/@tmp
btrfs su cr /mnt/@cache
btrfs su cr /mnt/@home

umount -v /mnt

set -e
BTRFS_OPTS="noatime,ssd,compress-force=zstd:3,space_cache=v2,commit=120,discard=async"

## Mount partitions (Oldmac)
mount -o $BTRFS_OPTS,subvol=@ /dev/disk/by-label/Archlinux /mnt
mkdir -pv /mnt/{home,.snapshots,boot/grub,var/log,var/tmp,var/cache,var/lib/pacman}

# Swap Optional
mkdir -pv /mnt/var/swap

mount -o $BTRFS_OPTS,subvol=@home /dev/disk/by-label/Archlinux /mnt/home
mount -o $BTRFS_OPTS,subvol=@snapshots /dev/disk/by-label/Archlinux /mnt/.snapshots
mount -o $BTRFS_OPTS,subvol=@var_log /dev/disk/by-label/Archlinux /mnt/var/log
mount -o $BTRFS_OPTS,subvol=@cache /dev/disk/by-label/Archlinux /mnt/var/cache
mount -o $BTRFS_OPTS,subvol=@snapshots /dev/disk/by-label/Archlinux /mnt/
mount -o $BTRFS_OPTS,subvol=@tmp /dev/disk/by-label/Archlinux /mnt/var/tmp
mount -o $BTRFS_OPTS,subvol=@swap /dev/disk/by-label/Archlinux /mnt/var/swap
mount -o $BTRFS_OPTS,subvol=@pacman /dev/disk/by-label/Archlinux /mnt/var/lib/pacman
# mount -t vfat -o defaults,noatime,nodiratime /dev/disk/by-label/Archlinux /mnt/boot

### Old Mac
# pacstrap /mnt base base-devel linux linux-headers linux-firmware intel-ucode btrfs-progs archlinux-keyring git neovim nano reflector dropbear duf exa fzf ripgrep pacman-contrib --ignore vi openssh
pacstrap /mnt base base-devel linux-lts linux-lts-headers linux-firmware intel-ucode btrfs-progs archlinux-keyring git neovim nano reflector dropbear duf ripgrep pacman-contrib --ignore vi openssh linux linux-headers

# Generate fstab
genfstab -U /mnt >>/mnt/etc/fstab
