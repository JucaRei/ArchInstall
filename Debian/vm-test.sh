#!/bin/sh

apt update && apt install debootstrap btrfs-progs lsb-release wget -y

umount -R /dev/vda

CODENAME=$(lsb_release --codename --short)
cat >/etc/apt/sources.list <<HEREDOC
deb https://deb.debian.org/debian/ $CODENAME main contrib non-free
deb-src https://deb.debian.org/debian/ $CODENAME main contrib non-free

deb https://security.debian.org/debian-security $CODENAME-security main contrib non-free
deb-src https://security.debian.org/debian-security $CODENAME-security main contrib non-free

deb https://deb.debian.org/debian/ $CODENAME-updates main contrib non-free
deb-src https://deb.debian.org/debian/ $CODENAME-updates main contrib non-free

deb https://deb.debian.org/debian/ $CODENAME-backports main contrib non-free
deb-src https://deb.debian.org/debian/ $CODENAME-backports main contrib non-free

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

# apt update

# wget -c http://deb.devuan.org/devuan/pool/main/d/debootstrap/debootstrap_1.0.126+nmu1devuan1.tar.gz

#####################################
####Gptfdisk Partitioning example####
#####################################

# -s script call | -a optimal
sgdisk -Z /dev/vda
parted -s -a optimal /dev/vda mklabel gpt

# Create new partition
sgdisk -n 0:0:512MiB /dev/vda
sgdisk -n 0:0:0 /dev/vda

# Change the name of partition
sgdisk -c 1:GRUB /dev/vda
sgdisk -c 2:Debian /dev/vda

# Change Types
sgdisk -t 1:ef00 /dev/vda
sgdisk -t 2:8300 /dev/vda

sgdisk -p /dev/vda

#####################################
##########  FileSystem  #############
#####################################

mkfs.vfat -F32 /dev/vda1 -n "GRUB"
mkfs.btrfs /dev/vda2 -f -L "Debian"

## Volumes vda apenas para testes em vm
set -e
Debian_ARCH="amd64"
BTRFS_OPTS="noatime,ssd,compress-force=zstd:15,space_cache=v2,commit=120,autodefrag,discard=async"
# Mude de acordo com sua partição
mount -o $BTRFS_OPTS /dev/vda2 /mnt

#Cria os subvolumes
btrfs su cr /mnt/@
btrfs su cr /mnt/@home
btrfs su cr /mnt/@snapshots
btrfs su cr /mnt/@var_log
# btrfs su cr /mnt/@swap
btrfs su cr /mnt/@var_cache_apt
umount -v /mnt

# Monta com os valores selecionados
# Lembre-se de mudar os valores de sdX

mount -o $BTRFS_OPTS,subvol=@ /dev/vda2 /mnt
mkdir -pv /mnt/boot/efi
mkdir -pv /mnt/home
mkdir -pv /mnt/.snapshots
mkdir -pv /mnt/var/log
mkdir -pv /mnt/var/cache/apt

mount -o $BTRFS_OPTS,subvol=@home /dev/vda2 /mnt/home
mount -o $BTRFS_OPTS,subvol=@snapshots /dev/vda2 /mnt/.snapshots
mount -o $BTRFS_OPTS,subvol=@var_log /dev/vda2 /mnt/var/log
mount -o $BTRFS_OPTS,subvol=@var_cache_apt /dev/vda2 /mnt/var/cache/apt
mount -t vfat -o noatime,nodiratime /dev/vda1 /mnt/boot/efi

# Check important packages
#dpkg-query -f '${binary:Package} ${Priority}\n' -W \
#   | grep -w 'required\|important'

# debootstrap --include "bash,zsh,wpasupplicant,locales,grub2,wget,curl,ntp,network-manager,dhcpcd5,linux-image-amd64,firmware-linux-free" --arch amd64 chimaera /mnt http://devuan.c3sl.ufpr.br/merged/ chimaera
# debootstrap --include "bash,zsh,iwd,locales,grub2,wget,curl,ntp,network-manager,dhcpcd5,linux-image-amd64,firmware-linux-free" --arch amd64 chimaera /mnt http://devuan.c3sl.ufpr.br/merged/ chimaera
# debootstrap --arch amd64 chimaera /mnt http://devuan.c3sl.ufpr.br/merged/ chimaera
# debootstrap --include=apt,apt-utils,extrepo,cpio,cron,zstd,ca-certificates,perl-openssl-defaults,sudo,neovim,console-setup,dosfstools,console-setup-linux,keyboard-configuration,debian-archive-keyring,locales,locales-all,btrfs-progs,dmidecode,kmod,less,gdisk,gpgv,neovim,ncurses-base,netbase,procps,systemd,systemd-sysv,udev,ifupdown,init,iproute2,iputils-ping,bash,whiptail --arch amd64 bullseye /mnt "http://debian.c3sl.ufpr.br/debian/ bullseye contrib non-free"
debootstrap --variant=minbase --include=apt,apt-utils,extrepo,cpio,cron,zstd,ca-certificates,perl-openssl-defaults,sudo,neovim,initramfs-tools,console-setup,dosfstools,console-setup-linux,keyboard-configuration,debian-archive-keyring,locales,busybox,btrfs-progs,dmidecode,kmod,less,gdisk,gpgv,neovim,ncurses-base,netbase,procps,systemd,systemd-sysv,udev,ifupdown,init,iproute2,iputils-ping,bash,whiptail --arch amd64 bullseye /mnt "http://debian.c3sl.ufpr.br/debian/ bullseye contrib non-free"
# debootstrap --arch=amd64 --include=zstd,locales,btrfs-progs,ca-certificates,sudo,neovim,initramfs-tools,dhcpcd5 bullseye /mnt http://debian.c3sl.ufpr.br/debian/ bullseye
# deb http://debian.c3sl.ufpr.br/debian/ main contrib non-free

# mmdebstrap --variant=minbase --include=apt,apt-utils,extrepo,cpio,cron,zstd,ca-certificates,perl-openssl-defaults,sudo,neovim,initramfs-tools,initramfs-tools-core,dracut,console-setup,dosfstools,console-setup-linux,keyboard-configuration,debian-archive-keyring,locales,locales-all,btrfs-progs,dmidecode,kmod,less,gdisk,gpgv,neovim,ncurses-base,netbase,procps,systemd,systemd-sysv,udev,ifupdown,init,iproute2,iputils-ping,bash,whiptail --arch=amd64 bullseye /mnt "http://debian.c3sl.ufpr.br/debian/ bullseye contrib non-free"

# apt install --yes console-setup locales chrony dosfstools wget dracut efitools efibootmgr sbsigntool python3 tpm2-tools linux-image-amd64 linux-doc systemd-boot systemd-boot-efi mokutil gdisk

# whiptail or dialog
# tasksel-data, debconf-i18n

# ca-certificates

# Repositorios mais rapidos
rm /mnt/etc/apt/sources.list
# mkdir -pv /mnt/etc/apt/sources.d/
touch /mnt/etc/apt/sources.list.d/{debian.list,various.list}

CODENAME=$(lsb_release --codename --short)
# CODENAME=bullseye
cat >/mnt/etc/apt/sources.list.d/debian.list <<HEREDOC
####################
### Debian repos ###
####################

deb https://deb.debian.org/debian/ $CODENAME main contrib non-free
deb-src https://deb.debian.org/debian/ $CODENAME main contrib non-free

deb https://security.debian.org/debian-security $CODENAME-security main contrib non-free
deb-src https://security.debian.org/debian-security $CODENAME-security main contrib non-free

deb https://deb.debian.org/debian/ $CODENAME-updates main contrib non-free
deb-src https://deb.debian.org/debian/ $CODENAME-updates main contrib non-free

deb https://deb.debian.org/debian/ $CODENAME-backports main contrib non-free
deb-src https://deb.debian.org/debian/ $CODENAME-backports main contrib non-free

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

# Disable verification 
# touch /mnt/etc/apt/apt.conf.d/99verify-peer.conf \
# && echo >> /mnt/etc/apt/apt.conf.d/99verify-peer.conf "Acquire { https::Verify-Peer false }"


# Mount points
for dir in dev proc sys run; do
        mount --rbind /$dir /mnt/$dir
        mount --make-rslave /mnt/$dir
done

chroot /mnt apt update
chroot /mnt apt upgrade -y

# copia o arquivo de resolv para o /mnt
# cp -v /etc/resolv.conf /mnt/etc/


#desabilitar algumas coisas
mkdir -pv /mnt/etc/modprobe.d
cat <<EOF >/mnt/etc/modprobe.d/blacklist.conf
# Disable watchdog
install iTCO_wdt /bin/true
install iTCO_vendor_support /bin/true

# Disable nouveau
blacklist nouveau
EOF

touch /mnt/etc/modprobe.d/blacklist-nouveau.conf
cat <<EOF | tee /mnt/etc/modprobe.d/blacklist-nouveau.conf
blacklist nouveau
blacklist lbm-nouveau
options nouveau modeset=0
alias nouveau off
alias lbm-nouveau off
EOF

# Load Modules on early-boot
mkdir -pv /mnt/etc/modprobe.d
touch /mnt/etc/modprobe.d/bbswitch.conf
cat <<EOF >/mnt/etc/modprobe.d/bbswitch.conf
#options bbswitch load_state=0 unload_state=1 
EOF

# Boot Faster with intel
touch /mnt/etc/modprobe.d/i915.conf
cat <<EOF >/mnt/etc/modprobe.d/i915.conf
# options i915 enable_guc=2 enable_fbc=1 enable_dc=4 enable_hangcheck=0 error_capture=0 enable_dp_mst=0 fastboot=1 #parameters may differ
EOF

touch /mnt/etc/modprobe.d/nvidia.conf
cat <<EOF >/mnt/etc/modprobe.d/nvidia.conf
# options nvidia_drm modeset=1
EOF

#Compress
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

chroot /mnt update-initramfs -u

# Config neovim as default editor
chroot /mnt update-alternatives --install /usr/bin/editor editor /usr/bin/nvim 100

# Desabilita instalar recomendados
touch /mnt/etc/apt/apt.conf
cat >/mnt/etc/apt/apt.conf <<HEREDOC
#Recommends are as of now abused in many packages
APT::Install-Recommends "0";
APT::Install-Suggests "0";

### For install testing packages
#APT::Default-Release "testing";
HEREDOC

mkdir -pv /mnt/etc/apt/preferences.d
touch /mnt/etc/apt/preferences.d/preferences
cat >/mnt/etc/apt/preferences.d/preferences <<HEREDOC
### Enable testing software ###

#Package: *
#Pin: release a=testing
#Pin-Priority:500

#Package: *
#Pin: release a=unstable
#Pin-Priority: 50

#Package: *
#Pin: release a=experimental
#Pin-Priority: 50
HEREDOC

# Hostname
cat <<EOF >/mnt/etc/hostname
kvmanager
EOF

# Hosts
touch /mnt/etc/hosts
cat <<\EOF >/mnt/etc/hosts
127.0.0.1 localhost
127.0.1.1 kvmanager

### The following lines are desirable for IPv6 capable hosts
::1     localhost ip6-localhost ip6-loopback
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
EOF

# fstab
UEFI_UUID=$(blkid -s UUID -o value /dev/vda1)
ROOT_UUID=$(blkid -s UUID -o value /dev/vda2)

echo $UEFI_UUID
echo $ROOT_UUID
# echo $SWAP_UUID
# echo $HOME_UUID

touch /mnt/etc/fstab
cat <<EOF >/mnt/etc/fstab
# <file system> <dir> <type> <options> <dump> <pass>

### ROOTFS ###
UUID=$ROOT_UUID   /               btrfs rw,$BTRFS_OPTS,subvol=@                         0 0
UUID=$ROOT_UUID   /.snapshots     btrfs rw,$BTRFS_OPTS,subvol=@snapshots                0 0
UUID=$ROOT_UUID   /var/log        btrfs rw,$BTRFS_OPTS,subvol=@var_log                  0 0
UUID=$ROOT_UUID   /var/cache/apt  btrfs rw,$BTRFS_OPTS,subvol=@var_cache_apt            0 0

### HOME_FS ###
# UUID=$HOME_UUID /home           btrfs rw,$BTRFS_OPTS,subvol=@home                     0 0
UUID=$ROOT_UUID   /home           btrfs rw,$BTRFS_OPTS,subvol=@home                     0 0

### EFI ###
# UUID=$UEFI_UUID /boot/efi       vfat rw,noatime,nodiratime,umask=0077,fmask=0022,dmask=0022,codepage=437,iocharset=iso8859-1,shortname=mixed,utf8,errors=remount-ro  0 2
UUID=$UEFI_UUID   /boot/efi       vfat noatime,nodiratime,umask=0077        0 2

### Swap ###
#UUID=$SWAP_UUID  none            swap defaults,noatime                                 0 0

### Tmp ###
# tmpfs         /tmp              tmpfs defaults,nosuid,nodev,noatime                   0 0
tmpfs           /tmp              tmpfs noatime,mode=1777,nosuid,nodev                  0 0
EOF

# antix-archive-keyring
# Locales
chroot /mnt echo "America/Sao_Paulo" >/mnt/etc/timezone && \
        dpkg-reconfigure -f noninteractive tzdata && \
        sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
        sed -i -e 's/# pt_BR.UTF-8 UTF-8/pt_BR.UTF-8 UTF-8/' /etc/locale.gen && \
        echo 'LANG="en_US.UTF-8"' >/etc/default/locale && \
        # export LC_ALL=C && \
        export LANGUAGE=en_US.UTF-8 && \
        export LC_ALL=en_US.UTF-8 && \
        export LANG=en_US.UTF-8 && \
        export LC_CTYPE=en_US.UTF-8 && \
        # locale-gen en_US.UTF-8 && \
        echo 'KEYMAP="br-abnt2"' >/etc/vconsole.conf
        #dpkg-reconfigure --frontend=noninteractive locales && \
        # update-locale LANG=en_US.UTF-8 && \
        # localedef -i en_US -f UTF-8 en_US.UTF-8 && \
        #localectl set-locale LANG="en_US.UTF-8"
        # update-locale LANG=en_US.UTF-8 && \
        # localedef -i en_US -f UTF-8 en_US.UTF-8

chroot /mnt apt update

# Network
chroot /mnt apt install prettyping net-tools arp-scan gvfs gvfs-backends nfs-common smbclient cifs-utils avahi-daemon firmware-realtek firmware-linux-nonfree firmware-linux-free firmware-iwlwifi network-manager iwd rfkill --no-install-recommends -y

# Config iwd as backend instead of wpasupplicant
cat <<EOF >/mnt/etc/NetworkManager/conf.d/iwd.conf
[device]
wifi.backend=iwd
wifi.iwd.autoconnect=yes
EOF

# Config iwd
mkdir -pv /mnt/etc/iwd
touch /mnt/etc/iwd/main.conf
cat <<EOF >/mnt/etc/iwd/main.conf
[General]
EnableNetworkConfiguration=true

[Network]
NameResolvingService=systemd
RouterPriorityOffset=30
EOF

### Pulseaudio
# chroot /mnt apt install bluetooth rfkill bluez bluez-tools pulseaudio-module-bluetooth pavucontrol --no-install-recommends -y

#### Pipewire ####
# Audio, Bluetooth
chroot /mnt apt install pipewire pipewire-pulse bluez bluez-tools gstreamer1.0-pipewire libspa-0.2-bluetooth libspa-0.2-jack pipewire-audio-client-libraries -y

# Config pipewire
touch /mnt/etc/pipewire/media-session.d/with-pulseaudio
cp /mnt/usr/share/doc/pipewire/examples/systemd/user/pipewire-pulse.* /mnt/etc/systemd/user/

# ssh
chroot /mnt apt install openssh-client openssh-server --no-install-recommends -y

# Utils
chroot /mnt apt install aptitude apt-show-versions rsyslog manpages acpid hwinfo lshw lshw-gtk dkms btrfs-compsize pciutils linux-image-amd64 linux-headers-amd64 fonts-firacode debian-keyring make libssl-dev libreadline-dev libffi-dev liblzma-dev xz-utils llvm git gnupg lolcat libncursesw5-dev libsqlite3-dev libxml2-dev libxmlsec1-dev zlib1g-dev libbz2-dev build-essential htop grub-efi-amd64 os-prober wget unzip curl sysfsutils chrony --no-install-recommends -y
# aptitude initramfs-tools firmware-linux
# dracut --list-modules --kver 5.10.0-20-amd64
# apt install linux-headers-$(uname -r|sed 's/[^-]*-[^-]*-//')

cat << EOF > /mnt/etc/initramfs-tools/modules
# List of modules that you want to include in your initramfs.
# They will be loaded at boot time in the order below.
#
# Syntax:  module_name [args ...]
#
# You must run update-initramfs(8) to effect this change.
#
# Examples:
#
# raid1
# sd_mod
crc32c-intel
btrfs
# drm
ahci
lz4hc
lz4hc_compress
zstd
zram
z3fold
# i915.modeset=1
# intel_agp
# nvidia-drm.modeset=1
# nvidia-drm
EOF

# chroot /mnt update-initramfs -u

# cat <<EOF >/mnt/etc/dracut.conf.d/10-debian.conf
# hostonly="yes"
# hostonly_cmdline=no
# dracutmodules+=" dash bash systemd kernel-modules rootfs-block btrfs udev-rules resume usrmount base fs-lib shutdown "
# use_fstab=yes

# ### Bare
# # add_drivers+=" crc32c-intel btrfs i915 ahci nvidia nvidia_drm nvidia_uvm nvidia_modeset "

# ### VM's
# add_drivers+=" crc32c-intel btrfs "
# force_drivers+=" z3fold "
# omit_dracutmodules+=" i18n luks rpmversion lvm fstab-sys lunmask fstab-sys securityfs img-lib biosdevname caps crypt crypt-gpg dmraid dmsquash-live mdraid "
# show_modules="yes"
# do_prelink=no
# # compress="cat";
# nofscks=yes
# compress="zstd"
# # compress="lz4hc -l -9"
# no_host_only_commandline=yes
# EOF

# Early micro code
# cat <<EOF >/mnt/etc/dracut.conf.d/intel_ucode.conf
# early_microcode=yes
# EOF

#cat <<EOF >/mnt/etc/dracut.conf.d/cmdline.conf
#kernel_cmdline="loglevel=0 console=tty2 gpt init_on_alloc=0 udev.log_level=0 intel_iommu=on,igfx_off zswap.enabled=1 zswap.compressor=lz4hc zswap.max_pool_percent=10 zswap.zpool=z3fold mitigations=off nowatchdog msr.allow_writes=on pcie_aspm=force module.sig_unenforce intel_idle.max_cstate=1 cryptomgr.notests initcall_debug net.ifnames=0 no_timer_check noreplace-smp page_alloc.shuffle=1 rcupdate.rcu_expedited=1 tsc=reliable"
#EOF

# cat <<EOF >/mnt/etc/dracut.conf.d/10-zram.conf
# # add_drivers+=" zram "
# EOF

# cat <<EOF >/mnt/etc/dracut.conf.d/10-lz4.conf
# add_drivers+=" lz4 lz4hc lz4hc_compress "
# EOF

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

# Tools
chroot /mnt apt install colord bash-completion bzip2 man-db gdisk dosfstools mtools p7zip neofetch fzf duf bat unattended-upgrades --no-install-recommends -y

# Optimizations
chroot /mnt apt install earlyoom powertop tlp thermald irqbalance --no-install-recommends -y

# zsh stterm rxvt-unicode-256color

# Microcode
# chroot /mnt apt install intel-microcode --no-install-recommends -y

# intel Hardware Acceleration
# chroot /mnt apt install intel-media-va-driver-non-free vainfo intel-gpu-tools gstreamer1.0-vaapi --no-install-recommends -y

# Nvidia Drivers with Cuda
# chroot /mnt apt install nvidia-driver nvidia-kernel-dkms nvidia-smi nvidia-settings nvidia-xconfig nvidia-persistenced libnvcuvid1 libnvidia-encode1 firmware-misc-nonfree --no-install-recommends -y
# primus primus-vk-nvidia nvidia-vaapi-driver
# chroot /mnt apt install xserver-xorg-video-nvidia-tesla-470 nvidia-tesla-470-smi nvidia-tesla-470-driver-bin nvidia-tesla-470-alternative libnvidia-tesla-470-cfg1 libnvidia-tesla-470-encode1 libnvidia-tesla-470-nvcuvid1 nvidia-tesla-470-driver-libs nvidia-tesla-470-kernel-dkms nvidia-tesla-470-driver firmware-misc-nonfree \
# glx-alternative-mesa glx-alternative-nvidia glx-diversions libegl-nvidia-tesla-470-0 libgl1-nvidia-tesla-470-glvnd-glx libgles-nvidia-tesla-470-1 libgles-nvidia-tesla-470-2 \
# libgles1 libgles2 libglx-nvidia-tesla-470-0 libnvidia-egl-wayland1 libnvidia-tesla-470-cbl libnvidia-tesla-470-cfg1 libnvidia-tesla-470-cuda1 libnvidia-tesla-470-eglcore \
# libnvidia-tesla-470-encode1 libnvidia-tesla-470-glcore libnvidia-tesla-470-glvkspirv libnvidia-tesla-470-ml1 libnvidia-tesla-470-nvcuvid1 libnvidia-tesla-470-ptxjitcompiler1 \
# libnvidia-tesla-470-rtcore libopengl0 nvidia-egl-common nvidia-installer-cleanup nvidia-kernel-common nvidia-modprobe nvidia-persistenced nvidia-settings-tesla-470 nvidia-support \
# nvidia-tesla-470-alternative nvidia-tesla-470-driver nvidia-tesla-470-driver-bin nvidia-tesla-470-driver-libs nvidia-tesla-470-egl-icd nvidia-tesla-470-kernel-dkms \
# nvidia-tesla-470-kernel-support nvidia-tesla-470-smi nvidia-tesla-470-vdpau-driver nvidia-tesla-470-vulkan-icd nvidia-vulkan-common update-glx xserver-xorg-video-nvidia-tesla-470 -y

mkdir -pv /mnt/etc/X11/xorg.conf.d
touch /mnt/etc/X11/xorg.conf.d/30-nvidia.conf
cat << EOF > /mnt/etc/X11/xorg.conf.d/30-nvidia.conf
# Section "Device"
#     Identifier "Nvidia GTX 1050"
#     Driver "nvidia"
#     BusID "PCI:1:0:0"
#     Option "DPI" "96 x 96"
#     Option "AllowEmptyInitialConfiguration" "Yes"
#     #  Option "UseDisplayDevice" "none"
# EndSection
EOF

# Fix tearing with intel
touch /mnt/etc/X11/xorg.conf.d/20-modesetting.conf
cat <<EOF >/mnt/etc/X11/xorg.conf.d/20-modesetting.conf
#Section "Device"
#   Identifier "Intel Graphics 630"
#   Driver "intel"
#   Option "AccelMethod" "sna"
#   Option "TearFree" "True"
#   Option "Tiling" "True"
#   Option "SwapbuffersWait" "True"
#   Option "DRI" "3"
#
#    Identifier  "Intel Graphics"
#    Driver      "modesetting"
#    Option      "TearFree"       "True"
#    Option      "AccelMethod"    "glamor"
#    Option      "DRI"            "3"
#EndSection
EOF

touch /mnt/etc/rc.local
cat <<EOF >/mnt/etc/rc.local
#PowerTop
powertop --auto-tune
EOF

# Minimal xorg packages
chroot /mnt apt install xserver-xorg-core xserver-xorg-input-evdev xserver-xorg-input-libinput xserver-xorg-input-kbd x11-xserver-utils x11-xkb-utils x11-utils xinit xinput --no-install-recommends -y
# xserver-xorg-video-intel

# Infrastructure packages
chroot /mnt apt install python3 python3-pip snapd flatpak spice-vdagent gir1.2-spiceclientgtk-3.0 ovmf ovmf-ia32 dnsmasq ipset ansible libguestfs0 virt-viewer qemu qemu-system qemu-utils qemu-system-gui vde2 uml-utilities virtinst virt-manager bridge-utils libvirt-daemon-system podman --no-install-recommends -y

# Plymouth
chroot /mnt apt install plymouth plymouth-themes --no-install-recommends -y
chroot /mnt plymouth-set-default-theme -R solar

mkdir -pv /mnt/etc/plymouth
touch /mnt/etc/plymouth/plymouth.conf
cat <<EOF >/mnt/etc/plymouth/plymouth.conf
# Administrator customizations go in this file
[Daemon]
Theme=solar
ShowDelay=5
EOF


# Umount
# for dir in dev proc sys run; do
#         umount --rbind /$dir /mnt/$dir
#         umount --make-rslave /mnt/$dir
# done

# copia o arquivo de resolv para o /mnt
# cp -v /etc/resolv.conf /mnt/etc/

cat <<EOF >/mnt/etc/resolv.conf
nameserver 8.8.8.8
nameserver 8.8.4.4
nameserver 1.1.1.1
EOF

mkdir -pv /mnt/etc/default/
touch /mnt/etc/default/keyboard
cat << EOF > /mnt/etc/default/keyboard
# KEYBOARD CONFIGURATION FILE

# Consult the keyboard(5) manual page.

XKBMODEL="pc105"
XKBLAYOUT="br"
XKBVARIANT=""
XKBOPTIONS="terminate:ctrl_alt_bksp"
EOF

# Locales
chroot /mnt echo "America/Sao_Paulo" >/etc/timezone && \
        #dpkg-reconfigure -f noninteractive tzdata && \
        #sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
        #sed -i -e 's/# pt_BR.UTF-8 UTF-8/pt_BR.UTF-8 UTF-8/' /etc/locale.gen && \
        echo 'LANGUAGE="en_US.UTF-8"' >/etc/default/locale && \
        export LANGUAGE=en_US.UTF-8 && \
        export LC_ALL=en_US.UTF-8 && \
        dpkg-reconfigure --frontend noninteractive keyboard-configuration && \
        echo 'KEYMAP="br-abnt2"' >/etc/vconsole.conf
        #dpkg-reconfigure --frontend=noninteractive locales && \
        #update-locale LANG=en_US.UTF-8
        #localedef -i en_US -f UTF-8 en_US.UTF-8

# setxkbmap -model pc105 -layout br -variant abnt2 &
# dpkg-reconfigure keyboard-configuration
# udevadm trigger --subsystem-match=input --action=change

# Set bash as default
chroot /mnt chsh -s /usr/bin/bash root

# install sudo
chroot /mnt apt install sudo -y

# Define user and root password
chroot /mnt sh -c 'echo "root:200291" | chpasswd -c SHA512'
chroot /mnt useradd juca -m -c "Reinaldo P JR" -s /bin/bash
chroot /mnt sh -c 'echo "juca:200291" | chpasswd -c SHA512'
chroot /mnt usermod -aG floppy,audio,video,kvm,lp,cdrom,netdev,input,libvirt,kvm juca
chroot /mnt usermod -aG sudo juca
# chroot /mnt usermod -aG wheel,floppy,audio,video,optical,kvm,lp,storage,cdrom,xbuilder,input juca
# chroot /mnt sed -i 's/^#\s*\(%wheel\s*ALL=(ALL)\)/\1/' /etc/sudoers
# chroot /mnt sed -i 's/^#\s*\(%wheel\s*ALL=(ALL)\s*NOPASSWD:\s*ALL\)/\1/' /etc/sudoers
# chroot /mnt usermod -a -G socklog juca

## NetworkManager config
cat << EOF > /mnt/etc/NetworkManager/NetworkManager.conf
[main]
plugins=ifupdown,keyfile

[ifupdown]
managed=true
EOF

touch /mnt/etc/NetworkManager/dispatcher.d/wlan_auto_toggle.sh
chroot /mnt chmod +x /etc/NetworkManager/dispatcher.d/wlan_auto_toggle.sh
cat << EOF > /mnt/etc/NetworkManager/dispatcher.d/wlan_auto_toggle.sh
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

### Services
#Network
chroot /mnt systemctl enable NetworkManager.service
chroot /mnt systemctl enable iwd.service
chroot /mnt systemctl enable ssh.service
# chroot /mnt systemctl enable --user pulseaudio.service
chroot /mnt systemctl enable chrony.service
chroot /mnt systemctl enable fstrim.timer


# Audio
chroot /mnt systemctl --user enable pipewire pipewire-pulse
# chroot /mnt systemctl --user daemon-reload

# chroot /mnt systemctl --user --now disable pulseaudio.service pulseaudio.socket

# chroot /mnt systemctl --user mask pulseaudio
# Allow run as root
# sed -i -e 's/ConditionUser=!root/#ConditionUser=!root/' /mnt/usr/lib/systemd/user/pipewire.socket
# sed -i -e 's/ConditionUser=!root/#ConditionUser=!root/' /mnt/etc/xdg/systemd/user/pipewire-pulse.service
# sed -i -e 's/ConditionUser=!root/#ConditionUser=!root/' /mnt/etc/xdg/systemd/user/sockets.target.wants/pipewire.socket
# sed -i -e 's/ConditionUser=!root/#ConditionUser=!root/' /mnt/etc/xdg/systemd/user/pipewire-pulse.socket
# sed -i -e 's/ConditionUser=!root/#ConditionUser=!root/' /mnt/etc/xdg/systemd/user/default.target.wants/pipewire.service
#Audio user setting

# chroot /mnt systemctl --user enable pipewire pipewire-pulse

# chroot /mnt systemctl --user --now enable pipewire pipewire-pulse
# check witch server is in use
# LANG=C pactl info | grep '^Server Name'

# Tune chrony
chroot /mnt touch /etc/chrony.conf
# sed -i -E 's/^(pool[ \t]+.*)$/\1\nserver time.google.com iburst prefer\nserver time.windows.com iburst prefer/g' /mnt/etc/chrony.conf
cat <<EOF >/mnt/etc/chrony.conf 
server time.windows.com iburst prefer
EOF

# Optimizations
chroot /mnt systemctl enable earlyoom.service
# chroot /mnt systemctl enable powertop.service
chroot /mnt systemctl enable thermald.service
chroot /mnt systemctl enable irqbalance.service

chroot /mnt update-initramfs -u

chroot /mnt grub-install --target=x86_64-efi --bootloader-id="Debian" --efi-directory=/boot/efi --no-nvram --removable --recheck

# GRUB_CMDLINE_LINUX_DEFAULT="quiet loglevel=0 vt.global_cursor_default==0 console=tty2 gpt acpi_osi=Darwin acpi_mask_gpe=0x06 init_on_alloc=0 udev.log_level=0 intel_iommu=on,igfx_off zswap.enabled=1 zswap.compressor=lz4hc zswap.max_pool_percent=10 zswap.zpool=z3fold mitigations=off nowatchdog msr.allow_writes=on pcie_aspm=force module.sig_unenforce intel_idle.max_cstate=1 cryptomgr.notests initcall_debug net.ifnames=0 no_timer_check noreplace-smp page_alloc.shuffle=1 rcupdate.rcu_expedited=1 tsc=reliable"

cat <<EOF >/mnt/etc/default/grub
#
# Configuration file for GRUB.
#
GRUB_DEFAULT=0
#GRUB_HIDDEN_TIMEOUT=0
#GRUB_HIDDEN_TIMEOUT_QUIET=false
GRUB_TIMEOUT=2
# GRUB_DISTRIBUTOR=`lsb_release -i -s 2> /dev/null || echo Debian`
GRUB_DISTRIBUTOR="Debian"
# GRUB_CMDLINE_LINUX_DEFAULT="quiet splash vt.global_cursor_default=0 loglevel=0 gpt init_on_alloc=0 udev.log_level=0 rd.driver.blacklist=grub.nouveau rcutree.rcu_idle_gp_delay=1 intel_iommu=on,igfx_off nvidia-drm.modeset=1 i915.modeset=1 zswap.enabled=1 zswap.compressor=lz4hc zswap.max_pool_percent=10 zswap.zpool=z3fold mitigations=off nowatchdog msr.allow_writes=on pcie_aspm=force module.sig_unenforce intel_idle.max_cstate=1 cryptomgr.notests initcall_debug net.ifnames=0 no_timer_check noreplace-smp page_alloc.shuffle=1 rcupdate.rcu_expedited=1 tsc=reliable"
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash vt.global_cursor_default=0 loglevel=0 gpt init_on_alloc=0 udev.log_level=0 zswap.enabled=1 zswap.compressor=lz4hc zswap.max_pool_percent=10 zswap.zpool=z3fold mitigations=off nowatchdog msr.allow_writes=on pcie_aspm=force module.sig_unenforce intel_idle.max_cstate=1 cryptomgr.notests initcall_debug net.ifnames=0 no_timer_check noreplace-smp page_alloc.shuffle=1 rcupdate.rcu_expedited=1 tsc=reliable"

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
GRUB_DISABLE_OS_PROBER=false
EOF

chroot /mnt update-grub

# chroot /mnt dracut --force --hostonly --kver 5.10.0-21-amd64
# chroot /mnt dracut --force --hostonly /boot/initramfs-5.10.0-21-amd64.img 5.10.0-21-amd64
# chroot /mnt dracut --force --hostonly /boot/initramfs-5.10.0-21-amd64-fallback.img 5.10.0-21-amd64


# chroot /mnt dracut --force --hostonly --kver 5.10.0-21-amd64

chroot /mnt update-initramfs -u

rm -rf /mnt/vmlinuz.old
rm -rf /mnt/vmlinuz
rm -rf /mnt/initrd.img
rm -rf /mnt/initrd.img.old

touch /mnt/home/juca/.xsessionrc
cat << EOF > /mnt/home/juca/.xsessionrc
#xrandr --setprovideroutputsource NVIDIA-G0 modesetting
EOF

chroot /mnt chmod +x /home/juca/.xsessionrc
chroot /mnt chown -R juca:juca /home/juca/.xsessionrc

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

# if X Server 'Crashes' while opening electron/chromium based programs or Chromium/Electron based Windows open up as black through prime-run or on nVidia cards then do this:
# using this flag --use-gl=desktop works
# hardware acceleration also works this way (electron apps only) 

# cmake -B build \
#   -DCMAKE_RELEASE_TYPE=Release \
#   -D[ENABLE_SYSTEMD=on] -D[USE_BPF_PROC_IMPL=on] [STATIC=on] \
#   -S .
# cmake --build build --target ananicy-cpp
# sudo cmake --install build --component Runtime
