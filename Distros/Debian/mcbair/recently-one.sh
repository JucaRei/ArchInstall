#!/bin/sh


#### Update and install needed packages ####
apt update && apt install debootstrap btrfs-progs lsb-release wget -y

#### Umount drive, if it's mounted ####

#### Add faster repo's ####
# CODENAME=$(lsb_release --codename --short) # or CODENAME=bullseye
# CODENAME=bookwarn # or CODENAME=bullseye
# cat >/etc/apt/sources.list <<HEREDOC
# deb https://deb.debian.org/debian/ $CODENAME main contrib non-free
# deb-src https://deb.debian.org/debian/ $CODENAME main contrib non-free

# #deb https://security.debian.org/debian-security $CODENAME-security main contrib non-free
# #deb-src https://security.debian.org/debian-security $CODENAME-security main contrib non-free

# deb https://deb.debian.org/debian/ $CODENAME-updates main contrib non-free
# deb-src https://deb.debian.org/debian/ $CODENAME-updates main contrib non-free

# deb https://deb.debian.org/debian/ $CODENAME-backports main contrib non-free
# deb-src https://deb.debian.org/debian/ $CODENAME-backports main contrib non-free

# #######################
# ### Debian unstable ###
# #######################

# ##Debian Testing
# #deb http://deb.debian.org/debian/ testing main
# #deb-src http://deb.debian.org/debian/ testing main

# ##Debian Unstable
# #deb http://deb.debian.org/debian/ unstable main
# ##Debian Experimental
# #deb http://deb.debian.org/debian/ experimental main

# ###################
# ### Tor com apt ###
# ###################

# #deb tor+http://vwakviie2ienjx6t.onion/debian stretch main
# #deb-src tor+http://vwakviie2ienjx6t.onion/debian stretch main

# #deb tor+http://sgvtcaew4bxjd7ln.onion/debian-security stretch/updates main
# #deb-src tor+http://sgvtcaew4bxjd7ln.onion/debian-security stretch/updates main

# #deb tor+http://vwakviie2ienjx6t.onion/debian stretch-updates main
# #deb-src tor+http://vwakviie2ienjx6t.onion/debian stretch-updates main
# HEREDOC

#### update fastest repo's
apt update

#####################################
####Gptfdisk Partitioning example####
#####################################

#######################
#### real hardware ####
#######################

### with mac partitioned
# sgdisk -Z ${DRIVE}4
# sgdisk -Z ${DRIVE}5
# parted -s -a optimal ${DRIVE}4 mklabel gpt
# parted -s -a optimal ${DRIVE}5 mklabel gpt
# sgdisk -c 4:SWAP ${DRIVE}
# sgdisk -c 5:Debian ${DRIVE}
# sgdisk -t 4:8200 ${DRIVE}
# sgdisk -t 5:8300 ${DRIVE}
# sgdisk -p ${DRIVE}

## Full drive
# sgdisk -Z ${DRIVE}
# parted -s -a optimal ${DRIVE} mklabel gpt
# sgdisk -n 0:0:512MiB ${DRIVE}
# sgdisk -n 0:0:0 ${DRIVE}
# sgdisk -t 1:ef00 ${DRIVE}
# sgdisk -t 2:8300 ${DRIVE}
# sgdisk -c 1:"EFI System Partition" ${DRIVE}
# sgdisk -c 2:"Debian Filesystem" ${DRIVE}
# sgdisk -p ${DRIVE}

#####################################
##########  FileSystem  #############
#####################################

#######################
#### real hardware ####
#######################

# mkswap /dev/sda4 -L "LinuxSwap"
# mkfs.btrfs /dev/sda5 -f -L "LinuxSystem"

# swapon /dev/disk/by-label/SWAP
# mkfs.btrfs /dev/sda5 -f -L "Debian"

###############################
#### Enviroments variables ####
###############################

set -e
Debian_ARCH="amd64"

## btrfs options ##
BTRFS_OPTS="noatime,ssd,compress-force=zstd:15,space_cache=v2,commit=120,discard=async"
BTRFS_OPTS2="noatime,ssd,compress-force=zstd:3,space_cache=v2,commit=120,discard=async"

## fstab real hardware ##
# UEFI_UUID=$(blkid -s UUID -o value ${DRIVE}1)
# SWAP_UUID=$(blkid -s UUID -o value /dev/sda4)
# ROOT_UUID=$(blkid -s UUID -o value ${DRIVE}2)

## fstab virtual hardware ##
# UEFI_UUID=$(blkid -s UUID -o value /dev/vda1)
# ROOT_UUID=$(blkid -s UUID -o value /dev/vda2)

###########################################
#### Mount and create Btrfs Subvolumes ####
###########################################

#######################
#### real hardware ####
#######################
mount -t btrfs -o $BTRFS_OPTS2 /dev/disk/by-label/Debian /mnt
btrfs su cr /mnt/@
btrfs su cr /mnt/@home
btrfs su cr /mnt/@snapshots
btrfs su cr /mnt/@var_log
btrfs su cr /mnt/@var_cache_apt
# btrfs su cr /mnt/@swapa
umount -v /mnt
## Make directories for mount ##
mount -t btrfs -o $BTRFS_OPTS2,subvol=@ /dev/disk/by-label/Debian /mnt
mkdir -pv /mnt/boot/efi
mkdir -pv /mnt/home
mkdir -pv /mnt/.snapshots
mkdir -pv /mnt/var/log
mkdir -pv /mnt/var/cache/apt
# mkdir -pv /mnt/swap
## Mount btrfs subvolumes ##
mount -t btrfs -o $BTRFS_OPTS2,subvol=@home /dev/disk/by-label/Debian /mnt/home
mount -t btrfs -o $BTRFS_OPTS,subvol=@snapshots /dev/disk/by-label/Debian /mnt/.snapshots
mount -t btrfs -o $BTRFS_OPTS,subvol=@var_log /dev/disk/by-label/Debian /mnt/var/log
mount -t btrfs -o $BTRFS_OPTS,subvol=@var_cache_apt /dev/disk/by-label/Debian /mnt/var/cache/apt
# mount -o $BTRFS_OPTS,subvol=@swap /dev/disk/by-label/SWAP /mnt/swap
mount -t vfat -o noatime,nodiratime /dev/disk/by-label/EFI /mnt/boot/efi

####################################################
#### Install tarball debootstrap to the mount / ####
####################################################

# debootstrap --variant=minbase --include=apt,apt-utils,extrepo,cpio,cron,zstd,ca-certificates,perl-openssl-defaults,sudo,neovim,initramfs-tools,console-setup,dosfstools,console-setup-linux,keyboard-configuration,debian-archive-keyring,locales,busybox,btrfs-progs,dmidecode,kmod,less,gdisk,gpgv,neovim,ncurses-base,netbase,procps,systemd,systemd-sysv,udev,ifupdown,init,iproute2,iputils-ping,bash,whiptail --arch amd64 $CODENAME /mnt "http://debian.c3sl.ufpr.br/debian/ $CODENAME contrib non-free"
# debootstrap --variant= --include=apt,apt-utils,extrepo,cpio,cron,zstd,ca-certificates,perl-openssl-defaults,sudo,neovim,initramfs-tools,console-setup,dosfstools,console-setup-linux,keyboard-configuration,debian-archive-keyring,locales,busybox,btrfs-progs,dmidecode,kmod,less,gdisk,gpgv,neovim,ncurses-base,netbase,procps,systemd,systemd-sysv,udev,ifupdown,init,iproute2,iputils-ping,bash,whiptail --arch amd64 bookworm /mnt "http://debian.c3sl.ufpr.br/debian/ bookworm contrib non-free"
debootstrap --verbose --include=apt,apt-utils,extrepo,cpio,cron,zstd,ca-certificates,perl-openssl-defaults,sudo,neovim,initramfs-tools,console-setup,dosfstools,console-setup-linux,keyboard-configuration,debian-archive-keyring,locales,busybox,btrfs-progs,dmidecode,kmod,less,gdisk,gpgv,neovim,ncurses-base,netbase,procps,systemd,systemd-sysv,udev,ifupdown,init,iproute2,iputils-ping,bash,whiptail --arch amd64 bookworm /mnt "http://debian.c3sl.ufpr.br/debian/ bookworm contrib non-free"
# deb http://debian.c3sl.ufpr.br/debian/ main contrib non-free
# mmdebstrap --variant=minbase --include=apt,apt-utils,extrepo,cpio,cron,zstd,ca-certificates,perl-openssl-defaults,sudo,neovim,initramfs-tools,initramfs-tools-core,dracut,console-setup,dosfstools,console-setup-linux,keyboard-configuration,debian-archive-keyring,locales,locales-all,btrfs-progs,dmidecode,kmod,less,gdisk,gpgv,neovim,ncurses-base,netbase,procps,systemd,systemd-sysv,udev,ifupdown,init,iproute2,iputils-ping,bash,whiptail --arch=amd64 bullseye /mnt "http://debian.c3sl.ufpr.br/debian/ bullseye contrib non-free"

########################
#### Fastest Repo's ####
########################

rm /mnt/etc/apt/sources.list
touch /mnt/etc/apt/sources.list.d/{debian.list,bullseye-security.list,various.list}

CODENAME=bookworm # or CODENAME=bullseye
# CODENAME=$(lsb_release --codename --short) # or CODENAME=bullseye
cat >/mnt/etc/apt/sources.list.d/debian.list <<HEREDOC
####################
### Debian repos ###
####################

deb http://deb.debian.org/debian bookworm main contrib non-free non-free-firmware
deb-src http://deb.debian.org/debian bookworm main contrib non-free non-free-firmware

deb http://deb.debian.org/debian-security/ bookworm-security main contrib non-free non-free-firmware
deb-src http://deb.debian.org/debian-security/ bookworm-security main contrib non-free non-free-firmware

deb http://deb.debian.org/debian bookworm-updates main contrib non-free non-free-firmware
deb-src http://deb.debian.org/debian bookworm-updates main contrib non-free non-free-firmware

deb http://deb.debian.org/debian bookworm-backports main contrib non-free non-free-firmware
deb-src http://deb.debian.org/debian bookworm-backports main contrib non-free non-free-firmware

#######################
### Debian unstable ###
#######################

##Debian Testing
#deb http://deb.debian.org/debian/ testing main
#deb-src http://deb.debian.org/debian/ testing main


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

cat <<\EOF > /mnt/etc/apt/sources.list.d/bullseye-security.list
deb http://security.debian.org/debian-security bullseye-security main contrib
deb-src http://security.debian.org/debian-security bullseye-security main contrib
EOF


## Disable verification ##
# touch /mnt/etc/apt/apt.conf.d/99verify-peer.conf \
# && echo >> /mnt/etc/apt/apt.conf.d/99verify-peer.conf "Acquire { https::Verify-Peer false }"

########################################################
#### Mount points for chroot, just like arch-chroot ####
########################################################

for dir in dev proc sys run; do
    mount --rbind /$dir /mnt/$dir
    mount --make-rslave /mnt/$dir
done

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
EOF

cat <<EOF >/mnt/etc/modprobe.d/iwlwifi.conf
options iwlwifi enable_ini=N
EOF

touch /mnt/etc/modprobe.d/i915.conf
cat <<EOF >/mnt/etc/modprobe.d/i915.conf
## Boot Faster with intel ##
options i915 enable_guc=2 enable_fbc=1 enable_dc=4 enable_hangcheck=0 error_capture=0 enable_dp_mst=0 fastboot=1 #parameters may differ
EOF

#######################################
#### Kernel params for tune system ####
#######################################
#######################
#### real hardware ####
#######################

mkdir -pv /mnt/etc/sysctl.d
cat <<EOF >/mnt/etc/sysctl.d/00-swap.conf
vm.vfs_cache_pressure=40
# vm.swappiness=10
vm.swappiness=20
vm.dirty_bytes" = 335544320
vm.dirty_background_ratio=1
vm.dirty_background_bytes" = 167772160
vm.dirty_ratio=50
EOF

cat <<\EOF >/mnt/etc/sysctl.d/10-conf.conf
net.ipv4.ping_group_range=0 $MAX_GID
EOF

cat <<\EOF >/mnt/etc/sysctl.d/10-intel.conf
# Intel Graphics
dev.i915.perf_stream_paranoid=0
EOF

######################################
#### Update initramfs load system ####
######################################

chroot /mnt update-initramfs -c -k all

############################
#### Set default editor ####
############################

chroot /mnt update-alternatives --install /usr/bin/editor editor /usr/bin/nvim 100

######################################
#### Optimize apt package manager ####
######################################

touch /mnt/etc/apt/apt.conf
cat >/mnt/etc/apt/apt.conf <<HEREDOC
#Recommends are as of now abused in many packages
APT::Install-Recommends "0";
APT::Install-Suggests "0";

### For install testing packages
#APT::Default-Release "testing";
HEREDOC

mkdir -pv /mnt/etc/apt/preferences.d
touch /mnt/etc/apt/preferences.d/stable.pref
touch /mnt/etc/apt/preferences.d/testing.pref
touch /mnt/etc/apt/preferences.d/unstable.pref
touch /mnt/etc/apt/preferences.d/experimental.pref
cat >/mnt/etc/apt/preferences.d/stable.pref <<HEREDOC
# 500 <= P < 990: causes a version to be installed unless there is a
# version available belonging to the target release or the installed
# version is more recent

Package: *
Pin: release a=stable
Pin-Priority: 900
HEREDOC

cat >/mnt/etc/apt/preferences.d/testing.pref <<HEREDOC
# 100 <= P < 500: causes a version to be installed unless there is a
# version available belonging to some other distribution or the installed
# version is more recent

Package: *
Pin: release a=testing
Pin-Priority: 400
HEREDOC

cat >/mnt/etc/apt/preferences.d/unstable.pref <<HEREDOC
# 0 < P < 100: causes a version to be installed only if there is no
# installed version of the package

Package: *
Pin: release a=unstable
Pin-Priority: 50
HEREDOC

cat >/mnt/etc/apt/preferences.d/experimental.pref <<HEREDOC
# 0 < P < 100: causes a version to be installed only if there is no
# installed version of the package

Package: *
Pin: release a=experimental
Pin-Priority: 1
HEREDOC

################################
#### Update package manager ####
################################

chroot /mnt apt update
chroot /mnt apt upgrade -y

######################
#### Set Hostname ####
######################

cat <<EOF >/mnt/etc/hostname
zion
EOF

# Hosts
touch /mnt/etc/hosts
cat <<\EOF >/mnt/etc/hosts
127.0.0.1 localhost
127.0.1.1 zion

### The following lines are desirable for IPv6 capable hosts
::1     localhost ip6-localhost ip6-loopback
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
EOF

echo $UEFI_UUID
echo $ROOT_UUID
# echo $SWAP_UUID
# echo $HOME_UUID

BTRFS_OPTS="noatime,ssd,compress-force=zstd:15,space_cache=v2,commit=120,discard=async"
BTRFS_OPTS2="noatime,ssd,compress-force=zstd:3,space_cache=v2,commit=120,discard=async"


touch /mnt/etc/fstab
cat <<EOF >/mnt/etc/fstab
# <file system>     <dir>           <type> <options>                                <dump> <pass>

### ROOTFS ###
# UUID=$ROOT_UUID   /               btrfs rw,$BTRFS_OPTS2,subvol=@                        0 0
LABEL="Debian"      /               btrfs rw,$BTRFS_OPTS2,subvol=@                        0 0
# UUID=$ROOT_UUID   /.snapshots     btrfs rw,$BTRFS_OPTS,subvol=@snapshots                0 0
LABEL="Debian"      /.snapshots     btrfs rw,$BTRFS_OPTS,subvol=@snapshots                0 0
# UUID=$ROOT_UUID   /var/log        btrfs rw,$BTRFS_OPTS,subvol=@var_log                  0 0
LABEL="Debian"      /var/log        btrfs rw,$BTRFS_OPTS,subvol=@var_log                  0 0
# UUID=$ROOT_UUID   /var/cache/apt  btrfs rw,$BTRFS_OPTS,subvol=@var_cache_apt            0 0
LABEL="Debian"      /var/cache/apt  btrfs rw,$BTRFS_OPTS,subvol=@var_cache_apt            0 0

### HOME_FS ###
# UUID=$HOME_UUID /home           btrfs rw,$BTRFS_OPTS2,subvol=@home                      0 0
LABEL="Debian"    /home           btrfs rw,$BTRFS_OPTS2,subvol=@home                      0 0

### EFI ###
# UUID=$UEFI_UUID /boot/efi       vfat rw,noatime,nodiratime,umask=0077,fmask=0022,dmask=0022,codepage=437,iocharset=iso8859-1,shortname=mixed,utf8,errors=remount-ro  0 2
LABEL="EFI"       /boot/efi       vfat noatime,nodiratime,umask=0077                      0 2

### Swap ###
# UUID=$SWAP_UUID  none            swap defaults,noatime                                 0 0
LABEL="SWAP"     none            swap defaults,noatime                                   0 0
# /swap/swapfile     none            swap sw                                             0 0

### Tmp ###
# tmpfs         /tmp              tmpfs defaults,nosuid,nodev,noatime                    0 0
tmpfs           /tmp              tmpfs noatime,mode=1777,nosuid,nodev                   0 0
EOF

#########################
#### Setting Locales ####
#########################

chroot /mnt echo "America/Sao_Paulo" >/mnt/etc/timezone &&
    dpkg-reconfigure -f noninteractive tzdata &&
    sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen &&
    sed -i -e 's/# pt_BR.UTF-8 UTF-8/pt_BR.UTF-8 UTF-8/' /etc/locale.gen &&
    echo 'LANG="en_US.UTF-8"' >/etc/default/locale &&
    # export LC_ALL=C && \
    # export LANGUAGE=en_US.UTF-8 &&
    # export LC_ALL=en_US.UTF-8 &&
    # export LANG=en_US.UTF-8 &&
    # export LC_CTYPE=en_US.UTF-8 &&
    # locale-gen en_US.UTF-8 && \
    # echo 'KEYMAP="br-abnt2"' >/etc/vconsole.conf
    #dpkg-reconfigure --frontend=noninteractive locales && \
    # update-locale LANG=en_US.UTF-8 && \
    # localedef -i en_US -f UTF-8 en_US.UTF-8 && \
    #localectl set-locale LANG="en_US.UTF-8"
    # update-locale LANG=en_US.UTF-8 && \
    # localedef -i en_US -f UTF-8 en_US.UTF-8
    chroot /mnt apt update

#####################################
#### Install additional packages ####
#####################################

##############
## AppArmor ##
##############

# chroot /mnt apt install apparmor apparmor-utils auditd --no-install-recommends -y

#############
## Network ##
#############

chroot /mnt apt install nftables net-tools wireless-regdb arp-scan gvfs gvfs-backends samba nfs-common smbclient cifs-utils avahi-daemon \
    firmware-linux-nonfree firmware-linux-free firmware-iwlwifi network-manager iwd rfkill firmware-brcm80211 --no-install-recommends -y

# ssh
# chroot /mnt apt install openssh-client openssh-server --no-install-recommends -y

########################################################
#### Config iwd as backend instead of wpasupplicant ####
########################################################

cat <<EOF >/mnt/etc/NetworkManager/conf.d/iwd.conf
[device]
wifi.backend=iwd
wifi.iwd.autoconnect=yes
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

###############
#### Audio ####
###############

## Pulseaudio
chroot /mnt apt install alsa-utils bluetooth rtkit rfkill bluez bluez-tools pulseaudio pulseaudio-module-bluetooth pavucontrol --no-install-recommends -y

## Pipewire
# chroot /mnt apt purge pipewire* pipewire-bin -y
# chroot /mnt apt install pipewire pipewire-audio-client-libraries --no-install-recommends -y
# chroot /mnt apt install alsa-utils rtkit pipewire bluez bluez-tools gstreamer1.0-pipewire libspa-0.2-bluetooth libspa-0.2-jack pipewire-audio-client-libraries -y

## Config pipewire
# touch /mnt/etc/pipewire/media-session.d/with-pulseaudio
# cp /mnt/usr/share/doc/pipewire/examples/systemd/user/pipewire-pulse.* /mnt/etc/systemd/user/

###############
#### Utils ####
###############
#
chroot /mnt apt install duperemove aptitude rsyslog manpages acpid hwinfo lshw dkms btrfs-compsize pciutils linux-image-5.10.0-25-amd64 linux-headers-amd64 \
    debian-keyring git htop efibootmgr grub-efi-amd64 wget unzip curl sysfsutils chrony --no-install-recommends -y
# apt install linux-headers-$(uname -r|sed 's/[^-]*-[^-]*-//')

cat <<EOF >/mnt/etc/initramfs-tools/modules
crc32c-intel
btrfs
#drm
ahci
lz4hc
lz4hc_compress
zstd
zram
z3fold
i915.modeset=1
intel_agp
EOF

# chroot /mnt update-initramfs -c -k all

###############
#### Tools ####
###############

# chroot /mnt apt install colord bash-completion bzip2 gdisk mtools p7zip duf bat unattended-upgrades --no-install-recommends -y
chroot /mnt apt install bash-completion bzip2 gdisk mtools p7zip unattended-upgrades --no-install-recommends -y

#############################
#### Optimizations Tools ####
#############################

chroot /mnt apt install earlyoom powertop tlp thermald irqbalance --no-install-recommends -y

###################
#### Microcode ####
###################

chroot /mnt apt install intel-microcode --no-install-recommends -y

#####################################
#### intel Hardware Acceleration ####
#####################################

chroot /mnt apt install intel-media-va-driver-non-free vainfo intel-gpu-tools gstreamer1.0-vaapi lm-sensors gstreamer1.0-gl mesa-vulkan-drivers --no-install-recommends -y

###############################
#### Minimal xorg packages ####
###############################

chroot /mnt apt install xserver-xorg-core xserver-xorg-input-evdev xserver-xorg-input-libinput xserver-xorg-input-kbd x11-xserver-utils x11-xkb-utils x11-utils xinit xinput --no-install-recommends -y

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
        # MatchIsTouchpad "on"
        # Driver "libinput"
        # Option "Tapping" "on"

        Identifier      "touchpad"
        Driver          "libinput"
        MatchIsTouchpad "on"
        Option          "Tapping"       "on"
EndSection
EOF

# Fix tearing with intel
touch /mnt/etc/X11/xorg.conf.d/20-modesetting.conf
cat <<EOF >/mnt/etc/X11/xorg.conf.d/20-modesetting.conf
Section "Device"
#   Identifier "Intel Graphics 630"
#   Driver "intel"
#   Option "AccelMethod" "sna"
#   Option "TearFree" "True"
#   Option "Tiling" "True"
#   Option "SwapbuffersWait" "True"
#   Option "DRI" "3"

    Identifier  "Intel Graphics"
    Driver      "modesetting"
    Option      "TearFree"       "True"
    Option      "AccelMethod"    "glamor"
    Option      "DRI"            "2"
EndSection
EOF

#########################
#### Config Powertop ####
#########################

touch /mnt/etc/rc.local
cat <<EOF >/mnt/etc/rc.local
#PowerTop
powertop --auto-tune
EOF

#################################
#### Infrastructure packages ####
#################################

#Python, snap and flatpak
# chroot /mnt apt install python3 python3-pip snapd flatpak --no-install-recommends -y
# chroot /mnt apt install snapd flatpak --no-install-recommends -y
#Virt-Manager
# chroot /mnt apt install spice-vdagent gir1.2-spiceclientgtk-3.0 ovmf ovmf-ia32 \
#     dnsmasq ipset libguestfs0 virt-viewer qemu qemu-system qemu-utils qemu-system-gui vde2 uml-utilities virtinst virt-manager \
#     bridge-utils libvirt-daemon-system uidmap zsync --no-install-recommends -y
#Podman
# chroot /mnt apt install podman buildah crun fuse-overlayfs slirp4netns containers-storage lrzip nftables tini dumb-init golang-github-containernetworking-plugin-dnsname --no-install-recommends -y
#Ansible
# chroot /mnt apt install ansible --no-install-recommends -y

############################
#### BTRFS Backup tools ####
############################

chroot /mnt apt install snapper snapper-gui --no-install-recommends -y

#################################
#### Plymouth animation boot ####
#################################

chroot /mnt apt install plymouth plymouth-themes --no-install-recommends -y
chroot /mnt plymouth-set-default-theme -R solar

mkdir -pv /mnt/etc/plymouth
touch /mnt/etc/plymouth/plymouth.conf
cat <<EOF >/mnt/etc/plymouth/plymouth.conf
# Administrator customizations go in this file
[Daemon]
Theme=solar
ShowDelay=0
EOF

###########################
#### Setup resolv.conf ####
###########################

cat <<EOF >/mnt/etc/resolv.conf
nameserver 8.8.8.8
nameserver 8.8.4.4
nameserver 1.1.1.1
EOF

################################
#### Setup default keyboard ####
################################

mkdir -pv /mnt/etc/default/
touch /mnt/etc/default/keyboard
cat <<EOF >/mnt/etc/default/keyboard
# KEYBOARD CONFIGURATION FILE

# Consult the keyboard(5) manual page.

XKBMODEL="pc105"
XKBLAYOUT="us"
XKBVARIANT="mac"
# XKBOPTIONS="terminate:ctrl_alt_bksp"
EOF

#################
#### Locales ####
#################

# chroot /mnt echo "America/Sao_Paulo" >/etc/timezone &&
    #dpkg-reconfigure -f noninteractive tzdata && \
    #sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
    #sed -i -e 's/# pt_BR.UTF-8 UTF-8/pt_BR.UTF-8 UTF-8/' /etc/locale.gen && \
    # echo 'LANGUAGE="en_US.UTF-8"' >/etc/default/locale &&
    # export LANGUAGE=en_US.UTF-8 &&
    # export LC_ALL=en_US.UTF-8 &&
    # dpkg-reconfigure --frontend noninteractive keyboard-configuration &&
    # echo 'KEYMAP="br-abnt2"' >/etc/vconsole.conf
    #dpkg-reconfigure --frontend=noninteractive locales && \
    #update-locale LANG=en_US.UTF-8
    #localedef -i en_US -f UTF-8 en_US.UTF-8

    # setxkbmap -model pc105 -layout br -variant abnt2 &
    # dpkg-reconfigure keyboard-configuration
    # udevadm trigger --subsystem-match=input --action=change

    #############################
    #### Set bash as default ####
    #############################
chroot /mnt chsh -s /usr/bin/bash root

##############
#### sudo ####
##############

chroot /mnt apt install sudo -y

##############################
#### User's and passwords ####
##############################

chroot /mnt sh -c 'echo "root:200291" | chpasswd -c SHA512'
chroot /mnt useradd juca -m -c "Reinaldo P JR" -s /bin/bash
chroot /mnt sh -c 'echo "juca:200291" | chpasswd -c SHA512'
chroot /mnt usermod -aG floppy,audio,sudo,video,systemd-journal,kvm,lp,cdrom,netdev,input,kvm juca
chroot /mnt usermod -aG sudo juca

# AppArmor podman fix

# mkdir -pv /mnt/etc/apparmor.d/local/
# touch /mnt/etc/apparmor.d/local/usr.sbin.dnsmasq
# cat << EOF >> /mnt/etc/apparmor.d/local/usr.sbin.dnsmasq
# owner /run/user/[0-9]*/containers/cni/dnsname/*/dnsmasq.conf r,
# owner /run/user/[0-9]*/containers/cni/dnsname/*/addnhosts r,
# owner /run/user/[0-9]*/containers/cni/dnsname/*/pidfile rw,
# EOF

# chroot /mnt apparmor_parser -R /etc/apparmor.d/usr.sbin.dnsmasq
# chroot /mnt apparmor_parser /etc/apparmor.d/usr.sbin.dnsmasq

############################################################
#### NetworkManager config as default instead of dhcpd5 ####
############################################################

cat <<EOF >/mnt/etc/NetworkManager/NetworkManager.conf
[main]
plugins=ifupdown,keyfile

[ifupdown]
managed=true
EOF

touch /mnt/etc/NetworkManager/dispatcher.d/wlan_auto_toggle.sh
chroot /mnt chmod +x /etc/NetworkManager/dispatcher.d/wlan_auto_toggle.sh
cat <<EOF >/mnt/etc/NetworkManager/dispatcher.d/wlan_auto_toggle.sh
#!/bin/sh

# Use dispatcher to automatically toggle wireless depending on LAN cable being plugged in
# replacing LAN_interface with yours

# if [ "$1" = "LAN_interface" ]; then
if [ "$1" = "eth0" ]; then
    case "$2" in
        up)
            nmcli radio wifi off
            ;;
        down)
            nmcli radio wifi on
            ;;
    esac
# elif [ "$(nmcli -g GENERAL.STATE device show LAN_interface)" = "20 (unavailable)" ]; then
elif [ "$(nmcli -g GENERAL.STATE device show eth0)" = "20 (unavailable)" ]; then
    nmcli radio wifi on
fi
EOF

#########################
#### Enable Services ####
#########################

## Network
chroot /mnt systemctl enable NetworkManager.service
chroot /mnt systemctl enable iwd.service
# chroot /mnt systemctl enable ssh.service
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
chroot /mnt systemctl --user enable pulseaudio.{socket,service}
#chroot /mnt systemctl --user --now disable pipewire{,-pulse}.{socket,service}
chroot /mnt systemctl --user --now mask pipewire{,-pulse}.{socket,service}

# Allow run as root
# sed -i -e 's/ConditionUser=!root/#ConditionUser=!root/' /mnt/usr/lib/systemd/user/pipewire.socket
# sed -i -e 's/ConditionUser=!root/#ConditionUser=!root/' /mnt/etc/xdg/systemd/user/pipewire-pulse.service
# sed -i -e 's/ConditionUser=!root/#ConditionUser=!root/' /mnt/etc/xdg/systemd/user/sockets.target.wants/pipewire.socket
# sed -i -e 's/ConditionUser=!root/#ConditionUser=!root/' /mnt/etc/xdg/systemd/user/pipewire-pulse.socket
# sed -i -e 's/ConditionUser=!root/#ConditionUser=!root/' /mnt/etc/xdg/systemd/user/default.target.wants/pipewire.service

## Pulseaudio
# chroot /mnt systemctl --user enable pulseaudio

## Tune chrony ##
touch /mnt/etc/chrony.conf
# sed -i -E 's/^(pool[ \t]+.*)$/\1\nserver time.google.com iburst prefer\nserver time.windows.com iburst prefer/g' /mnt/etc/chrony.conf
cat <<\EOF >>/mnt/etc/chrony.conf
server time.windows.com iburst prefer
EOF

## Optimizations ##
chroot /mnt systemctl enable earlyoom.service
# chroot /mnt systemctl enable powertop.service
chroot /mnt systemctl enable thermald.service
chroot /mnt systemctl enable irqbalance.service

## Update initramfs
chroot /mnt update-initramfs -c -k all

######################
#### Install grub ####
######################

chroot /mnt grub-install --target=x86_64-efi --bootloader-id="Debian" --efi-directory=/boot/efi --no-nvram --removable --recheck

#####################
#### Config Grub ####
#####################

cat <<EOF >/mnt/etc/default/grub
#
# Configuration file for GRUB.
#
GRUB_DEFAULT=0
#GRUB_HIDDEN_TIMEOUT=0
#GRUB_HIDDEN_TIMEOUT_QUIET=false
GRUB_TIMEOUT=2
# GRUB_DISTRIBUTOR=$(lsb_release -i -s 2>/dev/null || echo Debian)
GRUB_DISTRIBUTOR="Debian"
# GRUB_CMDLINE_LINUX_DEFAULT="quiet splash apparmor=1 security=apparmor kernel.unprivileged_userns_clone vt.global_cursor_default=0 loglevel=0 gpt init_on_alloc=0 udev.log_level=0 rd.driver.blacklist=grub.nouveau rcutree.rcu_idle_gp_delay=1 intel_iommu=on,igfx_off nvidia-drm.modeset=1 i915.modeset=1 zswap.enabled=1 zswap.compressor=lz4hc zswap.max_pool_percent=10 zswap.zpool=z3fold mitigations=off nowatchdog msr.allow_writes=on pcie_aspm=force module.sig_unenforce intel_idle.max_cstate=1 cryptomgr.notests initcall_debug net.ifnames=0 no_timer_check noreplace-smp page_alloc.shuffle=1 rcupdate.rcu_expedited=1 tsc=reliable"

GRUB_CMDLINE_LINUX_DEFAULT="quiet splash kernel.unprivileged_userns_clone loglevel=0 gpt init_on_alloc=0 udev.log_level=0 intel_iommu=on intel_iommu=igfx_off i915.enable_psr=0 i915.modeset=1 zswap.enabled=1 zswap.compressor=lz4hc zswap.max_pool_percent=10 zswap.zpool=z3fold mitigations=off nowatchdog msr.allow_writes=on pcie_aspm=force module.sig_unenforce intel_idle.max_cstate=1 cryptomgr.notests initcall_debug no_timer_check noreplace-smp page_alloc.shuffle=1 rcupdate.rcu_expedited=1 tsc=reliable"
# GRUB_CMDLINE_LINUX_DEFAULT="quiet splash apparmor=1 intel_pstate=hwp_only security=apparmor kernel.unprivileged_userns_clone vt.global_cursor_default=0 loglevel=0 gpt init_on_alloc=0 udev.log_level=0 rd.driver.blacklist=grub.nouveau rcutree.rcu_idle_gp_delay=1 intel_iommu=on,igfx_off nvidia-drm.modeset=1 i915.modeset=1 zswap.enabled=1 zswap.compressor=lz4hc zswap.max_pool_percent=10 zswap.zpool=z3fold mitigations=off nowatchdog msr.allow_writes=on pcie_aspm=force module.sig_unenforce intel_idle.max_cstate=1 cryptomgr.notests initcall_debug net.ifnames=0 no_timer_check noreplace-smp page_alloc.shuffle=1 rcupdate.rcu_expedited=1 tsc=reliable"
# Block nouveau driver = rd.driver.blacklist=grub.nouveau rcutree.rcu_idle_gp_delay=1

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
#GRUB_DISABLE_OS_PROBER=false
EOF

# MakeSwap
# touch /mnt/swap/swapfile
# chroot /mnt chmod 600 /swap/swapfile
# chroot /mnt chattr +C /swap/swapfile
# chroot /mnt lsattr /swap/swapfile
# dd if=/dev/zero of=/mnt/swap/swapfile bs=1M count=6144 status=progress
# mkswap /mnt/swap/swapfile
# swapon /mnt/swap/swapfile

# # Add to fstab
#echo " " >> /mnt/etc/fstab
#echo "# Swap" >> /etc/fstab
#SWAP_UUID=$(blkid -s UUID -o value /dev/vda2)
#mount -o defaults,noatime,subvol=@swap ${DRIVE}2 /mnt/swap
#echo "UUID=$SWAP_UUID /swap btrfs defaults,noatime,subvol=@swap 0 0" >> /etc/fstab
#echo "/swapfile      none     swap      sw  0 0" >> /etc/fstab

### Resume from Swap
# mkdir -pv /mnt/tmp
# cd /mnt/tmp
# wget -c https://raw.githubusercontent.com/osandov/osandov-linux/master/scripts/btrfs_map_physical.c
# gcc -O2 -o btrfs_map_physical btrfs_map_physical.c
# ./btrfs_map_physical /mnt/swap/swapfile >btrfs_map_physical.txt
# filefrag -v /mnt/swap/swapfile | awk '$1=="0:" {print substr($4, 1, length($4)-2)}' >/mnt/tmp/resume.txt
# set -e
# RESUME_OFFSET=$(cat /mnt/tmp/resume.txt)
# ROOT_UUID=$(blkid -s UUID -o value /dev/vda2)
# export ROOT_UUID
# export RESUME_OFFSET
# sed -i 's/GRUB_CMDLINE_LINUX=""/GRUB_CMDLINE_LINUX="'"resume=UUID=$ROOT_UUID resume_offset=$RESUME_OFFSET"'"/g' /mnt/etc/default/grub

mkdir -pv /mnt/etc/udev/rules.d/
touch /mnt/etc/udev/rules.d/70-persistent-net.rules
cat <<\EOF > /mnt/etc/udev/rules.d/70-persistent-net.rules
SUBSYSTEM=="net", ACTION=="add", DRIVERS=="?*", ATTR{address}=="e8:4e:06:2e:27:e2" , ATTR{dev_id}=="0x0", ATTR{type}=="1", KERNEL=="wlan*", NAME="wlan0"
EOF

touch /mnt/etc/udev/rules.d/backlight.rules
cat <<\EOF > /mnt/etc/udev/rules.d/backlight.rules
ACTION=="add", SUBSYSTEM=="backlight", RUN+="/bin/chgrp video $sys$devpath/brightness", RUN+="/bin/chmod g+w $sys$devpath/brightness"
EOF

touch /mnt/etc/udev/rules.d/81-backlight.rules
cat <<\EOF > /mnt/etc/udev/rules.d/81-backlight.rules
# Set backlight level to 8
SUBSYSTEM=="backlight", ACTION=="add", KERNEL=="acpi_video0", ATTR{brightness}="8"
EOF

chroot /mnt update-grub

chroot /mnt update-initramfs -c -k all

rm -rf /mnt/vmlinuz.old
rm -rf /mnt/vmlinuz
rm -rf /mnt/initrd.img
rm -rf /mnt/initrd.img.old

# Add pacstall
# bash -c "$(curl -fsSL https://git.io/JsADh || wget -q https://git.io/JsADh -O -)"

# this makes X server run only on your nvidia card considering you have optimus graphics (intel+nvidia)
# cat <<\EOF > /mnt/etc/X11/xorg.conf.d/10-nvidia-drm-outputclass.conf
# Section "OutputClass"
#     Identifier "intel"
#     MatchDriver "i915"
#     Driver "modesetting"
# EndSection

# Section "OutputClass"
#     Identifier "nvidia"
#     MatchDriver "nvidia-drm"
#     Driver "nvidia"
#     Option "AllowEmptyInitialConfiguration"
#     Option "PrimaryGPU" "yes"
#     ModulePath "/usr/lib/nvidia/xorg"
#     ModulePath "/usr/lib/xorg/modules"
# EndSection
# EOF

# cmake -B build \
#   -DCMAKE_RELEASE_TYPE=Release \
#   -D[ENABLE_SYSTEMD=on] -D[USE_BPF_PROC_IMPL=on] [STATIC=on] \
#   -S .
# cmake --build build --target ananicy-cpp
# sudo cmake --install build --component Runtime

# gnome-disk-utilities
# nosuid,nodev,nofail,x-gvfs-show,auto
# https://github.com/fkortsagin/Simple-Debian-Setup

# virt-install \
# --name nixos \
# --boot uefi \
# --ram 8196 \
# --vcpus 4 \
# --network bridge:virbr0 \
# --os-variant nixos-unstable \
# --disk path=/var/lib/libvirt/images/nixos.qcow2,size=100 \
# --console pty,target_type=serial \
# --cdrom ~/Downloads/nixos-minimal-*-x86_64-linux.iso