#!/bin/sh

umount -R /mnt
sgdisk -Z /dev/vda
parted -s -a optimal /dev/vda mklabel gpt
sgdisk -n 0:0:512MiB /dev/vda
sgdisk -n 0:0:0 /dev/vda
sgdisk -t 1:ef00 /dev/vda
sgdisk -t 2:8300 /dev/vda
sgdisk -c 1:GRUB /dev/vda
sgdisk -c 2:NIXOS /dev/vda
parted /dev/vda -- set 1 esp on
sgdisk -p /dev/vda

mkfs.vfat -F32 /dev/vda1 -n "GRUB"
mkfs.btrfs /dev/vda2 -f -L "NIXOS"

BTRFS_OPTS="rw,noatime,ssd,compress-force=zstd:15,space_cache=v2,commit=120,autodefrag,discard=async"
mount -o $BTRFS_OPTS /dev/vda2 /mnt
btrfs su cr /mnt/@root
btrfs su cr /mnt/@home
btrfs su cr /mnt/@nix
btrfs su cr /mnt/@snapshots
btrfs su cr /mnt/@tmp
# btrfs su cr /mnt/@swap
umount -R /mnt

# mount -o $BTRFS_OPTS,subvol=@root /dev/vda2 /mnt 
mount -o $BTRFS_OPTS,subvol="@root" /dev/disk/by-label/NIXOS /mnt
# mkdir -pv /mnt/{boot/efi,home,.snapshots,var/tmp,nix,swap}
mkdir -pv /mnt/{boot/efi,home,.snapshots,var/tmp,nix}
# mount -o $BTRFS_OPTS,subvol=@home /dev/vda2 /mnt/home
mount -o $BTRFS_OPTS,subvol="@home" /dev/disk/by-label/NIXOS /mnt/home
# mount -o $BTRFS_OPTS,subvol=@snapshots /dev/vda2 /mnt/.snapshots
mount -o $BTRFS_OPTS,subvol="@snapshots" /dev/disk/by-label/NIXOS /mnt/.snapshots
# mount -o $BTRFS_OPTS,subvol=@swap /dev/vda2 /mnt/swap
# mount -o $BTRFS_OPTS,subvol=@tmp /dev/vda2 /mnt/var/tmp
mount -o $BTRFS_OPTS,subvol="@tmp" /dev/disk/by-label/NIXOS /mnt/var/tmp
# mount -o $BTRFS_OPTS,subvol=@nix /dev/vda2 /mnt/nix
mount -o $BTRFS_OPTS,subvol="@nix" /dev/disk/by-label/NIXOS /mnt/nix
# mount -t vfat -o rw,defaults,noatime,nodiratime /dev/vda1 /mnt/boot/efi
# mount -t vfat -o rw,defaults,noatime,nodiratime /dev/disk/by-label/GRUB /mnt/boot/efi
mount -t vfat -o rw,defaults,noatime,nodiratime /dev/disk/by-label/EFI /mnt/boot/efi

# for dir in dev proc sys run; do
#    mount --rbind /$dir /mnt/$dir
#    mount --make-rslave /mnt/$dir
# done

# UEFI_UUID=$(blkid -s UUID -o value /dev/vda1)
# ROOT_UUID=$(blkid -s UUID -o value /dev/vda2)

# mkdir -pv /home/nixos/.config/nix/
# touch /home/nixos/.config/nix/nix.conf
# echo "experimental-features = nix-command flakes" >> /home/nixos/.config/nix/nix.conf

# nixos-generate-config --root /mnt
# nix.settings.experimental-features = [ "nix-command" "flakes" ];

# nix-env -iA nixos.git

# git clone --depth=1 https://github.com/JucaRei/teste-repo /home/nixos/.setup
# git clone --depth=1 https://github.com/JucaRei/teste-repo /mnt/etc/nixos


# sudo nixos-install -v --root /mnt --flake /home/nixos/.setup#vm