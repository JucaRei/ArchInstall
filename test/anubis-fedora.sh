#!/usr/bin/env bash
set -euo pipefail

# arch-install-scripts

########################################
# CONFIG
########################################

DRIVE="/dev/sda"
MNT="/mnt"
FEDORA_VER="43"

EFI_PART="${DRIVE}1"
BOOT_PART="${DRIVE}2"
ROOT_PART="${DRIVE}3"
SWAP_PART="${DRIVE}4"

ROOT_OPTS="noatime,ssd,compress=zstd:3,space_cache=v2,commit=120"
HOME_OPTS="$ROOT_OPTS"

########################################
# PARTITIONING
########################################

sgdisk --zap-all "$DRIVE"

sgdisk -n 1:0:+500M -t 1:ef00 -c 1:"EFI SYSTEM" "$DRIVE"
sgdisk -n 2:0:+1G   -t 2:8300 -c 2:"BOOT" "$DRIVE"
sgdisk -n 3:0:-5G   -t 3:8300 -c 3:"LINUX ROOT" "$DRIVE"
sgdisk -n 4:0:0     -t 4:8200 -c 4:"SWAP" "$DRIVE"

########################################
# FORMAT
########################################

mkfs.fat -F32 -n EFI "$EFI_PART"
mkfs.ext4 -L BOOT "$BOOT_PART"
mkfs.btrfs -f -L FEDORA "$ROOT_PART"
mkswap -L SWAP "$SWAP_PART"

########################################
# SUBVOLUMES
########################################

mount "$ROOT_PART" "$MNT"

btrfs subvolume create "$MNT/@"
btrfs subvolume create "$MNT/@home"
btrfs subvolume create "$MNT/@var_log"
btrfs subvolume create "$MNT/@var_cache"
btrfs subvolume create "$MNT/@snapshots"

umount "$MNT"

########################################
# MOUNT STRUCTURE
########################################

mount -o ${ROOT_OPTS},subvol=@ "$ROOT_PART" "$MNT"

mkdir -p "$MNT"/{boot,home,var/log,var/cache,.snapshots}

mount "$BOOT_PART" "$MNT/boot"
mkdir -p "$MNT/boot/efi"
mount "$EFI_PART" "$MNT/boot/efi"

mount -o ${HOME_OPTS},subvol=@home "$ROOT_PART" "$MNT/home"
mount -o noatime,ssd,compress=none,subvol=@var_log "$ROOT_PART" "$MNT/var/log"
mount -o noatime,ssd,compress=none,subvol=@var_cache "$ROOT_PART" "$MNT/var/cache"
mount -o ${ROOT_OPTS},subvol=@snapshots "$ROOT_PART" "$MNT/.snapshots"

swapon "$SWAP_PART"

########################################
# UUID
########################################

EFI_UUID=$(blkid -s UUID -o value $EFI_PART)
BOOT_UUID=$(blkid -s UUID -o value $BOOT_PART)
ROOT_UUID=$(blkid -s UUID -o value $ROOT_PART)
SWAP_UUID=$(blkid -s UUID -o value $SWAP_PART)

########################################
# BASE SYSTEM INSTALL
########################################

dnf --installroot=$MNT \
    --releasever=${FEDORA_VER} \
    --setopt=install_weak_deps=False \
    --use-host-config \
    install @core -y

dnf --installroot=$MNT \
    --releasever=${FEDORA_VER} \
    --setopt=install_weak_deps=False \
    install \
    kernel \
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
    tlp \
    acpid \
    openssh-server \
    neovim \
    -y

########################################
# PREP CHROOT
########################################

for i in dev dev/pts proc sys run; do
  mount --rbind /$i $MNT/$i
  mount --make-rslave $MNT/$i
  mount -t efivarfs efivarfs  $MNT/sys/firmware/efi/efivars
done

udevadm trigger

chroot "$MNT" /bin/bash <<CHROOT

########################################
# FSTAB
########################################

cat <<EOF > /etc/fstab
UUID=$EFI_UUID   /boot/efi  vfat   umask=0077  0 2
UUID=$BOOT_UUID  /boot      ext4   defaults    0 2
UUID=$ROOT_UUID  /          btrfs  ${ROOT_OPTS},subvol=@  0 0
UUID=$ROOT_UUID  /home      btrfs  ${HOME_OPTS},subvol=@home  0 0
UUID=$ROOT_UUID  /var/log   btrfs  noatime,ssd,compress=none,subvol=@var_log  0 0
UUID=$ROOT_UUID  /var/cache btrfs  noatime,ssd,compress=none,subvol=@var_cache  0 0
UUID=$ROOT_UUID  /.snapshots btrfs ${ROOT_OPTS},subvol=@snapshots  0 0
UUID=$SWAP_UUID  none       swap   defaults    0 0
EOF

########################################
# RPM FUSION (Broadcom WiFi)
########################################

dnf install -y \
 https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-43.noarch.rpm \
 https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-43.noarch.rpm

dnf install -y broadcom-wl akmod-wl
echo "blacklist b43" > /etc/modprobe.d/blacklist-b43.conf

########################################
# BLUETOOTH
########################################

dnf install -y bluez
systemctl enable bluetooth

########################################
# LOW RAM TUNING
########################################

cat <<EOF > /etc/sysctl.d/98-mba2gb.conf
vm.swappiness=180
vm.vfs_cache_pressure=250
vm.dirty_ratio=4
vm.dirty_background_ratio=2
vm.page-cluster=0
vm.compaction_proactiveness=0
vm.extfrag_threshold=1000
vm.min_free_kbytes=32768
kernel.numa_balancing=0
kernel.sched_autogroup_enabled=0
EOF

########################################
# ZRAM
########################################

mkdir -p /etc/systemd/zram-generator.conf.d
cat <<EOF > /etc/systemd/zram-generator.conf.d/99-zram.conf
[zram0]
zram-size = ram * 2
compression-algorithm = lz4
swap-priority = 100
EOF

systemctl enable systemd-zram-setup@zram0

########################################
# GPU STABILITY (HD3000)
########################################

echo "options i915 enable_psr=0" > /etc/modprobe.d/i915.conf

########################################
# GRUB
########################################

cat <<EOF > /etc/default/grub
GRUB_TIMEOUT=5
GRUB_DISABLE_SUBMENU=true
GRUB_TERMINAL_OUTPUT="console"
GRUB_CMDLINE_LINUX="quiet loglevel=3 i915.enable_psr=0 zswap.enabled=1 zswap.compressor=lz4 mitigations=auto"
GRUB_ENABLE_BLSCFG=true
EOF

grub2-install --target=x86_64-efi \
  --efi-directory=/boot/efi \
  --bootloader-id=fedora \
  --recheck --removable \
  --force


grub2-mkconfig -o /boot/grub2/grub.cfg
dracut --force --regenerate-all

########################################
# SNAPSHOT SYSTEM
########################################

snapper --no-dbus -c root create-config /
systemctl enable snapper-timeline.timer
systemctl enable snapper-cleanup.timer

########################################
# SERVICES
########################################

systemctl enable NetworkManager
systemctl enable firewalld
systemctl enable fail2ban
systemctl enable sshd
systemctl enable tlp
systemctl enable acpid

########################################
# USER
########################################

echo "anubis" > /etc/hostname
useradd juca -m -s /bin/bash
echo "juca:200291" | chpasswd
usermod -aG wheel juca

fixfiles -F onboot
dracut --force --regenerate-all

CHROOT

echo "✅ Fedora 43 installed for MacBook Air 4,1 (2GB RAM)"
echo "⚠ First boot will relabel SELinux."

#########
## KDE ##
#########

chroot /mnt dnf install -y plasma-desktop kde-settings sddm --exclude=vlc* 
