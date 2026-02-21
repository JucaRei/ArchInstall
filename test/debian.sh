#!/usr/bin/env bash

apt update && apt install gdisk debootstrap btrfs-progs lsb-release wget arch-install-scripts -y

# 🧭 Drive + partition paths
DRIVE="/dev/vda"
SYSTEM_PART="${DRIVE}2"
EFI_PART="${DRIVE}3"
ROOT_PART="${DRIVE}4"
HOME_PART="${DRIVE}5"


# 🔖 Labels
ROOT_LABEL="Linux_Root"
HOME_LABEL="data"
# SWAP_LABEL="SWAP"
SYSTEM_LABEL="SYSTEM"
EFI_LABEL="ESP"

# ⚙️ Btrfs options
BTRFS_OPTS="noatime,ssd,compress-force=zstd:8,space_cache=v2,commit=120,discard=async"
BTRFS_OPTS_HOME="noatime,ssd,compress-force=zstd:15,space_cache=v2,commit=120,discard=async"

# 📁 Mount point
MOUNTPOINT="/mnt"

echo "🧱 Creating partitions..."
sgdisk --zap-all $DRIVE
sleep 2
parted -s -a optimal $DRIVE mklabel gpt
sgdisk -n 0:0:+1M      -t 1:EF02 -c 1:"BIOS BOOT"          $DRIVE
sgdisk -n 0:0:+1G      -t 2:8301 -c 2:"SYSTEM RESERVED"    $DRIVE
sgdisk -n 0:0:+600M    -t 3:EF00 -c 3:"EFI SYSTEM"         $DRIVE
sgdisk -n 0:0:+25G     -t 4:8300 -c 4:"$ROOT_LABEL root"        $DRIVE
sgdisk -n 0:0:0        -t 5:8302 -c 5:"$HOME_LABEL home"        $DRIVE
sgdisk -p $DRIVE


echo "🧼 Formatting partitions..."
mkfs.ext4  -F   -L "$SYSTEM_LABEL"  "$SYSTEM_PART"
mkfs.fat   -F32 -n "$EFI_LABEL"     "$EFI_PART"
mkfs.btrfs -f   -L "$ROOT_LABEL"    "$ROOT_PART"
mkfs.btrfs -f   -L "$HOME_LABEL"    "$HOME_PART"

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
mount -o $BTRFS_OPTS,subvol=@root /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT
mkdir -pv $MOUNTPOINT/{boot,home,opt,nix,.snapshots,var/{tmp,spool,log,cache/apt,lib/{gdm,libvirt}}}

mount -o $BTRFS_OPTS_HOME,subvol=@home      /dev/disk/by-label/$HOME_LABEL $MOUNTPOINT/home
mount -o $BTRFS_OPTS,subvol=@opt            /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/opt
mount -o $BTRFS_OPTS,subvol=@gdm            /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/var/lib/gdm
mount -o $BTRFS_OPTS,subvol=@libvirt        /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/var/lib/libvirt
mount -o $BTRFS_OPTS,subvol=@log            /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/var/log
mount -o $BTRFS_OPTS,subvol=@nix            /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/nix
mount -o $BTRFS_OPTS,subvol=@spool          /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/var/spool
mount -o $BTRFS_OPTS,subvol=@tmp            /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/var/tmp
mount -o $BTRFS_OPTS,subvol=@apt            /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/var/cache/apt
mount -o $BTRFS_OPTS,subvol=@snapshots      /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/.snapshots

echo "⏏️ Mounting boot and EFI..."
mount /dev/disk/by-label/$SYSTEM_LABEL $MOUNTPOINT/boot
mkdir -pv $MOUNTPOINT/boot/efi
mount -t vfat -o defaults,noatime,nodiratime /dev/disk/by-label/$EFI_LABEL $MOUNTPOINT/boot/efi

### Debian VARS
Architecture="amd64"
CODENAME="trixie" #$(lsb_release --codename --short) # or CODENAME=bookworm
username="juca"
hostname="virtualvm"

# debootstrap \
#   --variant=minbase \
#   --include=apt,bash,btrfs-compsize,btrfs-progs,udisks2-btrfs,duperemove,zsh,nano,extrepo,cpio,net-tools,locales,console-setup,perl-openssl-defaults,apt-utils,dosfstools,debconf-utils,wget,curl,tzdata,keyboard-configuration,zstd,ca-certificates,debian-archive-keyring,xz-utils,kmod,gdisk,ncurses-base,systemd,udev,init,iproute2,iputils-ping \
#   --arch=${Architecture} \
#   ${CODENAME} /mnt \
#   "http://debian.c3sl.ufpr.br/debian/ ${CODENAME} contrib non-free non-free-firmware"

debootstrap \
  --arch=${Architecture} \
  --variant=minbase \
  --include=apt,bash,zsh,neovim,nano,locales,apt-utils,iputils-ping,dbus-broker,dbus-user-session,libpam-systemd,wget,curl,tzdata,ca-certificates,systemd-sysv,grub-efi-amd64,login,passwd,procps,e2fsprogs,network-manager,sudo \
  ${CODENAME} /mnt \
  http://debian.c3sl.ufpr.br/debian


echo "🔧 Mounting system filesystems..."
udevadm trigger
mkdir -p $MOUNTPOINT/{proc,sys,dev/pts}
mount -t proc   proc     $MOUNTPOINT/proc
mount -t sysfs  sysfs    $MOUNTPOINT/sys
mount --rbind   /dev     $MOUNTPOINT/dev
mount -t devpts devpts   $MOUNTPOINT/dev/pts


chroot /mnt apt purge ifupdown --yes

mkdir -pv /mnt/etc/network/
touch /mnt/etc/network/interfaces
cat <<EOF > /mnt/etc/network/interfaces
auto lo
iface lo inet loopback
EOF


# chroot /mnt update-alternatives --install /usr/bin/editor editor /usr/bin/nvim 100
# chroot /mnt apt --fix-broken install --yes

######################
### Dracut Modules ###
######################

mkdir -pv /mnt/etc/dracut.conf.d

touch /mnt/etc/dracut.conf.d/10-debian.conf
cat <<EOF > /mnt/etc/dracut.conf.d/10-debian.conf
do_prelink="no"
hostonly="yes"
# add_dracutmodules+=" systemd tpm2 crypt resume btrfs "
add_dracutmodules+=" systemd "
# force_drivers+=" nvme ahci hid_generic iwlwifi "
early_microcode=yes
EOF

cat <<EOF >/mnt/etc/dracut.conf.d/selinux.conf
# force_drivers+=" securityfs selinuxfs "
EOF

cat <<EOF >/mnt/etc/dracut.conf.d/10-custom.conf
# Host-specific image
hostonly_cmdline="yes"

# Fast compression
compress="zstd"
compressargs="-19"

# Don’t strip away any Plymouth bits
# (remove any omit_dracutmodules line for plymouth)
omit_dracutmodules+=" amdgpu 90crypt "


# Limit to Btrfs root filesystem
# filesystems+=" resume btrfs "
filesystems+=" btrfs "

# Kernel command-line: enable SELinux, show splash, keep messages quiet
kernel_cmdline=" rootflags=subvol=@root rw quiet security=apparmor apparmor=1 lsm=landlock lockdown yama apparmor bpf "

# Ensure Plymouth theme files are embedded
# install_items+="/usr/share/plymouth/themes/solar/* \
#  /etc/plymouth/plymouthd.conf"

EOF

touch /mnt/etc/dracut.conf.d/input.conf
cat <<EOF >/mnt/etc/dracut.conf.d/input.conf
# add_drivers+=" psmouse "
EOF

########################
#### Fastest Repo's ####
########################

rm /mnt/etc/apt/sources.list
# touch /mnt/etc/apt/sources.list.d/{debian.list,various.list,sid.list}
touch /mnt/etc/apt/sources.list.d/debian.sources

### OLD WAY
cat >/mnt/etc/apt/sources.list <<HEREDOC
# deb http://debian.c3sl.ufpr.br/debian/ $CODENAME main contrib non-free non-free-firmware
# deb-src http://debian.c3sl.ufpr.br/debian/ $CODENAME main contrib non-free non-free-firmware

# deb http://debian.c3sl.ufpr.br/debian/ $CODENAME-updates main contrib non-free non-free-firmware
# deb-src http://debian.c3sl.ufpr.br/debian/ $CODENAME-updates main contrib non-free non-free-firmware

# deb http://debian.c3sl.ufpr.br/debian/ $CODENAME-backports main contrib non-free non-free-firmware
# deb-src http://debian.c3sl.ufpr.br/debian/ $CODENAME-backports main contrib non-free non-free-firmware

# deb http://debian.c3sl.ufpr.br/debian/ experimental main contrib non-free non-free-firmware
# deb-src http://debian.c3sl.ufpr.br/debian/ experimental main contrib non-free non-free-firmware

# deb http://debian.c3sl.ufpr.br/debian/ unstable main contrib non-free non-free-firmware
# deb-src http://debian.c3sl.ufpr.br/debian/ unstable main contrib non-free non-free-firmware
HEREDOC

### NEW WAY ###
cat >/mnt/etc/apt/sources.list.d/debian.sources <<HEREDOC
Types: deb deb-src
# URIs: https://deb.debian.org/debian/
URIs: http://debian.c3sl.ufpr.br/debian/
Suites: trixie
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

Types: deb deb-src
# URIs: https://deb.debian.org/debian/
URIs: http://debian.c3sl.ufpr.br/debian/
Suites: trixie-updates
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

Types: deb deb-src
# URIs: https://deb.debian.org/debian/
URIs: http://debian.c3sl.ufpr.br/debian/
Suites: trixie-backports
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

# Types: deb deb-src
# # URIs: https://deb.debian.org/debian/
# URIs: http://debian.c3sl.ufpr.br/debian/
# Suites: trixie-security
# Components: main contrib non-free non-free-firmware
# Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

# Types: deb deb-src
# # URIs: http://deb.debian.org/debian/
# URIs: http://debian.c3sl.ufpr.br/debian/
# Suites: unstable
# Components: main contrib non-free non-free-firmware
# Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

# Types: deb deb-src
# # URIs: http://deb.debian.org/debian/
# URIs: http://debian.c3sl.ufpr.br/debian/
# Suites: experimental
# Components: main contrib non-free non-free-firmware
# Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

# Types: deb
# URIs: tor+http://2s4yqjx5ul6okpp3f2gaunr2syex5jgbfpfvhxxbbjwnrsvbk5v3qbid.onion/debian/
# Suites: trixie
# Components: main
# Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

# Types: deb
# URIs: tor+http://2s4yqjx5ul6okpp3f2gaunr2syex5jgbfpfvhxxbbjwnrsvbk5v3qbid.onion/debian/
# Suites: trixie-updates
# Components: main
# Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

# Types: deb
# URIs: tor+http://2s4yqjx5ul6okpp3f2gaunr2syex5jgbfpfvhxxbbjwnrsvbk5v3qbid.onion/debian/
# Suites: trixie-backports
# Components: main
# Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
HEREDOC

######################################
#### Optimize apt package manager ####
######################################

mkdir -pv /mnt/etc/apt/apt.conf.d

touch /mnt/etc/apt/apt.conf.d/00recommends
cat << EOF >/mnt/etc/apt/apt.conf.d/00recommends
APT::Install-Recommends "false"; # Prevents auto-installing recommended packages
# Aptitude::Recommends-Important "false";
EOF

touch /mnt/etc/apt/apt.conf.d/70debconf
cat << EOF >/mnt/etc/apt/apt.conf.d/70debconf
// Pre-configure all packages with debconf before they are installed.
// If you don't like it, comment it out.
# DPkg::Pre-Install-Pkgs {"/usr/sbin/dpkg-preconfigure --apt || true";};
EOF

touch /mnt/etc/apt/apt.conf.d/99suggests
cat << EOF >/mnt/etc/apt/apt.conf.d/99suggests
#Recommends are as of now abused in many packages
APT::Install-Suggests "0";          # Skips suggested packages (often unnecessary)
# Aptitude::Suggests-Important "false";

# // no install recommends/suggests packages
# APT::Install-Suggests "false";
EOF

touch /mnt/etc/apt/apt.conf.d/01autoremove
cat << EOF >/mnt/etc/apt/apt.conf.d/01autoremove
APT
{
  NeverAutoRemove
  {
    "^firmware-linux.*";
    "^linux-firmware$";
    # "^linux-image-[a-z0-9]*$";
    # "^linux-image-[a-z0-9]*-[a-z0-9]*$";
  };

  VersionedKernelPackages,
  {
    # Linux kernels
    "linux-image";
    "linux-headers";
    "linux-image-extra";
    "linux-modules";
    "linux-modules-extra";
    "linux-signed-image";
    "linux-.*";
    # BSD kernels,
    "kfreebsd-.*";
    "kfreebsd-image";
    "kfreebsd-headers";
    # hurd kernels
    "gnumach-image";
    "gnumach-.*";
    # (out-of-tree) modules
    ".*-modules";
    ".*-kernel";
    "linux-backports-modules-.*";
    "linux-modules-.*";
    # tools
    "linux-tools";
  };

  Never-MarkAuto-Sections
  {
    "metapackages";
    "tasks";
  };

  Move-Autobit-Sections
  {
    "oldlibs";
  };
};
EOF

touch /mnt/etc/apt/apt.conf.d/99assumeyes
cat << EOF >/mnt/etc/apt/apt.conf.d/99assumeyes
# assume yes install packages
// assume yes install packages
APT::Get::Assume-Yes "true";
EOF

touch /mnt/etc/apt/apt.conf.d/70assumeyes
cat << EOF >/mnt/etc/apt/apt.conf.d/70assumeyes
APT::Get::Assume-Yes "true";
EOF

# echo 'APT::Default-Release "stable";' | sudo tee /etc/apt/apt.conf.d/99default-release
echo 'APT::Default-Release "trixie";' | tee /mnt/etc/apt/apt.conf.d/99default-release

mkdir -pv /mnt/etc/apt/preferences.d

touch /mnt/etc/apt/preferences.d/99stable.pref
touch /mnt/etc/apt/preferences.d/50testing.pref
touch /mnt/etc/apt/preferences.d/99sid.pref
touch /mnt/etc/apt/preferences.d/10unstable.pref
touch /mnt/etc/apt/preferences.d/1experimental.pref
touch /mnt/etc/apt/preferences.d/no-initramfs-tools

cat << EOF >/mnt/etc/apt/preferences.d/99trixie.pref
# 500 <= P < 990: causes a version to be installed unless there is a
# version available belonging to the target release or the installed
# version is more recent

Package: *
# Pin: release a=stable
Pin: release a=${CODENAME}
Pin-Priority: 900
EOF

cat << EOF >/mnt/etc/apt/preferences.d/50testing.pref
# 100 <= P < 500: causes a version to be installed unless there is a
# version available belonging to some other distribution or the installed
# version is more recent

Package: *
Pin: release a=testing
Pin-Priority: 400
EOF

cat << EOF >/mnt/etc/apt/preferences.d/50testing.pref
# 100 <= P < 500: causes a version to be installed unless there is a
# version available belonging to some other distribution or the installed
# version is more recent

Package: *
Pin: release a=testing
Pin-Priority: 400
EOF


cat << EOF >/mnt/etc/apt/preferences.d/10unstable.pref
# 0 < P < 100: causes a version to be installed only if there is no
# installed version of the package

Package: *
Pin: release a=unstable
Pin-Priority: 50
EOF

cat << EOF >/mnt/etc/apt/preferences.d/1experimental.pref
# 0 < P < 100: causes a version to be installed only if there is no
# installed version of the package

Package: *
Pin: release a=experimental
Pin-Priority: 1
EOF

cat << EOF >/mnt/etc/apt/preferences.d/no-initramfs-tools
Package: initramfs-tools
Pin: release *
Pin-Priority: -1
EOF

chroot /mnt apt update
chroot /mnt apt upgrade --yes
# chroot /mnt apt purge initramfs-tools initramfs-tools-core --yes
# chroot /mnt apt-mark hold initramfs-tools

# make a initrd for the kernel:
# chroot /mnt apt install intel-microcode --yes

#########################
#### Setting Locales ####
#########################

chroot /mnt echo "America/Sao_Paulo" >/mnt/etc/timezone
chroot /mnt dpkg-reconfigure -f noninteractive tzdata
sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /mnt/etc/locale.gen
sed -i -e 's/# pt_BR.UTF-8 UTF-8/pt_BR.UTF-8 UTF-8/' /mnt/etc/locale.gen
chroot /mnt dpkg-reconfigure -f noninteractive locales
chroot /mnt apt update
touch /mnt/etc/vconsole.conf
echo 'KEYMAP="br-abnt2"' >/mnt/etc/vconsole.conf
echo 'KEYMAP_TOGGLE="us-intl"' >> /mnt/etc/vconsole.conf

chroot /mnt apt update
chroot /mnt apt upgrade
chroot /mnt apt autoremove
chroot /mnt apt autoclean


##############################
#### User's and passwords ####
##############################

chroot /mnt sh -c 'echo "root:200291" | chpasswd -c SHA512'
chroot /mnt useradd $username -m -c "Reinaldo P Jr" -s /bin/bash
chroot /mnt sh -c 'echo "juca:200291" | chpasswd -c SHA512'
chroot /mnt usermod -aG floppy,audio,sudo,video,systemd-journal,lp,cdrom,netdev $username
chroot /mnt usermod -aG sudo $username

# chroot /mnt apt install --yes dbus dbus-bin dbus-daemon dbus-session-bus-common dbus-system-bus-common dbus-user-session libpam-systemd
# chroot /mnt apt install --yes dbus-broker dbus-user-session libpam-systemd
chroot /mnt systemctl disable dbus-daemon.service
chroot /mnt systemctl enable dbus-broker.service

##################################################
#### Disable some features for optimal system ####
##################################################
########################################
#### real hardware modprobe modules ####
########################################

mkdir -pv /mnt/etc/modprobe.d
cat <<EOF >/mnt/etc/modprobe.d/blacklist.conf
# Disable watchdog
install iTCO_wdt /bin/true
install iTCO_vendor_support /bin/true

# This file lists those modules which we don't want to be loaded by
# alias expansion, usually so some other driver will be loaded for the
# device instead.

# evbug is a debug tool that should be loaded explicitly
blacklist evbug

# these drivers are very simple, the HID drivers are usually preferred
blacklist usbmouse
blacklist usbkbd

# replaced by e100
blacklist eepro100

# replaced by tulip
blacklist de4x5

# causes no end of confusion by creating unexpected network interfaces
blacklist eth1394

# snd_intel8x0m can interfere with snd_intel8x0, doesn't seem to support much
# hardware on its own (Ubuntu bug #2011, #6810)
# blacklist snd_intel8x0m

# Conflicts with dvb driver (which is better for handling this device)
blacklist snd_aw2

# replaced by p54pci
# blacklist prism54

# replaced by b43 and ssb.
blacklist bcm43xx

# most apps now use garmin usb driver directly (Ubuntu: #114565)
blacklist garmin_gps

# replaced by asus-laptop (Ubuntu: #184721)
# blacklist asus_acpi

# low-quality, just noise when being used for sound playback, causes
# hangs at desktop session start (Ubuntu: #246969)
# blacklist snd_pcsp

# ugly and loud noise, getting on everyone's nerves; this should be done by a
# nice pulseaudio bing (Ubuntu: #77010)
# blacklist pcspkr

# EDAC driver for amd76x clashes with the agp driver preventing the aperture
# from being initialised (Ubuntu: #297750). Blacklist so that the driver
# continues to build and is installable for the few cases where its
# really needed.
# blacklist amd76x_e0dac
EOF

cat <<EOF >/mnt/etc/modprobe.d/iwlwifi.conf
options iwlwifi enable_ini=0
options iwlwifi disable_11ac=0
options iwlwifi disable_11ax=0
EOF

touch /mnt/etc/systemd/system/iwlwifi-reload.service

cat <<EOF >/mnt/etc/systemd/system/iwlwifi-reload.service
[Unit]
Description=Reload iwlwifi module
After=network.target

[Service]
Type=oneshot
ExecStart=/sbin/modprobe -r iwlwifi
ExecStart=/sbin/modprobe iwlwifi
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

chroot /mnt systemctl enable iwlwifi-reload.service

mkdir -pv /mnt/etc/modules-load.d
touch /mnt/etc/modules-load.d/iptables.conf
cat << EOF > /mnt/etc/modules-load.d/iptables.conf
ip6_tables
ip6table_nat
ip_tables
iptable_nat
EOF

cat << EOF > /mnt/etc/modules-load.d/iwlwifi.conf
iwlwifi
EOF

#######################################
#### Kernel params for tune system ####
#######################################
#######################
#### real hardware ####
#######################

mkdir -pv /mnt/etc/sysctl.d
cat <<EOF >/mnt/etc/sysctl.d/00-swap.conf
vm.vfs_cache_pressure=500
vm.swappiness=100
vm.dirty_background_ratio=1
vm.dirty_ratio=50
EOF

cat <<EOF >/mnt/etc/sysctl.d/10-conf.conf
net.ipv4.ping_group_range=0 $MAX_GID
EOF

cat <<EOF >/mnt/etc/sysctl.d/10-intel.conf
# Intel Graphics
# dev.i915.perf_stream_paranoid=0
EOF

cat <<EOF >/mnt/etc/sysctl.d/10-console-messages.conf
# the following stops low-level messages on console
kernel.printk = 4 4 1 7
EOF

cat <<EOF >/mnt/etc/sysctl.d/99-dmesg.conf
kernel.dmesg_restrict = 0
EOF

cat <<EOF >/mnt/etc/sysctl.d/10-ipv6-privacy.conf
# IPv6 Privacy Extensions (RFC 4941)
# ---
# IPv6 typically uses a device's MAC address when choosing an IPv6 address
# to use in autoconfiguration. Privacy extensions allow using a randomly
# generated IPv6 address, which increases privacy.
#
# Acceptable values:
#    0 - don’t use privacy extensions.
#    1 - generate privacy addresses
#    2 - prefer privacy addresses and use them over the normal addresses.
net.ipv6.conf.all.use_tempaddr = 2
net.ipv6.conf.default.use_tempaddr = 2
EOF

cat <<EOF >/mnt/etc/sysctl.d/10-kernel-hardening.conf
# These settings are specific to hardening the kernel itself from attack
# from userspace, rather than protecting userspace from other malicious
# userspace things.
#
#
# When an attacker is trying to exploit the local kernel, it is often
# helpful to be able to examine where in memory the kernel, modules,
# and data structures live. As such, kernel addresses should be treated
# as sensitive information.
#
# Many files and interfaces contain these addresses (e.g. /proc/kallsyms,
# /proc/modules, etc), and this setting can censor the addresses. A value
# of "0" allows all users to see the kernel addresses. A value of "1"
# limits visibility to the root user, and "2" blocks even the root user.
kernel.kptr_restrict = 1

# Access to the kernel log buffer can be especially useful for an attacker
# attempting to exploit the local kernel, as kernel addresses and detailed
# call traces are frequently found in kernel oops messages. Setting
# dmesg_restrict to "0" allows all users to view the kernel log buffer,
# and setting it to "1" restricts access to those with CAP_SYSLOG.
#
# dmesg_restrict defaults to 1 via CONFIG_SECURITY_DMESG_RESTRICT, only
# uncomment the following line to disable.
# kernel.dmesg_restrict = 0
EOF

cat <<EOF >/mnt/etc/sysctl.d/10-network-security.conf
# Turn on Source Address Verification in all interfaces to
# prevent some spoofing attacks.
net.ipv4.conf.default.rp_filter=2
net.ipv4.conf.all.rp_filter=2
EOF

cat <<EOF >/mnt/etc/sysctl.d/10-zeropage.conf
# Protect the zero page of memory from userspace mmap to prevent kernel
# NULL-dereference attacks against potential future kernel security
# vulnerabilities.  (Added in kernel 2.6.23.)
#
# While this default is built into the Ubuntu kernel, there is no way to
# restore the kernel default if the value is changed during runtime; for
# example via package removal (e.g. wine, dosemu).  Therefore, this value
# is reset to the secure default each time the sysctl values are loaded.
vm.mmap_min_addr = 65536
EOF

######################
#### Set Hostname ####
######################

cat <<EOF >/mnt/etc/hostname
${hostname}
EOF

### HOSTs ###
touch /mnt/etc/hosts
cat <<EOF >/mnt/etc/hosts
# Loopback entries; do not change.
127.0.0.1   localhost
127.0.1.1   ${hostname}.localdomain ${hostname}

# The following lines are desirable for IPv6 capable hosts
::1         localhost ip6-localhost ip6-loopback
EOF

touch /mnt/etc/host.conf
cat <<EOF >/mnt/etc/host.conf
multi on
EOF

touch /mnt/etc/nsswitch.conf
cat <<EOF >/mnt/etc/nsswitch.conf
# Generated by authselect
# Do not modify this file manually, use authselect instead. Any user changes will be overwritten.
# You can stop authselect from managing your configuration by calling 'authselect opt-out'.
# See authselect(8) for more details.

# In order of likelihood of use to accelerate lookup.
passwd:     files systemd
shadow:     files systemd
group:      files [SUCCESS=merge] systemd
hosts:      files myhostname mdns4_minimal [NOTFOUND=return] resolve [!UNAVAIL=return] dns
services:   files
netgroup:   files
automount:  files

aliases:    files
ethers:     files
gshadow:    files systemd
networks:   files dns
protocols:  files
publickey:  files
rpc:        files
EOF

BOOT_UUID=$(blkid -s UUID -o value $SYSTEM_PART)
ESP_UUID=$(blkid -s UUID -o value $EFI_PART)
ROOT_UUID=$(blkid -s UUID -o value $ROOT_PART)
HOME_UUID=$(blkid -s UUID -o value $HOME_PART)

touch /mnt/etc/fstab
cat <<EOF >/mnt/etc/fstab
# <file system>           <dir>               <type>    <options>                               <dump> <pass>
### ROOTFS ###
# UUID="${ROOT_UUID}"     /                   btrfs     rw,$BTRFS_OPTS,subvol=@root                0     0
LABEL="${ROOT_LABEL}"     /                   btrfs     rw,$BTRFS_OPTS,subvol=@root                0     0

# UUID="${ROOT_UUID}"     /.snapshots         btrfs     rw,$BTRFS_OPTS,subvol=@snapshots           0     0
LABEL="${ROOT_LABEL}"     /.snapshots         btrfs     rw,$BTRFS_OPTS,subvol=@snapshots           0     0

# UUID="${ROOT_UUID}"     /nix                btrfs     rw,$BTRFS_OPTS_HOME,subvol=@nix            0     0
LABEL="${ROOT_LABEL}"     /nix                btrfs     rw,$BTRFS_OPTS_HOME,subvol=@nix            0     0

# UUID="${ROOT_UUID}"     /var/log            btrfs     rw,$BTRFS_OPTS,subvol=@log                 0     0
LABEL="${ROOT_LABEL}"     /var/log            btrfs     rw,$BTRFS_OPTS,subvol=@log                 0     0

# UUID="${ROOT_UUID}"     /var/tmp            btrfs     rw,$BTRFS_OPTS,subvol=@tmp                 0     0
LABEL="${ROOT_LABEL}"     /var/tmp            btrfs     rw,$BTRFS_OPTS,subvol=@tmp                 0     0

# UUID="${ROOT_UUID}"     /var/spool          btrfs     rw,$BTRFS_OPTS,subvol=@spool               0     0
LABEL="${ROOT_LABEL}"     /var/spool          btrfs     rw,$BTRFS_OPTS,subvol=@spool               0     0

# UUID="${ROOT_UUID}"     /var/cache/apt      btrfs     rw,$BTRFS_OPTS,subvol=@apt                 0     0
LABEL="${ROOT_LABEL}"     /var/cache/apt      btrfs     rw,$BTRFS_OPTS,subvol=@apt

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
LABEL="${SYSTEM_LABEL}"   /boot               ext4      rw,relatime                                0     1

### EFI ###
# UUID="${ESP_UUID}"      /boot/efi           vfat      defaults,noatime,nodiratime                0     2
LABEL="${EFI_LABEL}"      /boot/efi           vfat      defaults,noatime,nodiratime                0     2

### Swap ###
# UUID="${SWAP_UUID}"     none                swap      defaults,noatime                           0     0
# LABEL="${SWAP_LABEL}"   none                swap      defaults,noatime                           0     0

#Swapfile
# LABEL="${ROOT_UUID}"    none                swap      defaults,noatime
# /swap/swapfile          none                swap      sw                                         0     0

### Tmp ###
# tmpfs                   /tmp                tmpfs     defaults,nosuid,nodev,noatime              0     0
# tmpfs                   /tmp                tmpfs     noatime,mode=1777,nosuid,nodev             0     0
EOF

##############
## AppArmor ##
##############

chroot /mnt apt install apparmor \
  apparmor-utils auditd

mkdir -pv /mnt/var/log/audit
chown root:root /mnt/var/log/audit
chmod 0700 /mnt/var/log/audit

############
### ZRAM ###
############

chroot /mnt apt install zram-tools
cat >/mnt/etc/default/zramswap<<Heredoc
# Tamanho do zram em % da RAM
PERCENT=100

# Algoritmo de compressão (lzo, lz4, zstd)
ALGO=zstd

# Número de dispositivos zram (normalmente = núcleos de CPU)
ZRAM_NUM_DEVICES=

PRIORITY=100
Heredoc

#############
## Network ##
#############

chroot /mnt apt install gvfs gvfs-backends smbclient cifs-utils avahi-daemon


##################
### SOCKET RAW ###
##################

mkdir -pv /mnt/usr/lib/sysctl.d
touch /mnt/usr/lib/sysctl.d/50-default.conf
echo "net.ipv4.ping_group_range = 0 2147483647" >> /mnt/usr/lib/sysctl.d/50-default.conf

###############
#### Audio ####
###############

## Pipewire ##

# chroot /mnt apt purge pipewire* pipewire-bin -y
chroot /mnt apt install pipewire-audio pipewire-audio-client-libraries wireplumber pipewire-pulse pipewire-alsa libspa-0.2-bluetooth libspa-0.2-jack

# To support AAC and LDAC
chroot /mnt apt install libfdk-aac-dev libldacbt-abr2 libldacbt-enc2

mkdir -pv /mnt/etc/pulse/default.pa.d
cat << EOF >/etc/pulse/default.pa
load-module module-switch-on-connect
EOF
cat << EOF >/mnt/etc/pulse/default.pa.d/bluez5.pa
load-module module-bluez5-device
load-module module-bluez5-discover
EOF

mkdir -pv /mnt/etc/pipewire/media-session.d
cat << EOF >/mnt/etc/pipewire/media-session.d/bluez-monitor.conf
properties = {
    bluez5.codecs = [ aac ldac ]
    bluez5.default-codec = ldac
}
EOF

# Enable WirePlumber session manager:
chroot /mnt systemctl --user enable wireplumber.service # --now
# Symlink resolv.conf for systemd-resolved (optional):
# ln -sf /run/systemd/resolve/resolv.conf /mnt/etc/resolv.conf
# Disable PulseAudio:
chroot /mnt systemctl --user disable pulseaudio.service pulseaudio.socket # --now
chroot /mnt systemctl --user mask pulseaudio
# Enable PipeWire services:
chroot /mnt systemctl --user enable pipewire pipewire-pulse wireplumber
# chroot /mnt systemctl --user start pipewire pipewire-pulse wireplumber

## RealtimeKit
chroot /mnt apt install rtkit

###############
#### Utils ####
###############
chroot /mnt apt install gdisk bash-completion pciutils xz-utils curl unzip \
  # acpi acpid
  #dkms

##############
### Polkit ###
##############
# chroot /mnt apt install policykit-1 policykit-1-gnome udisks2 polkitd polkitd-pkla

mkdir -pv /mnt/run/polkit-1/rules.d
chmod 755 /mnt/run/polkit-1/rules.d

mkdir -pv /mnt/etc/polkit-1/localauthority/50-local.d
cat <<EOF >/mnt/etc/polkit-1/localauthority/50-local.d/50-udisks.pkla
[udisks]
Identity=unix-group:sudo
Action=org.freedesktop.udisks2.filesystem-mount-system
ResultAny=yes
ResultInactive=no
ResultActive=yes
EOF

### If you are on Arch/Redhat (polkit >= 106), then this would work:
mkdir -pv /mnt/etc/polkit-1/rules.d
cat >/mnt/etc/polkit-1/rules.d/10-udisks2.rules <<HEREDOC
polkit.addRule(function(action, subject) {
    if ((action.id == "org.freedesktop.udisks2.filesystem-mount" ||
        action.id == "org.freedesktop.udisks2.filesystem-mount-system") &&
        subject.isInGroup("sudo")) {
        return polkit.Result.YES;
    }
});
HEREDOC

cat >/mnt/etc/polkit-1/rules.d/10-logs.rules <<HEREDOC
/* Log authorization checks. */
polkit.addRule(function(action, subject) {
  polkit.log("user " +  subject.user + " is attempting action " + action.id + " from PID " + subject.pid);
});
HEREDOC

cat >/mnt/etc/polkit-1/rules.d/10-commands.rules << HEREDOC
polkit.addRule(function(action, subject) {
  if (
    subject.isInGroup("sudo")
      && (
        action.id == "org.freedesktop.login1.reboot" ||
        action.id == "org.freedesktop.login1.reboot-multiple-sessions" ||
        action.id == "org.freedesktop.login1.power-off" ||
        action.id == "org.freedesktop.login1.power-off-multiple-sessions" ||
        action.id == "org.freedesktop.login1.suspend" ||
        action.id == "org.freedesktop.login1.suspend-multiple-sessions"
      )
    )
  {
    return polkit.Result.YES;
  }
})
HEREDOC

chmod 644 /mnt/etc/polkit-1/rules.d/10-udisks2.rules
chmod 644 /mnt/etc/polkit-1/rules.d/10-commands.rules
chmod 644 /mnt/etc/polkit-1/rules.d/10-logs.rules
chown root:root /mnt/etc/polkit-1/rules.d/10-udisks2.rules
chown root:root /mnt/etc/polkit-1/rules.d/10-commands.rules
chown root:root /mnt/etc/polkit-1/rules.d/10-logs.rules

############
### BOOT ###
############
chroot /mnt apt install efibootmgr grub-efi-amd64 os-prober


############
### TIME ###
############
chroot /mnt apt install chrony

#############################
#### Optimizations Tools ####
#############################

# chroot /mnt apt install nix-setup-systemd --yes

chroot /mnt apt install earlyoom powertop tlp thermald irqbalance ssh --yes
chroot /mnt systemctl enable earlyoom
chroot /mnt systemctl enable powertop
chroot /mnt systemctl enable tlp
chroot /mnt systemctl enable thermald
chroot /mnt systemctl enable irqbalance

###########################
#### Some XORG configs ####
###########################

# Touchpad tap to click
mkdir -pv /mnt/etc/X11/xorg.conf.d/
touch /mnt/etc/X11/xorg.conf.d/30-touchpad.conf
cat <<EOF >/mnt/etc/X11/xorg.conf.d/30-touchpad.conf
Section "InputClass"
        # Identifier "SynPS/2 Synaptics TouchPad"
        # Identifier "SynPS/2 Synaptics TouchPad"
        # MatchIsTouchpad                                     "on"
        # Driver            "libinput"
        # Option            "Tapping"                         "on"

        Identifier          "libinput touchpad catchall"
        Driver              "libinput"
        MatchIsTouchpad     "on"
        MatchDevicePath     "/dev/input/event*"
        Option              "Tapping"   			                "on"
        Option 		          "NaturalScrolling" 			          "true"
EndSection
EOF

#################
### BLUETOOTH ###
#################

# chroot /mnt apt install bluez blueman


################################
#### Setup default keyboard ####
################################

mkdir -pv /mnt/etc/default/
touch /mnt/etc/default/keyboard
cat <<EOF >/mnt/etc/default/keyboard
# KEYBOARD CONFIGURATION FILE

# Consult the keyboard(5) manual page.

XKBMODEL="pc105"
XKBLAYOUT="us,br"
XKBVARIANT="alt-intl,abnt2"
XKBOPTIONS="grp:alt_shift_toggle"
BACKSPACE="guess"
EOF

chroot /mnt apt install console-setup

touch /mnt/etc/default/console-setup
cat <<EOF >/mnt/etc/default/console-setup
# CONFIGURATION FILE FOR SETUPCON

ACTIVE_CONSOLES="/dev/tty[1-6]"
CHARMAP="UTF-8"
CODESET="Lat15"
# FONTFACE="Terminus"
FONTFACE="Fixed"
# FONTSIZE="16x32"
FONTSIZE="8x16"
EOF

# chroot /mnt apt install console-setup fonts-terminus

# chroot /mnt setupcon --save

#############################
#### Set bash as default ####
#############################

chroot /mnt chsh -s /usr/bin/bash root

#########################
#### Enable Services ####
#########################

## Network
# Stop and disable systemd-networkd
chroot /mnt systemctl disable systemd-networkd.service
chroot /mnt systemctl disable systemd-networkd.socket
chroot /mnt systemctl disable systemd-networkd-wait-online.service

chroot /mnt systemctl enable nix-daemon

chroot /mnt systemctl mask systemd-networkd.service
chroot /mnt systemctl mask systemd-networkd.socket
chroot /mnt systemctl mask systemd-networkd-wait-online.service

chroot /mnt systemctl enable NetworkManager.service
# chroot /mnt systemctl disable networking.service
# chroot /mnt systemctl disable iwd.service
chroot /mnt systemctl enable ssh.service
# chroot /mnt systemctl enable --user pulseaudio.service
chroot /mnt systemctl enable rtkit-daemon.service
chroot /mnt systemctl enable chrony.service
chroot /mnt systemctl enable fstrim.timer

######################
### Install Kernel ###
######################

chroot /mnt apt install linux-image-amd64 linux-headers-amd64 --yes


######################################
#### Update initramfs load system ####
######################################

# chroot /mnt update-initramfs -c -k all
chroot /mnt apt install dracut
chroot /mnt dracut --kver "$(ls /mnt/lib/modules/ | head -n 1)" --force

######################
#### Install grub ####
######################

# chroot /mnt grub-install --target=x86_64-efi --bootloader-id="${ROOT_LABEL}" --efi-directory=/boot/efi --no-nvram --removable --recheck
chroot /mnt grub-install --target=x86_64-efi --bootloader-id="${ROOT_LABEL}" --efi-directory=/boot/efi --removable --recheck

#####################
#### Config Grub ####
#####################

cat <<EOF >/mnt/etc/default/grub
#
# Configuration file for GRUB.
#
GRUB_DEFAULT=saved
GRUB_TIMEOUT=5
#GRUB_HIDDEN_TIMEOUT=0
#GRUB_HIDDEN_TIMEOUT_QUIET=false
GRUB_DISABLE_SUBMENU=false
GRUB_DISTRIBUTOR=$(lsb_release -i -s 2>/dev/null || echo Debian)
GRUB_CMDLINE_LINUX_DEFAULT="rhgb quiet i8042.nopnp usbcore.autosuspend=-1 i915.enable_psr=0 i915.enable_fbc=0 nvidia-drm.modeset=1 apparmor=1 security=apparmor kernel.unprivileged_userns_clone vt.global_cursor_default=0 loglevel=0 gpt init_on_alloc=0 udev.log_level=0 rcutree.rcu_idle_gp_delay=1 intel_iommu=on,igfx_off i915.modeset=1 zswap.enabled=1 zswap.compressor=lz4hc zswap.max_pool_percent=10 zswap.zpool=z3fold nohz=on mitigations=off msr.allow_writes=on pcie_aspm=force intel_idle.max_cstate=1 initcall_debug no_timer_check noreplace-smp page_alloc.shuffle=1 rcupdate.rcu_expedited=1 tsc=reliable"
# GRUB_CMDLINE_LINUX_DEFAULT="rhgb quiet selinux=1 security=selinux splash kernel.unprivileged_userns_clone vt.global_cursor_default=0 loglevel=0 gpt init_on_alloc=0 udev.log_level=0 rcutree.rcu_idle_gp_delay=1 intel_iommu=on,igfx_off nvidia-drm.modeset=1 i915.modeset=1 zswap.enabled=1 zswap.compressor=lz4hc zswap.max_pool_percent=10 zswap.zpool=z3fold nohz=on mitigations=off msr.allow_writes=on pcie_aspm=force intel_idle.max_cstate=1 initcall_debug net.ifnames=0 no_timer_check noreplace-smp page_alloc.shuffle=1 rcupdate.rcu_expedited=1 tsc=reliable"
# security=selinux selinux=1

# Uncomment to use basic console
#GRUB_TERMINAL_INPUT="console"
# Uncomment to disable graphical terminal
#GRUB_TERMINAL_OUTPUT=console
#GRUB_BACKGROUND=/usr/share/void-artwork/splash.png
GRUB_GFXMODE=1920x1080x32
#GRUB_DISABLE_LINUX_UUID=true
#GRUB_DISABLE_RECOVERY=true
# Uncomment and set to the desired menu colors.  Used by normal and wallpaper
# modes only.  Entries specified as foreground/background.
GRUB_COLOR_NORMAL="light-blue/black"
GRUB_COLOR_HIGHLIGHT="light-cyan/blue"
GRUB_DISABLE_OS_PROBER=false
GRUB_ENABLE_BLSCFG=true
EOF

chroot /mnt update-grub

chroot /mnt efibootmgr


rm -rf /mnt/vmlinuz.old
rm -rf /mnt/vmlinuz
rm -rf /mnt/initrd.img
rm -rf /mnt/initrd.img.old
rm -rf /mnt/debootstrap

chroot /mnt apt autoremove --yes
chroot /mnt apt clean

# sudo apt install nvidia-driver nvidia-settings firmware-misc-nonfree
# sudo apt install mesa-utils mesa-vulkan-drivers intel-microcode
# sudo apt install xserver-xorg-video-intel


###########
### KDE ###
###########

sudo apt install debconf dialog

sudo apt install plymouth kde-config-plymouth plymouth-theme-breeze

sudo apt install sddm kde-config-sddm sddm-theme-debian-breeze
sudo mkdir -p /etc/sddm.conf.d

# sudo sed -i 's/^Current=.*/Current=debian-breeze/' /etc/sddm.conf.d/theme.conf
# echo -e "[Theme]\nCurrent=debian-breeze" | sudo tee /etc/sddm.conf.d/theme.conf

grep -q '^Current=' /etc/sddm.conf.d/theme.conf \
  && sudo sed -i 's/^Current=.*/Current=debian-breeze/' /etc/sddm.conf.d/theme.conf \
  || echo "Current=debian-breeze" | sudo tee -a /etc/sddm.conf.d/theme.conf

sudo apt install kio-extras xdg-utils xdg-user-dirs xdg-desktop-portal xdg-desktop-portal-kde plasma-desktop plasma-workspace kde-plasma-desktop \
  konsole dolphin kate plasma-nm systemsettings powerdevil \
  plasma-systemmonitor systemsettings kde-config-screenlocker kscreen plasma-discover gir1.2-ayatanaappindicator3-0.1 gir1.2-appindicator3-0.1 libayatana-appindicator3-1

sudo apt install -t sid firefox

# nix-channel --add https://nixos.org/channels/nixpkgs-unstable nixpkgs
# nix-channel --update
