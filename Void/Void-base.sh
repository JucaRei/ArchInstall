#!/bin/bash

#Formate e crie Pelo menos 3 partições para o: sistema, boot e home . Swap pode ser feito depois, com zram ou zramen
# Baixe o tarball e entre na pasta do arquivo como ex: cd Downloads
#curl or wget -c https://alpha.de.repo.voidlinux.org/live/current/void-x86_64-ROOTFS-20210930.tar.xz

# Instalando pela wifi

# cp /etc/wpa_supplicant/wpa_supplicant.conf /etc/wpa_supplicant/wpa_supplicant-<wlan-interface>.conf
# wpa_passphrase <ssid> <passphrase> >> /etc/wpa_supplicant/wpa_supplicant-<wlan-interface>.conf
# sv restart dhcpcd
# ip link set up <interface>


wget -c https://alpha.de.repo.voidlinux.org/live/current/void-x86_64-ROOTFS-20210930.tar.xz

xbps-install -Su xbps xz --yes

mkfs.vfat -F32 /dev/sda5 -n "Void"
mkfs.btrfs /dev/sda6 -f -L "VoidRoot"
mkfs.btrfs /dev/sda7 -f -L "VoidHome"

set -e
XBPS_ARCH="x86_64"
BTRFS_OPTS="noatime,ssd,compress-force=zstd:18,space_cache=v2,commit=120,autodefrag,discard=async"
# Mude de acordo com sua partição
mount -o $BTRFS_OPTS /dev/sda6 /mnt

#Cria os subvolumes

btrfs su cr /mnt/@
# btrfs su cr /mnt/@home
btrfs su cr /mnt/@snapshots
btrfs su cr /mnt/@var_log
btrfs su cr /mnt/@var_cache_xbps

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
mkdir -pv /mnt/var/cache/xbps
mount -o $BTRFS_OPTS,subvol=@home /dev/sda7 /mnt/home
mount -o $BTRFS_OPTS,subvol=@snapshots /dev/sda6 /mnt/.snapshots
mount -o $BTRFS_OPTS,subvol=@var_log /dev/sda6 /mnt/var/log
mount -o $BTRFS_OPTS,subvol=@var_cache_xbps /dev/sda6 /mnt/var/cache/xbps
mount -t vfat -o defaults,noatime,nodiratime /dev/sda5 /mnt/boot/efi

# Descompacta e copia para /mnt o tarball
tar xvf ./void-x86_64-*.tar.xz -C /mnt;sync;

for dir in dev proc sys run; do mount --rbind /$dir /mnt/$dir; mount --make-rslave /mnt/$dir; done

# copia o arquivo de resolv para o /mnt
cp -v /etc/resolv.conf /mnt/etc/

#desabilitar algumas coisas
mkdir -pv /mnt/etc/modprobe.d
cat << EOF > /mnt/etc/modprobe.d/blacklist.conf
# Disable watchdog
#install iTCO_wdt /bin/true
#install iTCO_vendor_support /bin/true

# Disable nouveau
blacklist nouveau
EOF

# Atualiza o initramfs com dracut
mkdir -pv /mnt/etc/dracut.conf.d
cat << EOF > /mnt/etc/dracut.conf.d/00-dracut.conf
hostonly="yes"
add_drivers+=" crc32c-intel i915 btrfs nvidia nvidia_drm nvidia_uvm nvidia_modeset "
omit_dracutmodules+=" lvm luks "
compress="zstd"
EOF

# Arrumar placa intel
#mkdir -pv /mnt/etc/X11/xorg.conf.d
#cat << EOF > /mnt/etc/X11/xorg.conf.d/20-intel.conf
#Section "Device"
#	Identifier "Intel Graphics"
#	Driver "modesetting"
#EndSection
#EOF

#Alternatively, you can use the nvidia-xconfig utility to insert these changes into xorg.conf with a single command:
# nvidia-xconfig --busid=PCI:3:0:0 --sli=AA

# Arrumar placa nvidia
# mkdir -pv /mnt/etc/X11/xorg.conf.d
# cat << EOF > /mnt/etc/X11/xorg.conf.d/20-nvidia.conf
# Section "Device"
#     Identifier     "Intel iGPU"
#     Driver         "intel"
#     BusID          "PCI:0:2:0"
# EndSection

# Section "Device"
#     Identifier "Nvidia Card"
#     Driver "nvidia"
#     VendorName "NVIDIA Corporation"
#     BoardName "GeForce GTX 1050"
# 	# Option         "Coolbits" "24"
# 	BusID          "PCI:2:0:0"
# EndSection
# EOF

# cat << EOF > /mnt/etc/X11/xorg.conf.d/20-nvidia.conf
# Section "Device"
#        Identifier "Nvidia Card"
#        Driver "nvidia"
#        VendorName "NVIDIA Corporation"
#        BoardName "GeForce GTX 1050"
# EndSection
# EOF

# Arrumar placa nvidia
#mkdir -pv /mnt/etc/X11/xorg.conf.d
#cat << EOF > /mnt/etc/X11/xorg.conf.d/10-nvidia.conf
#Section "Device"
#    Identifier     "Device0"
#    Driver         "nvidia"
#    VendorName     "NVIDIA Corporation"
#    BusID          "PCI:1:0:0"
#EndSection
#EOF

# no usr/share
mkdir -pv /mnt/usr/share/X11/xorg.conf.d
cat << EOF > /mnt/usr/share/X11/xorg.conf.d/10-nvidia-drm-outputclass.conf
Section "ServerLayout"
  Identifier "layout"
  Option "AllowNVIDIAGPUScreens"
EndSection

Section "OutputClass"
    Identifier "intel"
    MatchDriver "i915"
    Driver "modesetting"
EndSection

Section "OutputClass"
    Identifier "nvidia"
    MatchDriver "nvidia-drm"
    Driver "nvidia"
    Option "AllowEmptyInitialConfiguration"
    # Option "PrimaryGPU" "yes"
    ModulePath "/usr/lib/nvidia/xorg"
    ModulePath "/usr/lib/xorg/modules"
EndSection
EOF

mkdir -pv /mnt/etc/X11/xorg.conf.d/
cat << EOF > /mnt/etc/X11/xorg.conf.d/30-touchpad.conf
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

#Xorg Conf
# cat << EOF > /mnt/etc/X11/xorg.conf
# Section "ServerLayout"
# 	Identifier     "X.org Configured"
# 	Screen      0  "Screen0" 0 0
# 	Screen      1  "Screen1" RightOf "Screen0"
# 	InputDevice    "Mouse0" "CorePointer"
# 	InputDevice    "Keyboard0" "CoreKeyboard"
# EndSection

# Section "Files"
# 	ModulePath   "/usr/lib/xorg/modules"
# 	FontPath     "/usr/share/fonts/misc"
# 	FontPath     "/usr/share/fonts/TTF"
# 	FontPath     "/usr/share/fonts/OTF"
# 	FontPath     "/usr/share/fonts/Type1"
# 	FontPath     "/usr/share/fonts/100dpi"
# 	FontPath     "/usr/share/fonts/75dpi"
# EndSection

# Section "Module"
# 	Load  "glx"
# EndSection

# Section "InputDevice"
# 	Identifier  "Keyboard0"
# 	Driver      "kbd"
# EndSection

# Section "InputDevice"
# 	Identifier  "Mouse0"
# 	Driver      "mouse"
# 	Option	    "Protocol" "auto"
# 	Option	    "Device" "/dev/input/mice"
# 	Option	    "ZAxisMapping" "4 5 6 7"
# EndSection

# Section "Monitor"
# 	Identifier   "Monitor0"
# 	VendorName   "Monitor Vendor"
# 	ModelName    "Monitor Model"
# EndSection

# Section "Monitor"
# 	Identifier   "Monitor1"
# 	VendorName   "Monitor Vendor"
# 	ModelName    "Monitor Model"
# EndSection

# Section "Device"
# 	Identifier  "Card0"
# 	Driver      "intel"
# 	BusID       "PCI:0:2:0"
# EndSection

# Section "Device"
# 	Identifier  "Card1"
# 	Driver      "nvidia"
# 	BusID       "PCI:1:0:0"
# EndSection

# Section "Screen"
# 	Identifier "Screen0"
# 	Device     "Card0"
# 	Monitor    "Monitor0"
# 	SubSection "Display"
# 		Viewport   0 0
# 		Depth     1
# 	EndSubSection
# 	SubSection "Display"
# 		Viewport   0 0
# 		Depth     4
# 	EndSubSection
# 	SubSection "Display"
# 		Viewport   0 0
# 		Depth     8
# 	EndSubSection
# 	SubSection "Display"
# 		Viewport   0 0
# 		Depth     15
# 	EndSubSection
# 	SubSection "Display"
# 		Viewport   0 0
# 		Depth     16
# 	EndSubSection
# 	SubSection "Display"
# 		Viewport   0 0
# 		Depth     24
# 	EndSubSection
# EndSection

# Section "Screen"
# 	Identifier "Screen1"
# 	Device     "Card1"
# 	Monitor    "Monitor1"
# 	SubSection "Display"
# 		Viewport   0 0
# 		Depth     1
# 	EndSubSection
# 	SubSection "Display"
# 		Viewport   0 0
# 		Depth     4
# 	EndSubSection
# 	SubSection "Display"
# 		Viewport   0 0
# 		Depth     8
# 	EndSubSection
# 	SubSection "Display"
# 		Viewport   0 0
# 		Depth     15
# 	EndSubSection
# 	SubSection "Display"
# 		Viewport   0 0
# 		Depth     16
# 	EndSubSection
# 	SubSection "Display"
# 		Viewport   0 0
# 		Depth     24
# 	EndSubSection
# EndSection
# EOF

# Repositorios mais rapidos
cat << EOF > /mnt/etc/xbps.d/00-repository-main.conf
repository=https://mirrors.servercentral.com/voidlinux/current
EOF

cat << EOF > /mnt/etc/xbps.d/10-repository-nonfree.conf
repository=https://mirrors.servercentral.com/voidlinux/current/nonfree
EOF

cat << EOF > /mnt/etc/xbps.d/10-repository-multilib-nonfree.conf
repository=https://mirrors.servercentral.com/voidlinux/current/multilib/nonfree
EOF

cat << EOF > /mnt/etc/xbps.d/10-repository-multilib.conf
repository=https://mirrors.servercentral.com/voidlinux/current/multilib
EOF

# Ignorar alguns pacotes
cat << EOF > /mnt/etc/xbps.d/99-ignore.conf
ignorepkg=linux-firmware-amd
ignorepkg=xf86-video-nouveau
ignorepkg=linux
ignorepkg=linux-headers
EOF


# Hostname
cat << EOF > /mnt/etc/hostname
nitrovoid
EOF

# Hosts

cat << EOF > /mnt/etc/hosts
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

cat << EOF > /mnt/etc/fstab
#
# See fstab(5).
#
# <file system> <dir> <type> <options> <dump> <pass>

# ROOTFS
UUID=$ROOT_UUID /               btrfs rw,noatime,ssd,compress-force=zstd:18,space_cache=v2,commit=120,discard=async,subvol=@               0 1
UUID=$ROOT_UUID /.snapshots     btrfs rw,noatime,ssd,compress-force=zstd:18,space_cache=v2,commit=120,discard=async,subvol=@snapshots      0 2
UUID=$ROOT_UUID /var/log        btrfs rw,noatime,ssd,compress-force=zstd:18,space_cache=v2,commit=120,discard=async,subvol=@var_log        0 2
UUID=$ROOT_UUID /var/cache/xbps btrfs rw,noatime,ssd,compress-force=zstd:18,space_cache=v2,commit=120,discard=async,subvol=@var_cache_xbps 0 2

#HOME_FS
UUID=$HOME_UUID /home           btrfs rw,noatime,ssd,compress-force=zstd:18,space_cache=v2,commit=120,discard=async,subvol=@home           0 2

# EFI
UUID=$UEFI_UUID /boot/efi vfat rw,noatime,nodiratime,fmask=0022,dmask=0022,codepage=437,iocharset=iso8859-1,shortname=mixed,utf8,errors=remount-ro 0 2

tmpfs /tmp tmpfs noatime,mode=1777 0 0
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



cat << EOF > /mnt/etc/rc.conf
# /etc/rc.conf - system configuration for void

# Set the host name.
#
# NOTE: it's preferred to declare the hostname in /etc/hostname instead:
#       - echo myhost > /etc/hostname
#
#HOSTNAME="nitrovoid"

# Set RTC to UTC or localtime.
HARDWARECLOCK="UTC"

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
chroot /mnt xbps-install -uy
chroot /mnt $XBPS_ARCH xbps-install -y base-system linux-firmware linux-firmware-intel linux-firmware-intel linux-firmware-nvidia arp-scan xev opendoas zstd bash-completion minised nocache parallel util-linux bcache-tools necho starship linux-lts linux-lts-headers efivar neovim base-devel dropbear grub-x86_64-efi ripgrep alsa-plugins-pulseaudio netcat lsscsi dialog exa fzf dust fzf lm_sensors xtools inxi lshw intel-ucode zsh necho alsa-utils vim git wget curl efibootmgr btrfs-progs  nano ntfs-3g mtools dosfstools sysfsutils htop grub-x86_64-efi dbus-elogind dbus-elogind-libs dbus-elogind-x11 vsv vpm mate-polkit chrony neofetch dust duf lua bat glow bluez bluez-alsa sof-firmware xdg-user-dirs xdg-utils xdg-desktop-portal-gtk --yes
chroot /mnt xbps-remove base-voidstrap --yes
#chroot /mnt xbps-install -y base-minimal zstd linux5.10 linux-base neovim chrony grub-x86_64-efi tlp intel-ucode zsh curl opendoas tlp xorg-minimal libx11 xinit xorg-video-drivers xf86-input-evdev xf86-video-intel xf86-input-libinput libinput-gestures dbus dbus-x11 xorg-input-drivers xsetroot xprop xbacklight xrdb
#chroot /mnt xbps-remove -oORvy sudo

# Install Xorg base & others
chroot /mnt xbps-install -Sy xorg-minimal xorg-server-xdmx xrdb xsetroot xbacklight xprop  xrefresh  xorg-fonts xdpyinfo xclipboard xcursorgen mkfontdir mkfontscale xcmsdb  libXinerama-devel xf86-input-libinput libinput-gestures setxkbmap fuse-exfat fatresize xauth xrandr arandr font-misc-misc terminus-font dejavu-fonts-ttf --yes

# NetworkManager e iNet Wireless Daemon
chroot /mnt xbps-install -S NetworkManager iwd --yes

# Create config file to make NetworkManager use iwd as the Wi-Fi backend instead of wpa_supplicant
mkdir -pv /mnt/etc/NetworkManager/conf.d/
cat <<EOF >> /mnt/etc/NetworkManager/conf.d/wifi_backend.conf
[device]
wifi.backend=iwd
wifi.iwd.autoconnect=yes
EOF

# Install Nvidia video drivers
chroot /mnt xbps-install -S nvidia nvidia-libs-32bit vulkan-loader nv-codec-headers mesa-dri mesa-vulkan-intel mesa-intel-dri mesa-vaapi mesa-vdpau mesa-vulkan-overlay--layer --yes

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
chroot /mnt xbps-install -S gvfs gvfs-smb gvfs-mtp gvfs-afc avahi avahi-discover udisks2 udiskie samba tumbler ffmpegthumbnailer libgsf libopenraw --yes

# PACKAGES FOR SYSTEM LOGGING
chroot /mnt xbps-install -S socklog-void --yes

# NFS
chroot /mnt xbps-install -S nfs-utils sv-netmount --yes

#Install Grub
mount --bind /sys/firmware/efi/efivars /mnt/sys/firmware/efi/efivars
chroot /mnt mount -t efivarfs efivarfs /sys/firmware/efi/efivars
chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id="VoidLinux"
chroot /mnt update-grub

# GRUB Configuration

cat << EOF > /mnt/etc/default/grub
#
# Configuration file for GRUB.
#
GRUB_DEFAULT=0
#GRUB_HIDDEN_TIMEOUT=0
#GRUB_HIDDEN_TIMEOUT_QUIET=false
GRUB_TIMEOUT=7
GRUB_DISTRIBUTOR="VoidLinux"
#GRUB_CMDLINE_LINUX_DEFAULT="loglevel=4 mitigations=off intel_iommu=igfx_off i915.modeset=1"
GRUB_CMDLINE_LINUX_DEFAULT="loglevel=2 quiet udev.log_level=0 acpi_backlight=video console=tty2 zswap.enabled=1 zswap.compressor=zstd zswap.max_pool_percent=10 zswap.zpool=zsmalloc mitigations=off nowatchdog msr.allow_writes=on pcie_aspm=force module.sig_unenforce intel_idle.max_cstate=1 ahci.mobile_lpm_policy=1 cryptomgr.notests initcall_debug nvidia-drm.modeset=1 intel_iommu=on,igfx_off net.ifnames=0 no_timer_check noreplace-smp page_alloc.shuffle=1 rcupdate.rcu_expedited=1 tsc=reliable"
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

# Set zsh as default
chroot /mnt chsh -s /usr/bin/zsh root

# Define user and root password
chroot /mnt sh -c 'echo "root:200291" | chpasswd -c SHA512'
chroot /mnt useradd junior -m -c "Reinaldo P JR" -s /bin/bash
chroot /mnt sh -c 'echo "junior:200291" | chpasswd -c SHA512'
chroot /mnt usermod -aG wheel,floppy,audio,video,optical,kvm,lp,storage,cdrom,xbuilder,input junior
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

# Gerar initcpio
chroot /mnt xbps-reconfigure -fa

#Runit por default
# chroot /mnt ln -sv /etc/sv/wpa_supplicant /etc/runit/runsvdir/default/
chroot /mnt ln -srvf /etc/sv/chronyd /etc/runit/runsvdir/default/
# chroot /mnt ln -sv /etc/sv/scron /etc/runit/runsvdir/default/
# chroot /mnt ln -sv /etc/sv/tlp /etc/runit/runsvdir/default/
chroot /mnt ln -srvf /etc/sv/dropbear /etc/runit/runsvdir/default/
chroot /mnt ln -srvf /etc/sv/NetworkManager /etc/runit/runsvdir/default/
chroot /mnt ln -srvf /etc/sv/dbus /etc/runit/runsvdir/default/
chroot /mnt ln -srvf /etc/sv/polkitd /etc/runit/runsvdir/default/
chroot /mnt ln -srvf /etc/sv/elogind /etc/runit/runsvdir/default/
chroot /mnt ln -srvf /etc/sv/bluetoothd /etc/runit/runsvdir/default/
chroot /mnt ln -srvf /etc/sv/avahi-daemon /etc/runit/runsvdir/default/

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


#Fix mount external HD
mkdir -pv /mnt/etc/udev/rules.d
cat << EOF > /mnt/etc/udev/rules.d/99-udisks2.rules
# UDISKS_FILESYSTEM_SHARED
# ==1: mount filesystem to a shared directory (/media/VolumeName)
# ==0: mount filesystem to a private directory (/run/media/$USER/VolumeName)
# See udisks(8)
ENV{ID_FS_USAGE}=="filesystem|other|crypto", ENV{UDISKS_FILESYSTEM_SHARED}="1"
EOF

# Not asking for password
mkdir -pv /mnt/etc/polkit-1/rules.d
cat << EOF > /mnt/etc/polkit-1/rules.d/10-udisks2.rules
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

# install ncdu2
wget -c https://dev.yorhel.nl/download/ncdu-2.1-linux-x86_64.tar.gz
tar -xf ncdu-2.1-linux-x86_64.tar.gz
mv ncdu /mnt/usr/local/bin
