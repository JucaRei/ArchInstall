#!/usr/bin/env bash

# Variable's
# DRIVE="/dev/vda"
DRIVE="/dev/sda"
hostname="arch"

pacman -Syyy
pacman -Sy archlinux-keyring --noconfirm

# Enable pacman Color
sed -i '1n; /^#UseSyslog/i ILoveCandy' /etc/pacman.conf
sed -i '/Color/s/^#//' /etc/pacman.conf
sed -i '3n; /^#UseSyslog/i DisableDownloadTimeout' /etc/pacman.conf
sed -i 's/#ParallelDownloads = 5/ParallelDownloads = 4/g' /etc/pacman.conf

pacman -Syyy

sgdisk -Z $DRIVE

parted --script --fix --align optimal $DRIVE mklabel gpt
parted --script --fix --align optimal $DRIVE mkpart primary fat32 1MiB 512MiB
parted --script $DRIVE -- set 1 boot on
parted --script --align optimal --fix -- $DRIVE mkpart primary 512MiB -2GiB
parted --script --align optimal --fix -- $DRIVE mkpart primary -2GiB 100%

sgdisk -c 1:"EFI FileSystem partition" ${DRIVE}
sgdisk -t 1:ef00 ${DRIVE}
sgdisk -c 2:"Archlinux FileSystem" ${DRIVE}
sgdisk -t 2:8200 ${DRIVE}
sgdisk -c 3:"Archlinux Swap" ${DRIVE}
sgdisk -t 3:8300 ${DRIVE}
sgdisk -p ${DRIVE}

BOOT_PARTITION="${DRIVE}1"
ROOT_PARTITION="${DRIVE}2"
SWAP_PARTITION="${DRIVE}3"

mkfs.vfat -F32 $BOOT_PARTITION -n "EFI"
mkfs.btrfs $ROOT_PARTITION -f -L "Archsys"
mkswap /dev/sda3 -L "SWAP"
swapon /dev/disk/by-label/SWAP

pacstrap /mnt base base-devel linux linux-firmware archlinux-keyring man-db perl sysfsutils git man-pages openssh git nano neovim intel-ucode duf reflector mtools dosfstools btrfs-progs pacman-contrib nfs-utils --ignore vi

# Generate fstab
genfstab -U /mnt >>/mnt/etc/fstab

arch-chroot /mnt

ln -sf /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime

hwclock --systohc

sed -i '171s/.//' /etc/locale.gen # en-US
sed -i '391s/.//' /etc/locale.gen # pt-BR
locale-gen

echo "$hostname" >>/etc/hostname
echo "127.0.0.1           localhost" >> /etc/hosts
echo "::1                 localhost" >> /etc/hosts
echo "127.0.1.1           $hostname.localdomain $hostname" >> /etc/hosts

echo root:200291 | chpasswd

sed -i '1n; /^#UseSyslog/i ILoveCandy' /etc/pacman.conf
sed -i '3n; /^#UseSyslog/i DisableDownloadTimeout' /etc/pacman.conf
sed -i '/Color/s/^#//' /etc/pacman.conf
sed -i 's/#ParallelDownloads = 5/ParallelDownloads = 3/g' /etc/pacman.conf
sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf
sed -i "/\[lib32\]/,/Include/"'s/^#//' /etc/pacman.conf
sed -i '/\[core\]/a SigLevel\ =\ PackageRequired' /etc/pacman.conf
sed -i '/\[multilib\]/a SigLevel\ =\ PackageRequired' /etc/pacman.conf
sed -i '/\[community\]/a SigLevel\ =\ PackageRequired' /etc/pacman.conf
sed -i '/\[extra\]/a SigLevel\ =\ PackageRequired' /etc/pacman.conf

pacman-key --init

pacman -Syyy

reflector --country 'Brazil'
systemctl enable reflector.service
systemctl enable reflector.timer

pacman -S efibootmgr grub grub-btrfs  chrony irqbalance yad gvfs gvfs-smb inetutils dnsutils xdg-user-dirs xdg-utils bash-completion os-prober networkmanager
