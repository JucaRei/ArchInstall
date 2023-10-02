#!/bin/sh

########################
#### Fastest repo's ####
########################
# Repositorios mais rapidos
cat <<EOF >>/etc/xbps.d/00-repository-main.conf
#repository=https://mirror.clarkson.edu/voidlinux
#repository=http://ftp.dk.xemacs.org/voidlinux
#repository=http://ftp.debian.ru/mirrors/voidlinux
#repository=https://repo-fastly.voidlinux.org/voidlinux/current
# repository=http://void.chililinux.com/voidlinux/current
repository=https://mirrors.servercentral.com/voidlinux/current
EOF

cat <<EOF >>/etc/xbps.d/10-repository-nonfree.conf
#repository=https://mirror.clarkson.edu/voidlinux/nonfree
#repository=http://ftp.dk.xemacs.org/voidlinux/nonfree
#repository=http://ftp.debian.ru/mirrors/voidlinux/current/nonfree
#repository=https://repo-fastly.voidlinux.org/voidlinux/current/nonfree
# repository=http://void.chililinux.com/voidlinux/current/nonfree
repository=https://mirrors.servercentral.com/voidlinux/current/nonfree
EOF

cat <<EOF >>/etc/xbps.d/10-repository-multilib-nonfree.conf
#repository=https://mirror.clarkson.edu/voidlinux/multilib/nonfree
#repository=http://ftp.dk.xemacs.org/voidlinux/multilib/nonfree
#repository=https://repo-fastly.voidlinux.org/voidlinux/current/multilib/nonfree
#repository=http://ftp.debian.ru/mirrors/voidlinux/current/multilib/nonfree
# repository=http://void.chililinux.com/voidlinux/current/multilib/nonfree
repository=https://mirrors.servercentral.com/voidlinux/current/multilib/nonfree
EOF

cat <<EOF >>/etc/xbps.d/10-repository-multilib.conf
#repository=https://mirror.clarkson.edu/voidlinux/multilib
#repository=http://ftp.dk.xemacs.org/voidlinux/multilib
#repository=https://repo-fastly.voidlinux.org/voidlinux/current/multilib
#repository=http://ftp.debian.ru/mirrors/voidlinux/current/multilib
# repository=http://void.chililinux.com/voidlinux/current/multilib
repository=https://mirrors.servercentral.com/voidlinux/current/multilib
EOF

vpm sync

DRIVE="/dev/sda"

# Instalando pela wifi

# cp /etc/wpa_supplicant/wpa_supplicant.conf /etc/wpa_supplicant/wpa_supplicant-<wlan-interface>.conf
# wpa_passphrase <ssid> <passphrase> >> /etc/wpa_supplicant/wpa_supplicant-<wlan-interface>.conf
# sv restart dhcpcd
# ip link set up <interface>

### x86_64 GLIBC
# wget -c https://repo-default.voidlinux.org/live/current/void-x86_64-ROOTFS-20230628.tar.xz
### x86_64 MUSL
wget -c https://repo-default.voidlinux.org/live/current/void-x86_64-musl-ROOTFS-20230628.tar.xz

xbps-install -Su xbps xz --yes

#####################################
####Gptfdisk Partitioning example####
#####################################

# Zap entire device
#sgdisk -Z ${DRIVE}

# -s script call | -a optimal
#parted -s -a optimal ${DRIVE} mklabel gpt
#parted -s ${DRIVE} set 1 esp on

# Print partition table
sgdisk -p ${DRIVE}

# Delete partition
# sgdisk -d 1 /dev/vda

# Create new partition
#sgdisk -n 0:0:512MiB ${DRIVE}
#sgdisk -n 0:0:0 ${DRIVE}

# Change the name of partition
# sgdisk -c 1:"EFI Partition System" ${DRIVE}
# sgdisk -c 2:"Swap Linux" ${DRIVE}
# sgdisk -c 3:"Voidlinux System" ${DRIVE}
# sgdisk -c 4:"MacOS High Sierra" ${DRIVE}
# sgdisk -c 2:Swap /dev/sda

# Change Types
# sgdisk --list-types
# sgdisk -t 1:ef00 /dev/sda
# sgdisk -t 2:8200 /dev/sda
# sgdisk -t 2:8300 /dev/sda

# Zap entire device
# sgdisk -Z /dev/vda

#####################################
##########  FileSystem  #############
#####################################

# mkfs.vfat -F32 ${DRIVE}1 -n "EFI"
# mkfs.vfat -F32 /dev/vda1 -n "EFI"
# mkswap /dev/vda2
#mkswap ${DRIVE}2
swapon ${DRIVE}2
# mkfs.btrfs /dev/sda4 -f -L "Voidlinux"
mkfs.btrfs ${DRIVE}3 -f -L "Voidlinux"

## Volumes Vda apenas para testes em vm
set -e
XBPS_ARCH="x86_64"
BTRFS_OPTS="noatime,ssd,compress-force=zstd:15,space_cache=v2,commit=120,discard=async"
BTRFS_SYS="noatime,ssd,compress-force=zstd:5,space_cache=v2,commit=120,discard=async"
# Mude de acordo com sua partição
mount -o $BTRFS_OPTS ${DRIVE}3 /mnt
# mount -o $BTRFS_OPTS /dev/vda3 /mnt

#Cria os subvolumes
btrfs su cr /mnt/@
btrfs su cr /mnt/@home
btrfs su cr /mnt/@snapshots
btrfs su cr /mnt/@var_log
btrfs su cr /mnt/@swap
btrfs su cr /mnt/@var_cache_xbps
umount -v /mnt

# Monta com os valores selecionados
# Lembre-se de mudar os valores de sdX

# mount -o $BTRFS_OPTS,subvol=@ /dev/sda4 /mnt
# mount -o $BTRFS_OPTS,subvol=@ /dev/vda3 /mnt
mount -o $BTRFS_SYS,subvol=@ ${DRIVE}3 /mnt
mkdir -pv /mnt/boot # somente este se for por gummiboot
mkdir -pv /mnt/boot/efi
mkdir -pv /mnt/home
mkdir -pv /mnt/.snapshots
mkdir -pv /mnt/var/log
mkdir -pv /mnt/var/swap
mkdir -pv /mnt/var/cache/xbps

mount -o $BTRFS_OPTS,subvol=@home ${DRIVE}3 /mnt/home
# mount -o $BTRFS_OPTS,subvol=@home /dev/vda3 /mnt/home
mount -o $BTRFS_OPTS,subvol=@snapshots ${DRIVE}3 /mnt/.snapshots
# mount -o $BTRFS_OPTS,subvol=@snapshots /dev/vda3 /mnt/.snapshots
mount -o $BTRFS_OPTS,subvol=@var_log ${DRIVE}3 /mnt/var/log
# mount -o $BTRFS_OPTS,subvol=@var_log /dev/vda3 /mnt/var/log
# mount -o $BTRFS_OPTS,subvol=@swap /dev/vda2 /mnt/var/swap
mount -o $BTRFS_OPTS,subvol=@var_cache_xbps ${DRIVE}3 /mnt/var/cache/xbps
# mount -o $BTRFS_OPTS,subvol=@var_cache_xbps /dev/vda3 /mnt/var/cache/xbps
mount -t vfat -o defaults,noatime,nodiratime ${DRIVE}1 /mnt/boot/efi #grub
# mount -t vfat -o defaults,noatime,nodiratime /dev/sda1 /mnt/boot/   # Gummiboot
# mount -t vfat -o defaults,noatime,nodiratime /dev/vda1 /mnt/boot

# Descompacta e copia para /mnt o tarball
tar xvf ./void-x86_64-*.tar.xz -C /mnt
sync

for dir in dev proc sys run; do
        mount --rbind /$dir /mnt/$dir
        mount --make-rslave /mnt/$dir
done

cat <<EOF >/mnt/etc/resolv.conf
nameserver 8.8.8.8
nameserver 8.8.4.4
nameserver 1.1.1.1
EOF

#####################################################################################
#### Copy the RSA keys from the installation medium to the target root directory ####
#####################################################################################

mkdir -pv /mnt/var/db/xbps/keys
cp /var/db/xbps/keys/* /mnt/var/db/xbps/keys/

# copia o arquivo de resolv para o /mnt
#cp -v /etc/resolv.conf /mnt/etc/

#desabilitar algumas coisas
mkdir -pv /mnt/etc/modprobe.d
cat <<EOF >/mnt/etc/modprobe.d/blacklist.conf
# Disable nouveau
blacklist nouveau
EOF

# Atualiza o initramfs com dracut
# Remover se for testar em VM
mkdir -pv /mnt/etc/dracut.conf.d
cat <<EOF >/mnt/etc/dracut.conf.d/00-dracut.conf
hostonly="yes"
hostonly_cmdline=no
dracutmodules+=" dash kernel-modules rootfs-block btrfs udev-rules resume usrmount base fs-lib shutdown "
add_drivers+=" btrfs i915 crc32c-intel z3fold "
force_drivers+=" z3fold "
omit_dracutmodules+=" i18n nvidia luks rpmversion fstab-sys lunmask fstab-sys securityfs biosdevname caps dmraid dmsquash-live mdraid "
show_modules="yes"
nofscks="yes"
no_host_only_commandline="yes"
compress="zstd"
EOF

mkdir -pv /mnt/etc/sysctl.d
cat <<EOF >/mnt/etc/sysctl.d/00-sysctl.conf
vm.vfs_cache_pressure=500
vm.swappiness=100
vm.dirty_background_ratio=1
vm.dirty_ratio=50
EOF

cat <<EOF >/mnt/etc/dracut.conf.d/10-touchpad.conf
add_drivers+=" bcm5974 "
EOF

# Repositorios mais rapidos
cat <<EOF >>/mnt/etc/xbps.d/00-repository-main.conf
#repository=https://mirror.clarkson.edu/voidlinux
# repository=http://void.chililinux.com/voidlinux/current
repository=https://mirrors.servercentral.com/voidlinux/current
EOF

cat <<EOF >>/mnt/etc/xbps.d/10-repository-nonfree.conf
#repository=https://mirror.clarkson.edu/voidlinux/nonfree
#repository=http://ftp.dk.xemacs.org/voidlinux/nonfree
# repository=http://void.chililinux.com/voidlinux/current/musl/nonfree
repository=https://mirrors.servercentral.com/voidlinux/current/musl/nonfree
EOF

cat <<EOF >>/mnt/etc/xbps.d/10-repository-multilib-nonfree.conf
#repository=https://mirror.clarkson.edu/voidlinux/multilib/nonfree
#repository=http://ftp.dk.xemacs.org/voidlinux/multilib/nonfree
#repository=http://ftp.debian.ru/mirrors/voidlinux/current/musl/multilib/nonfree
# repository=http://void.chililinux.com/voidlinux/current/musl/multilib/nonfree
repository=https://mirrors.servercentral.com/voidlinux/current/musl/multilib/nonfree
EOF

cat <<EOF >>/mnt/etc/xbps.d/10-repository-multilib.conf
#repository=https://mirror.clarkson.edu/voidlinux/multilib
#repository=http://ftp.dk.xemacs.org/voidlinux/multilib
#repository=http://ftp.debian.ru/mirrors/voidlinux/current/musl/multilib
# repository=http://void.chililinux.com/voidlinux/current/musl/multilib
repository=https://mirrors.servercentral.com/voidlinux/current/musl/multilib
EOF

# Ignorar alguns pacotes
cat <<EOF >>/mnt/etc/xbps.d/99-ignore.conf
ignorepkg=linux-firmware-amd
ignorepkg=nvidia
ignorepkg=xf86-video-nouveau
ignorepkg=linux
ignorepkg=linux-headers
ignorepkg=nvi
ignorepkg=dhcpcd
ignorepkg=openssh
ignorepkg=xf86-video-amdgpu
ignorepkg=xf86-video-ati
ignorepkg=xf86-video-nouveau
ignorepkg=xf86-video-vmware
ignorepkg=xf86-video-fbdev
ignorepkg=zd1211-firmware
ignorepkg=xf86-video-vesa
ignorepkg=mobile-broadband-provider-info
ignorepkg=os-prober
EOF

### LXQT only X11 ###
cat <<EOF >/mnt/etc/xbps.d/90-lxqt-ignore.conf
ignorepkg=lxqt-sudo
ignorepkg=qterminal
# ignorepkg=wayland
# ignore=pkg=xorg-server-xwayland
# ignore=pkg=kwayland
# ignore=pkg=kwayland-devel
# ignore=pkg=kwayland-server
EOF

# Hostname
cat <<EOF >/mnt/etc/hostname
air
EOF

# Hosts

cat <<EOF >/mnt/etc/hosts
127.0.0.1 localhost
::1 localhost
127.0.1.1 air.localdomain air
EOF

# fstab

UEFI_UUID=$(blkid -s UUID -o value /dev/sda1)
# UEFI_UUID=$(blkid -s UUID -o value /dev/vda1)
# ROOT_UUID=$(blkid -s UUID -o value /dev/sda4)
# SWAP_UUID=$(blkid -s UUID -o value /dev/sda2)
SWAP_UUID=$(blkid -s UUID -o value /dev/sda2)
# ROOT_UUID=$(blkid -s UUID -o value /dev/vda5)
ROOT_UUID=$(blkid -s UUID -o value /dev/sda3)
# HOME_UUID=$(blkid -s UUID -o value /dev/sda5)

echo $UEFI_UUID
echo $ROOT_UUID
echo $SWAP_UUID
# echo $HOME_UUID

cat <<EOF >/mnt/etc/fstab
#
# See fstab(5).
#
# <file system> <dir> <type> <options> <dump> <pass>

# ROOTFS
UUID=$ROOT_UUID /               btrfs rw,$BTRFS_OPTS,subvol=@                    0 0
UUID=$ROOT_UUID /.snapshots     btrfs rw,$BTRFS_OPTS,subvol=@snapshots           0 0
UUID=$ROOT_UUID /var/log        btrfs rw,$BTRFS_OPTS,subvol=@var_log             0 0
UUID=$ROOT_UUID /var/cache/xbps btrfs rw,$BTRFS_OPTS,subvol=@var_cache_xbps      0 0

#HOME_FS
# UUID=$HOME_UUID /home           btrfs rw,$BTRFS_OPTS,subvol=@home              0 0
UUID=$ROOT_UUID /home           btrfs rw,$BTRFS_OPTS,subvol=@home                0 0

# EFI
UUID=$UEFI_UUID /boot/efi vfat defaults,noatime,nodiratime  0 2

# Swap
UUID=$SWAP_UUID none swap defaults,noatime                                                                                                      0 0

# tmpfs /tmp tmpfs defaults,nosuid,nodev,noatime                                                                                                0 0
tmpfs /tmp tmpfs noatime,nosuid,mode=1777                                                                                                       0 0
EOF

# Set user permition
cat <<\EOF >/mnt/etc/doas.conf
# allow user but require password
permit keepenv :juca

# allow user and dont require a password to execute commands as root
permit nopass keepenv :juca

# mount drives
permit nopass :juca cmd mount
permit nopass :juca cmd umount

# musicpd service start and stop
#permit nopass :$USER cmd service args musicpd onestart
#permit nopass :$USER cmd service args musicpd onestop

# pkg update
#permit nopass :$USER cmd vpm args update

# run personal scripts as root without prompting for a password,
# requires entering the full path when running with doas
#permit nopass :$USER cmd /home/username/bin/somescript

# root as root
#permit nopass keepenv root as root
EOF
chroot /mnt chown -c root:root /etc/doas.conf
# chroot /mnt chmod -c 0400 /etc/doas.conf

#Conf rc

cat <<EOF >/mnt/etc/rc.conf
# /etc/rc.conf - system configuration for void

# Set the host name.
#
# NOTE: it's preferred to declare the hostname in /etc/hostname instead:
#       - echo myhost > /etc/hostname
#
#HOSTNAME="mcbdev"

# Set RTC to UTC or localtime.
HARDWARECLOCK="localtime"

# Set timezone, availables timezones at /usr/share/zoneinfo.
#TIMEZONE="America/Sao_Paulo"

# Keymap to load, see loadkeys(8).
#KEYMAP="us-acentos"

# Console font to load, see setfont(8).
#FONT="lat9w-16"

# Console map to load, see setfont(8).
#FONT_MAP=

# Font unimap to load, see setfont(8).
#FONT_UNIMAP=

# Amount of ttys which should be setup.
#TTYS=
EOF

#############################
#### Base system chroot #####
#############################

# chroot /mnt export PS1="(chroot) ${PS1}"
chroot /mnt ln -sfv /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime

#Locales ONLY GLIB-C
# chroot /mnt sed -i 's/^# *\(en_US.UTF-8\sUTF-8\)/\1/' /etc/default/libc-locales
# chroot /mnt sed -i 's/^# *\(pt_BR.UTF-8\sUTF-8\)/\1/' /etc/default/libc-locales
# chroot /mnt xbps-reconfigure -f glibc-locales

# Update and install base system
chroot /mnt xbps-install -Suy xbps --yes
chroot /mnt xbps-remove -oORvy nvi --yes
chroot /mnt xbps-install -uy
# chroot /mnt $XBPS_ARCH xbps-install -y base-system base-devel linux-firmware intel-ucode void-repo-debug void-repo-nonfree void-repo-multilib void-repo-multilib-nonfree linux-firmware-network acl-progs light kbdlight powertop arp-scan xev earlyoom opendoas base-devel zstd bash-completion minised nocache parallel util-linux bcache-tools necho starship linux-lts linux-lts-headers efivar dropbear neovim base-devel gummiboot ripgrep dust exa zoxide fzf xtools lm_sensors inxi lshw intel-ucode zsh alsa-utils vim git wget curl efibootmgr btrfs-progs nano ntfs-3g mtools dosfstools sysfsutils htop elogind dbus-elogind dbus-elogind-libs dbus-elogind-x11 vsv vpm polkit chrony neofetch dust duf lua bat glow bluez bluez-alsa sof-firmware xdg-user-dirs xdg-utils --yes
# chroot /mnt $XBPS_ARCH xbps-install base-minimal linux linux-headers opendoas ncurses efibootmgr libgcc efivar bash zsh grep tar less man-pages mdocml btrfs-progs e2fsprogs dosfstools dash procps-ng linux-firmware intel-ucode pciutils usbutils kbd ethtool kmod acpid eudev iproute2 traceroute wifi-firmware file iputils iw zstd --yes
chroot /mnt $XBPS_ARCH xbps-install base-system base-devel linux-lts linux-lts-headers opendoas ncurses libgcc efivar bash grep tar less man-pages mdocml btrfs-progs e2fsprogs dosfstools dash procps-ng linux-firmware intel-ucode pciutils usbutils kbd ethtool kmod acpi acpi_call-dkms acpid eudev iproute2 traceroute file iputils iw zstd dropbear--yes
# chroot /mnt $XBPS_ARCH xbps-install base-system linux-firmware intel-ucode linux-firmware-network linux5.15 linux5.15-headers efivar efibootmgr opendoas linux-firmware intel-ucode linux-firmware-network acl-progs ntfs-3g mtools sysfsutils base-devel util-linux gummiboot lm_sensors bash zsh man-pages btrfs-progs e2fsprogs dosfstools dash pciutils usbutils kbd ethtool kmod acpid eudev iproute2 traceroute iputils iw zstd --yes
chroot /mnt xbps-remove base-voidstrap --yes

# Grub #
# chroot /mnt xbps-install -Sy efibootmgr grub-x86_64-efi grub-btrfs grub-btrfs-runit os-prober acl-progs btrfs-progs --yes

# Gummiboot #
#chroot /mnt xbps-install -S gummiboot --yes
chroot /mnt xbps-install -S grub-x86_64-efi acl-progs btrfs-progs --yes
chroot /mnt xbps-install -S void-repo-debug void-repo-multilib void-repo-multilib-nonfree void-repo-nonfree --yes

# Some firmwares and utils
chroot /mnt xbps-install -S linux-firmware intel-ucode dracut dracut-uefi gptfdisk ntfs-3g mtools sysfsutils util-linux lm_sensors xdg-user-dirs xdg-utils --yes
chroot /mnt xbps-install -S light kbdlight powertop bash-completion xtools alsa-utils alsa-firmware alsa-plugins-ffmpeg alsa-plugins-jack alsa-plugins-samplerate alsa-plugins-speex alsa-plugins-pulseaudio lsscsi dialog git curl nano elogind vsv vpm chrony bluez bluez-alsa sof-firmware xdg-desktop-portal --yes
#chroot /mnt xbps-install -y base-minimal zstd linux5.10 linux-base neovim chrony tlp intel-ucode zsh curl opendoas tlp xorg-minimal libx11 xinit xorg-video-drivers xf86-input-evdev xf86-video-intel xf86-input-libinput libinput-gestures dbus dbus-x11 xorg-input-drivers xsetroot xprop xbacklight xrdb dbus-elogind dbus-elogind-libs dbus-elogind-x11 polkit xdg-user-dirs
#chroot /mnt xbps-remove -oORvy sudo

# Install Xorg base & others
chroot /mnt xbps-install -Sy xorg mesa-vulkan-intel vulkan-loader fuse-exfat --yes

# NetworkManager e iNet Wireless Daemon
chroot /mnt xbps-install -S NetworkManager iwd --yes

# Create config file to make NetworkManager use iwd as the Wi-Fi backend instead of wpa_supplicant
mkdir -pv /mnt/etc/NetworkManager/conf.d/
touch /mnt/etc/NetworkManager/conf.d/wifi_backend.conf
cat <<EOF >>/mnt/etc/NetworkManager/conf.d/wifi_backend.conf
[device]
wifi.backend=iwd
wifi.iwd.autoconnect=yes
EOF

cat <<\EOF >>/mnt/etc/rc.local
modprobe -r usbmouse
modprobe -r bcm5974
modprobe bcm5974

# Podman fix
mount --make-rshared /

# Powertop
powertop --auto-tune

#echo 60000 > /sys/bus/usb/devices/2-1.5/power/autosuspend_delay_ms
#echo 60000 > /sys/bus/usb/devices/2-1.6/power/autosuspend_delay_ms
#echo 60000 > /sys/bus/usb/devices/3-1.5/power/autosuspend_delay_ms
#echo 60000 > /sys/bus/usb/devices/3-1.6/power/autosuspend_delay_ms
#echo 60000 > /sys/bus/usb/devices/4-1.5/power/autosuspend_delay_ms
#echo 60000 > /sys/bus/usb/devices/4-1.6/power/autosuspend_delay_ms

# Dual GPU
#/home/juca/.envs/dual.sh

exit 0
EOF

# Install Nvidia video drivers
# chroot /mnt xbps-install -S xf86-video-intel --yes

# Intel Video Drivers
# chroot /mnt xbps-install -S mesa-dri mesa-vulkan-intel intel-video-accel --yes

#chroot /mnt xbps-install -Sy libva-utils libva-vdpau-driver vdpauinfo

# "Mons is a Shell script to quickly manage 2-monitors display using xrandr."
# chroot /mnt xbps-install -S mons --yes

#File Management
chroot /mnt xbps-install -S gvfs gvfs-smb gvfs-mtp gvfs-afc avahi avahi-discover udisks2 samba tumbler ffmpegthumbnailer libgsf libopenraw --yes

# PACKAGES FOR SYSTEM LOGGING
chroot /mnt xbps-install -S socklog-void --yes

chroot /mnt xbps-install -S irqbalance earlyoom powertop --yes

# Dev virt
chroot /mnt xbps-install -S podman podman-compose binfmt-support containers.image buildah slirp4netns cni-plugins fuse-overlayfs --yes

chroot /mnt ln -srvf /etc/sv/binfmt-support /var/service
chroot /mnt ln -srvf /etc/sv/podman /var/service
chroot /mnt ln -srvf /etc/sv/podman-docker /var/service

# NFS
chroot /mnt xbps-install -S nfs-utils sv-netmount thermald tlp --yes

# Set zsh as default
# chroot /mnt chsh -s /usr/bin/zsh root

# Define user and root password
chroot /mnt sh -c 'echo "root:200291" | chpasswd -c SHA512'
chroot /mnt useradd juca -m -c "Reinaldo P JR" -s /bin/bash
chroot /mnt sh -c 'echo "juca:200291" | chpasswd -c SHA512'
chroot /mnt usermod -aG wheel,floppy,audio,video,optical,kvm,lp,storage,cdrom,xbuilder,input juca
# chroot /mnt sed -i 's/^#\s*\(%wheel\s*ALL=(ALL)\)/\1/' /etc/sudoers
# chroot /mnt sed -i 's/^#\s*\(%wheel\s*ALL=(ALL)\s*NOPASSWD:\s*ALL\)/\1/' /etc/sudoers
chroot /mnt usermod -a -G socklog juca
chroot /mnt usermod --add-subuids 100000-165535 --add-subgids 100000-165535 juca

cat <<\EOF >/mnt/etc/default/earlyoom
EARLYOOM_ARGS=" -m 96,92 -s 99,99 -r 5 -n --avoid '(^|/)(runit|Xorg|sshd)$'"
EOF

# Gerar initcpio
chroot /mnt xbps-reconfigure -fa

# Touchpad
mkdir -pv /mnt/etc/X11/xorg.conf.d/
cat <<EOF >/mnt/etc/X11/xorg.conf.d/30-touchpad.conf
section "InputClass"
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

cat <<EOF >/mnt/etc/X11/xorg.conf.d/00-keyboard.conf
Section "InputClass"
        Identifier              "system-keyboard"
        MatchIsKeyboard         "on"
        Option "XkbLayout"      "us"
        Option "XkbModel"       "pc105"
        Option "XkbVariant"     "mac"
        Option "Backspace"      "guess"
EndSection
EOF

cat <<EOF >/mnt/etc/X11/xorg.conf.d/99-killx.conf
Section "ServerFlags"
        Option  "DontZap"       "false"
EndSection

Section "InputClass"
        Identifier      "Keyboard Defaults"
        MatchIsKeyboard "yes"
        Option          "XkbOptions"    "terminate:crtl_alt_bksp"
EndSection
EOF

cat <<EOF >/mnt/etc/X11/xorg.conf.d/20-intel.conf
Section "Device"
        Identifier      "Intel Graphics"
        Driver          "Intel"
        Option          "AccelMethod"           "sna"
        Option          "TearFree"              "True"
EndSection
EOF

cat <<EOF >/mnt/etc/sysctl.d/10-conf.conf
net.ipv4.ping_group_range=0 $MAX_GID
EOF

cat <<EOF >/mnt/etc/sysctl.d/10-intel.conf
# Intel Graphics
dev.i915.perf_stream_paranoid=0
EOF

# mkdir -pv /mnt/etc/elogind
# cat <<EOF >/mnt/etc/elogind/logind.conf
# #  This file is part of elogind.
# #
# #  elogind is free software; you can redistribute it and/or modify it
# #  under the terms of the GNU Lesser General Public License as published by
# #  the Free Software Foundation; either version 2.1 of the License, or
# #  (at your option) any later version.
# #
# # Entries in this file show the compile time defaults.
# # You can change settings by editing this file.
# # Defaults can be restored by simply deleting this file.
# #
# # See logind.conf(5) for details.

# [Login]
# #KillUserProcesses=no
# #KillOnlyUsers=
# #KillExcludeUsers=root
# #InhibitDelayMaxSec=5
# # HandlePowerKey=ignore
# HandleSuspendKey=ignore
# HandleHibernateKey=ignore
# HandleLidSwitch=ignore
# HandleLidSwitchExternalPower=ignore
# HandleLidSwitchDocked=ignore
# #PowerKeyIgnoreInhibited=no
# #SuspendKeyIgnoreInhibited=no
# #HibernateKeyIgnoreInhibited=no
# #LidSwitchIgnoreInhibited=yes
# #HoldoffTimeoutSec=30s
# #IdleAction=ignore
# #IdleActionSec=30min
# #RuntimeDirectorySize=10%
# #RuntimeDirectoryInodes=400k
# #RemoveIPC=yes
# #InhibitorsMax=8192
# #SessionsMax=8192

# [Sleep]
# #AllowSuspend=yes
# #AllowHibernation=yes
# #AllowSuspendThenHibernate=yes
# #AllowHybridSleep=yes
# #AllowPowerOffInterrupts=no
# #BroadcastPowerOffInterrupts=yes
# #AllowSuspendInterrupts=no
# #BroadcastSuspendInterrupts=yes
# #HandleNvidiaSleep=ignore
# #SuspendState=mem standby freeze
# #SuspendMode=
# #HibernateState=disk
# #HibernateMode=platform shutdown
# #HybridSleepState=disk
# #HybridSleepMode=suspend platform shutdown
# #HibernateDelaySec=10800
# EOF

#Runit por default
# chroot /mnt ln -sv /etc/sv/dhcpcd /etc/runit/runsvdir/default/
chroot /mnt ln -svrf /etc/sv/acpid /etc/runit/runsvdir/default/
# chroot /mnt ln -sv /etc/sv/wpa_supplicant /etc/runit/runsvdir/default/
chroot /mnt ln -svrf /etc/sv/chronyd /etc/runit/runsvdir/default/
# chroot /mnt ln -sv /etc/sv/scron /etc/runit/runsvdir/default/
chroot /mnt ln -svrf /etc/sv/tlp /etc/runit/runsvdir/default/
chroot /mnt ln -svrf /etc/sv/dropbear /etc/runit/runsvdir/default/
chroot /mnt ln -svrf /etc/sv/NetworkManager /etc/runit/runsvdir/default/
chroot /mnt ln -srvf /etc/sv/dbus /etc/runit/runsvdir/default/
chroot /mnt ln -srvf /etc/sv/polkitd /etc/runit/runsvdir/default/
chroot /mnt ln -srvf /etc/sv/elogind /etc/runit/runsvdir/default/
chroot /mnt ln -srvf /etc/sv/bluetoothd /etc/runit/runsvdir/default/
chroot /mnt ln -srvf /etc/sv/avahi-daemon /etc/runit/runsvdir/default/
chroot /mnt ln -srvf /etc/sv/irqbalance /etc/runit/runsvdir/default/
chroot /mnt ln -srvf /etc/sv/earlyoom /etc/runit/runsvdir/default/
chroot /mnt ln -srvf /etc/sv/thermald /etc/runit/runsvdir/default/
# chroot /mnt ln -srvf /etc/sv/preload /etc/runit/runsvdir/default/
chroot /mnt ln -srvf /etc/sv/tlp /etc/runit/runsvdir/default/
#chroot /mnt ln -srvf /etc/sv/nix-daemon /etc/runit/runsvdir/default/

# NFS
chroot /mnt ln -srvf /etc/sv/rpcbind /etc/runit/runsvdir/default/
chroot /mnt ln -srvf /etc/sv/statd /etc/runit/runsvdir/default/
chroot /mnt ln -srvf /etc/sv/netmount /etc/runit/runsvdir/default/

#Samba
chroot /mnt ln -srvf /etc/sv/smbd /etc/runit/runsvdir/default/
chroot /mnt ln -srvf /etc/sv/nmbd /etc/runit/runsvdir/default/

# Enable socklog, a syslog implementation from the author of runit.
chroot /mnt ln -sv /etc/sv/socklog-unix /etc/runit/runsvdir/default/
chroot /mnt ln -sv /etc/sv/nanoklogd /etc/runit/runsvdir/default/

# Enable the iNet Wireless Daemon for Wi-Fi support
chroot /mnt ln -sv /etc/sv/iwd /etc/runit/runsvdir/default/

# Config zsh

#Install Gummiboot
#mount --bind /sys/firmware/efi/efivars /mnt/sys/firmware/efi/efivars
#chroot /mnt mount -t efivarfs efivarfs /sys/firmware/efi/efivars
#chroot /mnt gummiboot install

# alias dissh="export DISPLAY=:0.0"
# alias bquit="bspc quit"

cat <<\EOF >/mnt/etc/samba/smb.conf
[global]
   workgroup = WORKGROUP
   dns proxy = no
   log file = /var/log/samba/%m.log
   max log size = 1000
   client min protocol = NT1
   server role = standalone server
   passdb backend = tdbsam
   obey pam restrictions = yes
   unix password sync = yes
   passwd program = /usr/bin/passwd %u
   passwd chat = *New*UNIX*password* %n\n *ReType*new*UNIX*password* %n\n *passwd:*all*authentication*tokens*updated*successfully*
   pam password change = yes
   map to guest = Bad Password
   usershare allow guests = yes
   name resolve order = lmhosts bcast host wins
   security = user
   guest account = nobody
   usershare path = /var/lib/samba/usershare
   usershare max shares = 100
   usershare owner only = yes
   force create mode = 0070
   force directory mode = 0070

[homes]
   comment = Home Directories
   browseable = no
   read only = yes
   create mask = 0700
   directory mask = 0700
   valid users = %S

[printers]
   comment = All Printers
   browseable = no
   path = /var/spool/samba
   printable = yes
   guest ok = no
   read only = yes
   create mask = 0700

[print$]
   comment = Printer Drivers
   path = /var/lib/samba/printers
   browseable = yes
   read only = yes
   guest ok = no
EOF

# MakeSwap
# chroot /mnt touch /swapfile
# chroot /mnt chmod 600 /swapfile
# chroot /mnt chattr +C /swapfile
# chroot /mnt lsattr /swapfile
# chroot /mnt dd if=/dev/zero of=/swapfile bs=1M count=4096 status=progress
# chroot /mnt dd if=/dev/zero of=/swapfile bs=1M count=2048 status=progress
# chroot /mnt mkswap /swapfile
# chroot /mnt swapon /swapfile

# Add to fstab
# echo " " >>/mnt/etc/fstab
# echo "# Swap" >>/mnt/etc/fstab
# echo "/swapfile      none     swap      defaults  0 0" >>/mnt/etc/fstab

#Fix mount external HD
mkdir -pv /mnt/etc/udev/rules.d
cat <<\EOF >/mnt/etc/udev/rules.d/99-udisks2.rules
# UDISKS_FILESYSTEM_SHARED
# ==1: mount filesystem to a shared directory (/media/VolumeName)
# ==0: mount filesystem to a private directory (/run/media/$USER/VolumeName)
# See udisks(8)
ENV{ID_FS_USAGE}=="filesystem|other|crypto", ENV{UDISKS_FILESYSTEM_SHARED}="1"
EOF

# Not asking for password

mkdir -pv /mnt/etc/polkit-1/rules.d
cat <<\EOF >/mnt/etc/polkit-1/rules.d/10-udisks2.rules
// Allow udisks2 to mount devices without authentication
// for users in the "wheel" group.
polkit.addRule(function(action, subject) {
    if ((action.id == "org.freedesktop.udisks2.filesystem-mount-system" ||
         action.id == "org.freedesktop.udisks2.filesystem-mount") &&
        subject.isInGroup("wheel")) {
        return polkit.Result.YES;
    }
});
EOF

#Install Gummiboot
# mount --bind /sys/firmware/efi/efivars /mnt/sys/firmware/efi/efivars
# sleep 2
# chroot /mnt mount -t efivarfs efivarfs /sys/firmware/efi/efivars
# sleep 2
# chroot /mnt gummiboot install --path=/boot

# chroot /mnt bash -c 'echo "options root=/dev/sda4 rootflags=subvol=@ rw quiet loglevel=0 console=tty2 acpi_osi=Darwin acpi_mask_gpe=0x06 init_on_alloc=0 udev.log_level=0 zswap.enabled=1 zswap.compressor=zstd zswap.max_pool_percent=10 zswap.zpool=zsmalloc mitigations=off nowatchdog msr.allow_writes=on pcie_aspm=force module.sig_unenforce intel_idle.max_cstate=1 cryptomgr.notests initcall_debug intel_iommu=igfx_off net.ifnames=0 no_timer_check noreplace-smp page_alloc.shuffle=1 rcupdate.rcu_expedited=1 tsc=reliable" >> /boot/loader/entries/void-5.10**'
# chroot /mnt bash -c 'echo "options root=/dev/vda3 rootflags=subvol=@ rw quiet loglevel=0 console=tty2 gpt acpi_osi=! acpi_osi=Darwin acpi_mask_gpe=0x06 nomodeset init_on_alloc=0 udev.log_level=0 intel_iommu=on,igfx_off zswap.enabled=1 zswap.compressor=zstd zswap.max_pool_percent=10 zswap.zpool=zsmalloc mitigations=off nowatchdog msr.allow_writes=on pcie_aspm=force module.sig_unenforce intel_idle.max_cstate=1 cryptomgr.notests initcall_debug  net.ifnames=0 no_timer_check noreplace-smp page_alloc.shuffle=1 rcupdate.rcu_expedited=1 tsc=reliable" >> /boot/loader/entries/void-5.15**'
#chroot /mnt bash -c 'echo "options root=/dev/sda3 rootflags=subvol=@ rw quiet loglevel=0 console=tty2 gpt acpi_osi=Darwin acpi_mask_gpe=0x06 init_on_alloc=0 udev.log_level=0 intel_iommu=igfx_off zswap.enabled=1 zswap.compressor=lz4hc zswap.max_pool_percent=10 zswap.zpool=z3fold mitigations=off nowatchdog msr.allow_writes=on pcie_aspm=force module.sig_unenforce intel_idle.max_cstate=1 cryptomgr.notests initcall_debug  net.ifnames=0 no_timer_check noreplace-smp page_alloc.shuffle=1 rcupdate.rcu_expedited=1 tsc=reliable" >> /boot/loader/entries/void-**'

# Grub
# GRUB_CMDLINE_LINUX_DEFAULT="quiet loglevel=0 console=tty2 gpt acpi_osi=! acpi_osi=Darwin acpi_mask_gpe=0x06 nomodeset init_on_alloc=0 udev.log_level=0 intel_iommu=on,igfx_off zswap.enabled=1 zswap.compressor=zstd zswap.max_pool_percent=10 zswap.zpool=z3fold mitigations=off nowatchdog msr.allow_writes=on pcie_aspm=force module.sig_unenforce intel_idle.max_cstate=1 cryptomgr.notests initcall_debug  net.ifnames=0 no_timer_check noreplace-smp page_alloc.shuffle=1 rcupdate.rcu_expedited=1 tsc=reliable"
# chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot/ --bootloader-id="Void"
chroot /mnt grub-install --target=x86_64-efi --bootloader-id="Voidlinux" --efi-directory=/boot/efi --no-nvram --removable --recheck
# chroot /mnt update-grub

cat <<EOF >/mnt/etc/default/grub
#
# Configuration file for GRUB.
#
GRUB_DEFAULT=0
#GRUB_HIDDEN_TIMEOUT=0
#GRUB_HIDDEN_TIMEOUT_QUIET=false
GRUB_TIMEOUT=5
GRUB_DISTRIBUTOR="Void Linux"

GRUB_CMDLINE_LINUX_DEFAULT="quiet hid_apple.swap_opt_cmd=1 loglevel=0 console=tty2 udev.log_level=0 vt.global_cursor_default=0 mitigations=off nowatchdog intel_idle.max_cstate=1 cryptomgr.notests initcall_debug intel_iommu=igfx_off no_timer_check noreplace-smp page_alloc.shuffle=1 rcupdate.rcu_expedited=1 tsc=reliable zswap.enabled=1 zswap.compressor=lz4hc zswap.max_pool_percent=10 zswap.zpool=z3fold"

GRUB_CMDLINE_LINUX=""
GRUB_PRELOAD_MODULES="part_gpt part_msdos"
GRUB_TIMEOUT_STYLE=menu
GRUB_GFXMODE=auto
GRUB_GFXPAYLOAD_LINUX=keep

#GRUB_TERMINAL_INPUT="console"
# Uncomment to disable graphical terminal
#GRUB_TERMINAL_OUTPUT=console
#GRUB_BACKGROUND=/home/bastilla.jpg
#GRUB_GFXMODE=1920x1080x32,1366x768x32,auto
#GRUB_DISABLE_LINUX_UUID=true
#GRUB_DISABLE_RECOVERY=true
# Uncomment and set to the desired menu colors.  Used by normal and wallpaper
# modes only.  Entries specified as foreground/background.
GRUB_COLOR_NORMAL="red/black"
GRUB_COLOR_HIGHLIGHT="yellow/black"
#GRUB_DISABLE_OS_PROBER=false
EOF

cat <<EOF >>/mnt/etc/grub.d/custom_40

menuentry "Reboot" {
reboot
}

menuentry "Poweroff" {
halt
}
EOF

chroot /mnt update-grub

##Fix distrobox
touch /mnt/home/juca/.xprofile
cat <<\EOF >/mnt/home/juca/.xprofile
#!/bin/sh

### Distrobox
# xhost +si:localuser:$USER
xhost +si:localuser:juca
EOF

chroot /mnt chmod +x /home/juca/.xprofile
chroot /mnt chown -R juca:juca /home/juca/.xprofile

chroot /mnt xbps-reconfigure -fa

# cd ~/Downloads
# wget -c https://dev.yorhel.nl/download/ncdu-2.1-linux-x86_64.tar.gz
# ex ncdu-2.1-linux-x86_64.tar.gz
# mkdir ~/.local/bin
# mv ncdu ~/.local/bin
# source ~/.bashrc

# git clone https://gitlab.com/dwt1/shell-color-scripts.git
# cd shell-color-scripts
# rm -rf /opt/shell-color-scripts || return 1
# sudo mkdir -p /opt/shell-color-scripts/colorscripts || return 1
# sudo cp -rf colorscripts/* /opt/shell-color-scripts/colorscripts
# sudo cp colorscript.sh /usr/bin/colorscript
#
# optional for zsh completion
# sudo cp zsh_completion/_colorscript /usr/share/zsh/site-functions

# Boot Faster with intel
touch /mnt/etc/modprobe.d/i915.conf
cat <<EOF >/mnt/etc/modprobe.d/i915.conf
options i915 enable_guc=2 enable_dc=4 enable_hangcheck=0 error_capture=0 enable_dp_mst=0 fastboot=1 #parameters may differ
EOF

# brightness
# git clone https://github.com/madand/runit-services
# cd runit-services
# mv backlight /mnt/etc/sv/
# chroot /mnt ln -svrf /etc/sv/backlight /var/service/
# cd ..

# PSD
# git clone https://github.com/graysky2/profile-sync-daemon
# mv profile-sync-daemon /mnt/home/juca/psd
# chroot /mnt make /home/juca/psd/
# chroot /mnt make install /home/juca/psd/
# chroot /mnt rm -rf /usr/lib/systemd/

# git clone https://github.com/madand/runit-services
# mv runit-services/psd /mnt/etc/sv
# chroot /mnt ln -svrf /etc/sv/psd /var/service

# git clone https://github.com/Nefelim4ag/Ananicy.git
# mv Ananicy /mnt/home/juca/Ananicy
# chroot /mnt make install /home/juca/Ananicy
# chroot /mnt rm -rf /lib/systemd
# chroot /mnt mkdir /etc/sv/ananicy
# touch /mnt/etc/sv/ananicy/run
# touch /mnt/etc/sv/ananicy/finish
# cat <<EOF > /mnt/etc/sv/ananicy/run
### /bin/sh
# exec /usr/bin/ananicy start
# EOF
#cat <<EOF > /mnt/etc/sv/ananicy/finish
### /bin/sh
#exec /sbin/sysctl -e kernel.sched_autogroup_enabled=1
#EOF
#chroot /mnt ln -sfv /etc/sv/ananicy /var/service

#git clone --depth=1 https://github.com/JucaRei/my-nixfiles /mnt/home/juca/Zero/nix-config

#chroot /mnt xbps-reconfigure -fa

# chroot /mnt bash -c 'echo "options root=/dev/sda4 rootflags=subvol=@ rw quiet loglevel=0 console=tty2 gpt acpi_osi=! acpi_osi=Darwin acpi_mask_gpe=0x06 nomodeset init_on_alloc=0 udev.log_level=0 zswap.enabled=1 zswap.compressor=zstd zswap.max_pool_percent=10 zswap.zpool=zsmalloc mitigations=off nowatchdog msr.allow_writes=on pcie_aspm=force module.sig_unenforce intel_idle.max_cstate=1 cryptomgr.notests initcall_debug  net.ifnames=0 no_timer_check noreplace-smp page_alloc.shuffle=1 rcupdate.rcu_expedited=1 tsc=reliable" >> /boot/loader/entries/void-5.10**'

printf "\e[1;32mInstallation finished! Review your configuration, umount -a and reboot.\e[0m"

### interface name: wlp2s0b1
