#!/bin/bash

DRIVE="/dev/vda"

sgdisk -Z $DRIVE
# parted $DRIVE mklabel gpt
# parted $DRIVE mkpart primary 2048s 100%
parted --script --fix --align optimal $DRIVE mklabel gpt
parted --script --fix --align optimal $DRIVE mkpart primary fat32 1MiB 512MiB
parted --script $DRIVE -- set 1 boot on

# parted --script --align optimal -- $DRIVE mkpart primary 600MB 100%
# parted --script --align optimal --fix -- $DRIVE mkpart primary linux-swap -2GiB -1s
parted --script --align optimal --fix -- $DRIVE mkpart primary 512MiB -4GiB
parted --script --align optimal --fix -- $DRIVE mkpart primary -4GiB 100%

# parted --script align-check 1 $DRIVE


sgdisk -c 1:"EFI FileSystem partition" ${DRIVE}
sgdisk -c 2:"Voidlinux FileSystem" ${DRIVE}
sgdisk -c 3:"Voidlinux Swap" ${DRIVE}
sgdisk -p ${DRIVE}

BOOT_PARTITION="${DRIVE}1"
ROOT_PARTITION="${DRIVE}2"
SWAP_PARTITION="${DRIVE}3"

### Format
mkfs.vfat -F 32 $BOOT_PARTITION -n "EFI"
mkfs.btrfs $ROOT_PARTITION -f -L "Voidlinux"
sleep 1
mkswap $SWAP_PARTITION -L "SWAP"
swapon /dev/disk/by-label/SWAP

BTRFS_OPTS="noatime,ssd,compress-force=zstd:15,space_cache=v2,nodatacow,commit=120,discard=async"

## fstab real hardware ##
UEFI_UUID=$(blkid -s UUID -o value $BOOT_PARTITION)
ROOT_UUID=$(blkid -s UUID -o value $ROOT_PARTITION)
SWAP_UUID=$(blkid -s UUID -o value $SWAP_PARTITION)

mount -o $BTRFS_OPTS /dev/disk/by-label/Voidlinux /mnt
btrfs su cr /mnt/@root
btrfs su cr /mnt/@home
btrfs su cr /mnt/@snapshots
btrfs su cr /mnt/@logs
btrfs su cr /mnt/@xbps
btrfs su cr /mnt/@tmp
btrfs su cr /mnt/@swap

umount -Rv /mnt

mount -o $BTRFS_OPTS,subvol="@root" /dev/disk/by-label/Voidlinux /mnt
mkdir -pv /mnt/boot/efi
mkdir -pv /mnt/home
mkdir -pv /mnt/.snapshots
mkdir -pv /mnt/var/log
mkdir -pv /mnt/var/tmp
mkdir -pv /mnt/var/cache/xbps
mkdir -pv /mnt/var/swap
mount -o $BTRFS_OPTS,subvol="@home" /dev/disk/by-label/Voidlinux /mnt/home
mount -o $BTRFS_OPTS,subvol="@snapshots" /dev/disk/by-label/Voidlinux /mnt/.snapshots
# mount -o $BTRFS_OPTS,subvol=@swap /dev/disk/by-label/Voidlinux /mnt/var/swap
mount -o $BTRFS_OPTS,subvol="@tmp" /dev/disk/by-label/Voidlinux /mnt/var/tmp
mount -o $BTRFS_OPTS,subvol="@logs" /dev/disk/by-label/Voidlinux /mnt/var/log
mount -o $BTRFS_OPTS,subvol="@xbps" /dev/disk/by-label/Voidlinux /mnt/var/cache/xbps
mount -t vfat -o defaults,noatime,nodiratime /dev/disk/by-label/EFI /mnt/boot/efi

lsblk --output "NAME,SIZE,FSTYPE,FSVER,LABEL,PARTLABEL,UUID,FSAVAIL,FSUSE%,MOUNTPOINTS,DISC-MAX" "$disk"

vpm sync
xbps-install -Su xbps --y

vpm sync
xbps-install -Su xz --yes

# MUSL
wget -c https://repo-default.voidlinux.org/live/current/void-x86_64-musl-ROOTFS-20240314.tar.xz


set -e
# MUSL
ARCH="x86_64-musl"

# Musl
tar xvf ./void-x86_64-musl*.tar.xz -C /mnt
sync

# Monta chroot
for dir in dev proc sys run; do
   mount --rbind /$dir /mnt/$dir
   mount --make-rslave /mnt/$dir
done

# copia o arquivo de resolv para o /mnt
# cp -v /etc/resolv.conf /mnt/etc/

cat <<EOF >/mnt/etc/resolv.conf
nameserver 8.8.8.8
nameserver 8.8.4.4
nameserver 1.1.1.1
EOF

#Copy the RSA keys from the installation medium to the target root directory
mkdir -pv /mnt/var/db/xbps/keys
cp /var/db/xbps/keys/* /mnt/var/db/xbps/keys/

#desabilitar algumas coisas
mkdir -pv /mnt/etc/modprobe.d
cat <<EOF >/mnt/etc/modprobe.d/blacklist.conf
# Disable watchdog
#install iTCO_wdt /bin/true
#install iTCO_vendor_support /bin/true

# Disable nouveau
#blacklist nouveau
EOF

# Atualiza o initramfs com dracut
mkdir -pv /mnt/etc/dracut.conf.d
touch /mnt/etc/dracut.conf.d/00-dracut.conf
cat <<EOF >/mnt/etc/dracut.conf.d/00-dracut.conf
hostonly="yes"
hostonly_cmdline=no
dracutmodules+=" dash drm kernel-modules rootfs-block btrfs udev-rules resume usrmount base fs-lib shutdown "
use_fstab=yes
add_drivers+=" crc32c-intel btrfs ahci "
omit_dracutmodules+=" i18n luks rpmversion lvm fstab-sys lunmask fstab-sys securityfs img-lib biosdevname caps crypt crypt-gpg dmraid dmsquash-live mdraid "
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

mkdir -pv /mnt/etc/sysctl.d
cat <<EOF >/mnt/etc/sysctl.d/00-swap.conf
vm.vfs_cache_pressure=300
vm.swappiness=75
vm.dirty_background_ratio=1
vm.dirty_ratio=50
EOF

cat <<EOF >/mnt/etc/sysctl.d/00-intel.conf
# Intel Graphics
# dev.i915.perf_stream_paranoid=0
EOF

cat <<EOF >/mnt/etc/dracut.conf.d/10-zram.conf
add_drivers+=" zram z3fold "
EOF

cat <<EOF >/mnt/etc/dracut.conf.d/10-lz4.conf
add_drivers+=" lz4hc lz4hc_compress "
EOF

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
cat <<EOF > /mnt/etc/X11/xorg.conf.d/30-nvidia.conf
#Section "Device"
#    Identifier "Nvidia GTX 1050"
#    Driver "nvidia"
#    BusID "PCI:1:0:0"
#    Option "DPI" "96 x 96"
#    Option "AllowEmptyInitialConfiguration" "Yes"
#    #  Option "UseDisplayDevice" "none"
#EndSection
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

# Repositorios mais rapidos MUSL
cat <<EOF >/mnt/etc/xbps.d/00-repository-main.conf
repository=https://repo-default.voidlinux.org/current/musl
EOF

cat <<EOF >/mnt/etc/xbps.d/10-repository-nonfree.conf
repository=https://repo-default.voidlinux.org/current/musl/nonfree
EOF

# Ignorar alguns pacotes
cat <<EOF >/mnt/etc/xbps.d/99-ignore.conf
ignorepkg=linux
ignorepkg=linux-headers
ignorepkg=linux-firmware-amd
ignorepkg=xf86-video-nouveau
# ignorepkg=xfsprogs
# ignorepkg=wpa_supplicant
ignorepkg=xf86-input-wacon
ignorepkg=xf86-video-fbdev
# ignorepkg=rtkit
# ignorepkg=dhcpcd
ignorepkg=nvi
# ignorepkg=openssh
ignorepkg=xf86-video-amdgpu
ignorepkg=xf86-video-amdgpu
ignorepkg=xf86-video-ati
ignorepkg=xf86-video-vmware
ignorepkg=xf86-video-nouveau
ignorepkg=zd1211-firmware
# ignorepkg=mobile-broadband-provider-info
EOF

# Remove some packages
chroot /mnt xbps-remove -Rconn hicolor-icon-theme ipw2100-firmware ipw2200-firmware linux-firmware-amd nvi xf86-input-wacom xf86-video-amdgpu xf86-video-ati xf86-video-fbdev xf86-video-nouveau xf86-video-vesa xf86-video-vmware --yes

# Hostname
cat <<EOF >/mnt/etc/hostname
minimech
EOF

# Hosts

cat <<EOF >/mnt/etc/hosts
127.0.0.1       localhost
::1             localhost ip6-locahost ip6-loopback
127.0.1.1       minimech.localdomain minimech
ff02::1         ip6-allnodes
ff02::2         ip6-allrouters
EOF

BTRFS_OPTS="noatime,ssd,compress-force=zstd:15,space_cache=v2,nodatacow,commit=120,discard=async"

cat <<EOF >/mnt/etc/fstab
#
# See fstab(5).
#
# <file system> <dir> <type> <options> <dump> <pass>

# ROOTFS
# UUID=$ROOT_UUID /               btrfs $BTRFS_OPTS,subvol=@               0 0
# UUID=$ROOT_UUID /.snapshots     btrfs $BTRFS_OPTS,subvol=@snapshots      0 0
# UUID=$ROOT_UUID /var/log        btrfs $BTRFS_OPTS,subvol=@logs           0 0
# UUID=$ROOT_UUID /var/tmp        btrfs $BTRFS_OPTS,subvol=@tmp            0 0
# UUID=$ROOT_UUID /var/cache/xbps btrfs $BTRFS_OPTS,subvol=@xbps           0 0

LABEL="Voidlinux" /               btrfs $BTRFS_OPTS,subvol=@root           0 0
LABEL="Voidlinux" /.snapshots     btrfs $BTRFS_OPTS,subvol=@snapshots      0 0
LABEL="Voidlinux" /var/log        btrfs $BTRFS_OPTS,subvol=@logs           0 0
LABEL="Voidlinux" /var/tmp        btrfs $BTRFS_OPTS,subvol=@tmp            0 0
LABEL="Voidlinux" /var/cache/xbps btrfs $BTRFS_OPTS,subvol=@xbps           0 0


#HOME_FS
# UUID=$HOME_UUID /home           btrfs $BTRFS_OPTS,subvol=@home           0 0
LABEL="Voidlinux" /home           btrfs $BTRFS_OPTS,subvol=@home           0 0

# EFI
# UUID=$UEFI_UUID /boot/efi      vfat   defaults,noatime,nodiratime        0 2
LABEL="EFI"       /boot/efi      vfat   noatime,nodiratime,defaults        0 2

# SWAP
# UUID=$UEFI_UUID /boot/efi      vfat   defaults,noatime,nodiratime        0 2
LABEL="SWAP"      none           swap   defaults,noatime                   0 0

tmpfs             /tmp           tmpfs  noatime,nosuid,nodev,mode=1777     0 0
EOF

# Set user permition
# cat << EOF > /mnt/etc/doas.conf
# permit persist :wheel
# permit nopass juca cmd reboot
# permit nopass juca cmd poweroff
# permit nopass juca cmd shutdown
# permit nopass juca cmd halt
# permit nopass juca cmd zzz
# permit nopass juca cmd ZZZ
# EOF
# chroot /mnt chown -c root:root /etc/doas.conf
# chroot /mnt chmod -c 0400 /etc/doas.conf

#Conf rc


# Set user permition
cat <<EOF >/mnt/etc/doas.conf
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

# RC Conf

cat <<EOF >/mnt/etc/rc.conf
# /etc/rc.conf - system configuration for void

# Set the host name.
#
# NOTE: it's preferred to declare the hostname in /etc/hostname instead:
#       - echo myhost > /etc/hostname
#
#HOSTNAME="nitrovm"

# Set RTC to UTC or localtime.
HARDWARECLOCK="localtime"

# Set timezone, availables timezones at /usr/share/zoneinfo.
#TIMEZONE="America/Sao_Paulo"

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
EOF

##    chroot

# chroot /mnt export PS1="(chroot) ${PS1}"
chroot /mnt ln -srfv /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime

#Locales
# chroot /mnt sed -i 's/^# *\(en_US.UTF-8\sUTF-8\)/\1/' /etc/default/libc-locales
# chroot /mnt sed -i 's/^# *\(pt_BR.UTF-8\sUTF-8\)/\1/' /etc/default/libc-locales
# chroot /mnt xbps-reconfigure -f glibc-locales

# Update and install base system
chroot /mnt xbps-install -Suy xbps --yes
chroot /mnt xbps-remove -oORvy nvi --yes
chroot /mnt xbps-install -uy
# chroot /mnt $XBPS_ARCH xbps-install -Sy void-repo-nonfree base-system base-devel base-files dracut dracut-uefi vsv vpm dash vpsm xbps linux-lts linux-lts-headers linux-firmware opendoas mtools dosfstools sysfsutils elogind --yes
chroot /mnt $XBPS_ARCH xbps-install -S  base-minimal linux-base base-devel libgcc rng-tools dracut dracut-uefi vsv vpm vpsm vpnd util-linux bash linux5.10 linux5.10-headers sysfsutils acpid opendoas efivar ncurses grep tar less man-pages mdocml acl-progs dosfstools procps-ng binfmt-support fuse-exfat ethtool eudev iproute2 kmod traceroute gptfdisk lm_sensors pciutils usbutils kbd zstd nano mtools ntfs-3g chrony polkit --yes
chroot /mnt vpm up
# chroot /mnt vpm up

# Grub #
chroot /mnt xbps-install -Sy efibootmgr grub-x86_64-efi os-prober acl-progs btrfs-progs --yes

# Remove Base Strap
chroot /mnt xbps-remove base-voidstrap --yes
chroot /mnt vpm up

#Audio
chroot /mnt xbps-install -S pulseaudio alsa-plugins-pulseaudio --yes
# pulsemixer pulseaudio-utils

## Pipewire system-wide
# chroot /mnt xbps-install -S --yes pipewire alsa-pipewire libspa-bluetooth
# mkdir -pv /mnt/etc/pipewire/pipewire.conf.d
# ln -svf /mnt/usr/share/examples/wireplumber/10-wireplumber.conf /mnt/etc/pipewire/pipewire.conf.d/
# User
# mkdir -p "${XDG_CONFIG_HOME}/pipewire/pipewire.conf.d"
# ln -s /usr/share/examples/wireplumber/10-wireplumber.conf "${XDG_CONFIG_HOME}/pipewire/pipewire.conf.d/"

# dbus elogind xdg-desktop-portal-gtk

### Open GL
# mesa-dri vulkan-loader xorg-minimal xorg-fonts mesa-vaapi mesa-vdpau

### Intel
# linux-firmware-intel intel-video-accel

### Nvidia
# nvidia linux-firmware-nvidia nv-codec-headers nvidia-container-toolkit nvidia-dkms nvidia-libs nvidia-libs-32bit nvidia-vaapi-driver nvtop nvidia-gtklibs nvidia-gtklibs-32bit nvidia-docker


# Intel micro-code
# chroot /mnt xbps-install -S intel-ucode --yes
# chroot /mnt xbps-reconfigure -fa linux
# chroot /mnt vpm up

# Xorg Packages
# chroot /mnt xbps-install -S xorg-minimal xsetroot xrefresh xsettingsd xrandr arandr mkfontdir mkfontscale xrdb xev xorg-fonts xprop xcursorgen --yes

# Bluetooth
chroot /mnt xbps-install -S bluez --yes

# Network
chroot /mnt xbps-install -S NetworkManager iwd netcat nfs-utils samba sv-netmount --yes

# Grub
# chroot /mnt xbps-install -Sy efibootmgr grub-x86_64-efi grub-btrfs grub-btrfs-runit grub-customizer os-prober acl-progs btrfs-progs --yes
# efivar

# Optimization packages
chroot /mnt xbps-install -Sy irqbalance thermald earlyoom --yes

# Infrastructure packages
# chroot /mnt xbps-install -S ansible virt-manager bridge-utils qemu qemu-ga qemu-user-static qemuconf podman podman-compose binfmt-support containers.image buildah slirp4netns cni-plugins fuse-overlayfs --yes

# utils
chroot /mnt xbps-install -S elogind bash-completion curl wget dialog gvfs-afc gvfs-mtp gvfs-smb libgsf  socklog-void xtools --yes
# libinput-gestures

# Needed for DE
chroot /mnt xbps-install -Sy polkit-elogind dbus-elogind dbus-elogind-libs dbus-elogind-x11 fuse3 ifuse --yes

# Utilities
chroot /mnt xbps-install -Sy zramen cifs-utils lm_sensors --yes

# Audio/Video & Others
# alsa-firmware deadbeef deadbeef-fb deadbeef-waveform-seekbar alsa-plugins alsa-plugins-ffmpeg alsa-plugins-samplerate alsa-plugins-speex alsa-tools alsa_rnnoise alsa-utils alsaequal alsa-plugins-pulseaudio pulseaudio pulseaudio-utils apulse PAmix pulseaudio-equalizer-ladspa pulsemixer pamixer pavucontrol bluez bluez-alsa sof-firmware
# chroot /mnt xbps-install -Sy arp-scan xev playerctl mpv yt-dlp neovim ripgrep netcat dialog exa fzf dust fzf zsh alsa-utils vim git wget curl htop neofetch duf lua bat glow --yes
#chroot /mnt xbps-install -y base-minimal x86info schedtool cpuinfo pcc pcc-libs cpufrequtils libcpufreq pstate-frequency thermald lsscsi zstd linux5.10 linux-base neovim chrony grub-x86_64-efi tlp intel-ucode zsh curl opendoas tlp xorg-minimal libx11 xinit xorg-video-drivers xf86-input-evdev xf86-video-intel xf86-input-libinput libinput-gestures dbus dbus-x11 xorg-input-drivers xsetroot xprop xbacklight xrdb
#chroot /mnt xbps-remove -oORvy sudo

# Install Xorg base & others
# chroot /mnt xbps-install -Sy xorg-minimal libglapi numlockx xorg-server-xdmx xrdb xsetroot xprop xrefresh xorg-fonts xdpyinfo xclipboard xcursorgen mkfontdir mkfontscale xcmsdb libXinerama-devel xf86-input-libinput libinput-gestures setxkbmap fuse-exfat fatresize xauth xrandr arandr font-misc-misc terminus-font dejavu-fonts-ttf --yes
chroot /mnt xbps-install -Sy xorg-minimal xorg-server-xephyr numlockx xorg-server xorg-fonts mkfontdir mkfontscale libXinerama-devel xf86-input-libinput setxkbmap fatresize xauth xrandr arandr font-misc-misc terminus-font dejavu-fonts-ttf --yes

# light

# Display Manager
# chroot /mnt xbps-install -S lightdm light-locker lightdm-gtk3-greeter lightdm-gtk-greeter-settings lightdm-webkit2-greeter colord colord-gtk gnome-color-manager colordiff --yes

chroot /mnt xbps-install -S lightdm lightdm-gtk3-greeter

# Config Lightdm
# chroot /mnt touch /etc/lightdm/dual.sh
# chroot /mnt chmod +x /etc/lightdm/dual.sh
# cat <<EOF >/mnt/etc/lightdm/dual.sh
#!/bin/sh
# eDP1 - Lap Screen  |  HDMI-1-0 External monitor
# Lightdm or other script for dual monitor

# #xrandr --setprovideroffloadsink NVIDIA-G0 Intel &
# #xrandr --setprovideroffloadsink 1 0 &
# #xrandr --setprovideroffloadsink modesetting NVIDIA-G0 &
#xrandr --setprovideroffloadsink NVIDIA-G0 modesetting &
# #xrandr --setprovideroutputsource 1 0 &
# xrandr --setprovideroutputsource modesetting NVIDIA-G0 &

#numlockx on &

# XCOM0=$(xrandr -q | grep 'HDMI-1-0 connected')
# XCOM1=$(xrandr --output eDP1 --primary --auto --output HDMI-1-0 --auto --left-of eDP1)
# XCOM2=$(xrandr --output eDP1 --primary --auto)
# if the external monitor is connected, then we tell XRANDR to set up an extended desktop
# if [ -n "$XCOM0" ] || [ ! "$XCOM0" = "" ]; then
#     echo $XCOM1
# if the external monitor is disconnected, then we tell XRANDR to output only to the laptop screen
# else
#     echo $XCOM2
# fi

# exit 0
# EOF

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

# Install Nvidia video drivers
# chroot /mnt xbps-install -S nvidia nvidia-libs-32bit bumblebee bbswitch mesa --yes
#chroot /mnt xbps-install -S nvidia nvidia-libs-32bit mesa-vaapi intel-media-driver mesa-vulkan-intel vulkan-loader mesa-dri --yes
# chroot /mnt xbps-install -S linux-firmware-intel linux-firmware-nvidia nvidia nvidia-dkms nvidia-gtklibs nvidia-libs nvidia-opencl nv-codec-headers mesa vulkan-loader libva libva-glx libva-utils libva-intel-driver glu mesa-dri mesa-vulkan-intel mesa-intel-dri intel-video-accel mesa-vaapi mesa-demos mesa-vdpau vdpauinfo mesa-vulkan-overlay-layer --yes

# chroot /mnt dracut --force --kver 5.10.162_1
chroot /mnt xbps-reconfigure -fa
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
# chroot /mnt xbps-install -S gvfs gvfs-smb rsync rclone avahi avahi-discover avahi-utils samba tumbler ffmpegthumbnailer libgsf libopenraw --yes

# PACKAGES FOR SYSTEM LOGGING
# chroot /mnt xbps-install -S socklog-void --yes

# Virt-manager
# chroot /mnt xbps-install -S apparmor virt-manager virt-manager-tools qemu qemu-ga vde2 bridge-utils dnsmasq ebtables-32bit openbsd-netcat iptables-nft --yes

# NFS
chroot /mnt xbps-install -S nix nfs-utils sv-netmount --yes

# Plymouth
# chroot /mnt xbps-install -S plymouth plymouth-data --yes
# chroot /mnt xbps-install -S plymouth plymouth-data fbv --yes

#Install Grub
# mount --bind /sys/firmware/efi/efivars /mnt/sys/firmware/efi/efivars
# chroot /mnt mount -t efivarfs efivarfs /sys/firmware/efi/efivars
# chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id="Void Linux" --recheck
chroot /mnt grub-install --target=x86_64-efi --bootloader-id="Void" --efi-directory=/boot/efi --no-nvram --removable --recheck

chroot /mnt update-grub

# GRUB Configuration

# ROOT_UUID=$(blkid -s UUID -o value /dev/vda2)
# echo $ROOT_UUID

cat <<EOF >/etc/default/grub
#
# Configuration file for GRUB.
#
GRUB_DEFAULT=0
#GRUB_HIDDEN_TIMEOUT=0
#GRUB_HIDDEN_TIMEOUT_QUIET=false
GRUB_TIMEOUT=5
GRUB_DISTRIBUTOR="Void Linux"
GRUB_CMDLINE_LINUX_DEFAULT="quiet loglevel=0 gpt udev.log_level=0 zswap.enabled=1 zswap.compressor=lz4hc zswap.max_pool_percent=10 zswap.zpool=z3fold mitigations=off nowatchdog msr.allow_writes=on pcie_aspm=force module.sig_unenforce intel_idle.max_cstate=1 cryptomgr.notests initcall_debug net.ifnames=0 no_timer_check noreplace-smp page_alloc.shuffle=1 rcupdate.rcu_expedited=1 tsc=reliable"

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

# MakeSwap
# chroot /mnt mkdir -pv /var/swap
# mount -o subvol=@swap /dev/vda2 /mnt/var/swap
# chroot /mnt btrfs subvolume create /var/swap
# chroot /mnt/ touch var/swap/swapfile
# chroot /mnt truncate -s 0 /var/swap/swapfile
# chroot /mnt chattr +C /var/swap/swapfile
# chroot /mnt btrfs property set /var/swap/swapfile compression none
# chroot /mnt chmod 600 /var/swap/swapfile
# chroot /mnt dd if=/dev/zero of=/var/swap/swapfile bs=1G count=8 status=progress
# chroot /mnt mkswap /var/swap/swapfile
# chroot /mnt swapon /var/swap/swapfile

# Add to fstab
# SWAP_UUID=$(blkid -s UUID -o value /dev/vda2)
# echo $SWAP_UUID
# echo " " >>/mnt/etc/fstab
# echo "# Swap" >>/mnt/etc/fstab
# echo "UUID=$SWAP_UUID /var/swap btrfs defaults,noatime,subvol=@swap 0 0" >>/mnt/etc/fstab
# echo "/var/swap/swapfile none swap sw 0 0" >>/mnt/etc/fstab

#Runit por default
# chroot /mnt ln -srvf /etc/sv/acpid /etc/runit/runsvdir/default/
# chroot /mnt ln -srvf /etc/sv/preload /var/service/
# chroot /mnt ln -srvf /etc/sv/zramen /etc/runit/runsvdir/default/
# chroot /mnt ln -sv /etc/sv/wpa_supplicant /etc/runit/runsvdir/default/
chroot /mnt ln -srvf /etc/sv/chronyd /etc/runit/runsvdir/default/
# chroot /mnt ln -sv /etc/sv/scron /etc/runit/runsvdir/default/
# chroot /mnt ln -sv /etc/sv/tlp /etc/runit/runsvdir/default/
# chroot /mnt ln -srvf /etc/sv/dropbear /etc/runit/runsvdir/default/
chroot /mnt ln -srvf /etc/sv/sshd /etc/runit/runsvdir/default/
chroot /mnt ln -srvf /etc/sv/thermald /etc/runit/runsvdir/default/
chroot /mnt ln -srvf /etc/sv/NetworkManager /etc/runit/runsvdir/default/
chroot /mnt ln -srvf /etc/sv/dbus /etc/runit/runsvdir/default/
chroot /mnt ln -srvf /etc/sv/polkitd /etc/runit/runsvdir/default/
chroot /mnt ln -srvf /etc/sv/elogind /etc/runit/runsvdir/default/
chroot /mnt ln -srvf /etc/sv/bluetoothd /etc/runit/runsvdir/default/
chroot /mnt ln -srvf /etc/sv/avahi-daemon /etc/runit/runsvdir/default/
chroot /mnt ln -srvf /etc/sv/polkitd /etc/runit/runsvdir/default/
# chroot /mnt ln -sfv /etc/sv/bumblebeed /var/service/
chroot /mnt ln -sfv /etc/sv/irqbalance /var/service/

chroot /mnt ln -srvf /etc/sv/earlyoom /var/service

# Enable socklog, a syslog implementation from the author of runit.
chroot /mnt ln -sv /etc/sv/socklog-unix /etc/runit/runsvdir/default/
chroot /mnt ln -sv /etc/sv/nanoklogd /etc/runit/runsvdir/default/

# NFS
chroot /mnt ln -srvf /etc/sv/rpcbind /etc/runit/runsvdir/default/
chroot /mnt ln -srvf /etc/sv/statd /etc/runit/runsvdir/default/
chroot /mnt ln -srvf /etc/sv/netmount /etc/runit/runsvdir/default/

# Nix
chroot /mnt ln -srvf /etc/sv/nix-daemon /etc/runit/runsvdir/default/

#Samba
chroot /mnt ln -srvf /etc/sv/smbd /etc/runit/runsvdir/default/
chroot /mnt ln -srvf /etc/sv/nmbd /etc/runit/runsvdir/default/

# Enable the iNet Wireless Daemon for Wi-Fi support
chroot /mnt ln -srvf /etc/sv/iwd /etc/runit/runsvdir/default/

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
#options i915 enable_guc=2 enable_fbc=1 enable_dc=4 enable_hangcheck=0 error_capture=0 enable_dp_mst=0 fastboot=1 #parameters may differ
EOF

touch /mnt/etc/modprobe.d/nvidia.conf
cat <<EOF >/mnt/etc/modprobe.d/nvidia.conf
#options nvidia_drm modeset=1
EOF

touch /mnt/etc/modprobe.d/nouveau-kms.conf
cat << EOF > /mnt/etc/modprobe.d/nouveau-kms.conf
#options nouveau modeset=0
EOF

cat <<EOF >/mnt/etc/sysctl.d/10-net.conf
net.ipv4.ping_group_range=0 $MAX_GID
EOF

cat <<EOF >/mnt/etc/sysctl.d/10-intel.conf
# Intel Graphics
#dev.i915.perf_stream_paranoid=0
EOF

### LIBVIRT

# /etc/libvirt/qemu.conf
# security_driver = "apparmor"
# security_driver = "none"

# chroot /mnt xbps-reconfigure -f linux5.4
chroot /mnt xbps-reconfigure -fa

# FIX bad font rendering
chroot /mnt ln -s /usr/share/fontconfig/conf.avail/70-no-bitmaps.conf /etc/fonts/conf.d/
chroot /mnt xbps-reconfigure -f fontconfig

#Fix mount external HD
mkdir -pv /mnt/etc/udev/rules.d
cat <<EOF >/mnt/etc/udev/rules.d/99-udisks2.rules
# UDISKS_FILESYSTEM_SHARED
# ==1: mount filesystem to a shared directory (/media/VolumeName)
# ==0: mount filesystem to a private directory (/run/media/VolumeName)
# See udisks(8)
ENV{ID_FS_USAGE}=="filesystem|other|crypto", ENV{UDISKS_FILESYSTEM_SHARED}="1"
EOF

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
EOF

touch /mnt/etc/rc.local
cat <<EOF >/mnt/etc/rc.local
#PowerTop
# powertop --auto-tune

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

chroot /mnt cat <<EOF > /etc/xbps.d/90-xfce-ignore.conf
ignorepkg=ristretto
ignorepkg=mousepad
ignorepkg=xfce4-terminal
ignorepkg=parole
EOF


# chroot /mnt xbps-install -Sy xorg-minimal xfce4-appfinder xfce4-battery-plugin xfce4-clipman-plugin xfce4-cpufreq-plugin xfce4-genmon-plugin xfce4-notifyd xfce4-panel xfce4-panel-appmenu xfce4-places-plugin xfce4-power-manager xfce4-pulseaudio-plugin xfce4-screensaver xfce4-screenshooter xfce4-sensors-plugin xfce4-session xfce4-settings xfce4-systemload-plugin xfce4-taskmanager xfce4-terminal xfce4-timer-plugin xfce4-verve-plugin xfce4-whiskermenu-plugin xfce4-xkb-plugin Thunar thunar-volman thunar-archive-plugin thunar-media-tags-plugin ristretto xarchiver mousepad xfwm4 xfdesktop zathura zathura-pdf-poppler gvfs gvfs-mtp gvfs-gphoto2 xfce-polkit parole
# chroot /mnt xbps-install -Sy xfce4 lightdm light-locker lightdm-webkit2-greeter -y
# printf "\e[1;32mInstallation xfce4 finished! Umount -a and reboot.\e[0m"

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
# ignorepkg=Endeavour
# ignorepkg=epiphany
# ignorepkg=gnome-boxes
# ignorepkg=xorg-server-xwayland
# ignorepkg=gnome-builder
# ignorepkg=gnome-terminal
# ignorepkg=cinnamon-translations
# ignorepkg=nautilus
# EOF

# chroot /mnt vpm i gnome gnome-apps nemo nemo-extensions xdg-utils polkit-gnome seahorse pinentry-gnome gnome-usage gthumb nautilus-gnome-terminal-extension gparted gnome-colors-icon-theme gnome-screensaver gnome-icon-theme-extras gnome-epub-thumbnailer gnome-mpv firefox-esr Komikku gnome-power-manager gnome-browser-connector xorg mesa tilix python3 python3-pip sushi python3-psutil --yes

# WaylandEnable=false
# DefaultSession=gnome-xorg.desktop

# tilix --quake

# vpm i gtksourceview4 autoconf automake bison m4 make libtool flex meson ninja optipng sassc tilix dust gnome gdm octoxbps nix docker xdg-desktop-portal-gnome xdg-user-dirs xdg-user-dirs-gtk xdg-utils gnome-browser-connector python3 python3-pip python3-psutil nautilus-python syncthing
