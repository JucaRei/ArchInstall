#!/usr/bin/env bash

set -e
trap 'echo "❌ Error occurred at line $LINENO"' ERR

### Support boot encryption during installation
sed -i.bkp 's/encryption_support = False/encryption_support = True/' \
    /usr/lib64/python3.*/site-packages/pyanaconda/modules/storage/bootloader/base.py


# Variables
DRIVE="/dev/sda"
MOUNTPOINT="/mnt"
SWAP_LABEL="SWAP"
BOOT_LABEL="SYSTEM"
EFI_LABEL="ESP"
CRYPT_NAME="luks_root"
ROOT_LABEL="Fedora"
BTRFS_OPTS="noatime,ssd,compress-force=zstd:8,space_cache=v2,nodatacow,commit=120,discard=async"

echo "Disable SELinux temporarily..."
setenforce 0 # disable SELInux for now

### 📦 Install required tools
dnf install -y cryptsetup gdisk btrfs-progs

### Partition
echo "Creating partitions on $DRIVE..."
sgdisk --zap-all ${DRIVE}

parted --script --fix --align optimal $DRIVE mklabel gpt
parted --script --fix --align optimal $DRIVE mkpart primary ext4 1M 600M
parted --script $DRIVE -- set 1 boot on
parted --script --fix --align optimal $DRIVE mkpart primary fat32 600M 1.6G
parted --script --align optimal --fix -- $DRIVE mkpart primary 1.6G 100%

# parted -s -a optimal ${DRIVE} mklabel gpt
# sgdisk -n 0:0:+600M ${DRIVE}
# sgdisk -n 0:0:+1G ${DRIVE}
# sgdisk -n 0:0:-2G ${DRIVE}
# sgdisk -n 0:0:0 ${DRIVE}

# Type
# sgdisk -t 1:ef00 ${DRIVE}
sgdisk -t 1:8300 ${DRIVE}
sgdisk -t 2:EF00 ${DRIVE}
sgdisk -t 3:8300 ${DRIVE}
# sgdisk -t 4:8200 ${DRIVE}

# Labels
# sgdisk -c 1:'EFI system partition' ${DRIVE}
sgdisk -c 1:'SYSTEM Partition' ${DRIVE}
sgdisk -c 2:'EFI BOOT Partition' ${DRIVE}
sgdisk -c 3:'Fedora Root Partition' ${DRIVE}
# sgdisk -c 4:'Fedora swap partition' ${DRIVE}
echo "Partitions created successfully on $DRIVE."
sgdisk -p ${DRIVE}

### 🔐 Encrypt root partition with LUKS2 (Argon2id)
echo "Encrypting $DRIVE with LUKS2..."
echo -n "juca2002" | cryptsetup luksFormat --type luks2 --pbkdf argon2id ${DRIVE}3 --batch-mode --key-file=-
echo -n "juca2002" |cryptsetup open ${DRIVE}3 ${CRYPT_NAME} --key-file=-

# Just like fedora partition way
echo "Formatting partitions on $DRIVE..."
mkfs.ext4 -F -L SYSTEM ${DRIVE}1
mkfs.fat -F 32 -n ESP ${DRIVE}2
mkfs.btrfs -f -L Fedora /dev/mapper/${CRYPT_NAME}
# mkswap ${DRIVE}4 -L "SWAP"
# swapon ${DRIVE}4
echo "Partitions formatted successfully on $DRIVE."


echo "Mounting root partition..."
### 📁 Mount root and create subvolumes
mount /dev/mapper/${CRYPT_NAME} $MOUNTPOINT
cd $MOUNTPOINT
for subvol in @root @home @cache @opt @gdm @libvirt @log @tmp @spool @snapshots; do
  btrfs subvolume create $subvol
done
cd
umount -Rv $MOUNTPOINT
cryptsetup luksClose /dev/mapper/${CRYPT_NAME}

### Mount subvolumes
echo -n "juca2002" | cryptsetup luksOpen ${DRIVE}3 luks_root --key-file=-
mount -o $BTRFS_OPTS,subvol=@root /dev/mapper/${CRYPT_NAME} $MOUNTPOINT

mkdir -pv $MOUNTPOINT/{boot,home,opt,.snapshots,var/{tmp,spool,log,cache,lib/libvirt,lib/gdm}}

mount -o $BTRFS_OPTS,subvol=@home /dev/mapper/${CRYPT_NAME} $MOUNTPOINT/home
mount -o $BTRFS_OPTS,subvol=@opt /dev/mapper/${CRYPT_NAME} $MOUNTPOINT/opt
mount -o $BTRFS_OPTS,subvol=@gdm /dev/mapper/${CRYPT_NAME} $MOUNTPOINT/var/lib/gdm
mount -o $BTRFS_OPTS,subvol=@libvirt /dev/mapper/${CRYPT_NAME} $MOUNTPOINT/var/lib/libvirt
mount -o $BTRFS_OPTS,subvol=@log /dev/mapper/${CRYPT_NAME} $MOUNTPOINT/var/log
mount -o $BTRFS_OPTS,subvol=@spool /dev/mapper/${CRYPT_NAME} $MOUNTPOINT/var/spool
mount -o $BTRFS_OPTS,subvol=@tmp /dev/mapper/${CRYPT_NAME} $MOUNTPOINT/var/tmp
# mount -o $BTRFS_OPTS,subvol=@cache /dev/mapper/${CRYPT_NAME} /mnt/var/cache
mount -o $BTRFS_OPTS,subvol=@cache /dev/mapper/${CRYPT_NAME} $MOUNTPOINT/var/cache
mount -o $BTRFS_OPTS,subvol=@snapshots /dev/mapper/${CRYPT_NAME} $MOUNTPOINT/.snapshots

mount /dev/disk/by-label/${BOOT_LABEL} $MOUNTPOINT/boot
mkdir -pv $MOUNTPOINT/boot/efi
mount -t vfat -o defaults,noatime,nodiratime /dev/disk/by-label/${EFI_LABEL} $MOUNTPOINT/boot/efi

### 🧠 Prepare for chroot install
udevadm trigger
mkdir -pv $MOUNTPOINT/{proc,sys,dev/pts}
mount -t proc     proc     $MOUNTPOINT/proc
mount -t sysfs    sysfs    $MOUNTPOINT/sys
mount --rbind     /dev     $MOUNTPOINT/dev
mount -t devpts   devpts   $MOUNTPOINT/dev/pts

source /etc/os-release
export VERSION_ID="$VERSION_ID"
# env | grep -i version

### Install core system
# dnf --installroot=/mnt --releasever=$VERSION_ID groupinstall -y core --use-host-config
dnf5 group install core --installroot=/mnt --releasever=$VERSION_ID --use-host-config -y
dnf5 --installroot=/mnt --releasever=$VERSION_ID install system-release --use-host-config -y
# dnf --releasever=42 --installroot=/mnt core -y

# Lang pack
# dnf5 --installroot=/mnt install -y glibc-langpack-en
dnf5 --installroot=/mnt install -y glibc-langpack-en --use-host-config

# Get live iso resolv conf
# cp /mnt/etc/resolv.conf /mnt/etc/resolv.conf.orig
# cp /etc/resolv.conf /mnt/etc/resolv.conf.orig

rm -rf /mnt/etc/resolv.conf
touch /mnt/etc/resolv.conf
cat <<EOF >/mnt/etc/resolv.conf
# This is /run/systemd/resolve/stub-resolv.conf managed by man:systemd-resolved(8).
# Do not edit.
#
# This file might be symlinked as /etc/resolv.conf. If you're looking at
# /etc/resolv.conf and seeing this text, you have followed the symlink.
#
# This is a dynamic resolv.conf file for connecting local clients to the
# internal DNS stub resolver of systemd-resolved. This file lists all
# configured search domains.
#
# Run "resolvectl status" to see details about the uplink DNS servers
# currently in use.
#
# Third party programs should typically not access this file directly, but only
# through the symlink at /etc/resolv.conf. To manage man:resolv.conf(5) in a
# different way, replace this symlink by a static file or a different symlink.
#
# See man:systemd-resolved.service(8) for details about the supported modes of
# operation for /etc/resolv.conf.

nameserver 127.0.0.53
nameserver 1.1.1.1
nameserver 8.8.8.8
options edns0 trust-ad
search .
EOF

chroot /mnt cp /etc/resolv.conf /etc/resolv.conf.orig

# FSTAB
dnf install -y arch-install-scripts
genfstab -U /mnt >> /mnt/etc/fstab

# ====================================================

# Log in system
chroot /mnt /bin/bash

# mount efi
# mount -t efivarfs efivarfs /sys/firmware/efi/efivars
chroot /mnt mount -t efivarfs efivarfs /sys/firmware/efi/efivars

# Re-enable sys enhanciment
# fixfiles -F onboot
chroot /mnt fixfiles -F onboot

chroot /mnt dnf install -y btrfs-progs efi-filesystem efibootmgr fwupd grub2-common grub2-efi-ia32 grub2-efi-x64 grub2-pc grub2-pc-modules grub2-tools grub2-tools-efi grub2-tools-extra grub2-tools-minimal grubby kernel mactel-boot mokutil shim-ia32 shim-x64 --allowerasing --exclude='*nvidia*' --exclude='akmod-nvidia' --exclude='xorg-x11-drv-nvidia*'

# regenerate with current environment
chroot /mnt rm -f /boot/efi/EFI/fedora/grub.cfg
chroot /mnt rm -f /boot/grub2/grub.cfg
chroot /mnt dnf reinstall -y shim-* grub2-efi-* grub2-common

# rm -f /boot/efi/EFI/fedora/grub.cfg
# rm -f /boot/grub2/grub.cfg
# dnf reinstall -y shim-* grub2-efi-* grub2-common

luks="19b36027-a402-4221-bd61-299da7b856d3"

cat <<EOF >/mnt/etc/default/grub
GRUB_TIMEOUT=5
GRUB_DISTRIBUTOR="$(sed 's, release .*$,,g' /etc/system-release)"
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash rd.luks.uuid=${luks} kernel.unprivileged_userns_clone vt.global_cursor_default=0 loglevel=0 gpt init_on_alloc=0 udev.log_level=0 rcutree.rcu_idle_gp_delay=1 intel_iommu=on,igfx_off zswap.enabled=1 zswap.compressor=lz4hc zswap.max_pool_percent=10 zswap.zpool=z3fold mitigations=off nowatchdog msr.allow_writes=on pcie_aspm=force module.sig_unenforce intel_idle.max_cstate=1 cryptomgr.notests initcall_debug no_timer_check noreplace-smp page_alloc.shuffle=1 rcupdate.rcu_expedited=1 tsc=reliable"

GRUB_DEFAULT=saved
GRUB_DISABLE_SUBMENU=true
GRUB_TERMINAL_OUTPUT="console"
GRUB_CMDLINE_LINUX="rhgb quiet"
GRUB_DISABLE_RECOVERY="true"
GRUB_ENABLE_BLSCFG=true
GRUB_COLOR_NORMAL="light-blue/black"
GRUB_COLOR_HIGHLIGHT="light-cyan/blue"
GRUB_DISABLE_OS_PROBER=false
EOF

chroot /mnt efibootmgr -c -d /dev/disk/by-label/ESP -p 1 -L "Fedora (Custom)" -l \\EFI\\FEDORA\\SHIMX64.EFI

chroot /mnt grub2-mkconfig -o /boot/grub2/grub.cfg

rm -f /mnt/etc/localtime

# Do it manualy
# systemd-firstboot --prompt # 13 #49

chroot /mnt sh -c 'echo "root:200291" | chpasswd -c SHA512'

# umount -n -R /mnt

chroot /mnt useradd juca -m -c "Reinaldo P JR" -s /bin/bash
chroot /mnt sh -c 'echo "juca:200291" | chpasswd -c SHA512'
0
chroot /mnt usermod -aG wheel juca

# reboot


# RPM Fusion | Nvidia

# nvidia
# sudo dnf install kernel-devel kernel-headers gcc make dkms acpid libglvnd-glx libglvnd-opengl libglvnd-devel pkgconfig

chroot /mnt dnf install https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm -y
chroot /mnt dnf install https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm -y

chroot /mnt dnf makecache
# sudo dnf install akmod-nvidia xorg-x11-drv-nvidia-cuda
# sudo dnf install nvidia-vaapi-driver libva-utils vdpauinfo

# dnf lightdm slick-greeter xorg-x11-server-Xorg

cryptsetup luksChangeKey ${DRIVE}3 --pbkdf pbkdf2 --pbkdf-force-iterations 500000 --key-file=-

echo -n "juca2002" | sudo cryptsetup luksChangeKey ${DRIVE}3 \
  --key-file=- \
  --pbkdf pbkdf2 \
  --pbkdf-force-iterations 500000 \
  --new-keyfile=<(echo -n "new_password")
  # <new_key_file>

# Crypto mount for grub luks2

# /mnt/boot/efi/EFI/fedora/grub.cfg
cryptomount -u 19b36027a4024221bd61299da7b856d3

# /mnt/etc/default/grub
GRUB_PRELOAD_MODULES="cryptodisk luks"
GRUB_ENABLE_CRYPTODISK=y

# sudo hostnamectl set-hostname fedora
# sudo grub2-editenv - list
# sudo grub2-editenv - unset menu_auto_hide

sudo dnf install @xfce-desktop-environment xfce4-goodies -y
systemctl set-default graphical.target
systemctl enable lightdm  # or gdm, depending on your preference

sudo btrfs subvolume create .mozilla
sudo chown -cR $USER: ~/$(ls -A)
sudo restorecon -RFv ~/$(ls -A)
