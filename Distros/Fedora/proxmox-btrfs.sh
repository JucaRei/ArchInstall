#!/usr/bin/env bash

### Support boot encryption during installation
sed -i.bkp 's/encryption_support = False/encryption_support = True/' \
    /usr/lib64/python3.*/site-packages/pyanaconda/modules/storage/bootloader/base.py

dnf install -y gdisk arch-install-scripts

# Variables
DRIVE="/dev/sda"
# MAPPER_NAME="secure_btrfs"
MOUNTPOINT="/mnt"
ROOT_LABEL="Fedora"
SWAP_LABEL="SWAP"
BOOT_LABEL="BOOT"
EFI_LABEL="ESP"
BTRFS_OPTS="noatime,ssd,compress-force=zstd:8,space_cache=v2,nodatacow,commit=120,discard=async"

echo "Disable SELinux temporarily..."
setenforce 0 # disable SELInux for now

# Create Partitions and Encrypt
### Partition
echo "Creating partitions on $DRIVE..."
sgdisk --zap-all ${DRIVE}
parted -s -a optimal ${DRIVE} mklabel gpt
sgdisk -n 0:0:+600M ${DRIVE}
sgdisk -t 1:8300 ${DRIVE}
sgdisk -c 1:'BOOT SYSTEM' ${DRIVE}
sgdisk -n 0:0:+1G ${DRIVE}
sgdisk -t 2:EF00 ${DRIVE}
sgdisk -c 2:'EFI system partition' ${DRIVE}
# sgdisk -n 0:0:-2G ${DRIVE}
sgdisk -n 0:0:0 ${DRIVE}
sgdisk -t 3:8300 ${DRIVE}
sgdisk -c 3:'Fedora root partition' ${DRIVE}
# sgdisk -n 0:0:0 ${DRIVE}
# sgdisk -t 4:8200 ${DRIVE}
# sgdisk -c 4:'Fedora swap partition' ${DRIVE}
echo "Partitions created successfully on $DRIVE."
sgdisk -p ${DRIVE}

# === ENCRYPT PARTITION ===
# echo "Encrypting $DRIVE with LUKS2..."
# cryptsetup luksFormat --type luks2 "$DRIVE" # rei20021
# cryptsetup open "$DRIVE" "$MAPPER_NAME"

echo "Formatting partitions on $DRIVE..."
# Just like fedora partition way
mkfs.ext4 -F -L "${BOOT_LABEL}" ${DRIVE}1
mkfs.fat -F 32 -n "${EFI_LABEL}" ${DRIVE}2
# mkfs.ext4 -F -L ESP ${DRIVE}2
mkfs.btrfs -f -L "${ROOT_LABEL}" ${DRIVE}3
# mkswap ${DRIVE}4 -L "${SWAP_LABEL}"
# swapon ${DRIVE}4
echo "Partitions formatted successfully on $DRIVE."

echo "Mounting root partition..."
mount ${DRIVE}3 $MOUNTPOINT
cd $MOUNTPOINT

echo "Creating Btrfs subvolumes..."
# Subvolumes
btrfs subvolume create @root #The root filesystem, where Fedora is installed. This is the main subvolume and will be snapshot-enabled.
btrfs subvolume create @cache #Avoids bloating system snapshots with package caches.
btrfs subvolume create @home #User data and configuration files. This subvolume will also be snapshot-enabled, which is why .mozilla is separated below.
btrfs subvolume create @opt #Isolates optional or third-party software installations.
btrfs subvolume create @gdm #Required for GNOME (Workstation Edition). Without this, read-only snapshots may cause login issues.
btrfs subvolume create @libvirt #Isolates virtual machine data (useful if you use KVM/QEMU/libvirt).
btrfs subvolume create @spool #Separates queued print jobs or mail data from root.
btrfs subvolume create @log #Prevents constantly changing log files from filling up snapshot space.
btrfs subvolume create @tmp #Keeps temporary files out of snapshots.
# btrfs subvolume create @mozilla #Isolates Mozilla Firefox data, preventing it from bloating the /home snapshot.
# btrfs subvolume create @chrome #Keeps Chrome data out of /home snapshots, improving rollback speed and stability.
# btrfs subvolume create @brave # Same as above—helps reduce snapshot size and keeps session data isolated.
# btrfs subvolume create @gpg #Useful if you want to exclude GPG keys and trust settings from being affected by rollbacks.
# btrfs subvolume create @ssh #Keeps your SSH keys and configurations stable and unaffected by snapshot restores.
# btrfs subvolume create @mail #Helps preserve mail client data and cache separately from /home snapshots.
btrfs subvolume create @snapshots #Holds Btrfs snapshots.
echo "Btrfs subvolumes created successfully."

echo "Unmounting root partition..."
cd
umount -Rv $MOUNTPOINT

echo "Mounting subvolumes and boot partition..."
### Mount subvolumes
mount -o $BTRFS_OPTS,subvol=@root /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT
mkdir -pv $MOUNTPOINT/{boot,home,opt,.snapshots,var/{tmp,spool,log,cache,lib/libvirt,lib/gdm}}

mount -o $BTRFS_OPTS,subvol=@home /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/home
mount -o $BTRFS_OPTS,subvol=@opt /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/opt
mount -o $BTRFS_OPTS,subvol=@gdm /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/var/lib/gdm
mount -o $BTRFS_OPTS,subvol=@libvirt /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/var/lib/libvirt
mount -o $BTRFS_OPTS,subvol=@log /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/var/log
mount -o $BTRFS_OPTS,subvol=@spool /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/var/spool
mount -o $BTRFS_OPTS,subvol=@tmp /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/var/tmp
# mount -o $BTRFS_OPTS,subvol=@cache /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/var/cache
mount -o $BTRFS_OPTS,subvol=@cache /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/var/cache
mount -o $BTRFS_OPTS,subvol=@snapshots /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/.snapshots
mount /dev/disk/by-label/$BOOT_LABEL $MOUNTPOINT/boot
mkdir -pv $MOUNTPOINT/boot/efi
mount -t vfat -o defaults,noatime,nodiratime /dev/disk/by-label/$EFI_LABEL $MOUNTPOINT/boot/efi
echo "Subvolumes and boot partition mounted successfully."

### Mount sudo fs
echo "Mounting system filesystems..."
udevadm trigger
mkdir -pv $MOUNTPOINT/{proc,sys,dev/pts}
mount -t proc proc $MOUNTPOINT/proc
mount -t sysfs sys $MOUNTPOINT/sys
# mount -B /dev $MOUNTPOINT/dev
mount --rbind /dev /mnt/dev
mount -t devpts $MOUNTPOINT/dev/pts
echo "System filesystems mounted successfully."

source /etc/os-release
export VERSION_ID="$VERSION_ID"
# env | grep -i version

### Install core system
# dnf --installroot=/mnt --releasever=$VERSION_ID groupinstall -y core --use-host-config
dnf5 --installroot=/mnt --releasever=$VERSION_ID install system-release --use-host-config
# dnf --releasever=42 --installroot=/mnt core -y

# Lang pack
# dnf5 --installroot=/mnt install -y glibc-langpack-en
dnf5 --installroot=/mnt install -y glibc-langpack-en --use-host-config

# Get live iso resolv conf
# cp /mnt/etc/resolv.conf /mnt/etc/resolv.conf.orig
cp /etc/resolv.conf /mnt/etc/resolv.conf.orig
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

chroot /mnt dnf install -y btrfs-progs efi-filesystem efibootmgr fwupd grub2-common grub2-efi-ia32 grub2-efi-x64 grub2-pc grub2-pc-modules grub2-tools grub2-tools-efi grub2-tools-extra grub2-tools-minimal grubby kernel mactel-boot mokutil shim-ia32 shim-x64 --allowerasing

# regenerate with current environment
rm -f /mnt/boot/efi/EFI/fedora/grub.cfg
rm -f /mnt/boot/grub2/grub.cfg
chroot /mnt dnf reinstall -y shim-* grub2-efi-* grub2-common

cat <<\EOF >/mnt/etc/default/grub
GRUB_TIMEOUT=5
GRUB_DISTRIBUTOR="$(sed 's, release .*$,,g' /etc/system-release)"
GRUB_DEFAULT=saved
GRUB_DISABLE_SUBMENU=true
GRUB_TERMINAL_OUTPUT="console"
GRUB_CMDLINE_LINUX="rhgb quiet"
GRUB_DISABLE_RECOVERY="true"
GRUB_ENABLE_BLSCFG=true
EOF

chroot /mnt efibootmgr -c -d /dev/disk/by-label/SYS -p 1 -L "Fedora (Custom)" -l \\EFI\\FEDORA\\SHIMX64.EFI

chroot /mnt grub2-mkconfig -o /boot/grub2/grub.cfg

rm -f /mnt/etc/localtime

# Do it manualy
# systemd-firstboot --prompt # 13 #49

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
