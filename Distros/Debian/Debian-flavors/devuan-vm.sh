#!/bin/bash

apt update && apt install btrfs-progs wget -y

# wget -c http://deb.devuan.org/devuan/pool/main/d/debootstrap/debootstrap_1.0.126+nmu1devuan1.tar.gz

#####################################
####Gptfdisk Partitioning example####
#####################################

# -s script call | -a optimal
sgdisk -Z /dev/vda
parted -s -a optimal /dev/vda mklabel gpt

# Create new partition
sgdisk -n 0:0:100MiB /dev/vda
sgdisk -n 0:0:0 /dev/vda

# Change the name of partition
sgdisk -c 1:Devuan /dev/vda
sgdisk -c 2:Devroot /dev/vda

# Change Types
sgdisk -t 1:ef00 /dev/vda
sgdisk -t 2:8300 /dev/vda

sgdisk -p /dev/vda

#####################################
##########  FileSystem  #############
#####################################

mkfs.vfat -F32 /dev/vda1 -n "Grub"
mkfs.btrfs /dev/vda2 -f -L "Devuan"

## Volumes Vda apenas para testes em vm
set -e
DEVUAN_ARCH="amd64"
BTRFS_OPTS="noatime,ssd,compress-force=zstd:15,space_cache=v2,commit=120,autodefrag,discard=async"
# Mude de acordo com sua partição
# mount -o $BTRFS_OPTS /dev/vda5 /mnt
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
mkdir -pv /mnt/var/swap
mkdir -pv /mnt/var/cache/apt

mount -o $BTRFS_OPTS,subvol=@home /dev/vda2 /mnt/home
mount -o $BTRFS_OPTS,subvol=@snapshots /dev/vda2 /mnt/.snapshots
mount -o $BTRFS_OPTS,subvol=@var_log /dev/vda2 /mnt/var/log
# mount -o $BTRFS_OPTS,subvol=@swap /dev/vda2 /mnt/var/swap
mount -o $BTRFS_OPTS,subvol=@var_cache_apt /dev/vda2 /mnt/var/cache/apt
mount -t vfat -o noatime,nodiratime /dev/vda1 /mnt/boot/efi 



# debootstrap --include "bash,zsh,wpasupplicant,locales,grub2,wget,curl,ntp,network-manager,dhcpcd5,linux-image-amd64,firmware-linux-free" --arch amd64 chimaera /mnt http://devuan.c3sl.ufpr.br/merged/ chimaera
# debootstrap --include "bash,zsh,iwd,locales,grub2,wget,curl,ntp,network-manager,dhcpcd5,linux-image-amd64,firmware-linux-free" --arch amd64 chimaera /mnt http://devuan.c3sl.ufpr.br/merged/ chimaera
# debootstrap --arch amd64 chimaera /mnt http://devuan.c3sl.ufpr.br/merged/ chimaera
debootstrap --variant=minbase --arch amd64 chimaera /mnt http://devuan.c3sl.ufpr.br/merged/ chimaera
# deb http://devuan.c3sl.ufpr.br/merged/ main contrib non-free


# Mount points
for dir in dev proc sys run; do
        mount --rbind /$dir /mnt/$dir
        mount --make-rslave /mnt/$dir
done

# Desabilita instalar recomendados
touch /mnt/etc/apt/apt.conf
cat <<EOF > /mnt/etc/apt/apt.conf
#Recommends are as of now still abused in many packages
APT::Install-Recommends "0";
APT::Install-Suggests "0";
EOF

mkdir -pv /mnt/etc/apt/preferences.d
touch /mnt/etc/apt/preferences.d/00systemd
cat <<\EOF > /mnt/etc/apt/preferences.d/00systemd
# Remove systemd priority
Package: *systemd*:any
Pin: origin *
Pin-Priority: -1

Package: systemd
Pin: release *
Pin-Priority: -1
 
Package: *systemd*
Pin: release *
Pin-Priority: -1
 
Package: systemd:i386
Pin: release *
Pin-Priority: -1
EOF

chroot /mnt apt-mark hold libsystemd0

# Repositorios mais rapidos
rm /mnt/etc/apt/sources.list
# mkdir -pv /mnt/etc/apt/sources.d/
touch /mnt/etc/apt/sources.list.d/{devuan.list,various.list}
# touch /mnt/etc/apt/sources.d/{antix.list,various.list}
cat <<\EOF > /mnt/etc/apt/sources.list.d/devuan.list
### Repositories ###
deb http://devuan.c3sl.ufpr.br/merged chimaera main contrib non-free 
deb http://devuan.c3sl.ufpr.br/merged chimaera-updates main contrib non-free  
deb http://devuan.c3sl.ufpr.br/merged chimaera-security main contrib non-free  
deb http://devuan.c3sl.ufpr.br/merged chimaera-backports main contrib non-free  

# Source repositories
deb-src http://devuan.c3sl.ufpr.br/merged chimaera main contrib non-free  
deb-src http://devuan.c3sl.ufpr.br/merged chimaera-updates main contrib non-free  
deb-src http://devuan.c3sl.ufpr.br/merged chimaera-security main contrib non-free  
deb-src http://devuan.c3sl.ufpr.br/merged chimaera-backports main contrib non-free 
EOF

# Hostname
HOSTNAME=devuan
cat <<EOF >/mnt/etc/hostname
$HOSTNAME
EOF

# Hosts
touch /mnt/etc/hosts
cat <<EOF >/mnt/etc/hosts
127.0.0.1       localhost
127.0.1.1       $HOSTNAME.localdomain $HOSTNAME
::1             localhost ip6-localhost ip6-loopback
ff02::1         ip6-allnodes
ff02::2         ip6-allrouters
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
UUID=$ROOT_UUID   /var/cache/apt  btrfs rw,$BTRFS_OPTS,subvol=@var_cache_xbps           0 0

### HOME_FS ###
# UUID=$HOME_UUID /home           btrfs rw,$BTRFS_OPTS,subvol=@home                     0 0
UUID=$ROOT_UUID   /home           btrfs rw,$BTRFS_OPTS,subvol=@home                     0 0

### EFI ###
# UUID=$UEFI_UUID /boot/efi       vfat rw,noatime,nodiratime,umask=0077,fmask=0022,dmask=0022,codepage=437,iocharset=iso8859-1,shortname=mixed,utf8,errors=remount-ro  0 2
UUID=$UEFI_UUID   /boot/efi       vfat rw,defaults,noatime,nodiratime,umask=0077        0 2

### Swap ###
#UUID=$SWAP_UUID  none            swap defaults,noatime                                 0 0

### Tmp ###
# tmpfs         /tmp              tmpfs defaults,nosuid,nodev,noatime                   0 0
tmpfs           /tmp              tmpfs noatime,mode=1777,nosuid                        0 0
EOF

# antix-archive-keyring
# devuan-keyring


######################
#### Init Systems ####
######################

## Runit
chroot /mnt apt install --no-install-recommends -y zenity zenity-common elogind libpam-elogind orphan-sysvinit-scripts runit runit-run
## Openrc
# chroot /mnt apt install --no-install-recommends -y zenity zenity-common elogind libpam-elogind orphan-sysvinit-scripts openrc
## Sysvinit
# chroot /mnt apt install --no-install-recommends -y zenity zenity-common libpam-elogind orphan-sysvinit-scripts sysvinit-core


# Some base packages
chroot /mnt apt install --no-install-recommends -y apt apt-utils extrepo cpio cron zstd ca-certificates perl-openssl-defaults sudo neovim console-setup dosfstools console-setup-linux keyboard-configuration devuan-keyring locales busybox btrfs-progs dmidecode kmod less gdisk gpgv neovim ncurses-base netbase procps eudev ifupdown iproute2 iputils-ping bash whiptail

chroot /mnt apt install module-assistant apt apt-utils pciutils xdg-user-dirs extrepo cpio dracut manpages dbus devuan-keyring bash zstd locales btrfs-progs build-essential grub-efi-amd64 wget curl sysfsutils chrony network-manager iwd linux-image-amd64 linux-headers-amd64 firmware-linux-free multipath-tools --no-install-recommends -y

# Utils
# chroot /mnt apt install bash-completion bzip2 man-db gptfdisk dosfstools mtools p7zip neofetch fzf bat duf --no-install-recommends -y
chroot /mnt apt install bash-completion bzip2 man-db dosfstools mtools p7zip neofetch fzf bat --no-install-recommends -y

# Optimizations
chroot /mnt apt install earlyoom powertop thermald irqbalance --yes


zsh stterm rxvt-unicode-256color

# Microcode
chroot /mnt apt install intel-microcode --no-install-recommends -y

# Audio, Bluetooth and wifi
chroot /mnt apt install iwd rfkill --no-install-recommends -y
 
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
                echo 'LANG="en_US.UTF-8"'>/etc/default/locale && \
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

#desabilitar algumas coisas
mkdir -pv /mnt/etc/modprobe.d
touch /mnt/etc/modprobe.d/blacklist.conf
cat <<EOF >/mnt/etc/modprobe.d/blacklist.conf
# Disable watchdog
install iTCO_wdt /bin/true
install iTCO_vendor_support /bin/true

# Disable nouveau
blacklist nouveau
EOF

# Atualiza o initramfs com dracut
# Remover se for testar em VM
mkdir -pv /mnt/etc/dracut.conf.d
cat <<EOF >/mnt/etc/dracut.conf.d/10-debian.conf
hostonly="yes"
hostonly_cmdline=no
dracutmodules+=" dash kernel-modules rootfs-block btrfs udev-rules resume usrmount base fs-lib shutdown "
add_drivers+=" btrfs i915 nvidia nvidia_drm nvidia_uvm nvidia_modeset crc32c-intel z3fold "
force_drivers+=" z3fold "
omit_dracutmodules+=" i18n convertfs luks rpmversion lvm securityfs fstab-sys lunmask fstab-sys securityfs img-lib biosdevname caps crypt crypt-gpg dmraid dmsquash-live mdraid "
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

cat <<EOF >/mnt/etc/dracut.conf.d/10-zram.conf
# add_drivers+=" zram "
EOF

cat <<EOF >/mnt/etc/dracut.conf.d/10-lz4.conf
add_drivers+=" lz4hc lz4hc_compress "
EOF

# Mac touchpad
cat <<EOF >/mnt/etc/dracut.conf.d/10-touchpad.conf
# add_drivers+=" bcm5974 "
EOF

# Ignorar alguns pacotes
cat <<EOF >/mnt/etc/xbps.d/99-ignore.conf
ignorepkg=linux
ignorepkg=linux-headers
ignorepkg=nvi
ignorepkg=dhcpcd
ignorepkg=openssh
ignorepkg=xfsprogs
ignorepkg=rtkit
ignorepkg=xf86-input-wacon
ignorepkg=xf86-video-fbdev
ignorepkg=wpa_supplicant
ignorepkg=xf86-video-vesa
ignorepkg=xf86-video-amdgpu
ignorepkg=linux-firmware-amd
ignorepkg=linux-firmware-nvidia
ignorepkg=xf86-video-vmware
ignorepkg=xf86-video-nouveau
ignorepkg=xf86-video-ati
ignorepkg=nvidia
ignorepkg=zd1211-firmware
ignorepkg=os-prober
ignorepkg=ipw2100-firmware
ignorepkg=f2fs-tools
ignorepkg=mobile-broadband-provider-info
EOF

# chroot /mnt xbps-remove -Rcon f2fs-tools linux linux-headers openssh dhcpcd hicolor-icon-theme ipw2100-firmware ipw2200-firmware linux-firmware-amd mobile-broadband-provider-info nvi openssh os-prober rtkit xf86-input-wacom xf86-video-amdgpu xf86-video-ati xf86-video-fbdev xf86-video-nouveau xf86-video-vesa xf86-video-vmware --yes
chroot /mnt xbps-remove -Rcon f2fs-tools openssh dhcpcd hicolor-icon-theme ipw2100-firmware ipw2200-firmware linux-firmware-amd mobile-broadband-provider-info nvi openssh os-prober rtkit xf86-input-wacom xf86-video-amdgpu xf86-video-ati xf86-video-fbdev xf86-video-nouveau xf86-video-vesa xf86-video-vmware --yes



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


#############################
#### Base system chroot #####
#############################

chroot /mnt apt install locale -y

# chroot /mnt export PS1="(chroot) ${PS1}"
chroot /mnt dpkg-reconfigure -f noninteractive tzdata 
chroot /mnt echo 'LANG="en_US.UTF-8"'> /etc/default/locale
chroot /mnt echo 'America/Sao_Paulo'> /etc/timezone

#Locales
chroot /mnt sed -i 's/^# *\(en_US.UTF-8\sUTF-8\)/\1/' /etc/locale.gen
chroot /mnt sed -i 's/^# *\(pt_BR.UTF-8\sUTF-8\)/\1/' /etc/locale.gen
chroot /mnt dpkg-reconfigure --frontend=noninteractive locales
chroot /mnt update-locale LANG=en_US.UTF-8

# Update and install base system
chroot /mnt xbps-install -Suy xbps --yes
chroot /mnt xbps-install -uy
# chroot /mnt $XBPS_ARCH xbps-install -y base-system base-devel linux-firmware intel-ucode linux-firmware-network acl-progs light kbdlight powertop arp-scan xev earlyoom opendoas base-devel zstd bash-completion minised nocache parallel util-linux bcache-tools necho starship linux-lts linux-lts-headers efivar dropbear neovim base-devel gummiboot ripgrep dust exa zoxide fzf xtools lm_sensors inxi lshw intel-ucode zsh alsa-utils vim git wget curl efibootmgr btrfs-progs nano ntfs-3g mtools dosfstools sysfsutils htop elogind dbus-elogind dbus-elogind-libs dbus-elogind-x11 vsv vpm polkit chrony neofetch dust duf lua bat glow bluez bluez-alsa sof-firmware xdg-user-dirs xdg-utils --yes
chroot /mnt $XBPS_ARCH xbps-install base-minimal base-devel libgcc dracut dracut-uefi util-linux bash linux-lts linux-lts-headers efibootmgr sysfsutils acpid opendoas efivar ncurses grep tar less man-pages mdocml elogind acl-progs btrfs-progs dosfstools procps-ng binfmt-support fuse-exfat ethtool eudev iproute2 kmod traceroute python3 python3-pip git gptfdisk linux-firmware lm_sensors pciutils usbutils kbd zstd iputils neovim nano mtools ntfs-3g --yes
# chroot /mnt $XBPS_ARCH xbps-install base-system linux-firmware intel-ucode linux-firmware-network linux5.15 linux5.15-headers efivar efibootmgr opendoas linux-firmware intel-ucode linux-firmware-network acl-progs ntfs-3g mtools sysfsutils base-devel util-linux gummiboot lm_sensors bash zsh man-pages btrfs-progs e2fsprogs dosfstools dash pciutils usbutils kbd ethtool kmod acpid eudev iproute2 traceroute iputils iw zstd --yes
chroot /mnt xbps-remove base-voidstrap --yes

# Xbps wrapper
chroot /mnt xbps-install -Sy vsv vpm --yes

# Ucode
chroot /mnt xbps-install -S intel-ucode --yes

# Gummiboot #
# chroot /mnt xbps-install -S efibootmgr gummiboot --yes

# Grub #
chroot /mnt xbps-install -Sy efibootmgr grub-x86_64-efi grub-btrfs grub-btrfs-runit os-prober acl-progs btrfs-progs --yes

# Audio
chroot /mnt xbps-install -S alsa-utils alsa-pipewire pipewire libspa-bluetooth libjack-pipewire sof-firmware --yes

# Xorg Packages
chroot /mnt xbps-install -S xorg-minimal xsetroot xrefresh xsettingsd xrandr arandr mkfontdir mkfontscale xrdb xev xorg-fonts xprop xcursorgen --yes

# Bluetooth
chroot /mnt xbps-install -S bluez --yes

# Network
chroot /mnt xbps-install -S NetworkManager iwd netcat nfs-utils nm-tray samba arp-scan sv-netmount --yes

# Some firmwares and utils
chroot /mnt xbps-install -S bash-completion bat p7zip neofetch bleachbit btop chrony curl wget fatresize dialog dropbear duf exa fzf gvfs gvfs-afc gvfs-mtp gvfs-smb ffmpegthumbnailer flatpak glow gping gtk2-engines htop jq kbdlight libgsf libinput-gestures libopenraw light lolcat-c lshw lua ripgrep rofi rxvt-unicode rxvt-unicode-terminfo urxvt-bidi urxvt-perls urxvtconfig skim socklog-void speedtest-cli starship tumbler udevil udisks2 unclutter usbutils xtools zip yt-dlp --yes

# Optimizations
chroot /mnt xbps-install -S earlyoom powertop thermald irqbalance --yes

# Intel video card
chroot /mnt xbps-install -S xf86-video-intel mesa-vulkan-intel libva-intel-driver intel-gpu-tools intel-media-driver intel-video-accel --yes

# Infrastructure packages
chroot /mnt xbps-install -S ansible qemu qemu-ga qemu-user-static qemuconf podman podman-compose binfmt-support containers.image buildah slirp4netns cni-plugins fuse-overlayfs --yes

# Create config file to make NetworkManager use iwd as the Wi-Fi backend instead of wpa_supplicant
mkdir -pv /mnt/etc/NetworkManager/conf.d/
touch /mnt/etc/NetworkManager/conf.d/wifi_backend.conf
cat <<EOF >>/mnt/etc/NetworkManager/conf.d/iwd.conf
[device]
wifi.backend=iwd
wifi.iwd.autoconnect=yes
EOF

cat <<EOF >>/mnt/etc/rc.local
modprobe -r usbmouse
modprobe -r bcm5974
modprobe bcm5974
EOF

mkdir -pv /mnt/etc/X11/xorg.conf.d/
touch /mnt/etc/X11/xorg.conf.d/20-intel.conf
cat <<EOF >>/mnt/etc/X11/xorg.conf.d/20-intel.conf
Section "Device"
        Identifier      "Intel Graphics"
        Driver          "Intel"
        Option          "AccelMethod"           "sna"
        Option          "TearFree"              "true"
        Option          "Tiling"                "true"
        Option          "SwapbuffersWait"       "true"
#       Option          "DRI"                   "3"
        Option          "DRI"                   "2"
        Option          "Backlight"             "Intel_backlight"
EndSection

#Section "Device"
#       Identifier      "Intel Graphics"
#       Driver          "modesetting"
#EndSection
EOF
# Set zsh as default
# chroot /mnt chsh -s /usr/bin/zsh root

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

# Gerar initcpio
# chroot /mnt dracut --force --kver 5.15.82_1
# chroot /mnt dracut --force --kver 6.0.13_1
chroot /mnt dracut --force --kver 5.10.159_1
# chroot /mnt dracut -f /boot/initramfs-$(uname -r).img
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
        # Option "XkbModel"     "pc105"
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

touch /mnt/etc/rc.local
cat <<EOF >/mnt/etc/rc.local
#PowerTop
powertop --auto-tune

EOF

touch /mnt/etc/default/earlyoom
cat <<\EOF >/mnt/etc/default/earlyoom
EARLYOOM_ARGS=" -m 96,92 -s 99,99 -r 5 -n --avoid '(^|/)(runit|Xorg|sshd)$'"
EOF

mkdir -pv /mnt/etc/elogind
cat <<EOF >/mnt/etc/elogind/logind.conf
#  This file is part of elogind.
#
#  elogind is free software; you can redistribute it and/or modify it
#  under the terms of the GNU Lesser General Public License as published by
#  the Free Software Foundation; either version 2.1 of the License, or
#  (at your option) any later version.
#
# Entries in this file show the compile time defaults.
# You can change settings by editing this file.
# Defaults can be restored by simply deleting this file.
#
# See logind.conf(5) for details.

[Login]
#KillUserProcesses=no
#KillOnlyUsers=
#KillExcludeUsers=root
#InhibitDelayMaxSec=5
HandlePowerKey=ignore
HandleSuspendKey=ignore
HandleHibernateKey=ignore
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
HandleLidSwitchDocked=ignore
#PowerKeyIgnoreInhibited=no
#SuspendKeyIgnoreInhibited=no
#HibernateKeyIgnoreInhibited=no
#LidSwitchIgnoreInhibited=yes
#HoldoffTimeoutSec=30s
#IdleAction=ignore
#IdleActionSec=30min
#RuntimeDirectorySize=10%
#RuntimeDirectoryInodes=400k
#RemoveIPC=yes
#InhibitorsMax=8192
#SessionsMax=8192

[Sleep]
#AllowSuspend=yes
#AllowHibernation=yes
#AllowSuspendThenHibernate=yes
#AllowHybridSleep=yes
#AllowPowerOffInterrupts=no
#BroadcastPowerOffInterrupts=yes
#AllowSuspendInterrupts=no
#BroadcastSuspendInterrupts=yes
#HandleNvidiaSleep=ignore
#SuspendState=mem standby freeze
#SuspendMode=
#HibernateState=disk
#HibernateMode=platform shutdown
#HybridSleepState=disk
#HybridSleepMode=suspend platform shutdown
#HibernateDelaySec=10800
EOF

#Runit por default
# chroot /mnt ln -sv /etc/sv/dhcpcd /etc/runit/runsvdir/default/
chroot /mnt ln -sv /etc/sv/acpid /etc/runit/runsvdir/default/
# chroot /mnt ln -sv /etc/sv/wpa_supplicant /etc/runit/runsvdir/default/
chroot /mnt ln -sv /etc/sv/chronyd /etc/runit/runsvdir/default/
# chroot /mnt ln -sv /etc/sv/scron /etc/runit/runsvdir/default/
# chroot /mnt ln -sv /etc/sv/tlp /etc/runit/runsvdir/default/
chroot /mnt ln -sv /etc/sv/dropbear /etc/runit/runsvdir/default/
chroot /mnt ln -sv /etc/sv/NetworkManager /etc/runit/runsvdir/default/
chroot /mnt ln -srvf /etc/sv/dbus /etc/runit/runsvdir/default/
chroot /mnt ln -srvf /etc/sv/polkitd /etc/runit/runsvdir/default/
chroot /mnt ln -srvf /etc/sv/elogind /etc/runit/runsvdir/default/
chroot /mnt ln -srvf /etc/sv/bluetoothd /etc/runit/runsvdir/default/
chroot /mnt ln -srvf /etc/sv/avahi-daemon /etc/runit/runsvdir/default/
chroot /mnt ln -srvf /etc/sv/irqbalance /var/service
chroot /mnt ln -srvf /etc/sv/thermald /var/service

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

# alias dissh="export DISPLAY=:0.0"
# alias bquit="bspc quit"

cat <<EOF >/mnt/etc/samba/smb.conf
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

# FIX bad font rendering
chroot /mnt ln -s /usr/share/fontconfig/conf.avail/70-no-bitmaps.conf /etc/fonts/conf.d/
chroot /mnt xbps-reconfigure -f fontconfig

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
cat <<EOF >/mnt/etc/polkit-1/rules.d/10-udisks2.rules
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

# chroot /mnt bash -c 'echo "options root=/dev/vda4 rootflags=subvol=@ rw quiet loglevel=0 console=tty2 acpi_osi=Darwin acpi_mask_gpe=0x06 init_on_alloc=0 udev.log_level=0 zswap.enabled=1 zswap.compressor=zstd zswap.max_pool_percent=10 zswap.zpool=zsmalloc mitigations=off nowatchdog msr.allow_writes=on pcie_aspm=force module.sig_unenforce intel_idle.max_cstate=1 cryptomgr.notests initcall_debug intel_iommu=igfx_off net.ifnames=0 no_timer_check noreplace-smp page_alloc.shuffle=1 rcupdate.rcu_expedited=1 tsc=reliable" >> /boot/loader/entries/void-5.10**'
# chroot /mnt bash -c 'echo "options root=/dev/vda5 rootflags=subvol=@ ro quiet loglevel=0 console=tty2 gpt acpi_osi=Darwin acpi_mask_gpe=0x06 init_on_alloc=0 udev.log_level=0 intel_iommu=on,igfx_off zswap.enabled=1 zswap.compressor=lz4hc zswap.max_pool_percent=10 zswap.zpool=z3fold mitigations=off nowatchdog msr.allow_writes=on pcie_aspm=force module.sig_unenforce intel_idle.max_cstate=1 cryptomgr.notests initcall_debug  net.ifnames=0 no_timer_check noreplace-smp page_alloc.shuffle=1 rcupdate.rcu_expedited=1 tsc=reliable" >> /boot/loader/entries/void-5.15**'
# chroot /mnt bash -c 'echo "options root=/dev/vda5 rootflags=subvol=@ ro quiet loglevel=0 console=tty2 gpt acpi_osi=Darwin acpi_mask_gpe=0x06 init_on_alloc=0 udev.log_level=0 intel_iommu=on,igfx_off zswap.enabled=1 zswap.compressor=lz4hc zswap.max_pool_percent=10 zswap.zpool=z3fold mitigations=off nowatchdog msr.allow_writes=on pcie_aspm=force module.sig_unenforce intel_idle.max_cstate=1 cryptomgr.notests initcall_debug  net.ifnames=0 no_timer_check noreplace-smp page_alloc.shuffle=1 rcupdate.rcu_expedited=1 tsc=reliable" >> /boot/loader/entries/void-6.0.**'

# Grub
# chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot/ --bootloader-id="Void"
chroot /mnt grub-install --target=x86_64-efi --bootloader-id="Voidlinux" --efi-directory=/boot --no-nvram --removable --recheck
# GRUB_CMDLINE_LINUX_DEFAULT="quiet loglevel=0 console=tty2 gpt acpi_osi=Darwin acpi_mask_gpe=0x06 init_on_alloc=0 udev.log_level=0 intel_iommu=on,igfx_off zswap.enabled=1 zswap.compressor=lz4hc zswap.max_pool_percent=10 zswap.zpool=z3fold mitigations=off nowatchdog msr.allow_writes=on pcie_aspm=force module.sig_unenforce intel_idle.max_cstate=1 cryptomgr.notests initcall_debug net.ifnames=0 no_timer_check noreplace-smp page_alloc.shuffle=1 rcupdate.rcu_expedited=1 tsc=reliable"

cat <<EOF >/mnt/etc/default/grub
#
# Configuration file for GRUB.
#
GRUB_DEFAULT=0
#GRUB_HIDDEN_TIMEOUT=0
#GRUB_HIDDEN_TIMEOUT_QUIET=false
GRUB_TIMEOUT=2
GRUB_DISTRIBUTOR="VoidLinux"
GRUB_CMDLINE_LINUX_DEFAULT="quiet loglevel=0 console=tty2 gpt acpi_osi=Darwin acpi_mask_gpe=0x06 b43.allhwsupport=0 init_on_alloc=0 udev.log_level=0 intel_iommu=on,igfx_off zswap.enabled=1 zswap.compressor=lz4hc zswap.max_pool_percent=10 zswap.zpool=z3fold mitigations=off nowatchdog msr.allow_writes=on pcie_aspm=force module.sig_unenforce intel_idle.max_cstate=1 cryptomgr.notests initcall_debug net.ifnames=0 no_timer_check noreplace-smp page_alloc.shuffle=1 rcupdate.rcu_expedited=1 tsc=reliable"

# Uncomment to use basic console
#GRUB_TERMINAL_INPUT="console"
# Uncomment to disable graphical terminal
#GRUB_TERMINAL_OUTPUT=console
GRUB_BACKGROUND=/usr/share/void-artwork/splash.png
#GRUB_GFXMODE=1920x1080x32
#GRUB_DISABLE_LINUX_UUID=true
#GRUB_DISABLE_RECOVERY=true
# Uncomment and set to the desired menu colors.  Used by normal and wallpaper
# modes only.  Entries specified as foreground/background.
GRUB_COLOR_NORMAL="light-blue/black"
GRUB_COLOR_HIGHLIGHT="light-cyan/blue"
EOF

chroot /mnt update-grub

# chroot /mnt dracut --force --kver 5.15.**
# chroot /mnt dracut -f $(uname -r)
# chroot /mnt dracut --force --kver 6.0.13_1
chroot /mnt dracut --force --hostonly --kver 5.10.156_1
# chroot /mnt xbps-reconfigure -fa

# Boot Faster with intel
touch /mnt/etc/modprobe.d/i915.conf
cat <<EOF >/mnt/etc/modprobe.d/i915.conf
options i915 enable_guc=2 enable_dc=4 enable_hangcheck=0 error_capture=0 enable_dp_mst=0 fastboot=1 #parameters may differ
EOF

# Set bash as default
chroot /mnt chsh -s /usr/bin/bash juca

# Some other runit services
git clone --depth=1 https://github.com/madand/runit-services runit-services
mv runit-services /mnt/home/juca/

git clone https://github.com/Nefelim4ag/Ananicy.git ananicy
mv ananicy /mnt/home/juca/runit-services/
# chroot /mnt make install /home/juca/runit-services/ananicy/Makefile
# chroot /mmt rm -rf /lib/systemd
# chroot /mnt mkdir /etc/sv/ananicy
# touch /mnt/etc/sv/ananicy/run
# cat <<EOF >/mnt/etc/sv/ananicy/run
# exec /usr/bin/ananicy start
# EOF
# touch /mnt/etc/sv/ananicy/finish
# cat <<EOF >/mnt/etc/sv/ananicy/finish
# exec /sbin/sysctl -e kernel.sched_autogroup_enabled=1
# EOF

# chroot /mnt ln -srfv /etc/sv/ananicy /var/service

git clone https://github.com/graysky2/profile-sync-daemon profile-sync-daemon
mv profile-sync-daemon /mnt/home/juca/runit-services/
# chroot /mnt make /home/juca/runit-services/profile-sync-daemon/
# chroot /mnt make install /home/juca/runit-services/profile-sync-daemon/
# chroot /mnt rm -rf /usr/lib/systemd/
# mv /mnt/home/juca/runit-services/psd /mnt/etc/sv/
# chroot /mnt ln -srfv /etc/sv/psd /var/service/

printf "\e[1;32mInstallation finished! Review your configuration, umount -a and reboot.\e[0m"
