#!/usr/bin/env bash

dnf install gdisk btrfs-progs arch-install-scripts -y

#################
### Variaveis ###
#################

# Detect drive (VMs often use /dev/vda, physical uses /dev/sda)
if [ -b /dev/vda ]; then
    DRIVE="/dev/vda"
else
    DRIVE="/dev/sda"
fi

MOUNTPOINT="/mnt"
FEDORA_VER="43"
username="juca"

BOOT_PART="${DRIVE}1" # Partição /boot (ext4)
EFI_PART="${DRIVE}2"  # Partição EFI (FAT32)
HOME_PART="${DRIVE}3" # Partição home (Btrfs com subvolumes)
ROOT_PART="${DRIVE}4" # Partição root (Btrfs com subvolumes)
SWAP_PART="${DRIVE}5" # Partição de swap

# Rótulos para as partições (usados no fstab para montagem por label)
BOOT_LABEL="BOOT"
HOME_LABEL="Home"
ROOT_LABEL="Linux"
EFI_LABEL="ESP"
SWAP_LABEL="Swap"

# BTRFS Mount Options
BTRFS_OPTS="noatime,ssd,compress=zstd:3,space_cache=v2,commit=60,discard=async"
NIX_OPTS="noatime,ssd,compress=zstd:22,space_cache=v2,commit=120,discard=async"
HOME_OPTS="noatime,ssd,compress=zstd:10,space_cache=v2,commit=60,discard=async"

# UUID and LABEL detection will happen AFTER partitioning

#######################
### Particionamento ###
#######################

# Disable swap if already active
if [ -b /dev/disk/by-label/"${SWAP_LABEL}" ]; then
    swapoff /dev/disk/by-label/"${SWAP_LABEL}"
fi

umount -Rvf "${DRIVE}"
sleep 2
sgdisk --zap-all "${DRIVE}"
sleep 2
parted -s -a optimal "${DRIVE}" mklabel gpt
sgdisk -n 1:0:+1G   -t 1:8301 -c 1:"SYSTEM_RESERVED"      "${DRIVE}"  # Partição /boot (1G, ext4)
sgdisk -n 2:0:+600M -t 2:EF00 -c 2:"EFI_SYSTEM"           "${DRIVE}"  # Partição EFI (600M, FAT32)
sgdisk -n 3:0:25G   -t 3:8302 -c 3:"HOME_DATA"            "${DRIVE}"  # Partição home (25G)
sgdisk -n 4:0:-5G   -t 4:8300 -c 4:"ROOT_SYSTEM"          "${DRIVE}"  # Partição root
sgdisk -n 5:0:0     -t 5:8200 -c 5:"SWAP_FILESYSTEM"      "${DRIVE}"  # Partição de swap
sgdisk -p "${DRIVE}"

echo "🧼 Formatting partitions..."
mkfs.ext4  -F    -L  "${BOOT_LABEL}" "${BOOT_PART}"
mkfs.fat   -F32  -n  "${EFI_LABEL}"  "${EFI_PART}"
mkfs.btrfs -f    -L  "${HOME_LABEL}" "${HOME_PART}"
mkfs.btrfs -f    -L  "${ROOT_LABEL}" "${ROOT_PART}"
mkswap     -L        "${SWAP_LABEL}" "${SWAP_PART}"
swapon               "${SWAP_PART}"

# Wait for udev to create /dev/disk/by-label/* symlinks
udevadm settle
sleep 2

# Detect UUIDs after formatting
BOOT_UUID=$(blkid -s UUID -o value $BOOT_PART)
EFI_UUID=$(blkid -s UUID -o value $EFI_PART)
HOME_UUID=$(blkid -s UUID -o value $HOME_PART)
ROOT_UUID=$(blkid -s UUID -o value $ROOT_PART)
SWAP_UUID=$(blkid -s UUID -o value $SWAP_PART)

# Verify labels are detected
echo "🔍 Verifying partition labels..."
ls -la /dev/disk/by-label/

echo "🎯 Creating btrfs subvolumes..."
mkdir -pv "${MOUNTPOINT}"
mount "${ROOT_PART}" "${MOUNTPOINT}"
for sv in @ @opt @nix @gdm @libvirt @spool @log @tmp @cache @snapshots; do
  btrfs subvolume create "$MOUNTPOINT/$sv"
done
umount -Rvf "${MOUNTPOINT}"

# 🏠 Create @home subvolume on home partition
mkdir -pv "$MOUNTPOINT/home-temp"
mount "$HOME_PART" "$MOUNTPOINT/home-temp"
btrfs subvolume create "$MOUNTPOINT/home-temp/@home"
umount "$MOUNTPOINT/home-temp"

echo "📦 Mounting subvolumes..."
mount -o $BTRFS_OPTS,subvol=@ /dev/disk/by-label/"$ROOT_LABEL" "$MOUNTPOINT"
mkdir -pv "$MOUNTPOINT"/{boot,home,opt,nix,.snapshots,var/{tmp,spool,log,cache/apt,lib/{gdm,libvirt}}}

mount -o $HOME_OPTS,subvol=@home            /dev/disk/by-label/"$HOME_LABEL" "$MOUNTPOINT/home"
mount -o $BTRFS_OPTS,subvol=@opt            /dev/disk/by-label/"$ROOT_LABEL" "$MOUNTPOINT/opt"
mount -o $BTRFS_OPTS,subvol=@gdm            /dev/disk/by-label/"$ROOT_LABEL" "$MOUNTPOINT/var/lib/gdm"
mount -o $BTRFS_OPTS,subvol=@libvirt        /dev/disk/by-label/"$ROOT_LABEL" "$MOUNTPOINT/var/lib/libvirt"
mount -o $BTRFS_OPTS,subvol=@log            /dev/disk/by-label/"$ROOT_LABEL" "$MOUNTPOINT/var/log"
mount -o $NIX_OPTS,subvol=@nix              /dev/disk/by-label/"$ROOT_LABEL" "$MOUNTPOINT/nix"
mount -o $BTRFS_OPTS,subvol=@spool          /dev/disk/by-label/"$ROOT_LABEL" "$MOUNTPOINT/var/spool"
mount -o $BTRFS_OPTS,subvol=@tmp            /dev/disk/by-label/"$ROOT_LABEL" "$MOUNTPOINT/var/tmp"
mount -o $BTRFS_OPTS,subvol=@cache          /dev/disk/by-label/"$ROOT_LABEL" "$MOUNTPOINT/var/cache"
mount -o $BTRFS_OPTS,subvol=@snapshots      /dev/disk/by-label/"$ROOT_LABEL" "$MOUNTPOINT/.snapshots"

echo "⏏️ Mounting boot and EFI..."
mount /dev/disk/by-label/"$BOOT_LABEL" "$MOUNTPOINT/boot"
sleep 2
mkdir -pv "$MOUNTPOINT/boot/efi"
mount -t vfat -o defaults,noatime,nodiratime /dev/disk/by-label/"$EFI_LABEL" "$MOUNTPOINT/boot/efi"

########################################
# BASE SYSTEM INSTALL
########################################

dnf --installroot=$MOUNTPOINT \
    --releasever=${FEDORA_VER} \
    --setopt=install_weak_deps=False \
    --use-host-config \
    install @core -y

dnf --installroot=$MOUNTPOINT \
    --releasever=${FEDORA_VER} \
    --setopt=install_weak_deps=False \
    install \
    kernel \
    kernel-core \
    kernel-modules \
    grub2-efi-x64 \
    grub2-efi-x64-modules \
    shim \
    efibootmgr \
    NetworkManager \
    selinux-policy-targeted \
    zram-generator-defaults \
    firewalld \
    fail2ban \
    snapper \
    openssh-server \
    neovim \
    cracklib \
    cracklib-dicts \
    glibc-langpack-en \
    -y

    # tlp \
    # acpid \

########################################
# PREP CHROOT
########################################

for i in dev dev/pts proc sys run; do
  mount --rbind /$i $MOUNTPOINT/$i
  mount --make-rslave $MOUNTPOINT/$i
done

mount -t efivarfs efivarfs  $MOUNTPOINT/sys/firmware/efi/efivars

udevadm trigger

########################################
# FSTAB
########################################

touch /mnt/etc/fstab
cat <<EOF >/mnt/etc/fstab
# <file system>           <dir>               <type>    <options>                               <dump> <pass>
### ROOTFS ###
# UUID="${ROOT_UUID}"     /                   btrfs     rw,$BTRFS_OPTS,subvol=@                	   0     0
LABEL="${ROOT_LABEL}"     /                   btrfs     rw,$BTRFS_OPTS,subvol=@                    0     0

# UUID="${ROOT_UUID}"     /.snapshots         btrfs     rw,$BTRFS_OPTS,subvol=@snapshots           0     0
LABEL="${ROOT_LABEL}"     /.snapshots         btrfs     rw,$BTRFS_OPTS,subvol=@snapshots           0     0

# UUID="${ROOT_UUID}"     /nix                btrfs     rw,$NIX_OPTS,subvol=@nix                   0     0
LABEL="${ROOT_LABEL}"     /nix                btrfs     rw,$NIX_OPTS,subvol=@nix                   0     0

# UUID="${ROOT_UUID}"     /var/log            btrfs     rw,$BTRFS_OPTS,subvol=@log                 0     0
LABEL="${ROOT_LABEL}"     /var/log            btrfs     rw,$BTRFS_OPTS,subvol=@log                 0     0

# UUID="${ROOT_UUID}"     /var/tmp            btrfs     rw,$BTRFS_OPTS2,subvol=@tmp                0     0
LABEL="${ROOT_LABEL}"     /var/tmp            btrfs     rw,$BTRFS_OPTS2,subvol=@tmp                0     0

# UUID="${ROOT_UUID}"     /var/spool          btrfs     rw,$BTRFS_OPTS,subvol=@spool               0     0
LABEL="${ROOT_LABEL}"     /var/spool          btrfs     rw,$BTRFS_OPTS,subvol=@spool               0     0

# UUID="${ROOT_UUID}"     /var/cache          btrfs     rw,$BTRFS_OPTS,subvol=@cache               0     0
LABEL="${ROOT_LABEL}"     /var/cache          btrfs     rw,$BTRFS_OPTS,subvol=@cache               0     0

# UUID="${ROOT_UUID}"     /var/lib/libvirt    btrfs     rw,$BTRFS_OPTS,subvol=@libvirt             0     0
LABEL="${ROOT_LABEL}"     /var/lib/libvirt    btrfs     rw,$BTRFS_OPTS,subvol=@libvirt             0     0

# UUID="${ROOT_UUID}"     /var/lib/gdm        btrfs     rw,$BTRFS_OPTS,subvol=@gdm                 0     0
LABEL="${ROOT_LABEL}"     /var/lib/gdm        btrfs     rw,$BTRFS_OPTS,subvol=@gdm                 0     0

# UUID="${ROOT_UUID}"     /opt                btrfs     rw,$BTRFS_OPTS,subvol=@opt                 0     0
LABEL="${ROOT_LABEL}"     /opt                btrfs     rw,$BTRFS_OPTS,subvol=@opt                 0     0

### HOME_FS ###
# UUID="${HOME_UUID}"     /home               btrfs     rw,$BTRFS_OPTS_HOME,subvol=@home           0     0
LABEL="${HOME_LABEL}"     /home               btrfs     rw,$BTRFS_OPTS_HOME,subvol=@home           0     0

### BOOT ###
# UUID="${BOOT_UUID}"     /boot               ext4      rw,relatime                                0     1
LABEL="${BOOT_LABEL}"     /boot               ext4      rw,relatime                                0     1

### EFI ###
# UUID="${EFI_UUID}"      /boot/efi           vfat      defaults,noatime,nodiratime,umask=0077     0     2
LABEL="${EFI_LABEL}"      /boot/efi           vfat      defaults,noatime,nodiratime,umask=0077     0     2

### Swap ###
# UUID="${SWAP_UUID}"     none                swap      defaults,noatime                           0     0
LABEL="${SWAP_LABEL}"     none                swap      defaults,noatime                           0     0

#Swapfile
# LABEL="${ROOT_LABEL}"   none                swap      defaults,noatime
# UUID="${ROOT_UUID}"     none                swap      defaults,noatime
# /swap/swapfile          none                swap      sw                                         0     0
EOF

########################################
# LOW RAM TUNING
########################################

mkdir -pv $MOUNTPOINT/etc/sysctl.d
touch $MOUNTPOINT/etc/sysctl.d/98-mba2gb.conf
cat <<EOF > $MOUNTPOINT/etc/sysctl.d/98-mba2gb.conf
# vm.swappiness=180
# vm.vfs_cache_pressure=250
# vm.dirty_ratio=4
# vm.dirty_background_ratio=2
# vm.page-cluster=0
# vm.compaction_proactiveness=0
# vm.extfrag_threshold=1000
# vm.min_free_kbytes=32768
# kernel.numa_balancing=0
# kernel.sched_autogroup_enabled=0
EOF

########################################
# RPM FUSION
########################################

chroot /mnt dnf install -y \
    https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$FEDORA_VER.noarch.rpm \
    https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$FEDORA_VER.noarch.rpm 

##########################################
# DRACUT
##########################################
mkdir -pv $MOUNTPOINT/etc/dracut.conf.d
touch $MOUNTPOINT/etc/dracut.conf.d/anubis.conf
cat <<EOF > $MOUNTPOINT/etc/dracut.conf.d/anubis.conf
hostonly="yes"
hostonly_cmdline="yes"

# Intel must initialize early (Wayland + Waydroid)
# force_drivers+=" i915 "

# Avoid useless modules
omit_dracutmodules+=" brltty "
EOF

####################
### Intel Driver ###
####################

# chroot /mnt dnf install intel-gpu-tools mesa-dri-drivers libva-intel-driver -y

########################################
# ZRAM
########################################

# mkdir -p /etc/systemd/zram-generator.conf.d
# cat <<EOF > /etc/systemd/zram-generator.conf.d/99-zram.conf
# [zram0]
# zram-size = ram * 2
# compression-algorithm = lz4
# swap-priority = 100
# EOF

# systemctl enable systemd-zram-setup@zram0

########################################
# GPU STABILITY (HD3000)
########################################

# echo "options i915 enable_psr=0" > /etc/modprobe.d/i915.conf

##########################################
# GRUB
###########################################

chroot /mnt grub2-install --target=x86_64-efi \
    --efi-directory=/boot/efi \
    --bootloader-id=fedora \
    --recheck --removable \
    --force

touch $MOUNTPOINT/etc/default/grub
cat <<EOF > $MOUNTPOINT/etc/default/grub
#
# Configuration file for GRUB.
#
GRUB_DEFAULT=saved
GRUB_TIMEOUT=5
#GRUB_HIDDEN_TIMEOUT=0
#GRUB_HIDDEN_TIMEOUT_QUIET=false
GRUB_DISABLE_SUBMENU=false
GRUB_DISTRIBUTOR="$$   (sed 's, release .*   $$,,g' /etc/system-release)"
# GRUB_CMDLINE_LINUX_DEFAULT="rhgb quiet loglevel=3 i915.enable_psr=0 zswap.enabled=1 zswap.compressor=lz4 mitigations=auto"
GRUB_CMDLINE_LINUX_DEFAULT="rhgb quiet loglevel=3 zswap.enabled=1 zswap.compressor=lz4 mitigations=auto"
# Uncomment to use basic console
#GRUB_TERMINAL_INPUT="console"
# Uncomment to disable graphical terminal
#GRUB_TERMINAL_OUTPUT=console
#GRUB_BACKGROUND=/usr/share/void-artwork/splash.png
GRUB_COLOR_NORMAL="light-blue/black"
GRUB_COLOR_HIGHLIGHT="light-cyan/blue"
GRUB_DISABLE_OS_PROBER=false
GRUB_ENABLE_BLSCFG=true
EOF

chroot /mnt grub2-mkconfig -o /boot/grub2/grub.cfg
chroot /mnt grub2-mkconfig -o /boot/efi/EFI/fedora/grub.cfg

########################################
# BLUETOOTH
########################################

# chroot /mnt dnf install -y bluez
# chroot /mnt systemctl enable bluetooth

########################################
# SNAPSHOT SYSTEM
########################################

chroot /mnt snapper --no-dbus -c root create-config /
chroot /mnt systemctl enable snapper-timeline.timer
chroot /mnt systemctl enable snapper-cleanup.timer

########################################
# SERVICES
########################################

chroot /mnt systemctl enable NetworkManager
chroot /mnt systemctl enable firewalld
chroot /mnt systemctl enable fail2ban
chroot /mnt systemctl enable sshd
# chroot /mnt systemctl enable tlp
# chroot /mnt systemctl enable acpid

########################################
# USER
########################################

echo "anubisvm" > $MOUNTPOINT/etc/hostname
chroot /mnt useradd ${username} -m -s /bin/bash
chroot /mnt echo "${username}:200291" | chpasswd
chroot /mnt usermod -aG wheel ${username}

chroot /mnt fixfiles -F onboot

chroot /mnt dnf reinstall kernel kernel-core kernel-modules -y
chroot /mnt dracut --force --regenerate-all

# GRUB 40_custom - Reboot and Shutdown entries
cat <<EOF > $MOUNTPOINT/etc/grub.d/40_custom
#!/bin/sh
exec tail -n +3 \$0
# This file provides an easy way to add custom menu entries. Simply type the
# menu entries you want to add after this comment.  Be careful not to change
# the 'exec tail' line above.

menuentry "Reboot" {
    reboot
}

menuentry "Shutdown" {
    halt
}
EOF

chroot /mnt chmod +x /etc/grub.d/40_custom
chroot /mnt grub2-mkconfig -o /boot/grub2/grub.cfg

chroot /mnt dnf install sddm -y
chroot /mnt systemctl enable sddm -y

