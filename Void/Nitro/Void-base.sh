#!/bin/bash

########################
#### Fastest repo's ####
########################

cat <<EOF >/etc/xbps.d/00-repository-main.conf
repository=https://voidlinux.com.br/repo/current
# repository=http://void.chililinux.com/voidlinux/current
repository=https://mirrors.servercentral.com/voidlinux/current
EOF

cat <<EOF >/etc/xbps.d/10-repository-nonfree.conf
repository=https://voidlinux.com.br/repo/current/nonfree
# repository=http://void.chililinux.com/voidlinux/current/nonfree
repository=https://mirrors.servercentral.com/voidlinux/current/nonfree
EOF

cat <<EOF >/etc/xbps.d/10-repository-multilib-nonfree.conf
repository=https://voidlinux.com.br/repo/current/multilib/nonfree
# repository=http://void.chililinux.com/voidlinux/current/multilib/nonfree
repository=https://mirrors.servercentral.com/voidlinux/current/multilib/nonfree
EOF

cat <<EOF >/etc/xbps.d/10-repository-multilib.conf
repository=https://voidlinux.com.br/repo/current/multilib
# repository=http://void.chililinux.com/voidlinux/current/multilib
repository=https://mirrors.servercentral.com/voidlinux/current/multilib
EOF

vpm sync

##########################
#### Download tarball ####
##########################

# GlibC
wget -c https://repo-default.voidlinux.org/live/current/void-x86_64-ROOTFS-20221001.tar.xz
# MUSL
# wget -c https://repo-default.voidlinux.org/live/current/void-x86_64-musl-ROOTFS-20221001.tar.xz

xbps-install -Su xbps xz --yes

# xbps-install -Sy wget vsv xz vpm neovim git --yes

##########################
#### Setup Partitions ####
##########################

sgdisk -t 4:ef00 /dev/sda
sgdisk -c 4:VoidGrub /dev/sda
sgdisk -t 5:8300 /dev/sda
sgdisk -c 5:Voidlinux /dev/sda
sgdisk -p /dev/sda
mkfs.vfat -F32 /dev/sda4 -n "VoidEFI"
mkfs.btrfs /dev/sda5 -f -L "VoidRoot"

####################
#### Some Env's ####
####################

set -e
# GLIBC
XBPS_ARCH="x86_64"
# MUSL
# XBPS_ARCH="x86_64-musl"
BTRFS_OPTS="rw,noatime,ssd,compress-force=zstd:15,space_cache=v2,commit=120,autodefrag,discard=async"
# Mude de acordo com sua partição
mount -o $BTRFS_OPTS /dev/sda5 /mnt

##########################
#### BTRFS SUBVOLUMES ####
##########################

btrfs su cr /mnt/@
btrfs su cr /mnt/@home
btrfs su cr /mnt/@snapshots
btrfs su cr /mnt/@var_log
btrfs su cr /mnt/@var_cache_xbps
btrfs su cr /mnt/@tmp
btrfs su cr /mnt/@swap

# Remove a partição
umount -v /mnt

# mount home subvolume separated home
# mount -o $BTRFS_OPTS /dev/sda7 /mnt
# btrfs su cr /mnt/@home
# umount -v /mnt

# Monta com os valores selecionados
# Lembre-se de mudar os valores de sdX

mount -o $BTRFS_OPTS,subvol=@ /dev/sda5 /mnt
mkdir -pv /mnt/boot/efi
mkdir -pv /mnt/home
mkdir -pv /mnt/.snapshots
mkdir -pv /mnt/var/log
mkdir -pv /mnt/var/tmp
mkdir -pv /mnt/var/cache/xbps
# mount -o $BTRFS_OPTS,subvol=@home /dev/sda7 /mnt/home
mount -o $BTRFS_OPTS,subvol=@home /dev/sda5 /mnt/home
mount -o $BTRFS_OPTS,subvol=@snapshots /dev/sda5 /mnt/.snapshots
mount -o $BTRFS_OPTS,subvol=@var_log /dev/sda5 /mnt/var/log
mount -o $BTRFS_OPTS,subvol=@tmp /dev/sda5 /mnt/var/tmp
mount -o $BTRFS_OPTS,subvol=@var_cache_xbps /dev/sda5 /mnt/var/cache/xbps
mount -t vfat -o rw,defaults,noatime,nodiratime /dev/sda4 /mnt/boot/efi

####################################
#### Decompress tarball to /mnt ####
####################################

# GLIBC
tar xvf ./void-x86_64-*.tar.xz -C /mnt
# Musl
# tar xvf ./void-x86_64-*.tar.xz -C /mnt
sync

####################
### Mount chroot ###
####################

for dir in dev proc sys run; do
   mount --rbind /$dir /mnt/$dir
   mount --make-rslave /mnt/$dir
done

#########################
#### Fix resolv.conf ####
#########################

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

###########################################
#### Dracut, modprobe and sysctl confs ####
###########################################

#desabilitar algumas coisas
mkdir -pv /mnt/etc/modprobe.d
cat <<EOF >/mnt/etc/modprobe.d/blacklist.conf
# Disable watchdog
install iTCO_wdt /bin/true
install iTCO_vendor_support /bin/true

# Disable nouveau
blacklist nouveau
EOF

# Atualiza o initramfs com dracut
mkdir -pv /mnt/etc/dracut.conf.d
cat <<EOF >/mnt/etc/dracut.conf.d/00-dracut.conf
hostonly="yes"
hostonly_cmdline=no
dracutmodules+=" dash kernel-modules rootfs-block btrfs udev-rules resume usrmount base fs-lib shutdown "
use_fstab=yes
add_drivers+=" crc32c-intel drm plymouth "
# force_drivers+=""
omit_dracutmodules+=" i18n luks rpmversion lvm fstab-sys lunmask securityfs img-lib biosdevname caps crypt crypt-gpg dmraid dmsquash-live mdraid  "
show_modules="yes"
# compress="cat";
nofscks="yes"
compress="zstd"
no_host_only_commandline="yes"
EOF

# Early micro code
cat <<EOF >/mnt/etc/dracut.conf.d/intel_ucode.conf
early_microcode=yes
EOF

# Early micro code
cat <<EOF >/mnt/etc/dracut.conf.d/nvidia.conf
add_drivers+=" nvidia nvidia_drm nvidia_uvm nvidia_modeset "
EOF

cat <<EOF >/mnt/etc/dracut.conf.d/intel-graphics.conf
add_drivers+=" i915 "
EOF

cat <<EOF >/mnt/etc/dracut.conf.d/kernel-cmdline.conf
# kernel_cmdline=" quiet intel_pstate=disable apparmor=1 security=apparmor kernel.unprivileged_userns_clone vt.global_cursor_default=0 loglevel=0 gpt init_on_alloc=0 udev.log_level=0 rd.driver.blacklist=grub.nouveau rcutree.rcu_idle_gp_delay=1 intel_iommu=on,igfx_off nvidia-drm.modeset=1 i915.modeset=1 zswap.enabled=1 zswap.compressor=lz4hc zswap.max_pool_percent=25 zswap.zpool=z3fold mitigations=off nowatchdog msr.allow_writes=on pcie_aspm=force module.sig_unenforce intel_idle.max_cstate=1 cryptomgr.notests initcall_debug net.ifnames=0 no_timer_check noreplace-smp page_alloc.shuffle=1 rcupdate.rcu_expedited=1 tsc=reliable "
EOF

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

cat <<EOF >/mnt/etc/dracut.conf.d/10-z3fold.conf
add_drivers+=" z3fold "
EOF

cat <<EOF >/mnt/etc/dracut.conf.d/10-lz4.conf
add_drivers+=" lz4hc lz4hc_compress "
EOF

########################
#### Xorg's Configs ####
########################

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

touch /mnt/etc/X11/xorg.conf.d/30-nvidia.conf
cat << EOF > /mnt/etc/X11/xorg.conf.d/30-nvidia.conf
Section "Device"
    Identifier "Nvidia GTX 1050"
    Driver "nvidia"
    BusID "PCI:1:0:0"
    Option "DPI" "96 x 96"
    Option "AllowEmptyInitialConfiguration" "Yes"
    #  Option "UseDisplayDevice" "none"
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
    Option      "DRI"            "3"
EndSection
EOF

############################################
#### FASTEST GLIBC repo's for my region ####
############################################

cat <<EOF >/mnt/etc/xbps.d/00-repository-main.conf
repository=https://voidlinux.com.br/repo/current
# repository=http://void.chililinux.com/voidlinux/current
repository=https://mirrors.servercentral.com/voidlinux/current
EOF

cat <<EOF >/mnt/etc/xbps.d/10-repository-nonfree.conf
repository=https://voidlinux.com.br/repo/current/nonfree
# repository=http://void.chililinux.com/voidlinux/current/nonfree
# repository=https://mirrors.servercentral.com/voidlinux/current/nonfree
EOF

cat <<EOF >/mnt/etc/xbps.d/10-repository-multilib-nonfree.conf
repository=https://voidlinux.com.br/repo/current/multilib/nonfree
# repository=http://void.chililinux.com/voidlinux/current/multilib/nonfree
repository=https://mirrors.servercentral.com/voidlinux/current/multilib/nonfree
EOF

cat <<EOF >/mnt/etc/xbps.d/10-repository-multilib.conf
repository=https://voidlinux.com.br/repo/current/multilib
# repository=http://void.chililinux.com/voidlinux/current/multilib
repository=https://mirrors.servercentral.com/voidlinux/current/multilib
EOF

###########################################
#### FASTEST MUSL repo's for my region ####
###########################################

# cat <<EOF >/mnt/etc/xbps.d/00-repository-main.conf
# repository=https://mirrors.servercentral.com/voidlinux/current/musl
# EOF

# cat <<EOF >/mnt/etc/xbps.d/10-repository-nonfree.conf
# repository=https://mirrors.servercentral.com/voidlinux/current/musl/nonfree
# EOF

# cat <<EOF >/mnt/etc/xbps.d/10-repository-multilib-nonfree.conf
# repository=https://mirrors.servercentral.com/voidlinux/current/musl/multilib/nonfree
# EOF

# cat <<EOF >/mnt/etc/xbps.d/10-repository-multilib.conf
# repository=https://mirrors.servercentral.com/voidlinux/current/musl/multilib
# EOF

##############################
#### Ignore some packages ####
##############################

cat <<EOF >/mnt/etc/xbps.d/99-ignore.conf
ignorepkg=linux
ignorepkg=linux-headers
ignorepkg=linux-firmware-amd
ignorepkg=xf86-video-nouveau
ignorepkg=linux
ignorepkg=linux-headers
ignorepkg=xfsprogs
ignorepkg=wpa_supplicant
ignorepkg=xf86-input-wacon
ignorepkg=xf86-video-fbdev
ignorepkg=rtkit
ignorepkg=dhcpcd
ignorepkg=nvi
ignorepkg=openssh
ignorepkg=sudo
ignorepkg=xf86-input-wacon
ignorepkg=xf86-video-vesa


ignorepkg=xf86-video-amdgpu
ignorepkg=xf86-video-amdgpu
ignorepkg=xf86-video-ati
ignorepkg=xf86-video-vmware
ignorepkg=xf86-video-nouveau
ignorepkg=zd1211-firmware
ignorepkg=mobile-broadband-provider-info
EOF

##############################
#### Remove some packages ####
##############################

chroot /mnt xbps-remove -Rconn openssh dhcpcd hicolor-icon-theme ipw2100-firmware ipw2200-firmware linux-firmware-amd mobile-broadband-provider-info nvi openssh rtkit xf86-input-wacom xf86-video-amdgpu xf86-video-ati xf86-video-fbdev xf86-video-nouveau xf86-video-vesa xf86-video-vmware --yes

###################
#### Hostname #####
###################

cat <<EOF >/mnt/etc/hostname
nitrovoid
EOF

###############
#### Hosts ####
###############

cat <<EOF >/mnt/etc/hosts
127.0.0.1      localhost
::1            localhost ip6-locahost ip6-loopback
127.0.1.1      nitrovoid.localdomain nitrovoid

ff02::1        ip6-allnodes
ff02::2        ip6-allrouters
EOF

###############
#### FSTAB ####
###############

UEFI_UUID=$(blkid -s UUID -o value /dev/sda4)
ROOT_UUID=$(blkid -s UUID -o value /dev/sda5)
# HOME_UUID=$(blkid -s UUID -o value /dev/sda7)
echo $UEFI_UUID
echo $ROOT_UUID
# echo $HOME_UUID

cat <<EOF >/mnt/etc/fstab
#
# See fstab(5).
#
# <file system> <dir> <type> <options> <dump> <pass>

# ROOTFS
UUID=$ROOT_UUID /               btrfs $BTRFS_OPTS,subvol=@               0 0
UUID=$ROOT_UUID /.snapshots     btrfs $BTRFS_OPTS,subvol=@snapshots      0 0
UUID=$ROOT_UUID /var/log        btrfs $BTRFS_OPTS,subvol=@var_log        0 0
UUID=$ROOT_UUID /var/tmp        btrfs $BTRFS_OPTS,subvol=@tmp 0 0
UUID=$ROOT_UUID /var/cache/xbps btrfs $BTRFS_OPTS,subvol=@var_cache_xbps 0 0

#HOME_FS
# UUID=$HOME_UUID /home           btrfs $BTRFS_OPTS,subvol=@home           0 0
UUID=$ROOT_UUID /home           btrfs $BTRFS_OPTS,subvol=@home           0 0

# EFI
# UUID=$UEFI_UUID /boot/efi vfat rw,noatime,nodiratime,fmask=0022,dmask=0022,codepage=437,iocharset=iso8859-1,shortname=mixed,utf8,errors=remount-ro 0 2
UUID=$UEFI_UUID /boot/efi vfat noatime,nodiratime,defaults 0 2

# TMP
tmpfs /tmp tmpfs defaults,noatime,nosuid,nodev,mode=1777 0 0
EOF

#####################
#### Doas Config ####
#####################

cat <<\EOF >/mnt/etc/doas.conf
# allow user but require password
# permit keepenv :juca

# allow user and dont require a password to execute commands as root
permit nopass keepenv :juca

# mount drives
permit nopass :juca cmd mount
permit nopass :juca cmd umount

# musicpd service start and stop
#permit nopass :juca cmd service args musicpd onestart
#permit nopass :juca cmd service args musicpd onestop

# pkg update
#permit nopass :juca cmd vpm args update

# run personal scripts as root without prompting for a password,
# requires entering the full path when running with doas
#permit nopass :juca cmd /home/username/bin/somescript

# root as root
#permit nopass keepenv root as root
EOF
chroot /mnt chown -c root:root /etc/doas.conf
# chroot /mnt chmod -c 0400 /etc/doas.conf

###################
#### RC Config ####
###################

cat <<EOF >/mnt/etc/rc.conf
# /etc/rc.conf - system configuration for void

# Set the host name.
#
# NOTE: it's preferred to declare the hostname in /etc/hostname instead:
#       - echo myhost > /etc/hostname
#
#HOSTNAME="nitrovoid"

# Set RTC to UTC or localtime.
HARDWARECLOCK="localtime"

# Set timezone, availables timezones at /usr/share/zoneinfo.
TIMEZONE="America/Sao_Paulo"

# Keymap to load, see loadkeys(8).
KEYMAP="br-abnt2"
#KEYMAP="br"

# Console font to load, see setfont(8).
#FONT="lat9w-16"

# Console map to load, see setfont(8).
#FONT_MAP=

# Font unimap to load, see setfont(8).
#FONT_UNIMAP=

# Amount of ttys which should be setup.
#TTYS=

# Podman fix
mount --make-rshared /
EOF

#######################
#### Basic Configs ####
#######################

# chroot /mnt export PS1="(chroot) ${PS1}"
chroot /mnt ln -sfv /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime

#Locales
chroot /mnt sed -i 's/^# *\(en_US.UTF-8\sUTF-8\)/\1/' /etc/default/libc-locales
chroot /mnt sed -i 's/^# *\(pt_BR.UTF-8\sUTF-8\)/\1/' /etc/default/libc-locales
chroot /mnt xbps-reconfigure -f glibc-locales

########################################
#### Update and install base system ####
########################################

chroot /mnt xbps-install -Suy xbps --yes
chroot /mnt xbps-remove -oORvy nvi --yes
chroot /mnt xbps-install -uy
# chroot /mnt $XBPS_ARCH xbps-install -Sy void-repo-nonfree base-system base-devel base-files dracut dracut-uefi vsv vpm dash vpsm xbps linux-lts linux-lts-headers linux-firmware opendoas mtools dosfstools sysfsutils --yes
chroot /mnt $XBPS_ARCH xbps-install base-minimal base-devel cpufrequtils acpica-utils libgcc dracut dracut-uefi vsv vpm vpsm util-linux bash linux-lts linux-lts-headers sysfsutils acpid acpi opendoas efivar ncurses grep tar less man-pages mdocml elogind acl-progs dosfstools procps-ng binfmt-support fuse-exfat ethtool eudev iproute2 kmod traceroute python3 python3-pip git gptfdisk linux-firmware-intel linux-firmware-nvidia lm_sensors pciutils usbutils kbd zstd iputils neovim nano mtools ntfs-3g --yes
chroot /mnt vpm up

#######################
#### Grub Packages ####
#######################

chroot /mnt xbps-install -Sy efibootmgr grub-x86_64-efi os-prober btrfs-progs grub-btrfs grub-btrfs-runit grub-customizer --yes

###########################
#### Remove Base Strap ####
###########################

chroot /mnt xbps-remove base-voidstrap --yes
chroot /mnt vpm up

#############################
#### Audio (Pulseaudio) #####
#############################

chroot /mnt xbps-install -S pulseaudio pulseaudio-utils pulsemixer alsa-plugins-pulseaudio --yes

##########################
#### Intel micro-code ####
##########################

chroot /mnt xbps-install -Sy intel-ucode --yes
chroot /mnt xbps-reconfigure -fa linux-lts
chroot /mnt vpm up

#######################
#### Xorg Packages ####
#######################
chroot /mnt xbps-install -S xorg-minimal xhost xsetroot xrefresh xsettingsd xrandr arandr mkfontdir mkfontscale xrdb xev xorg-fonts xprop xcursorgen --yes

###################
#### Bluetooth ####
###################

chroot /mnt xbps-install -S bluez --yes

#################
#### Network ####
#################

chroot /mnt xbps-install -S NetworkManager iwd netcat nfs-utils nm-tray samba arp-scan sv-netmount --yes

###############################
#### Optimization packages ####
###############################

chroot /mnt xbps-install -Sy irqbalance tlp thermald earlyoom bash-completion --yes

#################################
#### Infrastructure packages ####
#################################

chroot /mnt xbps-install -S ansible virt-manager bridge-utils qemu qemu-ga qemu-user-static qemuconf podman podman-compose binfmt-support containers.image buildah slirp4netns cni-plugins fuse-overlayfs --yes

###############
#### Utils ####
###############

chroot /mnt xbps-install -S bash-completion bat p7zip neofetch btop chrony curl wget dialog dropbear duf exa fzf gvfs gvfs-afc gvfs-mtp gvfs-smb ffmpegthumbnailer flatpak glow gping htop jq libgsf libinput-gestures libopenraw lolcat-c lshw lua ripgrep rofi st skim socklog-void speedtest-cli starship tumbler udevil usbutils xtools zip --yes
chroot /mnt xbps-install -Sy util-linux zramen hwinfo ffmpeg udevil cifs-utils lm_sensors xtools dropbear inxi lshw nano ntfs-3g xdg-user-dirs xdg-utils --yes

# Needed for DE
# chroot /mnt xbps-install -Sy dbus-elogind dbus-elogind-libs dbus-elogind-x11 mate-polkit fuse-usmb gnome-keyring flatpak dumb_runtime_dir xdg-user-dirs-gtk xdg-utils xdg-desktop-portal-gtk --yes

#############################
#### Multimedia packages ####
#############################

# alsa-firmware deadbeef deadbeef-fb deadbeef-waveform-seekbar alsa-plugins alsa-plugins-ffmpeg alsa-plugins-samplerate alsa-plugins-speex alsa-tools alsa_rnnoise alsa-utils alsaequal alsa-plugins-pulseaudio pulseaudio pulseaudio-utils apulse PAmix pulseaudio-equalizer-ladspa pulsemixer pamixer pavucontrol bluez bluez-alsa sof-firmware
chroot /mnt xbps-install -Sy arp-scan xev playerctl mpv neovim ripgrep netcat dialog exa fzf dust fzf zsh alsa-utils vim git wget curl htop neofetch duf lua bat glow --yes
#chroot /mnt xbps-remove -oORvy sudo

# Install Xorg base & others
chroot /mnt xbps-install -Sy xorg-minimal xhost xorg-server-xdmx xrdb xsetroot xprop xrefresh xorg-fonts xdpyinfo xclipboard xcursorgen mkfontdir mkfontscale xcmsdb libXinerama-devel xf86-input-libinput libinput-gestures setxkbmap fuse-exfat fatresize xauth xrandr arandr font-misc-misc terminus-font dejavu-fonts-ttf --yes

# light

# NetworkManager e iNet Wireless Daemon
chroot /mnt xbps-install -S NetworkManager iwd --yes

#########################
#### Display Manager ####
#########################

## LIGHTDM ##

# chroot /mnt xbps-install -S lightdm light-locker lightdm-gtk3-greeter lightdm-gtk-greeter-settings lightdm-webkit2-greeter colord colord-gtk gnome-color-manager colordiff --yes

# Config Lightdm
#chroot /mnt touch /etc/lightdm/dual.sh
#chroot /mnt chmod +x /etc/lightdm/dual.sh
#cat <<EOF >/mnt/etc/lightdm/dual-xrandr.sh
##!/bin/sh
## eDP1 - Lap Screen  |  HDMI-1-0 External monitor
## Lightdm or other script for dual monitor

# #xrandr --setprovideroffloadsink NVIDIA-G0 Intel &
#xrandr --setprovideroffloadsink NVIDIA-G0 modesetting &
#numlockx on &

#XCOM0="$(xrandr -q | grep 'HDMI-1-0 connected')"
## XCOM1=$(xrandr --output eDP1 --primary --auto --output HDMI-1-0 --auto --left-of eDP1)
#XCOM1="$(xrandr --output eDP-1 --primary --mode 1920x1080 --pos 1920x0 --rotate normal --output HDMI-1-0 --mode 1920x1080 --pos 0x0 --rotate normal)"
#XCOM2="$(xrandr --output eDP1 --primary --auto)"

##if the external monitor is connected, then we tell XRANDR to set up an extended desktop
#if [ -n "$XCOM0" ] || [ ! "$XCOM0" = "" ]; then
#   echo $XCOM1
## if the external monitor is disconnected, then we tell XRANDR to output only to the laptop screen
#else
#   echo $XCOM2
#fi

#exit 0

# Create config file to make NetworkManager use iwd as the Wi-Fi backend instead of wpa_supplicant
mkdir -pv /mnt/etc/NetworkManager/conf.d/
touch /mnt/etc/NetworkManager/conf.d/wifi_backend.conf
cat <<EOF >>/mnt/etc/NetworkManager/conf.d/wifi_backend.conf
[device]
wifi.backend=iwd
wifi.iwd.autoconnect=yes
EOF

mkdir -pv /mnt/etc/modprobe.d
touch /mnt/etc/modprobe.d/bbswitch.conf
cat <<EOF >/mnt/etc/modprobe.d/bbswitch.conf
#options bbswitch load_state=0 unload_state=1 
EOF

##############################################
#### Nvidia and Intel Integrated graphics ####
##############################################

# chroot /mnt xbps-install -S nvidia nvidia-libs-32bit bumblebee bbswitch mesa --yes
chroot /mnt xbps-install -S nvidia nvidia-libs-32bit mesa-vaapi intel-media-driver mesa-vulkan-intel vulkan-loader mesa-dri --yes # nvidia
chroot /mnt xbps-install -S mesa-intel-dri libva-glx libva-utils libva-intel-driver mesa-vulkan-intel --yes # intel

# chroot /mnt dracut --force --kver 5.10.162_1
chroot /mnt xbps-reconfigure -f linux-lts
# chroot /mnt xbps-install -S bumblebee bbswitch vulkan-loader glu nv-codec-headers mesa-dri mesa-vulkan-intel mesa-intel-dri mesa-vaapi mesa-demos mesa-vdpau vdpauinfo mesa-vulkan-overlay-layer --yes
# bbswitch

# Intel Video Drivers
# chroot /mnt xbps-install -S xf86-video-intel --yes

#chroot /mnt xbps-install -Sy libva-utils libva-vdpau-driver vdpauinfo

# "Mons is a Shell script to quickly manage 2-monitors display using xrandr."
# chroot /mnt xbps-install -S mons --yes

# chroot /mnt alias ker="uname-r"
# chroot /mnt sudo dracut --force --hostonly --kver $ker

# Install the OpenGL driver for both Intel and AMD
# chroot /mnt xbps-install mesa-dri --yes
# Install the Khronos Vulkan Loader for both Intel and nvidia
# chroot /mnt xbps-install vulkan-loader --yes

#File Management
chroot /mnt xbps-install -S gvfs gvfs-smb gvfs-mtp gvfs-afc gvfs-afp rsync rclone avahi avahi-discover avahi-autoipd avahi-compat-libs avahi-utils udisks2 udiskie samba tumbler ffmpegthumbnailer libgsf libopenraw --yes

# PACKAGES FOR SYSTEM LOGGING
chroot /mnt xbps-install -S socklog-void --yes

# Virt-manager
chroot /mnt xbps-install -S apparmor virt-manager virt-manager-tools qemu qemu-ga vde2 bridge-utils dnsmasq ebtables-32bit openbsd-netcat iptables-nft --yes

# NFS
chroot /mnt xbps-install -S nfs-utils sv-netmount --yes

# Plymouth
# chroot /mnt xbps-install -S plymouth plymouth-data --yes
chroot /mnt xbps-install -S plymouth plymouth-data fbv --yes

#Install Grub
# mount --bind /sys/firmware/efi/efivars /mnt/sys/firmware/efi/efivars
# chroot /mnt mount -t efivarfs efivarfs /sys/firmware/efi/efivars
# chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id="Void Linux" --recheck
chroot /mnt grub-install --target=x86_64-efi --bootloader-id="Void Linux" --efi-directory=/boot/efi --no-nvram --removable --recheck

chroot /mnt update-grub

# GRUB Configuration

# ROOT_UUID=$(blkid -s UUID -o value /dev/sda5)
# echo $ROOT_UUID

cat <<EOF >/mnt/etc/default/grub
#
# Configuration file for GRUB.
#
GRUB_DEFAULT=0
#GRUB_HIDDEN_TIMEOUT=0
#GRUB_HIDDEN_TIMEOUT_QUIET=false
GRUB_TIMEOUT=5
GRUB_DISTRIBUTOR="Void Linux"

GRUB_CMDLINE_LINUX_DEFAULT="quiet splash apci_osi=Linux apparmor=1 intel_pstate=hwp_only security=apparmor kernel.unprivileged_userns_clone vt.global_cursor_default=0 loglevel=0 gpt init_on_alloc=0 udev.log_level=0 rd.driver.blacklist=grub.nouveau rcutree.rcu_idle_gp_delay=1 intel_iommu=on,igfx_off nvidia-drm.modeset=1 i915.modeset=1 zswap.enabled=1 zswap.compressor=lz4hc zswap.max_pool_percent=25 zswap.zpool=z3fold mitigations=off nowatchdog msr.allow_writes=on pcie_aspm=force module.sig_unenforce intel_idle.max_cstate=1 cryptomgr.notests initcall_debug net.ifnames=0 no_timer_check noreplace-smp page_alloc.shuffle=1 rcupdate.rcu_expedited=1 tsc=reliable"


# GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_pstate=disable apparmor=1 security=apparmor kernel.unprivileged_userns_clone vt.global_cursor_default=0 loglevel=0 gpt init_on_alloc=0 udev.log_level=0 rd.driver.blacklist=grub.nouveau rcutree.rcu_idle_gp_delay=1 intel_iommu=on,igfx_off nvidia-drm.modeset=1 i915.modeset=1 zswap.enabled=1 zswap.compressor=lz4hc zswap.max_pool_percent=10 zswap.zpool=z3fold mitigations=off nowatchdog msr.allow_writes=on pcie_aspm=force module.sig_unenforce intel_idle.max_cstate=1 cryptomgr.notests initcall_debug net.ifnames=0 no_timer_check noreplace-smp page_alloc.shuffle=1 rcupdate.rcu_expedited=1 tsc=reliable"
# GRUB_CMDLINE_LINUX_DEFAULT="quiet splash apparmor=1 security=apparmor kernel.unprivileged_userns_clone vt.global_cursor_default=0 loglevel=0 gpt init_on_alloc=0 udev.log_level=0 rd.driver.blacklist=grub.nouveau rcutree.rcu_idle_gp_delay=1 intel_iommu=on,igfx_off nvidia-drm.modeset=1 i915.modeset=1 zswap.enabled=1 zswap.compressor=lz4hc zswap.max_pool_percent=10 zswap.zpool=z3fold mitigations=off nowatchdog msr.allow_writes=on pcie_aspm=force module.sig_unenforce intel_idle.max_cstate=1 cryptomgr.notests initcall_debug net.ifnames=0 no_timer_check noreplace-smp page_alloc.shuffle=1 rcupdate.rcu_expedited=1 tsc=reliable"
# GRUB_CMDLINE_LINUX_DEFAULT="quiet vt.global_cursor_default=0 loglevel=0 gpt init_on_alloc=0 udev.log_level=0 rd.driver.blacklist=grub.nouveau rcutree.rcu_idle_gp_delay=1 intel_iommu=on,igfx_off nvidia-drm.modeset=1 i915.modeset=1 zswap.enabled=1 zswap.compressor=lz4hc zswap.max_pool_percent=10 zswap.zpool=z3fold mitigations=off nowatchdog msr.allow_writes=on pcie_aspm=force module.sig_unenforce intel_idle.max_cstate=1 cryptomgr.notests initcall_debug net.ifnames=0 no_timer_check noreplace-smp page_alloc.shuffle=1 rcupdate.rcu_expedited=1 tsc=reliable"
# GRUB_CMDLINE_LINUX_DEFAULT="loglevel=2 quiet apci_osi=Linux udev.log_level=0 acpi_backlight=video gpt acpi=force init_on_alloc=0 console=tty2 zswap.enabled=1 zswap.compressor=zstd zswap.max_pool_percent=10 zswap.zpool=zsmalloc mitigations=off nowatchdog msr.allow_writes=on pcie_aspm=force module.sig_unenforce intel_idle.max_cstate=1 cryptomgr.notests initcall_debug nvidia-drm.modeset=1 intel_iommu=on,igfx_off net.ifnames=0 no_timer_check noreplace-smp page_alloc.shuffle=1 rcupdate.rcu_expedited=1 tsc=reliable"
# GRUB_CMDLINE_LINUX_DEFAULT="loglevel=2 quiet udev.log_level=0 acpi_backlight=video gpt acpi=force intel_pstate=active init_on_alloc=0 console=tty2 zswap.enabled=1 zswap.compressor=zstd zswap.max_pool_percent=10 zswap.zpool=zsmalloc mitigations=off nowatchdog msr.allow_writes=on pcie_aspm=force module.sig_unenforce intel_idle.max_cstate=1 cryptomgr.notests initcall_debug nvidia-drm.modeset=1 intel_iommu=on,igfx_off net.ifnames=0 no_timer_check noreplace-smp page_alloc.shuffle=1 rcupdate.rcu_expedited=1 tsc=reliable"

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
GRUB_DISABLE_OS_PROBER=false
EOF

chroot /mnt update-grub

#udevil
chroot /mnt sed -i 's/allowed_types = $KNOWN_FILESYSTEMS, file/allowed_types = $KNOWN_FILESYSTEMS, file, cifs, nfs, sshfs, curlftpfs, davfs/g' /etc/udevil/udevil.conf

# Dumb runtime dir
# chroot /mnt sed -i 's/-session   optional   pam_dumb_runtime_dir.so/session    optional   pam_dumb_runtime_dir.so/g' /etc/pam.d/system-login

# Set zsh as default
# chroot /mnt chsh -s /usr/bin/zsh root

# Define user and root password
chroot /mnt sh -c 'echo "root:200291" | chpasswd -c SHA512'
chroot /mnt useradd juca -m -c "Reinaldo P JR" -s /bin/bash
chroot /mnt sh -c 'echo "juca:200291" | chpasswd -c SHA512'
# chroot /mnt usermod -aG wheel,floppy,audio,video,optical,kvm,lp,storage,cdrom,xbuilder,input,bumblebee juca
chroot /mnt usermod -aG wheel,floppy,audio,video,optical,kvm,lp,storage,cdrom,xbuilder,input juca
chroot /mnt sed -i 's/^#\s*\(%wheel\s*ALL=(ALL)\)/\1/' /etc/sudoers
chroot /mnt sed -i 's/^#\s*\(%wheel\s*ALL=(ALL)\s*NOPASSWD:\s*ALL\)/\1/' /etc/sudoers
chroot /mnt usermod -a -G socklog juca

# Refazer as config nvidia
#cat << EOF > /mnt/usr/share/X11/xorg.conf.d/10-nvidia-drm-outputclass.conf
#Section "OutputClass"
#    Identifier "nvidia"
#    MatchDriver "nvidia-drm"
#    Driver "nvidia"
#    Option "AllowEmptyInitialConfiguration"
#    # Option "PrimaryGPU" "yes"
#    ModulePath "/usr/lib/nvidia/xorg"
#    ModulePath "/usr/lib/xorg/modules"
#EndSection
#EOF

# zramen
cat <<EOF >/mnt/etc/sv/zramen/conf
export ZRAM_COMP_ALGORITHM='zstd'
#export ZRAM_PRIORITY=32767
export ZRAM_SIZE=100
#export ZRAM_STREAMS=1
EOF


###################
#### SWAPFILE #####
###################

chroot /mnt mkdir -pv /var/swap
mount -o subvol=@swap /dev/sda5 /mnt/var/swap
touch /mnt/var/swap/swapfile
# chroot /mnt btrfs filesystem mkswapfile --size 8g /var/swap/swapfile
# chroot /mnt swapon /var/swap/swapfile


# chroot /mnt btrfs subvolume create /var/swap
# chroot /mnt/ touch var/swap/swapfile
chroot /mnt truncate -s 0 /var/swap/swapfile
chroot /mnt chattr +C /var/swap/swapfile
# chroot /mnt btrfs property set /var/swap/swapfile compression none
chroot /mnt btrfs property set /var/swap/swapfile compression ""
chroot /mnt chmod 600 /var/swap/swapfile
chroot /mnt dd if=/dev/zero of=/var/swap/swapfile bs=1M count=8192 status=progress

chroot /mnt mkswap /var/swap/swapfile
chroot /mnt swapon -va /var/swap/swapfile


# resume_offset=$(chroot /mnt btrfs inspect-internal map-swapfile -r /var/swap/swapfile)
wget https://raw.githubusercontent.com/osandov/osandov-linux/master/scripts/btrfs_map_physical.c
gcc -O2 btrfs_map_physical.c -o btrfs_map_physical
RESUME_OFFSET=$(($(./btrfs_map_physical /mnt/var/swap/swapfile | awk -F " " 'FNR == 2 {print $NF}')/$(getconf PAGESIZE)))
sed -i "/GRUB_CMDLINE_LINUX_DEFAULT=/s/\"$/ resume=UUID=$ROOT_UUID resume_offset=$RESUME_OFFSET&/" /mnt/etc/default/grub
sed -i "/kernel_cmdline=/s/\"$/ resume=UUID=$ROOT_UUID resume_offset=$RESUME_OFFSET&/" /mnt/etc/dracut.conf.d/kernel-cmdline.conf

# Add to fstab
SWAP_UUID=$(blkid -s UUID -o value /dev/sda5)
echo $SWAP_UUID
echo " " >>/mnt/etc/fstab
echo "# Swap" >>/mnt/etc/fstab
# echo "UUID=$SWAP_UUID /var/swap btrfs defaults,noatime,subvol=@swap 0 0" >>/mnt/etc/fstab
echo "UUID=$SWAP_UUID /var/swap btrfs noatime,subvol=@swap 0 0" >>/mnt/etc/fstab
echo "/var/swap/swapfile none swap sw 0 0" >>/mnt/etc/fstab

################################
#### Runit Default Services ####
################################

# chroot /mnt ln -srvf /etc/sv/acpid /etc/runit/runsvdir/default/
chroot /mnt ln -srvf /etc/sv/preload /var/service/
# chroot /mnt ln -srvf /etc/sv/zramen /etc/runit/runsvdir/default/
# chroot /mnt ln -sv /etc/sv/wpa_supplicant /etc/runit/runsvdir/default/
chroot /mnt ln -srvf /etc/sv/chronyd /etc/runit/runsvdir/default/
# chroot /mnt ln -sv /etc/sv/scron /etc/runit/runsvdir/default/
chroot /mnt ln -sv /etc/sv/tlp /etc/runit/runsvdir/default/
chroot /mnt ln -srvf /etc/sv/dropbear /etc/runit/runsvdir/default/
chroot /mnt ln -srvf /etc/sv/thermald /etc/runit/runsvdir/default/
chroot /mnt ln -srvf /etc/sv/NetworkManager /etc/runit/runsvdir/default/
chroot /mnt ln -srvf /etc/sv/dbus /etc/runit/runsvdir/default/
chroot /mnt ln -srvf /etc/sv/polkitd /etc/runit/runsvdir/default/
chroot /mnt ln -srvf /etc/sv/elogind /etc/runit/runsvdir/default/
chroot /mnt ln -srvf /etc/sv/bluetoothd /etc/runit/runsvdir/default/
chroot /mnt ln -srvf /etc/sv/avahi-daemon /etc/runit/runsvdir/default/
# chroot /mnt ln -sfv /etc/sv/bumblebeed /var/service/
chroot /mnt ln -sfv /etc/sv/irqbalance /var/service/

chroot /mnt ln -srvf /etc/sv/earlyoom /var/service

# podman # 
chroot /mnt ln -srvf /etc/sv/binfmt-support /var/service
chroot /mnt ln -srvf /etc/sv/podman /var/service
chroot /mnt ln -srvf /etc/sv/podman-docker /var/service
chroot /mnt usermod --add-subuids 100000-165535 --add-subgids 100000-165535 juca

cat << EOF >>/mnt/etc/rc.local
# Fix podman
mount --make-rshared /
EOF

# virtmanager #
ln -s /etc/sv/libvirtd /var/service
ln -s /etc/sv/virtlockd /var/service
ln -s /etc/sv/virtlogd /var/service

# Enable socklog, a syslog implementation from the author of runit.
chroot /mnt ln -sv /etc/sv/socklog-unix /etc/runit/runsvdir/default/
chroot /mnt ln -sv /etc/sv/nanoklogd /etc/runit/runsvdir/default/

# NFS
chroot /mnt ln -srvf /etc/sv/rpcbind /etc/runit/runsvdir/default/
chroot /mnt ln -srvf /etc/sv/statd /etc/runit/runsvdir/default/
chroot /mnt ln -srvf /etc/sv/netmount /etc/runit/runsvdir/default/

#Samba
chroot /mnt ln -srvf /etc/sv/smbd /etc/runit/runsvdir/default/
chroot /mnt ln -srvf /etc/sv/nmbd /etc/runit/runsvdir/default/

# Enable the iNet Wireless Daemon for Wi-Fi support
chroot /mnt ln -srvf /etc/sv/iwd /etc/runit/runsvdir/default/

# Virt-manager
chroot /mnt ln -svrf /etc/sv/libvirtd /var/service
chroot /mnt ln -svrf /etc/sv/virtlockd /var/service
chroot /mnt ln -svrf /etc/sv/virtlogd /var/service

### SAMBA CONF ###

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

# # Boot Faster with intel
# touch /mnt/etc/modprobe.d/i915.conf
# cat <<EOF >/mnt/etc/modprobe.d/i915.conf
# options i915 enable_guc=2 enable_dc=4 enable_hangcheck=0 error_capture=0 enable_dp_mst=0 fastboot=1 #parameters may differ
# EOF

# Boot Faster with intel
touch /mnt/etc/modprobe.d/i915.conf
cat <<EOF >/mnt/etc/modprobe.d/i915.conf
options i915 enable_guc=2 enable_fbc=1 enable_dc=4 enable_hangcheck=0 error_capture=0 enable_dp_mst=0 fastboot=1 #parameters may differ
EOF

touch /mnt/etc/modprobe.d/nvidia.conf
cat <<EOF >/mnt/etc/modprobe.d/nvidia.conf
options nvidia_drm modeset=1
EOF

touch /mnt/etc/modprobe.d/nouveau-kms.conf
cat << EOF > /mnt/etc/modprobe.d/nouveau-kms.conf
options nouveau modeset=0
EOF

cat <<EOF >/mnt/etc/sysctl.d/10-conf.conf
net.ipv4.ping_group_range=0 $MAX_GID
EOF

cat <<EOF >/mnt/etc/sysctl.d/10-intel.conf
# Intel Graphics
dev.i915.perf_stream_paranoid=0
EOF


# chroot /mnt xbps-reconfigure -f linux5.4
chroot /mnt xbps-reconfigure -f linux-lts

# FIX bad font rendering
chroot /mnt ln -s /usr/share/fontconfig/conf.avail/70-no-bitmaps.conf /etc/fonts/conf.d/
chroot /mnt xbps-reconfigure -f fontconfig

#Fix mount external HD
mkdir -pv /mnt/etc/udev/rules.d
cat <<\EOF >/mnt/etc/udev/rules.d/99-udisks2.rules
# UDISKS_FILESYSTEM_SHARED
# ==1: mount filesystem to a shared directory (/media/juca/VolumeName)
# ==0: mount filesystem to a private directory (/run/media/juca/VolumeName)
# See udisks(8)
ENV{ID_FS_USAGE}=="filesystem|other|crypto", ENV{UDISKS_FILESYSTEM_SHARED}="1"
EOF

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

cat <<EOF >/mnt/etc/polkit-1/rules.d/00-mount-internal.rules
polkit.addRule(function(action, subject) {
   if ((action.id == "org.freedesktop.udisks2.filesystem-mount-system" &&
      subject.local && subject.active && subject.isInGroup("storage")))
      {
         return polkit.Result.YES;
      }
});
EOF

cat <<EOF >/mnt/etc/udev/rules.d/90-backlight.rules
SUBSYSTEM=="backlight", ACTION=="add", \
  RUN+="/bin/chgrp video /sys/class/backlight/%k/brightness", \
  RUN+="/bin/chmod g+w /sys/class/backlight/%k/brightness"
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

touch /mnt/etc/rc.local
cat <<EOF >/mnt/etc/rc.local
#PowerTop
powertop --auto-tune

EOF

mkdir -pv /mnt/etc/elogind
cat <<EOF >/mnt/etc/elogind/logind.conf
[Login]
#KillUserProcesses=no
#KillOnlyUsers=
#KillExcludeUsers=root
#InhibitDelayMaxSec=5
#HandlePowerKey=ignore
#HandleSuspendKey=ignore
#HandleHibernateKey=ignore
#HandleLidSwitch=ignore
#HandleLidSwitchExternalPower=ignore
#HandleLidSwitchDocked=ignore
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
AllowSuspend=yes
AllowHibernation=yes
AllowSuspendThenHibernate=yes
AllowHybridSleep=yes
#AllowPowerOffInterrupts=no
#BroadcastPowerOffInterrupts=yes
#AllowSuspendInterrupts=no
#BroadcastSuspendInterrupts=yes
HandleNvidiaSleep=ignore
#SuspendState=mem standby freeze
#SuspendMode=
#HibernateState=disk
#HibernateMode=platform shutdown
#HybridSleepState=disk
#HybridSleepMode=suspend platform shutdown
#HibernateDelaySec=10800
EOF
# install ncdu2
# wget -c https://dev.yorhel.nl/download/ncdu-2.1-linux-x86_64.tar.gz
# tar -xf ncdu-2.1-linux-x86_64.tar.gz
# mv ncdu /mnt/usr/local/bin

git clone --depth=1 https://github.com/madand/runit-services Services
mv Services /mnt/home/juca/

# Gerar initcpio
chroot /mnt xbps-reconfigure -fa

printf "\e[1;32mInstallation base finished! Umount -a and reboot.\e[0m"

###################################
############# XFCE4 ###############
###################################

# cat <<EOF >/mnt/etc/xbps.d/90-xfce-ignore.conf
# ignorepkg=ristretto
# ignorepkg=mousepad
# ignorepkg=xfce4-terminal
# ignorepkg=parole
# EOF
# 

###########################
#### Fix Dual provider ####
###########################

touch /mnt/home/juca/.xsessionrc
cat << EOF > /mnt/home/juca/.xsessionrc
### Dual Video
xrandr --setprovideroutputsource NVIDIA-G0 modesetting &
EOF

##Fix distrobox
touch /mnt/home/juca/.xprofile
cat << EOF > /mnt/home/juca/.xprofile
### Distrobox
xhost +si:localuser:$USER
EOF

chroot /mnt chmod +x /home/juca/.xsessionrc
chroot /mnt chown -R juca:juca /home/juca/.xsessionrc
chroot /mnt chmod +x /home/juca/.xprofile
chroot /mnt chown -R juca:juca /home/juca/.xprofile

# chroot /mnt xbps-install -Sy xorg-minimal xfce4-appfinder xfce4-battery-plugin xfce4-clipman-plugin xfce4-cpufreq-plugin xfce4-genmon-plugin xfce4-notifyd xfce4-panel xfce4-panel-appmenu xfce4-places-plugin xfce4-power-manager xfce4-pulseaudio-plugin xfce4-screensaver xfce4-screenshooter xfce4-sensors-plugin xfce4-session xfce4-settings xfce4-systemload-plugin xfce4-taskmanager xfce4-terminal xfce4-timer-plugin xfce4-verve-plugin xfce4-whiskermenu-plugin xfce4-xkb-plugin Thunar thunar-volman thunar-archive-plugin thunar-media-tags-plugin ristretto xarchiver mousepad xfwm4 xfdesktop zathura zathura-pdf-poppler gvfs gvfs-mtp gvfs-gphoto2 xfce-polkit parole
# chroot /mnt xbps-install -Sy xfce4
printf "\e[1;32mInstallation xfce4 finished! Umount -a and reboot.\e[0m"

###################################
############## Gnome ##############
###################################

# https://gist.github.com/karyan40024/398671398915888f977b8bddb33ab1f1#installation
# https://www.reddit.com/r/voidlinux/comments/xpl3vx/void_gnome/

# cat <<EOF >/mnt/etc/xbps.d/90-gnome-ignore.conf
# ignorepkg=gnome-maps
# ignorepkg=gnome-console
# ignorepkg=gnome-system-monitor
# ignorepkg=yelp
# EOF

# xinput xload xlsatoms xlsclients

# chroot /mnt xbps-install -Sy gnome tilix python3 python3-pip sushi python3-psutil nautilus-python --yes

#  cat /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor

# https://superuser.com/questions/1581885/btrfs-luks-swapfile-how-to-hibernate-on-swapfile

# chroot /mnt /bin/su - juca