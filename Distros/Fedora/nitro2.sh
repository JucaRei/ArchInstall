#!/usr/bin/env bash
set -euo pipefail

# 📦 Required tools
dnf install -y gdisk arch-install-scripts exfatprogs ntfs-3g

echo "🔐 Enabling encryption support..."
sed -i.bkp 's/encryption_support = False/encryption_support = True/' \
  /usr/lib64/python3.*/site-packages/pyanaconda/modules/storage/bootloader/base.py

echo "🛑 Disabling SELinux temporarily..."
setenforce 0

# 🧭 Drive + partition paths
DRIVE="/dev/vda"
SYSTEM_PART="${DRIVE}2"
EFI_PART="${DRIVE}3"
ROOT_PART="${DRIVE}4"
HOME_PART="${DRIVE}5"
WINDOWS_PART="${DRIVE}7"
MISC_PART="${DRIVE}8"

# 🔖 Labels
ROOT_LABEL="Fedora"
HOME_LABEL="HOME"
SWAP_LABEL="SWAP"
SYSTEM_LABEL="BOOT"
EFI_LABEL="ESP"
WINDOWS_LABEL="Windows_11"
MISC_LABEL="SharedData"

# ⚙️ Btrfs options
BTRFS_OPTS="noatime,ssd,compress-force=zstd:8,space_cache=v2,nodatacow,commit=120,discard=async"
BTRFS_OPTS_HOME="noatime,ssd,compress-force=zstd:15,space_cache=v2,nodatacow,commit=120,discard=async"

# 📁 Mount point
MOUNTPOINT="/mnt"

echo "🧱 Creating partitions..."
sgdisk --zap-all $DRIVE
parted -s -a optimal $DRIVE mklabel gpt
sgdisk -n 0:0:+1M      -t 1:EF02 -c 1:"BIOS BOOT"        $DRIVE
sgdisk -n 0:0:+1G      -t 2:8301 -c 2:"SYSTEM RESERVED"  $DRIVE
sgdisk -n 0:0:+600M    -t 3:EF00 -c 3:"EFI SYSTEM"       $DRIVE
sgdisk -n 0:0:+10G     -t 4:8300 -c 4:"Fedora root"      $DRIVE
sgdisk -n 0:0:+10G     -t 5:8302 -c 5:"Fedora home"      $DRIVE
sgdisk -n 0:0:+16M     -t 6:0C01 -c 6:"Microsoft Reserved" $DRIVE
sgdisk -n 0:0:+10G     -t 7:0700 -c 7:"Windows data"     $DRIVE
sgdisk -n 0:0:0        -t 8:0700 -c 8:"Misc data"        $DRIVE
sgdisk -p $DRIVE

echo "🧼 Formatting partitions..."
mkfs.ext4  -F -L "$SYSTEM_LABEL"   "$SYSTEM_PART"
mkfs.fat   -F32 -n "$EFI_LABEL"    "$EFI_PART"
mkfs.btrfs -f   -L "$ROOT_LABEL"   "$ROOT_PART"
mkfs.btrfs -f   -L "$HOME_LABEL"   "$HOME_PART"
mkfs.ntfs  -F   -L "$WINDOWS_LABEL" "$WINDOWS_PART"
mkfs.exfat      -n "$MISC_LABEL"   "$MISC_PART"

# 🎯 Create Btrfs subvolumes on root partition
mount "$ROOT_PART" "$MOUNTPOINT"
for sv in @root @cache @opt @gdm @libvirt @spool @log @tmp @snapshots; do
  btrfs subvolume create "$MOUNTPOINT/$sv"
done
umount -Rv "$MOUNTPOINT"

# 🏠 Create @home subvolume on home partition
mkdir -p /mnt/home-temp
mount "$HOME_PART" /mnt/home-temp
btrfs subvolume create /mnt/home-temp/@home
umount /mnt/home-temp

echo "📦 Mounting subvolumes..."
mount -o $BTRFS_OPTS,subvol=@root /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT
mkdir -p $MOUNTPOINT/{boot,boot/efi,home,opt,.snapshots,var/{tmp,spool,log,cache,lib/{gdm,libvirt}}}

mount -o $BTRFS_OPTS_HOME,subvol=@home      /dev/disk/by-label/$HOME_LABEL $MOUNTPOINT/home
mount -o $BTRFS_OPTS,subvol=@opt            /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/opt
mount -o $BTRFS_OPTS,subvol=@gdm            /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/var/lib/gdm
mount -o $BTRFS_OPTS,subvol=@libvirt        /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/var/lib/libvirt
mount -o $BTRFS_OPTS,subvol=@log            /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/var/log
mount -o $BTRFS_OPTS,subvol=@spool          /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/var/spool
mount -o $BTRFS_OPTS,subvol=@tmp            /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/var/tmp
mount -o $BTRFS_OPTS,subvol=@cache          /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/var/cache
mount -o $BTRFS_OPTS,subvol=@snapshots      /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/.snapshots

echo "⏏️ Mounting boot and EFI..."
mount /dev/disk/by-label/$SYSTEM_LABEL $MOUNTPOINT/boot
mount -t vfat -o defaults,noatime,nodiratime /dev/disk/by-label/$EFI_LABEL $MOUNTPOINT/boot/efi

echo "🔧 Mounting system filesystems..."
udevadm trigger
mkdir -p $MOUNTPOINT/{proc,sys,dev/pts}
mount -t proc   proc     $MOUNTPOINT/proc
mount -t sysfs  sysfs    $MOUNTPOINT/sys
mount --rbind   /dev     $MOUNTPOINT/dev
mount -t devpts devpts   $MOUNTPOINT/dev/pts

echo "📦 Installing Fedora base system (dnf5)..."
dnf5 --installroot=$MOUNTPOINT --releasever=42 install system-release --use-host-config -y
dnf5 --installroot=$MOUNTPOINT install -y glibc-langpack-en --use-host-config

echo "🌐 Setting up DNS config..."
cp -L /etc/resolv.conf $MOUNTPOINT/etc/resolv.conf

echo "📑 Generating /etc/fstab..."
genfstab -U $MOUNTPOINT >> $MOUNTPOINT/etc/fstab

echo "✅ Setup complete. Ready for chroot: chroot $MOUNTPOINT"
