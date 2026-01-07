#!/usr/bin/env bash
#!/usr/bin/env bash

# 🧭 Drive + partition paths
DRIVE="/dev/nvme0n1"
SYSTEM_PART="${DRIVE}p2"
EFI_PART="${DRIVE}p3"
ROOT_PART="${DRIVE}p4"
HOME_PART="${DRIVE}p5"
WINDOWS_PART="${DRIVE}p7"
MISC_PART="${DRIVE}p8"

# 🔖 Labels
ROOT_LABEL="Linux"
HOME_LABEL="Data-home"
# SWAP_LABEL="SWAP"
SYSTEM_LABEL="BOOT"
EFI_LABEL="ESP"
WINDOWS_LABEL="Windows 11"
MISC_LABEL="Shared-Data"

# ⚙️ Btrfs options
BTRFS_OPTS="noatime,ssd,compress-force=zstd:8,space_cache=v2,commit=120,discard=async"
NIX_OPTS="noatime,ssd,compress-force=zstd:22,space_cache=v2,commit=20,discard=async"
BTRFS_OPTS2="noatime,ssd,compress-force=zstd:3,space_cache=v2,commit=60,discard=async"
BTRFS_OPTS_HOME="noatime,ssd,compress-force=zstd:10,space_cache=v2,commit=120,discard=async"


# 📁 Mount point
MOUNTPOINT="/mnt"

echo "🧱 Creating partitions..."
sgdisk --zap-all $DRIVE
sleep 2
parted -s -a optimal $DRIVE mklabel gpt
sgdisk -n 0:0:+1M      -t 1:EF02 -c 1:"BIOS BOOT"          $DRIVE
sgdisk -n 0:0:+1G      -t 2:8301 -c 2:"SYSTEM RESERVED"    $DRIVE
sgdisk -n 0:0:+600M    -t 3:EF00 -c 3:"EFI SYSTEM"         $DRIVE
sgdisk -n 0:0:+50G     -t 4:8300 -c 4:"$ROOT_LABEL System" $DRIVE
sgdisk -n 0:0:+60G     -t 5:8302 -c 5:"$HOME_LABEL Home"   $DRIVE
sgdisk -n 0:0:+16M     -t 6:0C01 -c 6:"Microsoft Reserved" $DRIVE
sgdisk -n 0:0:+100G    -t 7:0700 -c 7:"Windows data"       $DRIVE
sgdisk -n 0:0:0        -t 8:0700 -c 8:"Miscellaceous data" $DRIVE
sgdisk -p $DRIVE


echo "🧼 Formatting partitions..."
mkfs.ext4  -F                 -L "$SYSTEM_LABEL"  "$SYSTEM_PART"
mkfs.fat   -F32               -n "$EFI_LABEL"     "$EFI_PART"
mkfs.btrfs -f                 -L "$ROOT_LABEL"    "$ROOT_PART"
mkfs.btrfs -f                 -L "$HOME_LABEL"    "$HOME_PART"
mkfs.ntfs  -F                 -L "$WINDOWS_LABEL" "$WINDOWS_PART"
mkfs.exfat -b 1M -c 32K       -n "$MISC_LABEL"    "$MISC_PART"      # 16K small files - 128k for large sequential files (VMs, videos).

# 🎯 Create Btrfs subvolumes on root partition
mount "$ROOT_PART" "$MOUNTPOINT"
for sv in @root @opt @nix @gdm @libvirt @spool @log @tmp @apt @snapshots; do
  btrfs subvolume create "$MOUNTPOINT/$sv"
done
umount -Rv "$MOUNTPOINT"

# 🏠 Create @home subvolume on home partition
mkdir -p $MOUNTPOINT/home-temp
mount "$HOME_PART" $MOUNTPOINT/home-temp
btrfs subvolume create $MOUNTPOINT/home-temp/@home
umount $MOUNTPOINT/home-temp

echo "📦 Mounting subvolumes..."
mount -o $BTRFS_OPTS2,subvol=@root /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT
mkdir -pv $MOUNTPOINT/{boot,home,opt,nix,.snapshots,var/{tmp,spool,log,cache/apt,lib/{gdm,libvirt}}}

mount -o $BTRFS_OPTS_HOME,subvol=@home      /dev/disk/by-label/$HOME_LABEL $MOUNTPOINT/home
mount -o $BTRFS_OPTS,subvol=@opt            /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/opt
mount -o $BTRFS_OPTS,subvol=@gdm            /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/var/lib/gdm
mount -o $BTRFS_OPTS,subvol=@libvirt        /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/var/lib/libvirt
mount -o $BTRFS_OPTS2,subvol=@log           /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/var/log
mount -o $NIX_OPTS,subvol=@nix              /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/nix
mount -o $BTRFS_OPTS,subvol=@spool          /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/var/spool
mount -o $BTRFS_OPTS2,subvol=@tmp           /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/var/tmp
mount -o $BTRFS_OPTS,subvol=@apt            /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/var/cache/apt
mount -o $BTRFS_OPTS,subvol=@snapshots      /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/.snapshots

echo "⏏️ Mounting boot and EFI..."
mount /dev/disk/by-label/$SYSTEM_LABEL $MOUNTPOINT/boot
mkdir -pv $MOUNTPOINT/boot/efi
mount -t vfat -o defaults,noatime,nodiratime /dev/disk/by-label/$EFI_LABEL $MOUNTPOINT/boot/efi
