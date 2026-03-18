#!/usr/bin/env bash
set -euo pipefail

dnf install gdisk arch-install-scripts -y

########################################
# CONFIG
########################################

DRIVE="/dev/vda"
MNT="/mnt"
FEDORA_VER="43"

EFI_PART="${DRIVE}1"
BOOT_PART="${DRIVE}2"
ROOT_PART="${DRIVE}3"

ROOT_OPTS="noatime,ssd,compress=zstd:15,space_cache=v2,commit=120"
HOME_OPTS="$ROOT_OPTS"

########################################
# PARTITIONING
########################################

sgdisk --zap-all "$DRIVE"

sgdisk -n 1:0:+500M -t 1:ef00 -c 1:"EFI SYSTEM" "$DRIVE"
sgdisk -n 2:0:+1G   -t 2:8300 -c 2:"BOOT" "$DRIVE"
sgdisk -n 3:0:0   -t 3:8300 -c 3:"LINUX ROOT" "$DRIVE"

########################################
# FORMAT
########################################

mkfs.fat -F32 -n EFI "$EFI_PART"
mkfs.ext4 -L BOOT "$BOOT_PART"
mkfs.btrfs -f -L FEDORA "$ROOT_PART"

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

########################################
# UUID
########################################

EFI_UUID=$(blkid -s UUID -o value $EFI_PART)
BOOT_UUID=$(blkid -s UUID -o value $BOOT_PART)
ROOT_UUID=$(blkid -s UUID -o value $ROOT_PART)

########################################
# PREP CHROOT
########################################

udevadm trigger
export MNT=/mnt

mkdir -p $MNT/dev $MNT/dev/pts $MNT/proc $MNT/sys $MNT/run $MNT/sys/firmware/efi/efivars

for i in dev dev/pts proc sys run; do
    mount --rbind /$i $MNT/$i
    mount --make-rslave $MNT/$i
done

mount -t efivarfs efivarfs $MNT/sys/firmware/efi/efivars

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
    openssh-server \
    neovim \
    btrfs-progs \
    tar \
    rsync \
    curl \ 
    -y

########################################
# FSTAB
########################################

cat <<EOF > $MNT/etc/fstab
UUID=$EFI_UUID   /boot/efi  vfat   umask=0077  0 2
UUID=$BOOT_UUID  /boot      ext4   defaults    0 2
UUID=$ROOT_UUID  /          btrfs  ${ROOT_OPTS},subvol=@  0 0
UUID=$ROOT_UUID  /home      btrfs  ${HOME_OPTS},subvol=@home  0 0
UUID=$ROOT_UUID  /var/log   btrfs  noatime,ssd,compress=none,subvol=@var_log  0 0
UUID=$ROOT_UUID  /var/cache btrfs  noatime,ssd,compress=none,subvol=@var_cache  0 0
UUID=$ROOT_UUID  /.snapshots btrfs ${ROOT_OPTS},subvol=@snapshots  0 0
EOF

########################################
# RPM FUSION (Broadcom WiFi)
########################################

chroot $MNT dnf install -y \
 https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-43.noarch.rpm \
 https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-43.noarch.rpm

########################################
# ZRAM
########################################

mkdir -p $MNT/etc/systemd/zram-generator.conf.d
touch $MNT/etc/systemd/zram-generator.conf.d/99-zram.conf
cat <<EOF > $MNT/etc/systemd/zram-generator.conf.d/99-zram.conf
[zram0]
zram-size = ram * 2
compression-algorithm = lz4
swap-priority = 100
EOF

chroot $MNT systemctl enable systemd-zram-setup@zram0


########################################
# GRUB
########################################

touch $MNT/etc/default/grub
cat <<EOF > $MNT/etc/default/grub
GRUB_TIMEOUT=5
#GRUB_HIDDEN_TIMEOUT_QUIET=false
GRUB_DISTRIBUTOR="$(sed 's, release .*$,,g' /etc/system-release)"
GRUB_DEFAULT=saved
GRUB_DISABLE_SUBMENU=true
GRUB_TERMINAL_OUTPUT="console"
# splash
GRUB_CMDLINE_LINUX="rhgb quiet loglevel=3 "
GRUB_DISABLE_RECOVERY="true"
GRUB_COLOR_NORMAL="light-blue/black"
GRUB_COLOR_HIGHLIGHT="light-cyan/blue"
GRUB_DISABLE_OS_PROBER=false
GRUB_ENABLE_BLSCFG=true
EOF

chroot $MNT grub2-install --target=x86_64-efi \
  --efi-directory=/boot/efi \
  --bootloader-id=fedora \
  --recheck --removable \
  --force


chroot $MNT grub2-mkconfig -o /boot/grub2/grub.cfg
chroot $MNT dracut --force --regenerate-all

########################################
# SERVICES
########################################

systemctl enable NetworkManager
systemctl enable firewalld
systemctl enable sshd

########################################
# USER
########################################

echo "fedora" > $MNT/etc/hostname
chroot $MNT useradd juca -m -c "Reinaldo" -s /bin/bash
chroot /mnt sh -c 'echo "juca:200291" | chpasswd -c SHA512'
chroot $MNT usermod -aG wheel juca

chroot $MNT fixfiles -F onboot
chroot $MNT dracut --force --regenerate-all
chroot $MNT grub2-mkconfig -o /boot/grub2/grub.cfg

########################################################
# BSPWM

# dnf install lightdm lightdm-gtk-greeter -y
# sudo systemctl enable lightdm --now

# On lightdm.conf, set:
# [Seat:*]
# session=bspwm
# greeter-session=lightdm-gtk-greeter

# Create on /usr/share/xsessions/bspwm.desktop:
# [Desktop Entry]
# Name=BSPWM
# Comment=Binary Space Partition Window Manager
# Exec=/home/juca/.xsession
# Type=Application

# sudo chmod 644 /usr/share/xsessions/bspwm.desktop

# curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | \
#   sh -s -- install --no-confirm

# . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh