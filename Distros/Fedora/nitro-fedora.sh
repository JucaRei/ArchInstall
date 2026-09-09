#!/usr/bin/env bash

# nitro an515-52

dnf install gdisk btrfs-progs arch-install-scripts -y

# 🧭 Drive + partition paths
DRIVE="/dev/nvme0n1"
SYSTEM_PART="${DRIVE}p2"
EFI_PART="${DRIVE}p3"
ROOT_PART="${DRIVE}p4"
HOME_PART="${DRIVE}p5"
# WINDOWS_PART="${DRIVE}p7"
# MISC_PART="${DRIVE}p8"
FEDORA_VER="43"
#FEDORA_VER="44"

# 🔖 Labels
ROOT_LABEL="Linux"
HOME_LABEL="Data-home"
# SWAP_LABEL="SWAP"
SYSTEM_LABEL="BOOT"
EFI_LABEL="ESP"
# WINDOWS_LABEL="Windows 11"
# MISC_LABEL="Shared-Data"

# ⚙️ Btrfs options
# BTRFS_OPTS="noatime,ssd,compress-force=zstd:15,space_cache=v2,commit=120,discard=async"
# BTRFS_OPTS2="noatime,ssd,compress-force=zstd:6,space_cache=v2,commit=120,discard=async"
# BTRFS_OPTS_HOME="noatime,ssd,compress-force=zstd:15,space_cache=v2,commit=120,discard=async"
NIX_OPTS="noatime,ssd,compress-force=zstd:22,space_cache=v2,commit=20,discard=async"
BTRFS_OPTS="noatime,ssd,compress-force=zstd:8,space_cache=v2,commit=120,discard=async"
BTRFS_OPTS2="noatime,ssd,compress-force=zstd:3,space_cache=v2,commit=120,discard=async"
BTRFS_OPTS_HOME="noatime,ssd,compress-force=zstd:9,space_cache=v2,commit=120,discard=async"


# 📁 Mount point
MOUNTPOINT="/mnt"

# echo "🧱 Creating partitions..."
# sgdisk --zap-all $DRIVE
# sleep 2
# parted -s -a optimal $DRIVE mklabel gpt
# sgdisk -n 0:0:+1M      -t 1:EF02 -c 1:"BIOS BOOT"          $DRIVE
# sgdisk -n 0:0:+1G      -t 2:8301 -c 2:"SYSTEM RESERVED"    $DRIVE
# sgdisk -n 0:0:+600M    -t 3:EF00 -c 3:"EFI SYSTEM"         $DRIVE
# sgdisk -n 0:0:+50G     -t 4:8300 -c 4:"$ROOT_LABEL root"        $DRIVE
# # sgdisk -n 0:0:+50G     -t 5:8302 -c 5:"$ROOT_LABEL home"        $DRIVE
# sgdisk -n 0:0:0        -t 5:8302 -c 5:"$HOME_LABEL home"        $DRIVE
# # sgdisk -n 0:0:+16M     -t 6:0C01 -c 6:"Microsoft Reserved" $DRIVE
# # sgdisk -n 0:0:+100G    -t 7:0700 -c 7:"Windows data"       $DRIVE
# # sgdisk -n 0:0:0        -t 8:0700 -c 8:"Miscellaceous data" $DRIVE
# sgdisk -p $DRIVE

sgdisk -c 4:"$ROOT_LABEL Root Filesystem" $DRIVE

echo "🧼 Formatting partitions..."
# mkfs.ext4  -F   -L "$SYSTEM_LABEL"  "$SYSTEM_PART"
# mkfs.fat   -F32 -n "$EFI_LABEL"     "$EFI_PART"
mkfs.btrfs -f   -L "$ROOT_LABEL"    "$ROOT_PART"
# mkfs.btrfs -f   -L "$HOME_LABEL"    "$HOME_PART"
# mkfs.ntfs  -F   -L "$WINDOWS_LABEL" "$WINDOWS_PART"
# mkfs.exfat      -n "$MISC_LABEL"    "$MISC_PART"

# 🎯 Create Btrfs subvolumes on root partition
mount "$ROOT_PART" "$MOUNTPOINT"
for sv in @ @opt @nix @gdm @libvirt @spool @log @tmp @cache @snapshots; do
  btrfs subvolume create "$MOUNTPOINT/$sv"
done
umount -Rv "$MOUNTPOINT"

# 🏠 Create @home subvolume on home partition
# mkdir -p $MOUNTPOINT/home-temp
# mount "$HOME_PART" $MOUNTPOINT/home-temp
# btrfs subvolume create $MOUNTPOINT/home-temp/@home
# umount $MOUNTPOINT/home-temp

echo "📦 Mounting subvolumes..."
mount -o $BTRFS_OPTS2,subvol=@ /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT
mkdir -pv $MOUNTPOINT/{boot,home,opt,nix,.snapshots,var/{tmp,spool,log,cache/apt,lib/{gdm,libvirt}}}

mount -o $BTRFS_OPTS_HOME,subvol=@home      /dev/disk/by-label/$HOME_LABEL $MOUNTPOINT/home
mount -o $BTRFS_OPTS,subvol=@opt            /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/opt
mount -o $BTRFS_OPTS,subvol=@gdm            /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/var/lib/gdm
mount -o $BTRFS_OPTS,subvol=@libvirt        /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/var/lib/libvirt
mount -o $BTRFS_OPTS2,subvol=@log           /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/var/log
mount -o $NIX_OPTS,subvol=@nix              /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/nix
mount -o $BTRFS_OPTS,subvol=@spool          /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/var/spool
mount -o $BTRFS_OPTS2,subvol=@tmp           /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/var/tmp
mount -o $BTRFS_OPTS,subvol=@cache          /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/var/cache
mount -o $BTRFS_OPTS,subvol=@snapshots      /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/.snapshots

echo "⏏️ Mounting boot and EFI..."
mount /dev/disk/by-label/$SYSTEM_LABEL $MOUNTPOINT/boot
mkdir -pv $MOUNTPOINT/boot/efi
mount -t vfat -o defaults,noatime,nodiratime /dev/disk/by-label/$EFI_LABEL $MOUNTPOINT/boot/efi

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
    tlp \
    acpid \
    openssh-server \
    neovim \
    cracklib \
    cracklib-dicts \
    glibc-langpack-en \
    -y

########################################
# PREP CHROOT
########################################

for i in dev dev/pts proc sys run; do
  mount --rbind /$i $MOUNTPOINT/$i
  mount --make-rslave $MOUNTPOINT/$i
  #mount -t efivarfs efivarfs $MOUNTPOINT/sys/firmware/efi/efivars
done

udevadm trigger

########################################
# UUID
########################################

BOOT_UUID=$(blkid -s UUID -o value $SYSTEM_PART)
BOOT_LABEL=$(blkid -s LABEL -o value $SYSTEM_PART)
EFI_UUID=$(blkid -s UUID -o value $EFI_PART)
EFI_LABEL=$(blkid -s LABEL -o value $EFI_PART)
ROOT_UUID=$(blkid -s UUID -o value $ROOT_PART)
ROOT_LABEL=$(blkid -s LABEL -o value $ROOT_PART)
HOME_UUID=$(blkid -s UUID -o value $HOME_PART)
HOME_LABEL=$(blkid -s LABEL -o value $HOME_PART)


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
# UUID="${EFI_UUID}"      /boot/efi           vfat      defaults,noatime,nodiratime,umask=0077      0     2
LABEL="${EFI_LABEL}"      /boot/efi           vfat      defaults,noatime,nodiratime,umask=0077      0     2

### Swap ###
# UUID="${SWAP_UUID}"     none                swap      defaults,noatime                           0     0
# LABEL="${SWAP_LABEL}"   none                swap      defaults,noatime                           0     0

#Swapfile
# LABEL="${ROOT_LABEL}"   none                swap      defaults,noatime
# UUID="${ROOT_UUID}"     none                swap      defaults,noatime
# /swap/swapfile          none                swap      sw                                         0     0
EOF
########################################
# Nvidia & Intel Install
########################################

#chroot /mnt dnf install akmod-nvidia xorg-x11-drv-nvidia-cuda xorg-x11-drv-nvidia-cuda-libs vulkan -y
#chroot /mnt dnf install libva-nvidia-driver libva-utils -y
#chroot /mnt dnf install libva-intel-media-driver -y # DNF 44
#chroot /mnt dnf install intel-media-driver -y # libva-intel-driver (older)

#cat > $MOUNTPOINT/etc/modprobe.d/nvidia.conf <<EOF
## Enable DynamicPwerManagement
## http://download.nvidia.com/XFree86/Linux-x86_64/440.31/README/dynamicpowermanagement.html
#options nvidia NVreg_DynamicPowerManagement=0x02
#EOF

########################################
# RPM FUSION
########################################

chroot /mnt dnf install -y \
 https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-44.noarch.rpm \
 https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-44.noarch.rpm
 # https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-43.noarch.rpm \
 # https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-43.noarch.rpm
 # https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm \
 # https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm

chroot /mnt dnf config-manager setopt fedora-cisco-openh264.enabled=1

##########################################
# DRACUT
##########################################
mkdir -pv $MOUNTPOINT/etc/dracut.conf.d
touch $MOUNTPOINT/etc/dracut.conf.d/nitro.conf
cat <<EOF > $MOUNTPOINT/etc/dracut.conf.d/nitro.conf
hostonly="yes"
hostonly_cmdline="yes"

# Intel must initialize early (Wayland + Waydroid)
force_drivers+=" i915 "

# NVIDIA for PRIME (not primary)
#add_drivers+=" nvidia nvidia_modeset nvidia_uvm nvidia_drm "

# Prevent conflicts
#omit_drivers+=" nouveau "

# Avoid useless modules
omit_dracutmodules+=" brltty "
EOF

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

GRUB_CMDLINE_LINUX_DEFAULT="rhgb quiet psi=1 i8042.nopnp usbcore.autosuspend=-1 i915.enable_psr=0 i915.enable_fbc=1 i915.enable_guc=3 i915.modeset=1 nvidia-drm.modeset=1 nvidia-drm.fbdev=1 rd.driver.blacklist=nouveau modprobe.blacklist=nouveau msr.allow_writes=on pcie_aspm=force intel_idle.max_cstate=1 no_timer_check page_alloc.shuffle=1 rcupdate.rcu_expedited=1 tsc=reliable vt.global_cursor_default=0 loglevel=0 udev.log_level=0 rcutree.rcu_idle_gp_delay=1"

#GRUB_CMDLINE_LINUX_DEFAULT="rhgb quiet psi=1 i8042.nopnp usbcore.autosuspend=-1 i915.enable_psr=0 i915.enable_fbc=0 nvidia-drm.modeset=1 vt.global_cursor_default=0 loglevel=0 udev.log_level=0 rcutree.rcu_idle_gp_delay=1 intel_iommu=on,igfx_off i915.modeset=1 msr.allow_writes=on pcie_aspm=force intel_idle.max_cstate=1 no_timer_check page_alloc.shuffle=1 rcupdate.rcu_expedited=1 tsc=reliable"

#GRUB_CMDLINE_LINUX_DEFAULT="rhgb usbcore.autosuspend=-1 loglevel=3 udev.log_level=3  msr.allow_writes=on pcie_aspm=force intel_idle.max_cstate=1 no_timer_check page_alloc.shuffle=1 "

# Uncomment to use basic console
#GRUB_TERMINAL_INPUT="console"
# Uncomment to disable graphical terminal
#GRUB_TERMINAL_OUTPUT=console
#GRUB_BACKGROUND=/usr/share/void-artwork/splash.png
# GRUB_GFXMODE=1920x1080x32
#GRUB_DISABLE_LINUX_UUID=true
#GRUB_DISABLE_RECOVERY=true
# Uncomment and set to the desired menu colors.  Used by normal and wallpaper
# modes only.  Entries specified as foreground/background.
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

chroot /mnt dnf install -y bluez
chroot /mnt systemctl enable bluetooth

########################################
# ZRAM
#########################################
mkdir -pv $MOUNTPOINT/etc/systemd/zram-generator.conf.d
cat <<EOF > $MOUNTPOINT/etc/systemd/zram-generator.conf.d/99-zram.conf
[zram0]
zram-size = ram * 1.5
compression-algorithm = lz4
swap-priority = 100
EOF

chroot /mnt systemctl enable systemd-zram-setup@zram0

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
chroot /mnt systemctl enable tlp
chroot /mnt systemctl enable acpid

########################################
# USER
########################################

echo "nitro" > $MOUNTPOINT/etc/hostname
chroot /mnt useradd juca -m -s /bin/bash
chroot /mnt echo "juca:200291" | chpasswd
chroot /mnt usermod -aG wheel juca

chroot /mnt fixfiles -F onboot
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


dnf group list --hidden
dnf group info "Group Name"
dnf info package-nam
dnf environment list
dnf environment info basic-desktop-environment

###########
### KDE ###
###########

dnf install @kde-desktop-environment

# Install KDE Packages
dnf install bluedevil breeze-gtk breeze-icon-theme colord-kde dolphin gnome-keyring-pam kcm_systemd kde-gtk-config kde-settings-plasma kde-style-breeze kdegraphics-thumbnailers kdeplasma-addons kdialog kdnssd kf5-akonadi-server kf5-akonadi-server-mysql kf5-baloo-file kf5-kipi-plugins khotkeys kmenuedit konsole5 kscreen kscreenlocker ksshaskpass ksysguard kwalletmanager5 kwin NetworkManager-config-connectivity-fedora pam-kwallet phonon-qt5-backend-gstreamer pinentry-qt plasma-breeze  plasma-desktop plasma-drkonqi plasma-nm plasma-nm-l2tp plasma-nm-openconnect plasma-nm-openswan plasma-nm-openvpn plasma-nm-pptp plasma-nm-vpnc plasma-pa plasma-user-manager plasma-workspace plasma-workspace-geolocation polkit-kde sddm sddm-breeze sddm-kcm setroubleshoot sni-qt --skip-unavailable -y

#!/bin/env bash
##### CHECK FOR SUDO or ROOT ##################################
if ! [ $(id -u) = 0 ]; then
  echo "This script must be run as sudo or root, try again..."
  exit 1
fi

# Install KDE Packages
dnf install \
  @"base-x" \
  @"Common NetworkManager Submodules" \
  @"Fonts" \
  @"Hardware Support" \
  bluedevil \
  breeze-gtk \
  breeze-icon-theme \
  cagibi \
  colord-kde \
  cups-pk-helper \
  dolphin \
  glibc-all-langpacks \
  gnome-keyring-pam \
  kcm_systemd \
  kde-gtk-config \
  kde-partitionmanager \
  kde-print-manager \
  kde-settings-pulseaudio \
  kde-style-breeze \
  kdegraphics-thumbnailers \
  kdeplasma-addons \
  kdialog \
  kdnssd \
  kf5-akonadi-server \
  kf5-akonadi-server-mysql \
  kf5-baloo-file \
  kf5-kipi-plugins \
  khotkeys \
  kmenuedit \
  konsole5 \
  kscreen \
  kscreenlocker \
  ksshaskpass \
  ksysguard \
  kwalletmanager5 \
  kwebkitpart \
  kwin \
  NetworkManager-config-connectivity-fedora \
  pam-kwallet \
  phonon-qt5-backend-gstreamer \
  pinentry-qt \
  plasma-breeze \
  plasma-desktop \
  plasma-desktop-doc \
  plasma-drkonqi \
  plasma-nm \
  plasma-nm-l2tp \
  plasma-nm-openconnect \
  plasma-nm-openswan \
  plasma-nm-openvpn \
  plasma-nm-pptp \
  plasma-nm-vpnc \
  plasma-pa \
  plasma-user-manager \
  plasma-workspace \
  plasma-workspace-geolocation \
  polkit-kde \
  qt5-qtbase-gui \
  qt5-qtdeclarative \
  sddm \
  sddm-breeze \
  sddm-kcm \
  setroubleshoot \
  sni-qt \
  xorg-x11-drv-libinput --skip-unavailable -y

  ### UPGRADE RELEASE

  dnf upgrade --refresh
  dnf system-upgrade download --releasever=43 --allowerasing --best
  dnf system-upgrade reboot
  dnf5 offline reboot
  dnf install remove-retired-packages
  remove-retired-packages 43
  dnf repoquery --duplicates
  dnf repoquery remove --duplicates
  dnf autoremove

sudo dnf install @virtualization
sudo dnf install gnome-shell-extension-appindicator
