sgdisk -Z /dev/vda
parted -s -a optimal /dev/vda mklabel gpt
sgdisk -n 0:0:512MiB /dev/vda
sgdisk -n 0:0:0 /dev/vda
sgdisk -t 1:ef00 /dev/vda
sgdisk -t 2:8300 /dev/vda
sgdisk -c 1:GRUB /dev/vda
sgdisk -c 2:NIXOS /dev/vda
sgdisk -p /dev/vda
mkfs.vfat -F32 /dev/vda1 -n "GRUB"
mkfs.btrfs /dev/vda2 -f -L "NIXOS"

BTRFS_OPTS="rw,noatime,ssd,compress-force=zstd:15,space_cache=v2,commit=120,autodefrag,discard=async"
mount -o $BTRFS_OPTS /dev/vda2 /mnt
btrfs su cr /mnt/@
btrfs su cr /mnt/@home
btrfs su cr /mnt/@nix
btrfs su cr /mnt/@snapshots
btrfs su cr /mnt/@tmp
btrfs su cr /mnt/@swap
umount /mnt

mkdir -pv /mnt/{boot/efi,home,.snapshots,var/tmp,nix,swap}
mount -o $BTRFS_OPTS,subvol=@ /dev/vda2 /mnt/
mount -o $BTRFS_OPTS,subvol=@home /dev/vda2 /mnt/home
mount -o $BTRFS_OPTS,subvol=@snapshots /dev/vda2 /mnt/.snapshots
mount -o $BTRFS_OPTS,subvol=@swap /dev/vda2 /mnt/swap
mount -o $BTRFS_OPTS,subvol=@tmp /dev/vda2 /mnt/var/tmp
mount -o $BTRFS_OPTS,subvol=@nix /dev/vda2 /mnt/nix
mount -t vfat -o rw,defaults,noatime,nodiratime /dev/vda1 /mnt/boot/efi


# ZFS

zpool create -f \
-o altroot="/mnt" \
-o ashift=12 \
-o autotrim=on \
-O compression=zstd \
-O acltype=posixacl \
-O xattr=sa \
-O relatime=on \
-O normalization=formD \
-O dnodesize=auto \
-O sync=standard \
-O encryption=aes-256-gcm \
-O keylocation=prompt \
-O keyformat=passphrase \
-O mountpoint="legacy" \
NIXOS \
/dev/vda2 

zfs create -o mountpoint=legacy NIXOS/root
zfs create -o mountpoint=legacy NIXOS/home

mount -t zfs NIXOS/root /mnt
mkdir -pv /mnt/{boot/efi,home}
mount /dev/vda1 /mnt/boot/efi
mount -t zfs NIXOS/home /mnt/home

nixos-generate-config --root /mnt
