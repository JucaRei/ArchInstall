#!/bin/bash

# BR repo
cat <<EOF >/etc/xbps.d/00-repository-main.conf
repository=https://voidlinux.com.br/repo/current
repository=http://void.chililinux.com/voidlinux/current
repository=https://mirrors.servercentral.com/voidlinux/current
EOF

cat <<EOF >/etc/xbps.d/10-repository-nonfree.conf
repository=https://voidlinux.com.br/repo/current/nonfree
repository=http://void.chililinux.com/voidlinux/current/nonfree
repository=https://mirrors.servercentral.com/voidlinux/current/nonfree
EOF

cat <<EOF >/etc/xbps.d/10-repository-multilib-nonfree.conf
repository=https://voidlinux.com.br/repo/current/multilib/nonfree
repository=http://void.chililinux.com/voidlinux/current/multilib/nonfree
repository=https://mirrors.servercentral.com/voidlinux/current/multilib/nonfree
EOF

cat <<EOF >/etc/xbps.d/10-repository-multilib.conf
repository=https://voidlinux.com.br/repo/current/multilib
repository=http://void.chililinux.com/voidlinux/current/multilib
repository=https://mirrors.servercentral.com/voidlinux/current/multilib
EOF


# GlibC
wget -c https://repo-default.voidlinux.org/live/current/void-x86_64-ROOTFS-20221001.tar.xz
# MUSL
# wget -c https://repo-default.voidlinux.org/live/current/void-x86_64-musl-ROOTFS-20221001.tar.xz

xbps-install -Su xbps xz --yes

xbps-install -Su wget vsv xz vpm neovim git --yes

sgdisk -t 4:ef00 /dev/vda
sgdisk -c 4:VoidGrub /dev/vda
sgdisk -t 6:8300 /dev/vda
sgdisk -c 6:Voidlinux /dev/vda
sgdisk -p /dev/vda
mkfs.vfat -F32 /dev/sda4 -n "VoidEFI"
mkfs.btrfs /dev/sda6 -f -L "VoidRoot"

set -e

# GLIBC
XBPS_ARCH="x86_64"
# MUSL
# XBPS_ARCH="x86_64-musl"
BTRFS_OPTS="rw,noatime,ssd,compress-force=zstd:15,space_cache=v2,commit=120,autodefrag,discard=async"
# Mude de acordo com sua partição
mount -o $BTRFS_OPTS /dev/sda6 /mnt

#Cria os subvolumes

btrfs su cr /mnt/@
btrfs su cr /mnt/@home
btrfs su cr /mnt/@snapshots
btrfs su cr /mnt/@var_log
btrfs su cr /mnt/@var_cache_xbps
# btrfs su cr /mnt/@swap

umount -v /mnt

# Monta com os valores selecionados
# Lembre-se de mudar os valores de sdX

mount -o $BTRFS_OPTS,subvol=@ /dev/sda6 /mnt
mkdir -pv /mnt/boot/efi
mkdir -pv /mnt/home
mkdir -pv /mnt/.snapshots
mkdir -pv /mnt/var/log
mkdir -pv /mnt/var/cache/xbps
mount -o $BTRFS_OPTS,subvol=@home /dev/sda6 /mnt/home
mount -o $BTRFS_OPTS,subvol=@snapshots /dev/sda6 /mnt/.snapshots
mount -o $BTRFS_OPTS,subvol=@var_log /dev/sda6 /mnt/var/log
mount -o $BTRFS_OPTS,subvol=@var_cache_xbps /dev/sda6 /mnt/var/cache/xbps
mount -t vfat -o rw,defaults,noatime,nodiratime /dev/sda4 /mnt/boot/efi

# Descompacta e copia para /mnt o tarball
# GLIBC
tar xvf ./void-x86_64-*.tar.xz -C /mnt
# Musl
# tar xvf ./void-x86_64-*.tar.xz -C /mnt
sync

# Monta chroot
for dir in dev proc sys run; do
   mount --rbind /$dir /mnt/$dir
   mount --make-rslave /mnt/$dir
done

# copia o arquivo de resolv para o /mnt
cp -v /etc/resolv.conf /mnt/etc/

#~ cat <<EOF >/mnt/etc/resolv.conf
#~ nameserver 8.8.8.8
#~ nameserver 8.8.4.4
#~ nameserver 1.1.1.1
#~ EOF

#Copy the RSA keys from the installation medium to the target root directory
mkdir -pv /mnt/var/db/xbps/keys
cp /var/db/xbps/keys/* /mnt/var/db/xbps/keys/

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
force_drivers+=" z3fold "
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
vm.vfs_cache_pressure=500
vm.swappiness=100
vm.dirty_background_ratio=1
vm.dirty_ratio=50
EOF

cat <<EOF >/mnt/etc/sysctl.d/00-intel.conf
# Intel Graphics
dev.i915.perf_stream_paranoid=0
EOF

cat <<EOF >/mnt/etc/dracut.conf.d/10-zram.conf
# add_drivers+=" zram "
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

# Repositorios mais rapidos GLIBC
cat <<EOF >/mnt/etc/xbps.d/00-repository-main.conf
repository=https://voidlinux.com.br/repo/current
repository=http://void.chililinux.com/voidlinux/current
repository=https://mirrors.servercentral.com/voidlinux/current
EOF

cat <<EOF >/mnt/etc/xbps.d/10-repository-nonfree.conf
repository=https://voidlinux.com.br/repo/current/nonfree
repository=http://void.chililinux.com/voidlinux/current/nonfree
# repository=https://mirrors.servercentral.com/voidlinux/current/nonfree
EOF

cat <<EOF >/mnt/etc/xbps.d/10-repository-multilib-nonfree.conf
repository=https://voidlinux.com.br/repo/current/multilib/nonfree
repository=http://void.chililinux.com/voidlinux/current/multilib/nonfree
repository=https://mirrors.servercentral.com/voidlinux/current/multilib/nonfree
EOF

cat <<EOF >/mnt/etc/xbps.d/10-repository-multilib.conf
repository=https://voidlinux.com.br/repo/current/multilib
repository=http://void.chililinux.com/voidlinux/current/multilib
repository=https://mirrors.servercentral.com/voidlinux/current/multilib
EOF

# Ignorar alguns pacotes
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
ignorepkg=openssh
ignorepkg=sudo
ignorepkg=nvi
ignorepkg=xf86-video-amdgpu
ignorepkg=xf86-input-wacon
ignorepkg=xf86-video-ati
ignorepkg=xf86-video-vmware
ignorepkg=xf86-video-nouveau
ignorepkg=xf86-video-vesa
ignorepkg=zd1211-firmware
ignorepkg=mobile-broadband-provider-info
EOF

# Remove some packages
chroot /mnt xbps-remove -Rcon openssh dhcpcd hicolor-icon-theme ipw2100-firmware ipw2200-firmware linux-firmware-amd mobile-broadband-provider-info nvi openssh rtkit xf86-input-wacom xf86-video-amdgpu xf86-video-ati xf86-video-fbdev xf86-video-nouveau xf86-video-vesa xf86-video-vmware --yes

HOSTNAME="nitrovoid"

# Hostname
cat <<EOF >/mnt/etc/hostname
$HOSTNAME
EOF

cat <<EOF >/mnt/etc/xbps.d/90-lxqt-ignore.conf
ignorepkg=qterminal
ignorepkg=lxqt-about
ignorepkg=lxqt-sudo
EOF


# Hosts
cat <<EOF >/mnt/etc/hosts
127.0.0.1      localhost
::1            localhost
127.0.1.1      nitrovoid.localdomain nitrovoid
EOF

# fstab

UEFI_UUID=$(blkid -s UUID -o value /dev/sda4)
ROOT_UUID=$(blkid -s UUID -o value /dev/sda6)
echo $UEFI_UUID
echo $ROOT_UUID

cat <<EOF >/mnt/etc/fstab
#
# See fstab(5).
#
# <file system> <dir> <type> <options> <dump> <pass>

# ROOTFS
UUID=$ROOT_UUID /               btrfs $BTRFS_OPTS,subvol=@               0 0
UUID=$ROOT_UUID /.snapshots     btrfs $BTRFS_OPTS,subvol=@snapshots      0 0
UUID=$ROOT_UUID /var/log        btrfs $BTRFS_OPTS,subvol=@var_log        0 0
UUID=$ROOT_UUID /var/cache/xbps btrfs $BTRFS_OPTS,subvol=@var_cache_xbps 0 0

#HOME_FS
UUID=$ROOT_UUID /home           btrfs $BTRFS_OPTS,subvol=@home           0 0

# EFI
# UUID=$UEFI_UUID /boot/efi vfat rw,noatime,nodiratime,fmask=0022,dmask=0022,codepage=437,iocharset=iso8859-1,shortname=mixed,utf8,errors=remount-ro 0 2
UUID=$UEFI_UUID /boot/efi vfat noatime,nodiratime,defaults 0 2

tmpfs /tmp tmpfs defaults,noatime,nosuid,nodev,mode=1777 0 0
EOF

# DOAS conf
# Set user permition
cat <<\EOF >/mnt/etc/doas.conf
# allow user but require password
permit keepenv :junior

# allow user and dont require a password to execute commands as root
permit nopass keepenv :junior

# mount drives
permit nopass :junior cmd mount
permit nopass :junior cmd umount

# musicpd service start and stop
#permit nopass :junior cmd service args musicpd onestart
#permit nopass :junior cmd service args musicpd onestop

# pkg update
#permit nopass :junior cmd vpm args update

# run personal scripts as root without prompting for a password,
# requires entering the full path when running with doas
#permit nopass :junior cmd /home/username/bin/somescript

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
TIMEZONE="America/Sao_Paulo"

# Keymap to load, see loadkeys(8).
KEYMAP="br-abnt"
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

chroot /mnt ln -sfv /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime

#Locales
chroot /mnt sed -i 's/^# *\(en_US.UTF-8\sUTF-8\)/\1/' /etc/default/libc-locales
chroot /mnt sed -i 's/^# *\(pt_BR.UTF-8\sUTF-8\)/\1/' /etc/default/libc-locales
chroot /mnt xbps-reconfigure -f glibc-locales

# Update and install base system
chroot /mnt xbps-install -Suy xbps --yes
chroot /mnt xbps-remove -oORvy nvi --yes
chroot /mnt xbps-install -uy
# chroot /mnt $XBPS_ARCH xbps-install -Sy void-repo-nonfree base-system base-devel base-files dracut dracut-uefi vsv vpm dash vpsm xbps linux-lts linux-lts-headers linux-firmware opendoas mtools dosfstools sysfsutils --yes
chroot /mnt $XBPS_ARCH xbps-install base-minimal base-devel libgcc dracut dracut-uefi util-linux bash linux-lts linux-lts-headers efibootmgr sysfsutils acpid opendoas efivar ncurses grep tar less man-pages mdocml elogind acl-progs btrfs-progs dosfstools procps-ng binfmt-support fuse-exfat ethtool eudev iproute2 kmod traceroute python3 python3-pip git gptfdisk linux-firmware lm_sensors pciutils usbutils kbd zstd iputils neovim nano mtools ntfs-3g --yes
chroot /mnt xbps-remove base-voidstrap --yes

# Xbps wrapper
chroot /mnt xbps-install -Sy vsv vpm --yes


chroot /mnt vpm up

# Grub #
chroot /mnt xbps-install -Sy efibootmgr grub-x86_64-efi os-prober acl-progs btrfs-progs --yes

#Audio
chroot /mnt xbps-install -S pulseaudio pulseaudio-utils pulsemixer alsa-plugins-pulseaudio --yes

# Intel micro-code
chroot /mnt xbps-install -Sy intel-ucode --yes
chroot /mnt xbps-reconfigure -fa linux-lts

# Xorg Packages
chroot /mnt xbps-install -S xorg-minimal xsetroot xrefresh xsettingsd xrandr arandr mkfontdir mkfontscale xrdb xev xorg-fonts xprop xcursorgen --yes

# Bluetooth
chroot /mnt xbps-install -S bluez --yes

# Network
chroot /mnt xbps-install -S NetworkManager iwd netcat nfs-utils nm-tray samba arp-scan sv-netmount --yes

# Grub
# chroot /mnt xbps-install -Sy efibootmgr grub-x86_64-efi grub-btrfs grub-btrfs-runit grub-customizer os-prober acl-progs btrfs-progs --yes
# efivar

# Optimization packages
chroot /mnt xbps-install -Sy irqbalance tlp thermald earlyoom bash-completion zramen --yes

# Infrastructure packages
chroot /mnt xbps-install -S ansible virt-manager bridge-utils qemu qemu-ga qemu-user-static qemuconf podman podman-compose binfmt-support containers.image buildah slirp4netns cni-plugins fuse-overlayfs --yes

# Some firmwares and utils
chroot /mnt xbps-install -S bash-completion bat p7zip neofetch bleachbit btop chrony curl wget dialog dropbear duf exa fzf gvfs gvfs-afc gvfs-mtp gvfs-smb ffmpegthumbnailer flatpak glow gping htop jq kbdlight libgsf libinput-gestures libopenraw lolcat-c lshw lua ripgrep rofi st skim socklog-void speedtest-cli starship tumbler udevil usbutils xtools zip --yes

# Optimizations
chroot /mnt xbps-install -S earlyoom powertop thermald irqbalance --yes

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

# Set bash as default
chroot /mnt chsh -s /usr/bin/bash root


# NFS
chroot /mnt xbps-install -S nfs-utils sv-netmount --yes

#Install Grub
# mount --bind /sys/firmware/efi/efivars /mnt/sys/firmware/efi/efivars
# chroot /mnt mount -t efivarfs efivarfs /sys/firmware/efi/efivars
# chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id="Void Linux" --recheck
chroot /mnt grub-install --target=x86_64-efi --bootloader-id="Voidlinux" --efi-directory=/boot/efi --no-nvram --removable --recheck
chroot /mnt update-grub

cat <<EOF >/mnt/etc/default/grub
#
# Configuration file for GRUB.
#
GRUB_DEFAULT=0
#GRUB_HIDDEN_TIMEOUT=0
#GRUB_HIDDEN_TIMEOUT_QUIET=false
GRUB_TIMEOUT=5
GRUB_DISTRIBUTOR="Void Linux"
GRUB_CMDLINE_LINUX_DEFAULT="quiet apci_osi=Linux udev.log_level=0 acpi_backlight=vendor vt.global_cursor_default=0 gpt intel_pstate=hwp_only acpi=force init_on_alloc=0 console=tty2 zswap.enabled=1 zswap.compressor=lz4hc zswap.max_pool_percent=10 zswap.zpool=z3fold mitigations=off nowatchdog msr.allow_writes=on pcie_aspm=force module.sig_unenforce intel_idle.max_cstate=1 cryptomgr.notests initcall_debug nvidia-drm.modeset=1 intel_iommu=on,igfx_off net.ifnames=0 no_timer_check noreplace-smp page_alloc.shuffle=1 rcupdate.rcu_expedited=1 tsc=reliable"
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

# Define user and root password
chroot /mnt sh -c 'echo "root:200291" | chpasswd -c SHA512'
chroot /mnt useradd junior -m -c "Reinaldo P JR" -s /bin/bash
chroot /mnt sh -c 'echo "junior:200291" | chpasswd -c SHA512'
# chroot /mnt usermod -aG wheel,floppy,audio,video,optical,kvm,lp,storage,cdrom,xbuilder,input,bumblebee junior
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

# zramen
cat <<EOF >/mnt/etc/sv/zramen/conf
export ZRAM_COMP_ALGORITHM='zstd'
#export ZRAM_PRIORITY=32767
export ZRAM_SIZE=100
#export ZRAM_STREAMS=1
EOF

#Runit por default
chroot /mnt ln -srvf /etc/sv/acpid /etc/runit/runsvdir/default/
chroot /mnt ln -srvf /etc/sv/zramen /etc/runit/runsvdir/default/
chroot /mnt ln -srvf /etc/sv/chronyd /etc/runit/runsvdir/default/
chroot /mnt ln -sv /etc/sv/tlp /etc/runit/runsvdir/default/
chroot /mnt ln -srvf /etc/sv/dropbear /etc/runit/runsvdir/default/
chroot /mnt ln -srvf /etc/sv/thermald /etc/runit/runsvdir/default/
chroot /mnt ln -srvf /etc/sv/NetworkManager /etc/runit/runsvdir/default/
chroot /mnt ln -srvf /etc/sv/dbus /etc/runit/runsvdir/default/
chroot /mnt ln -srvf /etc/sv/polkitd /etc/runit/runsvdir/default/
chroot /mnt ln -srvf /etc/sv/bluetoothd /etc/runit/runsvdir/default/
# chroot /mnt ln -sfv /etc/sv/bumblebeed /var/service/
chroot /mnt ln -srvf /etc/sv/thermald /var/service
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

# Virt-manager
chroot /mnt ln -svrf /etc/sv/libvirtd /var/service
chroot /mnt ln -svrf /etc/sv/virtlockd /var/service
chroot /mnt ln -svrf /etc/sv/virtlogd /var/service

# Tune chrony
sed -i -E 's/^(pool[ \t]+.*)$/\1\nserver time.google.com iburst prefer\nserver time.windows.com iburst prefer/g' /mnt/etc/chrony.conf


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
cat <<\EOF >/mnt/etc/udev/rules.d/99-udisks2.rules
# UDISKS_FILESYSTEM_SHARED
# ==1: mount filesystem to a shared directory (/media/VolumeName)
# ==0: mount filesystem to a private directory (/run/media/$USER/VolumeName)
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

touch /mnt/etc/rc.local
cat <<EOF >/mnt/etc/rc.local
#PowerTop
powertop --auto-tune

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


git clone --depth=1 https://github.com/madand/runit-services Services
mv Services /mnt/home/junior/

# Gerar initcpio
chroot /mnt dracut --force --hostonly --kver 5.15.85_1

printf "\e[1;32mInstallation finished! Umount -a and reboot.\e[0m"
