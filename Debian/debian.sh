#!/bin/sh


apt update && apt install debootstrap btrfs-progs wget -y

# wget -c http://deb.devuan.org/devuan/pool/main/d/debootstrap/debootstrap_1.0.126+nmu1devuan1.tar.gz

#####################################
####Gptfdisk Partitioning example####
#####################################

# -s script call | -a optimal
# sgdisk -Z /dev/sda
# parted -s -a optimal /dev/sda mklabel gpt

# Create new partition
# sgdisk -n 0:0:100MiB /dev/sda
# sgdisk -n 0:0:0 /dev/sda

# Change the name of partition
# sgdisk -c 1:Deboot /dev/sda
# sgdisk -c 2:Debian /dev/sda

# Change Types
# sgdisk -t 1:ef00 /dev/sda
# sgdisk -t 2:8300 /dev/sda

# sgdisk -p /dev/sda

#####################################
##########  FileSystem  #############
#####################################

mkfs.vfat -F32 /dev/sda1 -n "Grub"
mkfs.btrfs /dev/sda2 -f -L "Debian"

## Volumes Vda apenas para testes em vm
set -e
Debian_ARCH="amd64"
BTRFS_OPTS="noatime,ssd,compress-force=zstd:15,space_cache=v2,commit=120,autodefrag,discard=async"
# Mude de acordo com sua partição
mount -o $BTRFS_OPTS /dev/sda2 /mnt

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

mount -o $BTRFS_OPTS,subvol=@ /dev/sda2 /mnt
mkdir -pv /mnt/boot/efi
mkdir -pv /mnt/home
mkdir -pv /mnt/.snapshots
mkdir -pv /mnt/var/log
mkdir -pv /mnt/var/cache/apt

mount -o $BTRFS_OPTS,subvol=@home /dev/sda2 /mnt/home
mount -o $BTRFS_OPTS,subvol=@snapshots /dev/sda2 /mnt/.snapshots
mount -o $BTRFS_OPTS,subvol=@var_log /dev/sda2 /mnt/var/log
mount -o $BTRFS_OPTS,subvol=@var_cache_apt /dev/sda2 /mnt/var/cache/apt
mount -t vfat -o noatime,nodiratime /dev/sda1 /mnt/boot/efi 


# Check important packages
#dpkg-query -f '${binary:Package} ${Priority}\n' -W \
#   | grep -w 'required\|important'


# debootstrap --include "bash,zsh,wpasupplicant,locales,grub2,wget,curl,ntp,network-manager,dhcpcd5,linux-image-amd64,firmware-linux-free" --arch amd64 chimaera /mnt http://devuan.c3sl.ufpr.br/merged/ chimaera
# debootstrap --include "bash,zsh,iwd,locales,grub2,wget,curl,ntp,network-manager,dhcpcd5,linux-image-amd64,firmware-linux-free" --arch amd64 chimaera /mnt http://devuan.c3sl.ufpr.br/merged/ chimaera
# debootstrap --arch amd64 chimaera /mnt http://devuan.c3sl.ufpr.br/merged/ chimaera
debootstrap --variant=minbase --include=apt,apt-utils,cpio,cron,console-setup,dosfstools,keyboard-configuration,debian-archive-keyring,zstd,locales,btrfs-progs,dmidecode,kmod,less,gdisk,gpgv,neovim,ncurses-base,netbase,procps,systemd,systemd-sysv,udev,ifupdown,init,iproute2,iputils-ping,bash,whiptail,ca-certificates --arch amd64 bullseye /mnt http://debian.c3sl.ufpr.br/debian/ bullseye
# deb http://debian.c3sl.ufpr.br/debian/ main contrib non-free

# apt install --yes console-setup locales chrony dosfstools wget dracut efitools efibootmgr sbsigntool python3 tpm2-tools linux-image-amd64 linux-doc systemd-boot systemd-boot-efi mokutil gdisk

# whiptail or dialog 
# tasksel-data, debconf-i18n


# ca-certificates

# Mount points
for dir in dev proc sys run; do
        mount --rbind /$dir /mnt/$dir
        mount --make-rslave /mnt/$dir
done

# Config neovim as default editor
chroot /mnt update-alternatives --install /usr/bin/editor editor /usr/bin/nvim 100

# Desabilita instalar recomendados
touch /mnt/etc/apt/apt.conf
cat > /mnt/etc/apt/apt.conf << HEREDOC
#Recommends are as of now abused in many packages
APT::Install-Recommends "0";
APT::Install-Suggests "0";
HEREDOC

# Repositorios mais rapidos
rm /mnt/etc/apt/sources.list
# mkdir -pv /mnt/etc/apt/sources.d/
touch /mnt/etc/apt/sources.list.d/{debian.list,various.list}

apt install lsb-release
CODENAME=$(lsb_release --codename --short)
cat > /mnt/etc/apt/sources.list.d/debian.list << HEREDOC
deb https://deb.debian.org/debian/ $CODENAME main contrib non-free
deb-src https://deb.debian.org/debian/ $CODENAME main contrib non-free

deb https://security.debian.org/debian-security $CODENAME-security main contrib non-free
deb-src https://security.debian.org/debian-security $CODENAME-security main contrib non-free

deb https://deb.debian.org/debian/ $CODENAME-updates main contrib non-free
deb-src https://deb.debian.org/debian/ $CODENAME-updates main contrib non-free
HEREDOC

# Hostname
HOSTNAME=debian
cat <<EOF >/mnt/etc/hostname
$HOSTNAME
EOF

# Hosts
touch /mnt/etc/hosts
cat << EOF > /etc/hosts
127.0.0.1 localhost
127.0.1.1 $HOSTNAME

# The following lines are desirable for IPv6 capable hosts
::1     localhost ip6-localhost ip6-loopback
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
EOF

# fstab
UEFI_UUID=$(blkid -s UUID -o value /dev/sda1)
ROOT_UUID=$(blkid -s UUID -o value /dev/sda2)

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
UUID=$ROOT_UUID   /var/cache/apt  btrfs rw,$BTRFS_OPTS,subvol=@var_cache_xbps           0 0

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
tmpfs           /tmp              tmpfs noatime,mode=1777,nosuid                        0 0
EOF

# antix-archive-keyring
# Locales
chroot /mnt echo "America/Sao_Paulo" > /mnt/etc/timezone && \
                dpkg-reconfigure -f noninteractive tzdata && \
                sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
                sed -i -e 's/# pt_BR.UTF-8 UTF-8/pt_BR.UTF-8 UTF-8/' /etc/locale.gen && \
                echo 'LANG="en_US.UTF-8"'>/etc/default/locale && \
                export LC_ALL=C && \
                dpkg-reconfigure --frontend=noninteractive locales && \
                update-locale LANG=en_US.UTF-8 && \
                localedef -i en_US -f UTF-8 en_US.UTF-8



chroot /mnt apt update

# Network
chroot /mnt apt install network-manager iwd rfkill --no-install-recommends -y

# Config iwd as backend instead of wpasupplicant
cat << EOF > /mnt/etc/NetworkManager/conf.d/iwd.conf 
[device]
wifi.backend=iwd
EOF

# Audio, Bluetooth 
chroot /mnt apt install pipewire libspa-0.2-bluetooth libspa-0.2-jack pipewire-audio-client-libraries --no-install-recommends -y

# Config pipewire
touch /mnt/etc/pipewire/media-session.d/with-pulseaudio
cp /mnt/usr/share/doc/pipewire/examples/systemd/user/pipewire-pulse.* /mnt/etc/systemd/user/

# ssh
chroot /mnt apt install openssh-client openssh-server --no-install-recommends -y

# Utils
chroot /mnt apt install dracut manpages debian-keyring build-essential grub-efi-amd64 efibootmgr os-prober wget curl sysfsutils chrony network-manager iwd linux-image-amd64 linux-headers-amd64 firmware-linux --no-install-recommends -y
# aptitude initramfs-tools
# dracut --list-modules --kver 5.10.0-20-amd64

cat <<EOF >/mnt/etc/dracut.conf.d/10-debian.conf
hostonly="yes"
hostonly_cmdline=no
dracutmodules+=" bash systemd kernel-modules rootfs-block btrfs udev-rules resume usrmount base fs-lib shutdown "
use_fstab=yes
# add_drivers+=" crc32c-intel btrfs i915 ahci nvidia nvidia_drm nvidia_uvm nvidia_modeset "
add_drivers+=" crc32c-intel btrfs i915 nvidia nvidia_drm nvidia_uvm nvidia_modeset "
force_drivers+=" z3fold "
omit_dracutmodules+=" i18n luks rpmversion lvm fstab-sys lunmask fstab-sys securityfs img-lib biosdevname caps crypt crypt-gpg dmraid dmsquash-live mdraid "
show_modules="yes"
do_prelink=no
# compress="cat";
nofscks=yes
#compress="zstd"
compress="lz4 -l -9"
no_host_only_commandline=yes
EOF

# Early micro code
cat <<EOF >/mnt/etc/dracut.conf.d/intel_ucode.conf
early_microcode=yes
EOF

cat <<EOF >/mnt/etc/dracut.conf.d/10-zram.conf
# add_drivers+=" zram "
EOF

cat <<EOF >/mnt/etc/dracut.conf.d/10-lz4.conf
add_drivers+=" lz4hc lz4hc_compress "
EOF

# Load Modules on early-boot
mkdir -pv /mnt/etc/modprobe.d
touch /mnt/etc/modprobe.d/bbswitch.conf
cat <<EOF >/mnt/etc/modprobe.d/bbswitch.conf
#options bbswitch load_state=0 unload_state=1 
EOF

#Compress
mkdir -pv /mnt/etc/sysctl.d
cat <<EOF >/mnt/etc/sysctl.d/00-swap.conf
vm.vfs_cache_pressure=500
vm.swappiness=100
vm.dirty_background_ratio=1
vm.dirty_ratio=50
EOF

cat <<EOF >/mnt/etc/sysctl.d/00-intel.conf
# Intel Graphics
dev.i915.perf_stream_paranoid=0
EOF

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
chroot /mnt apt install bash-completion bzip2 man-db gdisk dosfstools mtools p7zip neofetch fzf bat duf --no-install-recommends -y

# Optimizations
chroot /mnt apt install earlyoom powertop thermald irqbalance --no-install-recommends -y


# zsh stterm rxvt-unicode-256color

# Microcode
chroot /mnt apt install intel-microcode --no-install-recommends -y

# intel Hardware Acceleration
chroot /mnt apt install intel-media-driver-non-free --no-install-recommends -y

# Nvidia Drivers
chroot /mnt apt install nvidia-driver libnvcuvid1 libnvidia-encode1 firmware-misc-nonfree --no-install-recommends -y

# Minimal xorg packages
chroot /mnt apt install xserver-xorg-core xserver-xorg-video-intel xserver-xorg-input-evdev x11-xserver-utils x11-xkb-utils x11-utils xinit --no-install-recommends -y

# Infrastructure packages
chroot /mnt apt install ansible virt-manager bridge-utils qemu qemu-ga qemu-user-static qemuconf podman podman-compose binfmt-support containers.image buildah slirp4netns cni-plugins fuse-overlayfs --no-install-recommends -y

 
# Umount
# for dir in dev proc sys run; do
#         umount --rbind /$dir /mnt/$dir
#         umount --make-rslave /mnt/$dir
# done

# copia o arquivo de resolv para o /mnt
# cp -v /etc/resolv.conf /mnt/etc/

cat <<EOF > /mnt/etc/resolv.conf 
nameserver 8.8.8.8
nameserver 8.8.4.4
nameserver 1.1.1.1
EOF

# Locales
chroot /mnt echo "America/Sao_Paulo" > /mnt/etc/timezone && \
                dpkg-reconfigure -f noninteractive tzdata && \
                sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
                sed -i -e 's/# pt_BR.UTF-8 UTF-8/pt_BR.UTF-8 UTF-8/' /etc/locale.gen && \
                echo 'LANGUAGE="en_US.UTF-8"'>/mnt/etc/default/locale && \
                export LANGUAGE=en_US.UTF-8 && \
                export LC_ALL=en_US.UTF-8 && \
                echo 'KEYMAP="br-abnt2"' > /etc/vconsole.conf && \ 
                dpkg-reconfigure --frontend=noninteractive locales && \
                update-locale LANG=en_US.UTF-8 && \
                localedef -i en_US -f UTF-8 en_US.UTF-8


# Set bash as default
chroot /mnt chsh -s /usr/bin/bash root

# Define user and root password
chroot /mnt sh -c 'echo "root:200291" | chpasswd -c SHA512'
chroot /mnt useradd juca -m -c "Reinaldo P JR" -s /bin/bash
chroot /mnt sh -c 'echo "juca:200291" | chpasswd -c SHA512'
chroot /mnt usermod -aG wheel,floppy,audio,video,optical,kvm,lp,storage,cdrom,xbuilder,input juca
chroot /mnt sed -i 's/^#\s*\(%wheel\s*ALL=(ALL)\)/\1/' /etc/sudoers
chroot /mnt sed -i 's/^#\s*\(%wheel\s*ALL=(ALL)\s*NOPASSWD:\s*ALL\)/\1/' /etc/sudoers
chroot /mnt usermod -a -G socklog juca


# install sudo
chroot /mnt apt install sudo -y
chroot /mnt usermod -aG sudo juca

### Services

#Network
chroot /mnt systemctl enable NetworkManager.service
chroot /mnt systemctl enable iwd.service

# Audio
chroot /mnt systemctl --user enable pipewire pipewire-pulse
chroot /mnt systemctl --user daemon-reload
# chroot /mnt systemctl --user --now disable pulseaudio.service pulseaudio.socket
chroot /mnt systemctl --user mask pulseaudio
# Allow run as root
# sed -i -e 's/ConditionUser=!root/#ConditionUser=!root/' /mnt/usr/lib/systemd/user/pipewire.socket 
# sed -i -e 's/ConditionUser=!root/#ConditionUser=!root/' /mnt/etc/xdg/systemd/user/pipewire-pulse.service 
# sed -i -e 's/ConditionUser=!root/#ConditionUser=!root/' /mnt/etc/xdg/systemd/user/sockets.target.wants/pipewire.socket 
# sed -i -e 's/ConditionUser=!root/#ConditionUser=!root/' /mnt/etc/xdg/systemd/user/pipewire-pulse.socket
# sed -i -e 's/ConditionUser=!root/#ConditionUser=!root/' /mnt/etc/xdg/systemd/user/default.target.wants/pipewire.service 
#Audio user setting
chroot /mnt systemctl --user enable pipewire pipewire-pulse
# chroot /mnt systemctl --user --now enable pipewire pipewire-pulse
# check witch server is in use
# LANG=C pactl info | grep '^Server Name'


# Optimizations
chroot /mnt systemctl enable earlyoom.service 
chroot /mnt systemctl enable powertop.service 
chroot /mnt systemctl enable thermald.service 
chroot /mnt systemctl enable irqbalance.service

# chroot /mnt dracut --regenete-all --force --hostonly --kver 5.10.0-20-amd64