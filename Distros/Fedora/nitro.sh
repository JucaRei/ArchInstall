#!/usr/bin/env bash

### Support boot encryption during installation
sed -i.bkp 's/encryption_support = False/encryption_support = True/' \
    /usr/lib64/python3.*/site-packages/pyanaconda/modules/storage/bootloader/base.py

dnf install -y gdisk arch-install-scripts exfatprogs ntfs-3g

# Variables
DRIVE="/dev/nvme0n1"
#DRIVE="/dev/vda"
SYSTEM_PART="${DRIVE}p2"
EFI_PART="${DRIVE}p3"
ROOT_PART="${DRIVE}p4"
HOME_PART="${DRIVE}p5"
WINDOWS_PART="${DRIVE}p7"
MISC_PART="${DRIVE}p8"

# MAPPER_NAME="secure_btrfs"
MOUNTPOINT="/mnt"
ROOT_LABEL="Fedora"
HOME_LABEL="HOME"
SWAP_LABEL="SWAP" 
EFI_LABEL="ESP"
SYSTEM_LABEL="BOOT"
Windows_LABEL="Windows 11"
MISC_LABEL="SharedData"
BTRFS_OPTS="noatime,ssd,compress-force=zstd:8,space_cache=v2,nodatacow,commit=120,discard=async"
BTRFS_OPTS_HOME="noatime,ssd,compress-force=zstd:15,space_cache=v2,nodatacow,commit=120,discard=async"

echo "Disable SELinux temporarily..."
setenforce 0 # disable SELInux for now

# Create Partitions and Encrypt
### Partition
echo "Creating partitions on $DRIVE..."
sgdisk --zap-all $DRIVE
parted -s -a optimal $DRIVE mklabel gpt
sgdisk -n 0:0:+1M      -t 1:EF02 -c 1:"BIOS BOOT"           $DRIVE
sgdisk -n 0:0:+1G      -t 2:8301 -c 2:"SYSTEM RESERVED"     $DRIVE
sgdisk -n 0:0:+600M    -t 3:EF00 -c 3:"EFI SYSTEM"          $DRIVE
sgdisk -n 0:0:+50G     -t 4:8300 -c 4:"Fedora root"         $DRIVE
sgdisk -n 0:0:+50G     -t 5:8302 -c 5:"Fedora home"         $DRIVE
sgdisk -n 0:0:+16M     -t 6:0C01 -c 6:"Microsoft Reserved"  $DRIVE
sgdisk -n 0:0:+100G    -t 7:0700 -c 7:"Windows data"        $DRIVE
sgdisk -n 0:0:0        -t 8:0700 -c 8:"Misc data"           $DRIVE
sgdisk -p $DRIVE

# === ENCRYPT PARTITION ===
# echo "Encrypting $DRIVE with LUKS2..."
# cryptsetup luksFormat --type luks2 "$DRIVE" # rei20021
# cryptsetup open "$DRIVE" "$MAPPER_NAME"

echo "Formatting partitions on $DRIVE..."
echo "🧼 Formatting partitions..."
#mkfs.ext4  -f   -L      $SYSTEM_LABEL      $SYSTEM_PART
mkfs.ext4   -L      	  "$SYSTEM_LABEL"      "$SYSTEM_PART"
mkfs.fat   -F32 -n      "$EFI_LABEL"         "$EFI_PART"
mkfs.btrfs -f   -L      "$ROOT_LABEL"        "$ROOT_PART"
mkfs.btrfs -f   -L      "$HOME_LABEL"        "$HOME_PART"
mkfs.ntfs  -Q   -f -L   "$WINDOWS_LABEL"     "$WINDOWS_PART"
mkfs.exfat      -n      "$MISC_LABEL"        "$MISC_PART"

echo "Partitions formatted successfully on $DRIVE."


echo "Creating Btrfs subvolumes..."
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
echo "Btrfs subvolumes created successfully."

echo "Mounting subvolumes and boot partition..."
### Mount subvolumes
mount -o $BTRFS_OPTS,subvol=@root /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT
mkdir -pv $MOUNTPOINT/{boot,home,opt,.snapshots,var/{tmp,spool,log,cache,lib/{libvirt,gdm}}}

mount -o $BTRFS_OPTS_HOME,subvol=@home /dev/disk/by-label/$HOME_LABEL $MOUNTPOINT/home
mount -o $BTRFS_OPTS,subvol=@opt /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/opt
mount -o $BTRFS_OPTS,subvol=@gdm /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/var/lib/gdm
mount -o $BTRFS_OPTS,subvol=@libvirt /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/var/lib/libvirt
mount -o $BTRFS_OPTS,subvol=@log /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/var/log
mount -o $BTRFS_OPTS,subvol=@spool /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/var/spool
mount -o $BTRFS_OPTS,subvol=@tmp /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/var/tmp
# mount -o $BTRFS_OPTS,subvol=@cache /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/var/cache
mount -o $BTRFS_OPTS,subvol=@cache /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/var/cache
mount -o $BTRFS_OPTS,subvol=@snapshots /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/.snapshots
mount /dev/disk/by-label/$SYSTEM_LABEL $MOUNTPOINT/boot
# mount /dev/disk/by-label/BOOT /mnt/boot
mkdir -pv $MOUNTPOINT/boot/efi
mount -t vfat -o defaults,noatime,nodiratime /dev/disk/by-label/$EFI_LABEL $MOUNTPOINT/boot/efi
echo "Subvolumes and boot partition mounted successfully."

### Mount sudo fs
echo "🔧 Mounting system filesystems..."
udevadm trigger
#mkdir -p $MOUNTPOINT/{proc,sys,dev/pts}
#mount -t proc   proc     $MOUNTPOINT/proc
#mount -t sysfs  sysfs    $MOUNTPOINT/sys
#mount --rbind   /dev     $MOUNTPOINT/dev
#mount -t devpts devpts   $MOUNTPOINT/dev/pts

for dir in dev proc sys run; do
    sudo mkdir -pv /mnt/$dir
    sudo mount --bind /$dir /mnt/$dir
done


source /etc/os-release
export VERSION_ID="$VERSION_ID"
# env | grep -i version

mkdir -pv /mnt/etc
touch /mnt/etc/fstab
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

### HOME_FS ###
# UUID="${HOME_UUID}"     /home               btrfs rw,$BTRFS_OPTS_HOME,subvol=@home              0 0
LABEL="${HOME_LABEL}"     /home               btrfs rw,$BTRFS_OPTS_HOME,subvol=@home              0 0

### BOOT ###
# UUID="${BOOT_UUID}"     /boot               ext4 rw,relatime                                    0 2
LABEL="${SYSTEM_LABEL}"   /boot               ext4 rw,relatime                                    0 2

### EFI ###
# UUID="${ESP_UUID}"     /boot/efi           vfat defaults,noatime,nodiratime                     0 2
LABEL="${EFI_LABEL}"      /boot/efi           vfat defaults,noatime,nodiratime                    0 2

### Swap ###
# UUID="${SWAP_UUID}"     none                swap defaults,noatime                               0 0
# LABEL="${SWAP_LABEL}"   none                swap defaults,noatime                               0 0

#Swapfile
# LABEL="${ROOT_UUID}"    none                swap defaults,noatime
# /swap/swapfile          none                swap sw                                             0 0

### Tmp ###
# tmpfs                   /tmp                tmpfs defaults,nosuid,nodev,noatime                 0 0
tmpfs                     /tmp                tmpfs noatime,mode=1777,nosuid,nodev                0 0
EOF

### Install core system
# dnf --installroot=/mnt --releasever=$VERSION_ID groupinstall -y core --use-host-config
dnf5 --installroot=/mnt --releasever=$VERSION_ID group install core --use-host-config -y
#dnf5 --installroot=/mnt --releasever=$VERSION_ID group install system-release coreutils bash --use-host-config -y
#dnf5 --installroot=/mnt --releasever=41 group install base --nogpgcheck
# dnf5 --installroot=/mnt --releasever=42 install system-release coreutils bash --use-host-config -y
# dnf --releasever=42 --installroot=/mnt core -y

# Lang pack
# dnf5 --installroot=/mnt install -y glibc-langpack-en
dnf5 --installroot=/mnt install -y glibc-langpack-en --use-host-config -y

# Get live iso resolv conf
# cp /mnt/etc/resolv.conf /mnt/etc/resolv.conf.orig
cp /etc/resolv.conf /mnt/etc/resolv.conf.orig
cp -L /etc/resolv.conf /mnt/etc

# FSTAB
# dnf install -y arch-install-scripts
# genfstab -U /mnt >> /mnt/etc/fstab

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
#rm -f /mnt/boot/efi/EFI/fedora/grub.cfg
rm -f /boot/efi/EFI/fedora/grub.cfg
#rm -f /mnt/boot/grub2/grub.cfg
rm -f /boot/grub2/grub.cfg
chroot /mnt dnf reinstall -y shim-* grub2-efi-* grub2-common

#cat <<EOF >/mnt/etc/default/grub
cat <<EOF >/etc/default/grub
GRUB_TIMEOUT=5
#GRUB_HIDDEN_TIMEOUT_QUIET=false
GRUB_DISTRIBUTOR="$(sed 's, release .*$,,g' /etc/system-release)"
GRUB_DEFAULT=saved
GRUB_DISABLE_SUBMENU=true
GRUB_TERMINAL_OUTPUT="console"
# splash
GRUB_CMDLINE_LINUX="rhgb quiet usbcore.autosuspend=-1 kernel.unprivileged_userns_clone vt.global_cursor_default=0 loglevel=0 gpt init_on_alloc=0 udev.log_level=0 rd.driver.blacklist=grub.nouveau rcutree.rcu_idle_gp_delay=1 intel_iommu=on,igfx_off nvidia-drm.modeset=1 i915.enable_psr=0 i915.modeset=1 zswap.enabled=1 zswap.compressor=lz4hc zswap.max_pool_percent=10 zswap.zpool=z3fold mitigations=off nowatchdog msr.allow_writes=on pcie_aspm=force module.sig_unenforce intel_idle.max_cstate=1 cryptomgr.notests initcall_debug no_timer_check noreplace-smp page_alloc.shuffle=1 rcupdate.rcu_expedited=1 tsc=reliable "
GRUB_DISABLE_RECOVERY="true"
GRUB_GFXMODE=1920x1080x32
GRUB_COLOR_NORMAL="light-blue/black"
GRUB_COLOR_HIGHLIGHT="light-cyan/blue"
GRUB_DISABLE_OS_PROBER=false
GRUB_ENABLE_BLSCFG=true
EOF

#chroot /mnt efibootmgr -c -d /dev/disk/by-label/$SYSTEM_LABEL -p 1 -L "Fedora (Custom)" -l \\EFI\\FEDORA\\SHIMX64.EFI
efibootmgr -c -d /dev/disk/by-label/BOOT -p 1 -L "Fedora (Custom)" -l \\EFI\\FEDORA\\SHIMX64.EFI

#chroot /mnt grub2-mkconfig -o /boot/grub2/grub.cfg
grub2-mkconfig -o /boot/grub2/grub.cfg

#rm -f /mnt/etc/localtime
rm -f /etc/localtime

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

sudo dnf install https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm -y
sudo dnf install https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm -y

sudo dnf makecache
sudo dnf install akmod-nvidia xorg-x11-drv-nvidia-cuda -y
sudo dnf install nvidia-vaapi-driver libva-utils vdpauinfo -y

# dnf lightdm slick-greeter xorg-x11-server-Xorg

sudo localectl set-x11-keymap us,br pc105 "" grp:alt_shift_toggle
# sudo localectl set-keymap br-abnt2

# Plasma
sudo dnf group install "KDE Plasma Workspaces"
sudo systemctl enable sddm
sudo systemctl set-default graphical.target

sudo dnf install @base-x sddm plasma-desktop konsole dolphin okular ark kate gwenview spectacle firefox thunderbird

# XFCE4
sudo dnf groupinstall "Xfce Desktop"
sudo dnf install lightdm
sudo systemctl enable lightdm --force


sudo dnf5 install \
  xfwm4 \
  xfce4-panel \
  xfce4-session \
  xfce4-settings \
  xfce4-terminal \
  xfce4-appfinder \
  xfdesktop \
  thunar \
  xfconf
  
  sudo dnf5 install lightdm
sudo systemctl enable lightdm --force

sudo dnf5 install \
  firefox \
  ristretto \
  atril \
  keepassxc \
  libreoffice \
  network-manager-applet \
  papirus-icon-theme
