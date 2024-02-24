#!/usr/bin/env bash

# Variables
DRIVE="/dev/sda"
BTRFS_OPTS="noatime,ssd,compress-force=zstd:15,space_cache=v2,nodatacow,commit=120,discard=async"


setenforce 0 # disable SELInux for now

### Partition
sgdisk --zap-all ${DRIVE}
parted -s -a optimal ${DRIVE} mklabel gpt
sgdisk -n 0:0:+600M ${DRIVE}
sgdisk -t 1:ef00 ${DRIVE}
sgdisk -c 1:'EFI system partition' ${DRIVE}
sgdisk -n 0:0:+1G ${DRIVE}
sgdisk -t 2:8300 ${DRIVE}
sgdisk -c 2:'BOOT partition' ${DRIVE}
sgdisk -n 0:0:0 ${DRIVE}
sgdisk -t 3:8300 ${DRIVE}
sgdisk -c 3:'Fedora root partition' ${DRIVE}

# Just like fedora partition way
mkfs.fat -F32 -n SYS ${DRIVE}1
mkfs.ext4 -F -L BOOT ${DRIVE}2
mkfs.btrfs -f -L Fedora ${DRIVE}3

mount /dev/disk/by-label/Fedora /mnt
cd /mnt

# Subvolumes
btrfs subvolume create @
btrfs subvolume create @cache
btrfs subvolume create @home
btrfs subvolume create @images
btrfs subvolume create @log
btrfs subvolume create @snapshots
btrfs subvolume create @swap

cd
umount -Rv /mnt

### Mount subvolumes
mount -o $BTRFS_OPTS,subvol=@ /dev/disk/by-label/Fedora /mnt
mkdir -pv /mnt/{boot,home,.snapshots,var/{log,cache,lib/libvirt/images,swap}}

mount -o $BTRFS_OPTS,subvol=@home /dev/disk/by-label/Fedora /mnt/home
mount -o $BTRFS_OPTS,subvol=@images /dev/disk/by-label/Fedora /mnt/var/lib/libvirt/images
mount -o $BTRFS_OPTS,subvol=@log /dev/disk/by-label/Fedora /mnt/var/log
mount -o $BTRFS_OPTS,subvol=@cache /dev/disk/by-label/Fedora /mnt/var/cache
mount -o $BTRFS_OPTS,subvol=@snapshots /dev/disk/by-label/Fedora /mnt/.snapshots
mount -o $BTRFS_OPTS,subvol=@swap /dev/disk/by-label/Fedora /mnt/var/swap
mount /dev/disk/by-label/BOOT /mnt/boot
mkdir -pv /mnt/boot/efi
mount -t vfat -o defaults,noatime,nodiratime /dev/disk/by-label/SYS /mnt/boot/efi

touch /mnt/var/swap/swapfile
chmod 600 /mnt/var/swap/swapfile
chattr +C /mnt/var/swap/swapfile
lsattr /mnt/var/swap/swapfile
# dd if=/dev/zero of=/mnt/var/swap/swapfile bs=1M count=5120 status=progress
dd if=/dev/zero of=/mnt/var/swap/swapfile bs=1M count=6144 status=progress
mkswap /mnt/var/swap/swapfile
swapon /mnt/var/swap/swapfile

### Mount sudo fs
udevadm trigger
mkdir -pv /mnt/{proc,sys,dev/pts}
mount -t proc proc /mnt/proc
mount -t sysfs sys /mnt/sys
mount -B /dev /mnt/dev
mount -t /devpts /mnt/dev/pts

source /etc/os-release
export VERSION_ID="$VERSION_ID"
# env | grep -i version

### Install core system
dnf --installroot=/mnt --releasever=$VERSION_ID groupinstall -y core

# Lang pack
dnf --installroot=/mnt install -y glibc-langpack-en NetworkManager-wifi NetworkManager-tui kmod-wl mt7xxx-firmware

# Get live iso resolv conf
mv /mnt/etc/resolv.conf /mnt/etc/resolv.conf.orig
cp -L /etc/resolv.conf /mnt/etc

# FSTAB
dnf install -y arch-install-scripts 
genfstab -U /mnt >> /mnt/etc/fstab

====================================================
# Log in system
chroot /mnt /bin/bash

# mount efi
# mount -t efivarfs efivarfs /sys/firmware/efi/efivars
chroot /mnt mount -t efivarfs efivarfs /sys/firmware/efi/efivars


# Re-enable sys enhanciment
# fixfiles -F onboot
chroot /mnt fixfiles -F onboot
dnf install https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

chroot /mnt dnf install -y btrfs-progs efi-filesystem efibootmgr fwupd grub2-common grub2-efi-ia32 grub2-efi-x64 grub2-pc grub2-pc-modules grub2-tools grub2-tools-efi grub2-tools-extra grub2-tools-minimal grubby kernel mactel-boot mokutil shim-ia32 shim-x64 --allowerasing

# regenerate with current environment
rm -f /mnt/boot/efi/EFI/fedora/grub.cfg
rm -f /mnt/boot/grub2/grub.cfg
chroot /mnt dnf reinstall -y shim-* grub2-efi-* grub2-common

cat <<\EOF >/etc/default/grub
GRUB_TIMEOUT=5
GRUB_DISTRIBUTOR="$(sed 's, release .*$,,g' /etc/system-release)"
GRUB_DEFAULT=saved
GRUB_DISABLE_SUBMENU=true
GRUB_TERMINAL_OUTPUT="console"
GRUB_CMDLINE_LINUX="rhgb quiet splash kernel.unprivileged_userns_clone vt.global_cursor_default=0 loglevel=0 gpt init_on_alloc=0 udev.log_level=0 intel_iommu=igfx_off i915.enable_psr=0 i915.modeset=1 zswap.enabled=1 zswap.compressor=lz4hc zswap.max_pool_percent=10 zswap.zpool=z3fold mitigations=off nowatchdog msr.allow_writes=on pcie_aspm=force module.sig_unenforce intel_idle.max_cstate=1 cryptomgr.notests initcall_debug no_timer_check noreplace-smp page_alloc.shuffle=1 rcupdate.rcu_expedited=1 tsc=reliable"
GRUB_DISABLE_RECOVERY="true"
GRUB_ENABLE_BLSCFG=true
EOF

mkdir -pv /tmp
cd /tmp
wget -c https://raw.githubusercontent.com/osandov/osandov-linux/master/scripts/btrfs_map_physical.c
gcc -O2 -o btrfs_map_physical btrfs_map_physical.c
./btrfs_map_physical /var/swap/swapfile >btrfs_map_physical.txt
filefrag -v /var/swap/swapfile | awk '$1=="0:" {print substr($4, 1, length($4)-2)}' >/tmp/resume.txt
set -e
RESUME_OFFSET=$(cat /tmp/resume.txt)
ROOT_UUID=$(blkid -s UUID -o value /dev/vda2)
export ROOT_UUID
export RESUME_OFFSET
sed -i 's/GRUB_CMDLINE_LINUX=""/GRUB_CMDLINE_LINUX="'"resume=UUID=$ROOT_UUID resume_offset=$RESUME_OFFSET"'"/g' /mnt/etc/default/grub
UUID=a3a5e688-9ea8-424d-af2e-0bd19c55758c

269568

chroot /mnt efibootmgr -c -d /dev/disk/by-label/SYS -p 1 -L "Fedora (Custom)" -l \\EFI\\FEDORA\\SHIMX64.EFI

chroot /mnt grub2-mkconfig -o /boot/grub2/grub.cfg

rm -f /mnt/etc/localtime

# Do it manualy
# systemd-firstboot --prompt # 13 #49 £579 £200

chroot /mnt sh -c 'echo "root:200291" | chpasswd -c SHA512'

umount -n -R /mnt

chroot /mnt useradd juca -m -c "Reinaldo P JR" -s /bin/bash
chroot /mnt sh -c 'echo "juca:200291" | chpasswd -c SHA512'

chroot /mnt usermod -aG wheel juca

reboot


# RPM Fusion | Nvidia

# nvidia
sudo dnf install kernel-devel kernel-headers gcc make dkms acpid libglvnd-glx libglvnd-opengl libglvnd-devel pkgconfig

sudo dnf install https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm
sudo dnf install https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

sudo dnf makecache
sudo dnf install akmod-nvidia xorg-x11-drv-nvidia-cuda
sudo dnf install nvidia-vaapi-driver libva-utils vdpauinfo

dnf lightdm slick-greeter xorg-x11-server-Xorg
