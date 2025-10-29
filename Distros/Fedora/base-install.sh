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
DRIVE="/dev/nvme0n1"
SYSTEM_PART="${DRIVE}p2"
EFI_PART="${DRIVE}p3"
ROOT_PART="${DRIVE}p4"
HOME_PART="${DRIVE}p5"
WINDOWS_PART="${DRIVE}p7"
MISC_PART="${DRIVE}p8"

# 🔖 Labels
ROOT_LABEL="Fedora"
HOME_LABEL="Workspace"
SWAP_LABEL="SWAP"
SYSTEM_LABEL="BOOT"
EFI_LABEL="ESP"
WINDOWS_LABEL="Windows_11"
MISC_LABEL="SharedData"

# ⚙️ Btrfs options
BTRFS_OPTS="noatime,nodatasum,nodatacow,ssd,compress-force=zstd:8,space_cache=v2,nodatacow,commit=120,discard=async"
BTRFS_OPTS_HOME="noatime,nodatasum,nodatacow,ssd,compress-force=zstd:15,space_cache=v2,nodatacow,commit=120,discard=async"

# 📁 Mount point
MOUNTPOINT="/mnt"

echo "🧼 Formatting partitions..."
# mkfs.ext4  -F   -L "$SYSTEM_LABEL"  "$SYSTEM_PART"
# mkfs.fat   -F32 -n "$EFI_LABEL"     "$EFI_PART"
mkfs.btrfs -f   -L "$ROOT_LABEL"    "$ROOT_PART"
mkfs.btrfs -f   -L "$HOME_LABEL"    "$HOME_PART"
# mkfs.ntfs  -F   -L "$WINDOWS_LABEL" "$WINDOWS_PART"
# mkfs.exfat      -n "$MISC_LABEL"    "$MISC_PART"

# 🎯 Create Btrfs subvolumes on root partition
mount "$ROOT_PART" "$MOUNTPOINT"
for sv in @root @cache @opt @nix @gdm @libvirt @spool @log @tmp @snapshots; do
  btrfs subvolume create "$MOUNTPOINT/$sv"
done
umount -Rv "$MOUNTPOINT"

# 🏠 Create @home subvolume on home partition
mkdir -p $MOUNTPOINT/home-temp
mount "$HOME_PART" $MOUNTPOINT/home-temp
btrfs subvolume create $MOUNTPOINT/home-temp/@home
umount $MOUNTPOINT/home-temp

echo "📦 Mounting subvolumes..."
mount -o $BTRFS_OPTS,subvol=@root /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT
mkdir -pv $MOUNTPOINT/{boot,home,opt,nix,.snapshots,var/{tmp,spool,log,cache,lib/{gdm,libvirt}}}

mount -o $BTRFS_OPTS_HOME,subvol=@home      /dev/disk/by-label/$HOME_LABEL $MOUNTPOINT/home
mount -o $BTRFS_OPTS,subvol=@opt            /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/opt
mount -o $BTRFS_OPTS,subvol=@gdm            /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/var/lib/gdm
mount -o $BTRFS_OPTS,subvol=@libvirt        /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/var/lib/libvirt
mount -o $BTRFS_OPTS,subvol=@log            /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/var/log
mount -o $BTRFS_OPTS,subvol=@nix            /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/nix
mount -o $BTRFS_OPTS,subvol=@spool          /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/var/spool
mount -o $BTRFS_OPTS,subvol=@tmp            /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/var/tmp
mount -o $BTRFS_OPTS,subvol=@cache          /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/var/cache
mount -o $BTRFS_OPTS,subvol=@snapshots      /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/.snapshots

echo "⏏️ Mounting boot and EFI..."
mount /dev/disk/by-label/$SYSTEM_LABEL $MOUNTPOINT/boot
mkdir -pv $MOUNTPOINT/boot/efi
mount -t vfat -o defaults,noatime,nodiratime /dev/disk/by-label/$EFI_LABEL $MOUNTPOINT/boot/efi

echo "🔧 Mounting system filesystems..."
udevadm trigger
mkdir -p $MOUNTPOINT/{proc,sys,dev/pts}
mount -t proc   proc     $MOUNTPOINT/proc
mount -t sysfs  sysfs    $MOUNTPOINT/sys
mount --rbind   /dev     $MOUNTPOINT/dev
mount -t devpts devpts   $MOUNTPOINT/dev/pts

export VERSION_ID="43"
export ARCH="x86_64"

echo "📦 Installing Fedora base system (dnf5)..."
dnf5 --installroot=$MOUNTPOINT --forcearch=$ARCH --releasever=$VERSION_ID --setopt=fastestmirror=True group install "core" system-release --use-host-config -y --skip-unavailable
# dnf5 --installroot=$MOUNTPOINT install -y glibc-langpack-en --use-host-config
dnf5 --installroot=$MOUNTPOINT install -y glibc-langpack-en

echo "🌐 Setting up DNS config..."
# cp /etc/resolv.conf $MOUNTPOINT/etc/resolv.conf.orig
# cp -L /etc/resolv.conf $MOUNTPOINT/etc/resolv.conf
cp /etc/resolv.conf $MOUNTPOINT/etc/resolv.conf
echo "nameserver 1.1.1.1" > /mnt/etc/resolv.conf
chroot /mnt dnf --releasever=43 distro-sync


echo "📑 Generating /etc/fstab..."
# genfstab -U $MOUNTPOINT >> $MOUNTPOINT/etc/fstab
# sed -i 's/rw,/rw,compress-force=zstd:15,/' $MOUNTPOINT/etc/fstab

BOOT_UUID=$(blkid -s UUID -o value $SYSTEM_PART)
ESP_UUID=$(blkid -s UUID -o value $EFI_PART)
ROOT_UUID=$(blkid -s UUID -o value $ROOT_PART)
HOME_UUID=$(blkid -s UUID -o value $HOME_PART)
# SWAP_UUID=$(blkid -s UUID -o value $SWAP_PARTITION)

cat << EOF > /mnt/etc/fstab
# <file system> <dir> <type> <options> <dump> <pass>

### ROOTFS ###
# UUID="${ROOT_UUID}"     /                   btrfs rw,$BTRFS_OPTS,subvol=@root                   0 0
LABEL="${ROOT_LABEL}"     /                   btrfs rw,$BTRFS_OPTS,subvol=@root                   0 0

# UUID="${ROOT_UUID}"     /.snapshots         btrfs rw,$BTRFS_OPTS,subvol=@snapshots              0 0
LABEL="${ROOT_LABEL}"     /.snapshots         btrfs rw,$BTRFS_OPTS,subvol=@snapshots              0 0

# UUID="${ROOT_UUID}"     /var/log            btrfs rw,$BTRFS_OPTS,subvol=@log                    0 0
LABEL="${ROOT_LABEL}"     /var/log            btrfs rw,$BTRFS_OPTS,subvol=@log                    0 0

# UUID="${ROOT_UUID}"     /var/tmp            btrfs rw,$BTRFS_OPTS,subvol=@tmp                    0 0
LABEL="${ROOT_LABEL}"     /var/tmp            btrfs rw,$BTRFS_OPTS,subvol=@tmp                    0 0

# UUID="${ROOT_UUID}"     /var/spool          btrfs rw,$BTRFS_OPTS,subvol=@spool                  0 0
LABEL="${ROOT_LABEL}"     /var/spool          btrfs rw,$BTRFS_OPTS,subvol=@spool                  0 0

# UUID="${ROOT_UUID}"     /var/cache          btrfs rw,$BTRFS_OPTS,subvol=@cache                  0 0
LABEL="${ROOT_LABEL}"     /var/cache          btrfs rw,$BTRFS_OPTS,subvol=@cache                  0 0

# UUID="${ROOT_UUID}"     /var/lib/libvirt    btrfs rw,$BTRFS_OPTS,subvol=@libvirt                0 0
LABEL="${ROOT_LABEL}"     /var/lib/libvirt    btrfs rw,$BTRFS_OPTS,subvol=@libvirt                0 0

# UUID="${ROOT_UUID}"     /var/lib/gdm        btrfs rw,$BTRFS_OPTS,subvol=@gdm                    0 0
LABEL="${ROOT_LABEL}"     /var/lib/gdm        btrfs rw,$BTRFS_OPTS,subvol=@gdm                    0 0

# UUID="${ROOT_UUID}"     /opt                btrfs rw,$BTRFS_OPTS,subvol=@opt                    0 0
LABEL="${ROOT_LABEL}"     /opt                btrfs rw,$BTRFS_OPTS,subvol=@opt                    0 0

# UUID="${ROOT_UUID}"     /nix                btrfs rw,$BTRFS_OPTS,subvol=@nix                    0 0
LABEL="${ROOT_LABEL}"     /nix                btrfs rw,$BTRFS_OPTS,subvol=@nix                    0 0

### HOME_FS ###
# UUID="${HOME_UUID}"     /home               btrfs rw,$BTRFS_OPTS_HOME,subvol=@home              0 0
LABEL="${HOME_LABEL}"     /home               btrfs rw,$BTRFS_OPTS_HOME,subvol=@home              0 0

### BOOT ###
# UUID="${BOOT_UUID}"     /boot               ext4 rw,relatime                                    0 1
LABEL="${SYSTEM_LABEL}"   /boot               ext4 rw,relatime                                    0 1

### EFI ###
# UUID="${ESP_UUID}"     /boot/efi           vfat defaults,noatime,nodiratime                     0 2
LABEL="${EFI_LABEL}"      /boot/efi           vfat defaults,noatime,nodiratime                    0 2

### Swap ###
# UUID="${SWAP_UUID}"     none                swap defaults,noatime                               0 0
# LABEL="${SWAP_LABEL}"   none                swap defaults,noatime                               0 0

#Swapfile
# LABEL="${ROOT_UUID}"    none                swap defaults,noatime
# /swap/swapfile          none                swap sw                                             0 0

EOF

echo "✅ Setup complete. Ready for chroot: chroot $MOUNTPOINT"

# Log in system
# chroot /mnt /bin/bash

# mount efi
chroot /mnt mount -t efivarfs efivarfs /sys/firmware/efi/efivars

# Re-enable sys enhanciment
# fixfiles -F onboot
chroot /mnt fixfiles -F onboot

chroot /mnt dnf install -y btrfs-progs efi-filesystem efibootmgr grub2-common grub2-efi-ia32 grub2-efi-x64 grub2-pc grub2-pc-modules grub2-tools grub2-tools-efi grub2-tools-extra grub2-tools-minimal grubby kernel mokutil shim-ia32 shim-x64 --allowerasing
rm -f /mnt/boot/efi/EFI/fedora/grub.cfg
rm -f /mnt/boot/grub2/grub.cfg
chroot /mnt dnf reinstall -y shim-* grub2-efi-* grub2-common


cat <<EOF >/mnt/etc/default/grub
GRUB_TIMEOUT=5
#GRUB_HIDDEN_TIMEOUT_QUIET=false
GRUB_DISTRIBUTOR="$(sed 's, release .*$,,g' /etc/system-release)"
GRUB_DEFAULT=saved
GRUB_DISABLE_SUBMENU=true
GRUB_TERMINAL_OUTPUT="console"
# splash
GRUB_CMDLINE_LINUX="rhgb quiet usbcore.autosuspend=-1 kernel.unprivileged_userns_clone vt.global_cursor_default=0 loglevel=0 gpt init_on_alloc=0 udev.log_level=0 rcutree.rcu_idle_gp_delay=1 zswap.enabled=1 zswap.compressor=lz4hc zswap.max_pool_percent=20 zswap.zpool=z3fold mitigations=off nowatchdog msr.allow_writes=on pcie_aspm=force module.sig_unenforce intel_idle.max_cstate=1 cryptomgr.notests initcall_debug no_timer_check noreplace-smp page_alloc.shuffle=1 rcupdate.rcu_expedited=1 tsc=reliable "
GRUB_DISABLE_RECOVERY="true"
GRUB_GFXMODE=1920x1080x32
GRUB_COLOR_NORMAL="light-blue/black"
GRUB_COLOR_HIGHLIGHT="light-cyan/blue"
GRUB_DISABLE_OS_PROBER=false
GRUB_ENABLE_BLSCFG=true
EOF

chroot /mnt efibootmgr -c -d /dev/disk/by-label/BOOT -p 1 -L "Fedora (Custom)" -l \\EFI\\FEDORA\\SHIMX64.EFI
chroot /mnt grub2-mkconfig -o /boot/grub2/grub.cfg

rm -f /mnt/etc/localtime
chroot /mnt sh -c 'echo "root:200291" | chpasswd -c SHA512'

chroot /mnt useradd juca -m -c "Reinaldo P JR" -s /bin/bash
chroot /mnt sh -c 'echo "juca:200291" | chpasswd -c SHA512'

chroot /mnt usermod -aG wheel juca

chroot /mnt dnf install openssh-server -y
chroot /mnt firewall-cmd --permanent --add-service=ssh
chroot /mnt firewall-cmd --reload

chroot /mnt systemctl enable sshd

# sudo setenforce 0

# umount -n -R /mnt
