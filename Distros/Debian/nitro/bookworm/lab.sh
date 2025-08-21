#!/usr/bin/env bash

apt update && apt install debootstrap btrfs-progs lsb-release wget -y
apt update

#####################################
####Gptfdisk Partitioning example####
#####################################

# Variables
hostname="lab"
name="Virtual Machine"
username="juca"
Architecture="amd64"
CODENAME=bookworm #$(lsb_release --codename --short) # or CODENAME=bookworm
DRIVE="/dev/vda"
EFI_PART="${DRIVE}2"
SWAP_PART="${DRIVE}3"
ROOT_PART="${DRIVE}4"

MOUNTPOINT="/mnt"
ROOT_LABEL="Debian"
SWAP_LABEL="SWAP" 
EFI_LABEL="ESP"
BTRFS_OPTS="noatime,ssd,compress-force=zstd:8,space_cache=v2,nodatacow,commit=120,discard=async"
BTRFS_OPTS_HOME="noatime,ssd,compress-force=zstd:15,space_cache=v2,nodatacow,commit=120,discard=async"

echo "Disable SELinux temporarily..."
# setenforce 0 # disable SELInux for now

# Create Partitions and Encrypt
### Partition
echo "Creating partitions on $DRIVE..."
sgdisk --zap-all $DRIVE
sgdisk -n 0:0:+1M      -t 1:EF02 -c 1:"BIOS BOOT"                           $DRIVE
sgdisk -n 0:0:+600M    -t 2:EF00 -c 2:"EFI SYSTEM"                          $DRIVE
sgdisk -n 0:0:+2G      -t 3:8200 -c 3:"${SWAP_LABEL}"                       $DRIVE
sgdisk -n 0:0:0        -t 4:8300 -c 4:"${ROOT_LABEL} Root Filesystem "      $DRIVE
sgdisk -p $DRIVE


echo "Formatting partitions on $DRIVE..."
echo "🧼 Formatting partitions..."

mkfs.fat    -F32 -n      "$EFI_LABEL"         "$EFI_PART"
mkswap      -L           "$SWAP_LABEL"        "$SWAP_PART"
swapon                                        "$SWAP_PART"
mkfs.btrfs  -f   -L      "$ROOT_LABEL"        "$ROOT_PART"

udevadm trigger

echo "Partitions formatted successfully on $DRIVE."


echo "Creating Btrfs subvolumes..."
mount "$ROOT_PART" "$MOUNTPOINT"
for sv in @root @cache @opt @gdm @spool @log @tmp @snapshots @nix @home; do
  btrfs subvolume create "$MOUNTPOINT/$sv"
done
umount -Rvf "$MOUNTPOINT"
echo "Btrfs subvolumes created successfully."

echo "Mounting subvolumes and boot partition..."
### Mount subvolumes
mount -o $BTRFS_OPTS,subvol=@root /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT
mkdir -pv $MOUNTPOINT/{boot/efi,home,opt,nix,.snapshots,var/{tmp,spool,log,cache,lib/gdm}}

mount -o $BTRFS_OPTS,subvol=@home /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/home
mount -o $BTRFS_OPTS_HOME,subvol=@nix /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/nix
mount -o $BTRFS_OPTS_HOME,subvol=@opt /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/opt
mount -o $BTRFS_OPTS,subvol=@gdm /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/var/lib/gdm
mount -o $BTRFS_OPTS,subvol=@log /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/var/log
mount -o $BTRFS_OPTS,subvol=@spool /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/var/spool
mount -o $BTRFS_OPTS,subvol=@tmp /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/var/tmp
mount -o $BTRFS_OPTS,subvol=@cache /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/var/cache
mount -o $BTRFS_OPTS_HOME,subvol=@snapshots /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/.snapshots
mount -t vfat -o defaults,noatime,nodiratime /dev/disk/by-label/$EFI_LABEL $MOUNTPOINT/boot/efi
echo "Subvolumes and boot partition mounted successfully."

####################################################
#### Install tarball debootstrap to the mount / ####
####################################################

debootstrap \
  --variant=minbase \
  --include=apt,bash,btrfs-compsize,btrfs-progs,udisks2-btrfs,duperemove,zsh,nano,extrepo,cpio,net-tools,locales,console-setup,perl-openssl-defaults,apt-utils,dosfstools,debconf-utils,wget,curl,tzdata,keyboard-configuration,zstd,ca-certificates,debian-archive-keyring,xz-utils,kmod,gdisk,ncurses-base,systemd,udev,init,iproute2,iputils-ping \
  --arch=${Architecture} \
  ${CODENAME} /mnt \
  "http://debian.c3sl.ufpr.br/debian/ ${CODENAME} contrib non-free non-free-firmware"

########################################################
#### Mount points for chroot, just like arch-chroot ####
########################################################

# Bind essential virtual filesystems
for dir in dev proc sys run; do
    mount --rbind /$dir /mnt/$dir
    mount --make-rslave /mnt/$dir
done

# Ensure devpts is mounted for pseudo-terminal support
mount -t devpts devpts /mnt/dev/pts

# chroot /mnt apt install plymouth plymouth-themes --yes

chroot /mnt apt --fix-broken install --yes

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
EOF

cat <<EOF >/mnt/etc/dracut.conf.d/selinux.conf
# force_drivers+=" securityfs selinuxfs "
EOF

cat <<EOF >/mnt/etc/dracut.conf.d/10-custom.conf
# Host-specific image
hostonly_cmdline="yes"

# Fast compression
compress="zstd --ultra -14"

# Don’t strip away any Plymouth bits
# (remove any omit_dracutmodules line for plymouth)
omit_dracutmodules+=" amdgpu "


# Limit to Btrfs root filesystem
# filesystems+=" resume btrfs "
filesystems+=" btrfs "

# Kernel command-line: enable SELinux, show splash, keep messages quiet
kernel_cmdline=" rootflags=subvol=@root rw quiet  "

# Ensure Plymouth theme files are embedded
# install_items+="/usr/share/plymouth/themes/solar/* \
#  /etc/plymouth/plymouthd.conf"

EOF

touch /mnt/etc/dracut.conf.d/input.conf
cat <<EOF >/mnt/etc/dracut.conf.d/input.conf
add_drivers+=" psmouse "
EOF

########################
#### Fastest Repo's ####
########################

rm /mnt/etc/apt/sources.list
touch /mnt/etc/apt/sources.list.d/{debian.list,various.list,sid.list}

CODENAME=bookworm #$(lsb_release --codename --short) # or CODENAME=bookworm
cat >/mnt/etc/apt/sources.list.d/debian.list <<HEREDOC
####################
### Debian repos ###
####################

deb https://deb.debian.org/debian/ $CODENAME main contrib non-free non-free-firmware
deb-src https://deb.debian.org/debian/ $CODENAME main contrib non-free non-free-firmware

#deb https://security.debian.org/debian-security $CODENAME-security main contrib non-free non-free-firmware
#deb-src https://security.debian.org/debian-security $CODENAME-security main contrib non-free non-free-firmware

deb https://deb.debian.org/debian/ $CODENAME-updates main contrib non-free non-free-firmware
deb-src https://deb.debian.org/debian/ $CODENAME-updates main contrib non-free non-free-firmware

deb https://deb.debian.org/debian/ $CODENAME-backports main contrib non-free non-free-firmware
deb-src https://deb.debian.org/debian/ $CODENAME-backports main contrib non-free non-free-firmware

#######################
### Debian unstable ###
#######################

##Debian Testing
#deb http://deb.debian.org/debian/ testing main contrib non-free non-free-firmware
#deb-src http://deb.debian.org/debian/ testing main contrib non-free non-free-firmware


##Debian Unstable
#deb http://deb.debian.org/debian/ unstable main
##Debian Experimental
#deb http://deb.debian.org/debian/ experimental main

###################
### Tor com apt ###
###################

#deb tor+http://vwakviie2ienjx6t.onion/debian stretch main
#deb-src tor+http://vwakviie2ienjx6t.onion/debian stretch main

#deb tor+http://sgvtcaew4bxjd7ln.onion/debian-security stretch/updates main
#deb-src tor+http://sgvtcaew4bxjd7ln.onion/debian-security stretch/updates main

#deb tor+http://vwakviie2ienjx6t.onion/debian stretch-updates main
#deb-src tor+http://vwakviie2ienjx6t.onion/debian stretch-updates main
HEREDOC

cat >/mnt/etc/apt/sources.list.d/sid.list <<HEREDOC
deb http://deb.debian.org/debian sid main
HEREDOC

# cat >/mnt/etc/apt/sources.list.d/extrepo_librewolf.sources <<HEREDOC
# Types: deb
# Architectures: amd64 arm64
# Components: main
# Uris: https://repo.librewolf.net
# Suites: librewolf
# Signed-By: /var/lib/extrepo/keys/librewolf.asc
# HEREDOC

# cat >/mnt/etc/apt/sources.list.d/vscode.list <<HEREDOC
# ### THIS FILE IS AUTOMATICALLY CONFIGURED ###
# # You may comment out this entry, but any other modifications may be lost.
# Types: deb
# URIs: https://packages.microsoft.com/repos/code
# Suites: stable
# Components: main
# Architectures: amd64,arm64,armhf
# Signed-By: /usr/share/keyrings/microsoft.gpg
# HEREDOC

curl -fsSL https://dl.xanmod.org/gpg.key | gpg --dearmor | tee /mnt/etc/apt/keyrings/xanmod.gpg > /dev/null
curl -fsSL https://repo.waydro.id/waydroid.gpg | tee /mnt/etc/apt/keyrings/waydroid.gpg > /dev/null

cat >/mnt/etc/apt/sources.list.d/waydroid.list <<HEREDOC
deb [signed-by=/etc/apt/keyrings/waydroid.gpg] https://repo.waydro.id bookworm main
HEREDOC

cat >/mnt/etc/apt/sources.list.d/xanmod-kernel.list <<HEREDOC
deb [signed-by=/etc/apt/keyrings/xanmod.gpg] http://deb.xanmod.org releases main
HEREDOC

chroot /mnt apt update
chroot /mnt apt upgrade --yes

# make a initrd for the kernel:
chroot /mnt apt install firmware-iwlwifi firmware-misc-nonfree intel-microcode --yes
# chroot /mnt apt install firmware-linux firmware-linux-free firmware-linux-nonfree firmware-linux-nonfree-amd64 firmware-misc-nonfree firmware-iwlwifi firmware-realtek --yes
# chroot /mnt apt install firmware-linux firmware-misc-nonfree firmware-iwlwifi --yes
# firmware-realtek fwupdate fwupd

chroot /mnt apt update
chroot /mnt apt purge initramfs-tools initramfs-tools-core --yes
chroot /mnt apt-mark hold initramfs-tools

### Network
chroot /mnt apt install network-manager rfkill --yes
# chroot /mnt apt install network-manager iwd rfkill --yes

## dbus initilized
# chroot /mnt dbus-uuidgen > /var/lib/dbus/machine-id

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
chroot /mnt apt upgrade --yes

##############
#### sudo ####
##############

chroot /mnt apt install sudo -y

##############################
#### User's and passwords ####
##############################

chroot /mnt sh -c 'echo "root:200291" | chpasswd -c SHA512'
chroot /mnt useradd $username -m -c "Reinaldo P Jr" -s /bin/bash
chroot /mnt sh -c 'echo "juca:200291" | chpasswd -c SHA512'
chroot /mnt usermod -aG floppy,audio,sudo,video,systemd-journal,lp,cdrom,netdev,input $username
chroot /mnt usermod -aG sudo $username

# chroot /mnt apt install --yes dbus dbus-bin dbus-daemon dbus-session-bus-common dbus-system-bus-common dbus-user-session libpam-systemd
chroot /mnt apt install --yes dbus-broker dbus-user-session libpam-systemd

chroot /mnt systemctl disable dbus-daemon.service
chroot /mnt systemctl enable dbus-broker.service

## Disable verification ##
# touch /mnt/etc/apt/apt.conf.d/99verify-peer.conf \
# && echo >> /mnt/etc/apt/apt.conf.d/99verify-peer.conf "Acquire { https::Verify-Peer false }"


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
blacklist asus_acpi

# low-quality, just noise when being used for sound playback, causes
# hangs at desktop session start (Ubuntu: #246969)
blacklist snd_pcsp

# ugly and loud noise, getting on everyone's nerves; this should be done by a
# nice pulseaudio bing (Ubuntu: #77010)
blacklist pcspkr

# EDAC driver for amd76x clashes with the agp driver preventing the aperture
# from being initialised (Ubuntu: #297750). Blacklist so that the driver
# continues to build and is installable for the few cases where its
# really needed.
blacklist amd76x_e0dac
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
dev.i915.perf_stream_paranoid=0
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

############################
#### Set default editor ####
############################

# chroot /mnt update-alternatives --install /usr/bin/editor editor /usr/bin/nvim 100

######################################
#### Optimize apt package manager ####
######################################

mkdir -pv /mnt/etc/apt/apt.conf.d
touch /mnt/etc/apt/apt.conf.d/99norecommends
cat >/mnt/etc/apt/apt.conf.d/99norecommends <<HEREDOC
#Recommends are as of now abused in many packages
APT::Install-Recommends "0";        # Prevents auto-installing recommended packages
APT::Install-Suggests "0";          # Skips suggested packages (often unnecessary)

# // no install recommends/suggests packages
# APT::Install-Recommends "false";
# APT::Install-Suggests "false";

### For install testing packages
#APT::Default-Release "testing";    # Commented out, but useful if you want to prioritize testing selectively
HEREDOC

touch /mnt/etc/apt/apt.conf.d/99assumeyes
cat >/mnt/etc/apt/apt.conf.d/99assumeyes <<HEREDOC
# assume yes install packages
// assume yes install packages
APT::Get::Assume-Yes "true";
HEREDOC

# echo 'APT::Default-Release "stable";' | sudo tee /etc/apt/apt.conf.d/99default-release
# echo 'APT::Default-Release "stable";' | tee /mnt/etc/apt/apt.conf.d/99default-release
echo 'APT::Default-Release "bookworm";' | tee /mnt/etc/apt/apt.conf.d/99default-release

mkdir -pv /mnt/etc/apt/preferences.d

touch /mnt/etc/apt/preferences.d/99stable.pref
touch /mnt/etc/apt/preferences.d/50testing.pref
touch /mnt/etc/apt/preferences.d/99sid.pref
touch /mnt/etc/apt/preferences.d/10unstable.pref
touch /mnt/etc/apt/preferences.d/1experimental.pref
touch /mnt/etc/apt/preferences.d/no-initramfs-tools

cat >/mnt/etc/apt/preferences.d/99stable.pref <<HEREDOC
# 500 <= P < 990: causes a version to be installed unless there is a
# version available belonging to the target release or the installed
# version is more recent

Package: *
# Pin: release a=stable
Pin: release a=bookworm
Pin-Priority: 900
HEREDOC

cat >/mnt/etc/apt/preferences.d/99sid.pref <<HEREDOC
Package: *
Pin: release a=sid
Pin-Priority: 100
HEREDOC

cat >/mnt/etc/apt/preferences.d/50testing.pref <<HEREDOC
# 100 <= P < 500: causes a version to be installed unless there is a
# version available belonging to some other distribution or the installed
# version is more recent

Package: *
Pin: release a=testing
Pin-Priority: 400
HEREDOC

cat >/mnt/etc/apt/preferences.d/10unstable.pref <<HEREDOC
# 0 < P < 100: causes a version to be installed only if there is no
# installed version of the package

Package: *
Pin: release a=unstable
Pin-Priority: 50
HEREDOC

cat >/mnt/etc/apt/preferences.d/1experimental.pref <<HEREDOC
# 0 < P < 100: causes a version to be installed only if there is no
# installed version of the package

Package: *
Pin: release a=experimental
Pin-Priority: 1
HEREDOC

cat >/mnt/etc/apt/preferences.d/no-initramfs-tools <<HEREDOC
Package: initramfs-tools
Pin: release *
Pin-Priority: -1
HEREDOC

################################
#### Update package manager ####
################################

chroot /mnt apt update
chroot /mnt apt upgrade
chroot /mnt apt autoremove
chroot /mnt apt autoclean

######################
#### Set Hostname ####
######################
# real=nitro

cat <<EOF >/mnt/etc/hostname
${hostname}
EOF

# Hosts
touch /mnt/etc/hosts
cat <<EOF >/mnt/etc/hosts
# Loopback entries; do not change.
127.0.0.1   localhost
127.0.1.1   ${hostname}.localdomain ${hostname}
# The following lines are desirable for IPv6 capable hosts
::1         localhost ip6-localhost ip6-loopback
ff02::1     ip6-allnodes
ff02::2     ip6-allrouters
# See hosts(5) for proper format and other examples:
# 192.168.1.10 foo.example.org foo
# 192.168.1.13 bar.example.org bar
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

ESP_UUID=$(blkid -s UUID -o value $EFI_PART)
ROOT_UUID=$(blkid -s UUID -o value $ROOT_PART)
HOME_UUID=$(blkid -s UUID -o value $HOME_PART)
SWAP_UUID=$(blkid -s UUID -o value $SWAP_PART)

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

# UUID="${ROOT_UUID}"     /var/cache          btrfs     rw,$BTRFS_OPTS,subvol=@cache               0     0
LABEL="${ROOT_LABEL}"     /var/cache          btrfs     rw,$BTRFS_OPTS,subvol=@cache               0     0

# UUID="${ROOT_UUID}"     /var/lib/libvirt    btrfs     rw,$BTRFS_OPTS,subvol=@libvirt             0     0
LABEL="${ROOT_LABEL}"     /var/lib/libvirt    btrfs     rw,$BTRFS_OPTS,subvol=@libvirt             0     0

# UUID="${ROOT_UUID}"     /var/lib/gdm        btrfs     rw,$BTRFS_OPTS,subvol=@gdm                 0     0
LABEL="${ROOT_LABEL}"     /var/lib/gdm        btrfs     rw,$BTRFS_OPTS,subvol=@gdm                 0     0

# UUID="${ROOT_UUID}"     /opt                btrfs     rw,$BTRFS_OPTS,subvol=@opt                 0     0
LABEL="${ROOT_LABEL}"     /opt                btrfs     rw,$BTRFS_OPTS,subvol=@opt                 0     0

### HOME_FS ###
# UUID="${ROOT_UUID}"     /home               btrfs     rw,$BTRFS_OPTS_HOME,subvol=@home           0     0
LABEL="${ROOT_LABEL}"     /home               btrfs     rw,$BTRFS_OPTS_HOME,subvol=@home           0     0

### EFI ###
# UUID="${ESP_UUID}"      /boot/efi           vfat      defaults,noatime,nodiratime                0     2
LABEL="${EFI_LABEL}"      /boot/efi           vfat      defaults,noatime,nodiratime                0     2

### Swap ###
UUID="${SWAP_UUID}"     none                swap      defaults,noatime                           0     0
LABEL="${SWAP_LABEL}"   none                swap      defaults,noatime                           0     0

#Swapfile
# LABEL="${ROOT_UUID}"    none                swap      defaults,noatime
# /swap/swapfile          none                swap      sw                                         0     0

### Tmp ###
# tmpfs                   /tmp                tmpfs     defaults,nosuid,nodev,noatime              0     0
# tmpfs                   /tmp                tmpfs     noatime,mode=1777,nosuid,nodev             0     0
EOF

#############
## Network ##
#############

chroot /mnt apt install gvfs gvfs-backends smbclient cifs-utils avahi-daemon
# ssh
chroot /mnt apt install openssh-client openssh-server 

########################################################
#### Config iwd as backend instead of wpasupplicant ####
########################################################

mkdir -pv /mnt/etc/NetworkManager/conf.d
cat <<EOF >/mnt/etc/NetworkManager/conf.d/wifi_backend.conf
[device]
wifi.backend=iwd
wifi.iwd.autoconnect=yes
EOF

cat <<EOF >/mnt/etc/NetworkManager/conf.d/10-wlan.conf
[keyfile]
unmanaged-devices=none
EOF

mkdir -pv /mnt/etc/iwd
touch /mnt/etc/iwd/main.conf
cat <<EOF >/mnt/etc/iwd/main.conf
[General]
EnableNetworkConfiguration=true

[Network]
NameResolvingService=systemd
RouterPriorityOffset=30
EOF

##################
### SOCKET RAW ###
##################

mkdir -pv /mnt/usr/lib/sysctl.d
touch /mnt/usr/lib/sysctl.d/50-default.conf
echo "-net.ipv4.ping_group_range = 0 2147483647" >> /mnt/usr/lib/sysctl.d/50-default.conf


### BTRFS
# chroot /mnt apt install btrfs-progs btrfs-compsize udisks2-btrfs duperemove 

###############
#### Audio ####
###############

## Pulseaudio
# chroot /mnt apt install alsa-utils bluetooth rfkill bluez bluez-tools pulseaudio pulseaudio-module-bluetooth pavucontrol 

## Pipewire
# chroot /mnt apt purge pipewire* pipewire-bin -y
chroot /mnt apt install pipewire-audio wireplumber pipewire-pulse pipewire-alsa libspa-0.2-bluetooth libspa-0.2-jack 

# Enable WirePlumber session manager:
chroot /mnt systemctl --user enable wireplumber.service # --now
# Symlink resolv.conf for systemd-resolved (optional):
# ln -sf /run/systemd/resolve/resolv.conf /mnt/etc/resolv.conf
# Disable PulseAudio:
chroot /mnt systemctl --user disable pulseaudio.service pulseaudio.socket # --now
chroot /mnt systemctl --user mask pulseaudio 
# Enable PipeWire services:
chroot /mnt systemctl --user enable pipewire pipewire-pulse # --now

## RealtimeKit
chroot /mnt apt install rtkit

###############
#### Utils ####
###############
chroot /mnt apt install gdisk bash-completion pciutils debian-keyring xz-utils htop wget unzip 

##############
### Polkit ###
##############
# chroot /mnt apt install policykit-1 policykit-1-gnome udisks2 polkitd polkitd-pkla
chroot /mnt apt install polkitd pkexec udisks2

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
chmod root:root /mnt/etc/polkit-1/rules.d/10-commands.rules
chmod root:root /mnt/etc/polkit-1/rules.d/10-logs.rules

cat >/mnt/etc/sudoers.d/sysctl <<HEREDOC
$USER ALL = NOPASSWD: /bin/systemctl
HEREDOC

############
### BOOT ###
############
chroot /mnt apt install efibootmgr grub-efi-amd64 os-prober

############
### TIME ###
############
chroot /mnt apt install chrony

# apt install linux-headers-$(uname -r|sed 's/[^-]*-[^-]*-//')


# chroot /mnt update-initramfs -c -k all

######################################
#### Update initramfs load system ####
######################################

# chroot /mnt update-initramfs -c -k all
chroot /mnt dracut --kver "$(ls /mnt/lib/modules/ | head -n 1)" --force


###############################
#### Minimal xorg packages ####
###############################

chroot /mnt apt install xserver-xorg x11-utils x11-xserver-utils xinit

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

#########################
#### Config Powertop ####
#########################

touch /mnt/etc/rc.local

### Nix
chroot /mnt apt install nix-setup-systemd -y

############################
#### BTRFS Backup tools ####
############################

# chroot /mnt apt install snapper snapper-gui 

#################################
#### Plymouth animation boot ####
#################################

# chroot /mnt apt install plymouth plymouth-themes 
# chroot /mnt plymouth-set-default-theme -R solar

# mkdir -pv /mnt/etc/plymouth
# touch /mnt/etc/plymouth/plymouth.conf
# cat <<EOF >/mnt/etc/plymouth/plymouth.conf
# Administrator customizations go in this file
# [Daemon]
# Theme=solar
# ShowDelay=5
# EOF

###########################
#### Setup resolv.conf ####
###########################
# touch /mnt/etc/resolv.conf
# cat <<EOF >/mnt/etc/resolv.conf
# nameserver 9.9.9.9
# # nameserver 8.8.8.8
# # nameserver 8.8.4.4
# # nameserver 1.1.1.1
# EOF

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

chroot /mnt setupcon --save
# chroot /mnt service keyboard-setup restart
# setxkbmap -layout us,br -variant intl, -option grp:alt_shift_toggle

# GSETTINGS
# gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'us'), ('xkb', 'br')]"
# gsettings set org.gnome.desktop.input-sources xkb-options "['grp:alt_shift_toggle']"

#############################
#### Set bash as default ####
#############################

chroot /mnt chsh -s /usr/bin/bash root


#########################
#### Enable Services ####
#########################

## Network
chroot /mnt systemctl enable systemd-networkd.service # if want to use systemd as default, disable it if want network-manager or ifupdown
chroot /mnt systemctl enable NetworkManager.service
# chroot /mnt systemctl disable networking.service
# chroot /mnt systemctl disable iwd.service
chroot /mnt systemctl enable ssh.service
# chroot /mnt systemctl enable --user pulseaudio.service
chroot /mnt systemctl enable rtkit-daemon.service
chroot /mnt systemctl enable chrony.service
chroot /mnt systemctl enable fstrim.timer

## Audio
## Pipewire
# chroot /mnt systemctl --user --now enable pipewire{,-pulse}.{socket,service}
# chroot /mnt systemctl --user --now disable pulseaudio.service pulseaudio.socket
# chroot /mnt systemctl --user mask pulseaudio.{socket,service}

# chroot /mnt systemctl --user daemon-reload

##Pulseaudio
# chroot /mnt systemctl --user enable pulseaudio.{socket,service}
#chroot /mnt systemctl --user --now disable pipewire{,-pulse}.{socket,service}
# chroot /mnt systemctl --user --now mask pipewire{,-pulse}.{socket,service}

# Allow run as root
# sed -i -e 's/ConditionUser=!root/#ConditionUser=!root/' /mnt/usr/lib/systemd/user/pipewire.socket
# sed -i -e 's/ConditionUser=!root/#ConditionUser=!root/' /mnt/etc/xdg/systemd/user/pipewire-pulse.service
# sed -i -e 's/ConditionUser=!root/#ConditionUser=!root/' /mnt/etc/xdg/systemd/user/sockets.target.wants/pipewire.socket
# sed -i -e 's/ConditionUser=!root/#ConditionUser=!root/' /mnt/etc/xdg/systemd/user/pipewire-pulse.socket
# sed -i -e 's/ConditionUser=!root/#ConditionUser=!root/' /mnt/etc/xdg/systemd/user/default.target.wants/pipewire.service

## Pulseaudio
# chroot /mnt systemctl --user enable pulseaudio

## Tune chrony ##
# touch /mnt/etc/chrony.conf
sed -i -E 's/^(pool[ \t]+.*)$/\1\nserver time.google.com iburst prefer\nserver time.windows.com iburst prefer/g' /mnt/etc/chrony.conf
# cat <<EOF >>/mnt/etc/chrony.conf
# server time.windows.com iburst prefer
# EOF

## Update initramfs
# chroot /mnt update-initramfs -c -k all

######################
#### Install grub ####
######################

# chroot /mnt grub-install --target=x86_64-efi --bootloader-id="${ROOT_LABEL}" --efi-directory=/boot/efi --no-nvram --removable --recheck
chroot /mnt grub-install --target=x86_64-efi --bootloader-id=GRUB --efi-directory=/boot/efi --removable --recheck

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
GRUB_CMDLINE_LINUX_DEFAULT="rhgb quiet i8042.nopnp kernel.unprivileged_userns_clone vt.global_cursor_default=0 loglevel=0 gpt init_on_alloc=0 udev.log_level=0 rcutree.rcu_idle_gp_delay=1 zswap.enabled=1 zswap.compressor=lz4hc zswap.max_pool_percent=10 zswap.zpool=z3fold nohz=on mitigations=off msr.allow_writes=on pcie_aspm=force intel_idle.max_cstate=1 initcall_debug no_timer_check noreplace-smp page_alloc.shuffle=1 rcupdate.rcu_expedited=1 tsc=reliable"
# GRUB_CMDLINE_LINUX_DEFAULT="rhgb quiet i8042.nopnp usbcore.autosuspend=-1 nvidia-drm.modeset=1 apparmor=1 security=apparmor kernel.unprivileged_userns_clone vt.global_cursor_default=0 loglevel=0 gpt init_on_alloc=0 udev.log_level=0 rcutree.rcu_idle_gp_delay=1 intel_iommu=on,igfx_off nvidia-drm.modeset=1 i915.modeset=1 zswap.enabled=1 zswap.compressor=lz4hc zswap.max_pool_percent=10 zswap.zpool=z3fold nohz=on mitigations=off msr.allow_writes=on pcie_aspm=force intel_idle.max_cstate=1 initcall_debug no_timer_check noreplace-smp page_alloc.shuffle=1 rcupdate.rcu_expedited=1 tsc=reliable"
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

# chroto /mnt efibootmgr -c -d /dev/disk/by-label/${ROOT_LABEL} -p 1 -L "${ROOT_LABEL} (Custom)" -l \\EFI\\DEBIAN\\SHIMX64.EFI
# chroot /mnt efibootmgr -c -d /dev/by-label/${ROOT_LABEL} -L ${ROOT_LABEL} -l \\EFI\\BOOT\\BOOTX64.efi
# chroot /mnt efibootmgr -c -d /dev/by-label/Debian -L Debian -l \\EFI\\BOOT\\BOOTX64.efi
chroot /mnt efibootmgr


chroot /mnt apt install dracut

### Kernel ###
chroot /mnt apt install linux-image-amd64 linux-headers-amd64 --yes
# chroot /mnt apt install linux-image-amd64 linux-headers-amd64 --yes

# chroot /mnt apt install extrepo -y
# chroot /mnt extrepo enable librewolf

# chroot /mnt update-initramfs -c -k all

rm -rf /mnt/vmlinuz.old
rm -rf /mnt/vmlinuz
rm -rf /mnt/initrd.img
rm -rf /mnt/initrd.img.old
rm -rf /mnt/debootstrap

###########################
#### Fix Dual provider ####
###########################

# touch /mnt/home/${username}/.xsessionrc
# cat <<EOF >/mnt/home/${username}/.xsessionrc
# xrandr --setprovideroutputsource NVIDIA-G0 modesetting
# EOF

# chroot /mnt chmod +x /home/${username}/.xsessionrc
# chroot /mnt chown -R ${username}:${username} /home/${username}/.xsessionrc

# Add pacstall
# bash -c "$(curl -fsSL https://git.io/JsADh || wget -q https://git.io/JsADh -O -)"
# chroot /mnt bash -c "$(curl -fsSL https://pacstall.dev/q/install)"

