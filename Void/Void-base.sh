#!/bin/bash

#Formate e crie Pelo menos 3 partições para o: sistema, boot e home . Swap pode ser feito depois, com zram ou zramen
# Baixe o tarball e entre na pasta do arquivo como ex: cd Downloads
#curl or wget -c https://alpha.de.repo.voidlinux.org/live/current/void-x86_64-ROOTFS-20210930.tar.xz

# Instalando pela wifi

# cp /etc/wpa_supplicant/wpa_supplicant.conf /etc/wpa_supplicant/wpa_supplicant-<wlan-interface>.conf
# wpa_passphrase <ssid> <passphrase> >> /etc/wpa_supplicant/wpa_supplicant-<wlan-interface>.conf
# sv restart dhcpcd
# ip link set up <interface>

xbps-install -Sy wget vsv xz vpm neovim git --yes

wget -c https://alpha.de.repo.voidlinux.org/live/current/void-x86_64-ROOTFS-20210930.tar.xz

xbps-install -Su xbps xz --yes

mkfs.vfat -F32 /dev/sda5 -n "VoidEFI"
mkfs.btrfs /dev/sda6 -f -L "VoidRoot"
mkfs.btrfs /dev/sda7 -f -L "VoidHome"

set -e
XBPS_ARCH="x86_64"
BTRFS_OPTS="rw,noatime,ssd,compress-force=zstd:16,space_cache=v2,commit=120,autodefrag,discard=async"
# Mude de acordo com sua partição
mount -o $BTRFS_OPTS /dev/sda6 /mnt

#Cria os subvolumes

btrfs su cr /mnt/@
# btrfs su cr /mnt/@home
btrfs su cr /mnt/@snapshots
btrfs su cr /mnt/@var_log
btrfs su cr /mnt/@var_cache_xbps
btrfs su cr /mnt/@tmp
btrfs su cr /mnt/@swap

# Remove a partição
umount -v /mnt

# mount home subvolume
mount -o $BTRFS_OPTS /dev/sda7 /mnt
btrfs su cr /mnt/@home
umount -v /mnt

# Monta com os valores selecionados
# Lembre-se de mudar os valores de sdX

mount -o $BTRFS_OPTS,subvol=@ /dev/sda6 /mnt
mkdir -pv /mnt/boot/efi
mkdir -pv /mnt/home
mkdir -pv /mnt/.snapshots
mkdir -pv /mnt/var/log
mkdir -pv /mnt/var/tmp
mkdir -pv /mnt/var/cache/xbps
mount -o $BTRFS_OPTS,subvol=@home /dev/sda7 /mnt/home
mount -o $BTRFS_OPTS,subvol=@snapshots /dev/sda6 /mnt/.snapshots
mount -o $BTRFS_OPTS,subvol=@var_log /dev/sda6 /mnt/var/log
mount -o $BTRFS_OPTS,subvol=@tmp /dev/sda6 /mnt/var/tmp
mount -o $BTRFS_OPTS,subvol=@var_cache_xbps /dev/sda6 /mnt/var/cache/xbps
mount -t vfat -o rw,defaults,noatime,nodiratime /dev/sda5 /mnt/boot/efi

# Descompacta e copia para /mnt o tarball
tar xvf ./void-x86_64-*.tar.xz -C /mnt
sync

for dir in dev proc sys run; do
   mount --rbind /$dir /mnt/$dir
   mount --make-rslave /mnt/$dir
done

cp -v /etc/resolv.conf /mnt/etc/

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
add_drivers+=" crc32c-intel btrfs i915 nvidia nvidia_drm nvidia_uvm nvidia_modeset "
omit_dracutmodules+=" i18n luks rpmversion lvm fstab-sys lunmask fstab-sys securityfs img-lib biosdevname caps crypt crypt-gpg dmraid dmsquash-live mdraid "
show_modules="yes"
# compress="cat";
nofscks="yes"
compress="zstd"
no_host_only_commandline="yes"
EOF

mkdir -pv /mnt/etc/sysctl.d
cat << EOF > /mnt/etc/sysctl.d/00-sysctl.conf
vm.vfs_cache_pressure=500
vm.swappiness=100
vm.dirty_background_ratio=1
vm.dirty_ratio=50
EOF

# Xorg conf dual gpu

mkdir -pv /mnt/etc/X11
touch /mnt/etc/X11/xorg.conf
cat <<EOF >/mnt/etc/X11/xorg.conf
Section "Device"
  Identifier "iGPU"
  Driver "intel"
  Option "AccelMethod" "sna"
  Option "TearFree" "True"
  Option "Tiling" "True"
  Option "SwapbuffersWait" "True"
  Option "DRI" "3"
EndSection

Section "Screen"
  Identifier "iGPU"
  Device "iGPU"
EndSection

Section "Device"
  Identifier "dGPU"
  Driver "nvidia"
  BusID "PCI:1:0:0"
  Option "AllowEmptyInitialConfiguration"
  BoardName "GeForce 1050"
EndSection

Section "Files"
	ModulePath "/usr/lib/nvidia/xorg"
	ModulePath "/usr/lib/xorg/modules"
EndSection

Section "Monitor"
	Identifier "HDMI-1-0"
	#Option "Position" "1920 0" # FOR INBUILT AS SECOND
	Option "Position" "0 0"
EndSection

Section "Monitor"
	Identifier "eDP-1"
	# Option "Position" "0 0"
	Option "Primary" "true"
EndSection
EOF

# mkdir -pv /mnt/etc/X11/xorg.conf.d/
# cat << EOF > /mnt/etc/X11/xorg.conf.d/20-intel.conf
# Section "Device"
#         Identifier      "Intel Graphics"
#         Driver          "Intel"
#         Option          "AccelMethod"           "sna"
#         Option          "TearFree"              "True"
# EndSection
# EOF

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

# Repositorios mais rapidos
cat <<EOF >/mnt/etc/xbps.d/00-repository-main.conf
repository=https://mirrors.servercentral.com/voidlinux/current
EOF

cat <<EOF >/mnt/etc/xbps.d/10-repository-nonfree.conf
repository=https://mirrors.servercentral.com/voidlinux/current/nonfree
EOF

cat <<EOF >/mnt/etc/xbps.d/10-repository-multilib-nonfree.conf
repository=https://mirrors.servercentral.com/voidlinux/current/multilib/nonfree
EOF

cat <<EOF >/mnt/etc/xbps.d/10-repository-multilib.conf
repository=https://mirrors.servercentral.com/voidlinux/current/multilib
EOF

# Ignorar alguns pacotes
cat <<EOF >/mnt/etc/xbps.d/99-ignore.conf
ignorepkg=linux-firmware-amd
ignorepkg=xf86-video-nouveau
ignorepkg=linux
ignorepkg=linux-headers
ignorepkg=nvi
ignorepkg=openssh
ignorepkg=dhcpcd
ignorepkg=xf86-video-amdgpu
ignorepkg=xf86-video-ati
EOF

# Hostname
cat <<EOF >/mnt/etc/hostname
nitrovoid
EOF

# Hosts

cat <<EOF >/mnt/etc/hosts
127.0.0.1 localhost
::1 localhost
127.0.1.1 nitrovoid.localdomain nitrovoid
EOF

# fstab

UEFI_UUID=$(blkid -s UUID -o value /dev/sda5)
ROOT_UUID=$(blkid -s UUID -o value /dev/sda6)
HOME_UUID=$(blkid -s UUID -o value /dev/sda7)
echo $UEFI_UUID
echo $ROOT_UUID
echo $HOME_UUID

cat <<EOF >/mnt/etc/fstab
#
# See fstab(5).
#
# <file system> <dir> <type> <options> <dump> <pass>

# ROOTFS
UUID=$ROOT_UUID /               btrfs rw,noatime,ssd,compress-force=zstd:18,space_cache=v2,commit=120,discard=async,subvol=@               0 1
UUID=$ROOT_UUID /.snapshots     btrfs rw,noatime,ssd,compress-force=zstd:18,space_cache=v2,commit=120,discard=async,subvol=@snapshots      0 2
UUID=$ROOT_UUID /var/log        btrfs rw,noatime,ssd,compress-force=zstd:18,space_cache=v2,commit=120,discard=async,subvol=@var_log        0 2
UUID=$ROOT_UUID /var/tmp        btrfs rw,noatime,ssd,compress-force=zstd:18,space_cache=v2,commit=120,discard=async,subvol=@tmp 0 2
UUID=$ROOT_UUID /var/cache/xbps btrfs rw,noatime,ssd,compress-force=zstd:18,space_cache=v2,commit=120,discard=async,subvol=@var_cache_xbps 0 2

#HOME_FS
UUID=$HOME_UUID /home           btrfs rw,noatime,ssd,compress-force=zstd:18,space_cache=v2,commit=120,discard=async,subvol=@home           0 2

# EFI
UUID=$UEFI_UUID /boot/efi vfat rw,noatime,nodiratime,fmask=0022,dmask=0022,codepage=437,iocharset=iso8859-1,shortname=mixed,utf8,errors=remount-ro 0 2

tmpfs /tmp tmpfs defaults,noatime,nosuid,nodev,mode=1777 0 0
EOF

# Set user permition
# cat << EOF > /mnt/etc/doas.conf
# permit persist :wheel
# permit nopass junior cmd reboot
# permit nopass junior cmd poweroff
# permit nopass junior cmd shutdown
# permit nopass junior cmd halt
# permit nopass junior cmd zzz
# permit nopass junior cmd ZZZ
# EOF
# chroot /mnt chown -c root:root /etc/doas.conf
# chroot /mnt chmod -c 0400 /etc/doas.conf

#Conf rc

# DOAS conf

# Set user permition
cat <<EOF >/mnt/etc/doas.conf
# allow user but require password
permit keepenv :junior

# allow user and dont require a password to execute commands as root
permit nopass keepenv :junior

# mount drives
permit nopass :junior cmd mount
permit nopass :junior cmd umount

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
#HOSTNAME="nitrovoid"

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
chroot /mnt ln -sfv /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime

#Locales
chroot /mnt sed -i 's/^# *\(en_US.UTF-8\sUTF-8\)/\1/' /etc/default/libc-locales
chroot /mnt sed -i 's/^# *\(pt_BR.UTF-8\sUTF-8\)/\1/' /etc/default/libc-locales
chroot /mnt xbps-reconfigure -f glibc-locales

# Update and install base system
chroot /mnt xbps-install -Suy xbps --yes
chroot /mnt xbps-remove -oORvy nvi --yes
chroot /mnt xbps-install -uy
chroot /mnt $XBPS_ARCH xbps-install -Sy void-repo-nonfree base-system base-devel base-files dracut vsv vpm dash vpsm xbps xbps-tests xbps-triggers linux-lts linux-lts-headers linux-firmware fwupd opendoas mtools dosfstools sysfsutils --yes
chroot /mnt vpm up
# chroot /mnt xbps-install -Sy linux-lts linux-lts-headers linux-firmware linux-firmware-intel linux-firmware-nvidia  fwupd opendoas --yes
# chroot /mnt vpm up

# chroot /mnt xbps-install -Sy linux5.4 linux5.4-headers dracut-053_2 dracut-network-053_2 dracut-uefi-053_2 linux-firmware linux-firmware-intel linux-firmware-nvidia linux-firmware-network fwupd opendoas --yes

# Remove Base Strap
chroot /mnt xbps-remove base-voidstrap --yes
chroot /mnt vpm up

# Intel micro-code
chroot /mnt xbps-install -Sy intel-ucode --yes
# chroot /mnt xbps-reconfigure -f linux5.4
chroot /mnt xbps-reconfigure -f linux-lts
chroot /mnt vpm up

# Grub
chroot /mnt xbps-install -Sy efibootmgr grub-x86_64-efi grub-btrfs grub-btrfs-runit grub-customizer os-prober btrfs-progs --yes
# efivar 

# Optimization packages
chroot /mnt xbps-install -Sy acpi acpi_call-dkms acpid irqbalance tlp powerstat x86info schedtool cpuinfo pcc pcc-libs cpufrequtils libcpufreq pstate-frequency thermald preload earlyoom powertop bash-completion --yes

# Needed for DE
chroot /mnt xbps-install -Sy dbus-elogind dbus-elogind-libs dbus-elogind-x11 mate-polkit fuse-usmb gnome-keyring flatpak dumb_runtime_dir xdg-user-dirs-gtk xdg-utils xdg-desktop-portal-gtk --yes

# Utilities
chroot /mnt xbps-install -Sy nocache parallel util-linux bcache-tools zramen udevil smartmontools zstd minised gsmartcontrol ethtool cifs-utils necho lm_sensors xtools necho dropbear btop chrony inxi lshw nano ntfs-3g --yes

# Audio/Video & Others
chroot /mnt xbps-install -Sy xbacklight arp-scan xev mpd ncmpcpp playerctl mpv mpv-mpris deadbeef deadbeef-fb deadbeef-waveform-seekbar yt-dlp redshift redshift-gtk starship neovim ripgrep lsd alsa-firmware alsa-plugins alsa-plugins-ffmpeg alsa-plugins-samplerate alsa-plugins-speex alsa-tools alsa_rnnoise alsa-utils alsaequal alsa-plugins-pulseaudio pulseaudio pulseaudio-utils apulse PAmix pulseaudio-equalizer-ladspa pulsemixer pamixer pavucontrol netcat lsscsi dialog exa fzf dust fzf zsh alsa-utils vim git wget curl htop neofetch duf lua bat glow bluez bluez-alsa sof-firmware --yes
#chroot /mnt xbps-install -y base-minimal x86info schedtool cpuinfo pcc pcc-libs cpufrequtils libcpufreq pstate-frequency thermald zstd linux5.10 linux-base neovim chrony grub-x86_64-efi tlp intel-ucode zsh curl opendoas tlp xorg-minimal libx11 xinit xorg-video-drivers xf86-input-evdev xf86-video-intel xf86-input-libinput libinput-gestures dbus dbus-x11 xorg-input-drivers xsetroot xprop xbacklight xrdb
#chroot /mnt xbps-remove -oORvy sudo

# Install Xorg base & others
chroot /mnt xbps-install -Sy xorg-minimal xorg-server-xdmx xrdb xsetroot xprop xrefresh xorg-fonts xdpyinfo xclipboard xcursorgen mkfontdir mkfontscale xcmsdb libXinerama-devel xf86-input-libinput libinput-gestures setxkbmap fuse-exfat fatresize xauth xrandr arandr font-misc-misc terminus-font dejavu-fonts-ttf --yes

# light

# NetworkManager e iNet Wireless Daemon
chroot /mnt xbps-install -S NetworkManager iwd --yes

# Display Manager
chroot /mnt xbps-install -S lightdm light-locker lightdm-gtk3-greeter lightdm-gtk-greeter-settings lightdm-webkit2-greeter colord colord-gtk gnome-color-manager colordiff --yes

# Config Lightdm
chroot /mnt touch /etc/lightdm/dual.sh
chroot /mnt chmod +x /etc/lightdm/dual.sh
cat <<EOF >/mnt/etc/lightdm/dual.sh
#!/bin/sh
# eDP1 - Lap Screen  |  HDMI-1-0 External monitor
# Lightdm or other script for dual monitor

#xrandr --setprovideroffloadsink NVIDIA-G0 Intel &
#xrandr --setprovideroffloadsink 1 0 &
#xrandr --setprovideroffloadsink modesetting NVIDIA-G0 &
xrandr --setprovideroffloadsink NVIDIA-G0 modesetting &
#xrandr --setprovideroutputsource 1 0 &
xrandr --setprovideroutputsource modesetting NVIDIA-G0 &

numlockx on &

XCOM0=$(xrandr -q | grep 'HDMI-1-0 connected')
XCOM1=$(xrandr --output eDP1 --primary --auto --output HDMI-1-0 --auto --left-of eDP1)
XCOM2=$(xrandr --output eDP1 --primary --auto)
# if the external monitor is connected, then we tell XRANDR to set up an extended desktop
if [ -n "$XCOM0" ] || [ ! "$XCOM0" = "" ]; then
    echo $XCOM1
# if the external monitor is disconnected, then we tell XRANDR to output only to the laptop screen
else
    echo $XCOM2
fi

exit 0
EOF

# Create config file to make NetworkManager use iwd as the Wi-Fi backend instead of wpa_supplicant
mkdir -pv /mnt/etc/NetworkManager/conf.d/
cat <<EOF >>/mnt/etc/NetworkManager/conf.d/wifi_backend.conf
[device]
wifi.backend=iwd
wifi.iwd.autoconnect=yes
EOF

mkdir -pv /mnt/etc/modprobe.d
touch /mnt/etc/modprobe.d/bbswitch.conf
cat <<EOF >/mnt/etc/modprobe.d/bbswitch.conf
options bbswitch load_state=0 unload_state=1 
EOF

# Install Nvidia video drivers
# chroot /mnt xbps-install -S nvidia nvidia-libs-32bit bumblebee bbswitch mesa --yes
chroot /mnt xbps-install -S linux-firmware-intel linux-firmware-nvidia nvidia nvidia-dkms nvidia-gtklibs nvidia-libs nvidia-opencl nv-codec-headers mesa vulkan-loader libva libva-glx libva-utils libva-intel-driver glu mesa-dri mesa-vulkan-intel mesa-intel-dri intel-video-accel mesa-vaapi mesa-demos mesa-vdpau vdpauinfo mesa-vulkan-overlay-layer --yes

# chroot /mnt dracut --force --kver 5.4.**
chroot /mnt dracut --force --kver 5.10.117_1
# chroot /mnt xbps-reconfigure -f linux5.4
chroot /mnt xbps-reconfigure -f linux-lts
# chroot /mnt xbps-install -S bumblebee bbswitch vulkan-loader glu nv-codec-headers mesa-dri mesa-vulkan-intel mesa-intel-dri mesa-vaapi mesa-demos mesa-vdpau vdpauinfo mesa-vulkan-overlay-layer --yes
# bbswitch

# Intel Video Drivers
# chroot /mnt xbps-install -S xf86-video-intel --yes

#chroot /mnt xbps-install -Sy libva-utils libva-vdpau-driver vdpauinfo

# "Mons is a Shell script to quickly manage 2-monitors display using xrandr."
chroot /mnt xbps-install -S mons --yes

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
chroot /mnt xbps-install -S virt-manager virt-manager-tools qemu qemu-ga vde2 bridge-utils dnsmasq ebtables-32bit openbsd-netcat iptables-nft --yes

# NFS
chroot /mnt xbps-install -S nfs-utils sv-netmount --yes

#Install Grub
# mount --bind /sys/firmware/efi/efivars /mnt/sys/firmware/efi/efivars
# chroot /mnt mount -t efivarfs efivarfs /sys/firmware/efi/efivars
# chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id="Void Linux" --recheck
chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id="Void"
chroot /mnt update-grub

# GRUB Configuration

# ROOT_UUID=$(blkid -s UUID -o value /dev/sda6)
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
GRUB_CMDLINE_LINUX_DEFAULT="loglevel=2 quiet apci_osi=Linux udev.log_level=0 acpi_backlight=video gpt acpi=force intel_pstate=active init_on_alloc=0 console=tty2 zswap.enabled=1 zswap.compressor=zstd zswap.max_pool_percent=10 zswap.zpool=zsmalloc mitigations=off nowatchdog msr.allow_writes=on pcie_aspm=force module.sig_unenforce intel_idle.max_cstate=1 cryptomgr.notests initcall_debug nvidia-drm.modeset=1 intel_iommu=on,igfx_off net.ifnames=0 no_timer_check noreplace-smp page_alloc.shuffle=1 rcupdate.rcu_expedited=1 tsc=reliable"
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
chroot /mnt useradd junior -m -c "Reinaldo P JR" -s /bin/bash
chroot /mnt sh -c 'echo "junior:200291" | chpasswd -c SHA512'
chroot /mnt usermod -aG wheel,floppy,audio,video,optical,kvm,lp,storage,cdrom,xbuilder,input,bumblebee junior
chroot /mnt sed -i 's/^#\s*\(%wheel\s*ALL=(ALL)\)/\1/' /etc/sudoers
chroot /mnt sed -i 's/^#\s*\(%wheel\s*ALL=(ALL)\s*NOPASSWD:\s*ALL\)/\1/' /etc/sudoers
chroot /mnt usermod -a -G socklog junior

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
chroot /mnt mkdir -pv /var/swap
mount -o subvol=@swap /dev/sda6 /mnt/var/swap
# chroot /mnt btrfs subvolume create /var/swap
chroot /mnt/ touch var/swap/swapfile
chroot /mnt truncate -s 0 /var/swap/swapfile
chroot /mnt chattr +C /var/swap/swapfile
chroot /mnt btrfs property set /var/swap/swapfile compression none
chroot /mnt chmod 600 /var/swap/swapfile
chroot /mnt dd if=/dev/zero of=/var/swap/swapfile bs=1G count=8 status=progress
chroot /mnt mkswap /var/swap/swapfile
chroot /mnt swapon /var/swap/swapfile

# Add to fstab
SWAP_UUID=$(blkid -s UUID -o value /dev/sda6)
echo $SWAP_UUID
echo " " >>/mnt/etc/fstab
echo "# Swap" >>/mnt/etc/fstab
echo "UUID=$SWAP_UUID /var/swap btrfs defaults,noatime,subvol=@swap 0 0" >>/mnt/etc/fstab
echo "/var/swap/swapfile none swap sw 0 0" >>/mnt/etc/fstab

#Runit por default
chroot /mnt ln -srvf /etc/sv/acpid /etc/runit/runsvdir/default/
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
chroot /mnt ln -sfv /etc/sv/bumblebeed /var/service/
chroot /mnt ln -sfv /etc/sv/irqbalance /var/service/

chroot /mnt ln -srvf /etc/sv/earlyoom /var/service

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

# Boot Faster with intel
touch /mnt/etc/modprobe.d/i915.conf
cat <<EOF >/mnt/etc/modprobe.d/i915.conf
options i915 enable_guc=2 enable_dc=4 enable_hangcheck=0 error_capture=0 enable_dp_mst=0 fastboot=1 #parameters may differ
EOF

# chroot /mnt xbps-reconfigure -f linux5.4
chroot /mnt xbps-reconfigure -f linux-lts

# FIX bad font rendering
chroot /mnt ln -s /usr/share/fontconfig/conf.avail/70-no-bitmaps.conf /etc/fonts/conf.d/
chroot /mnt xbps-reconfigure -f fontconfig

#Fix mount external HD
mkdir -pv /mnt/etc/udev/rules.d
cat <<EOF >/mnt/etc/udev/rules.d/99-udisks2.rules
# UDISKS_FILESYSTEM_SHARED
# ==1: mount filesystem to a shared directory (/media/VolumeName)
# ==0: mount filesystem to a private directory (/run/media/$USER/VolumeName)
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
});
EOF

touch /mnt/etc/rc.local
cat <<EOF >/mnt/etc/rc.local
#PowerTop
powertop --auto-tune

EOF

# install ncdu2
wget -c https://dev.yorhel.nl/download/ncdu-2.1-linux-x86_64.tar.gz
tar -xf ncdu-2.1-linux-x86_64.tar.gz
mv ncdu /mnt/usr/local/bin

git clone --depth=1 https://github.com/madand/runit-services Services
mv Services /mnt/home/junior/

# Gerar initcpio
chroot /mnt xbps-reconfigure -fa

printf "\e[1;32mInstallation finished! Umount -a and reboot.\e[0m"
