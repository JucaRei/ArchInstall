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

mkfs.vfat -F32 /dev/sda1
mkfs.btrfs /dev/sda2 -f
mkfs.btrfs /dev/sda3 -f

set -e
XBPS_ARCH="x86_64"
BTRFS_OPTS="noatime,ssd,compress-force=zstd:18,space_cache=v2,commit=120,autodefrag,discard=async"
# Mude de acordo com sua partição
mount -o $BTRFS_OPTS /dev/sda2 /mnt

#Cria os subvolumes

btrfs su cr /mnt/@
# btrfs su cr /mnt/@home
btrfs su cr /mnt/@snapshots
btrfs su cr /mnt/@var_log
btrfs su cr /mnt/@var_cache_xbps

# Remove a partição
umount -v /mnt

# mount home subvolume
mount -o $BTRFS_OPTS /dev/sda3 /mnt
btrfs su cr /mnt/@home
umount -v /mnt

# Monta com os valores selecionados
# Lembre-se de mudar os valores de sdX

mount -o $BTRFS_OPTS,subvol=@ /dev/sda2 /mnt
mkdir -pv /mnt/boot
mkdir -pv /mnt/boot/grub
mkdir -pv /mnt/home
mkdir -pv /mnt/.snapshots
mkdir -pv /mnt/var/log
mkdir -pv /mnt/var/cache/xbps
mount -o $BTRFS_OPTS,subvol=@home /dev/sda3 /mnt/home
mount -o $BTRFS_OPTS,subvol=@snapshots /dev/sda2 /mnt/.snapshots
mount -o $BTRFS_OPTS,subvol=@var_log /dev/sda2 /mnt/var/log
mount -o $BTRFS_OPTS,subvol=@var_cache_xbps /dev/sda2 /mnt/var/cache/xbps
mount -t vfat -o defaults,noatime,nodiratime /dev/sda1 /mnt/boot

# Descompacta e copia para /mnt o tarball
tar xvf ./void-x86_64-*.tar.xz -C /mnt;sync;

for dir in dev proc sys run; do mount --rbind /$dir /mnt/$dir; mount --make-rslave /mnt/$dir; done

# copia o arquivo de resolv para o /mnt
cp -v /etc/resolv.conf /mnt/etc/

# Atualiza o initramfs com dracut
# Remover se for testar em VM
mkdir -pv /mnt/etc/dracut.conf.d
cat << EOF > /mnt/etc/dracut.conf.d/00-dracut.conf
hostonly="yes"
add_drivers+=" nouveau i915 btrfs crc32c-intel "
omit_dracutmodules+=" lvm luks "
compress="zstd"
EOF

cat << EOF > /mnt/etc/dracut.conf.d/10-touchpad.conf
add_drivers+=" bcm5974 "
EOF

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
ignorepkg=linux
ignorepkg=linux-headers
EOF


# Hostname
cat << EOF > /mnt/etc/hostname
oldmac
EOF

# Hosts

cat << EOF > /mnt/etc/hosts
127.0.0.1 localhost
::1 localhost
127.0.1.1 oldmac.localdomain oldmac
EOF

# fstab

UEFI_UUID=$(blkid -s UUID -o value /dev/sda1)
ROOT_UUID=$(blkid -s UUID -o value /dev/sda2)
HOME_UUID=$(blkid -s UUID -o value /dev/sda3)
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
UUID=$UEFI_UUID /boot vfat rw,noatime,nodiratime,fmask=0022,dmask=0022,codepage=437,iocharset=iso8859-1,shortname=mixed,utf8,errors=remount-ro 0 2

tmpfs /tmp tmpfs defaults,nosuid,nodev,noatime 0 0
EOF

# Set user permition
cat << EOF > /mnt/etc/doas.conf
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

cat << EOF > /mnt/etc/rc.conf
# /etc/rc.conf - system configuration for void

# Set the host name.
#
# NOTE: it's preferred to declare the hostname in /etc/hostname instead:
#       - echo myhost > /etc/hostname
#
#HOSTNAME="oldmac"

# Set RTC to UTC or localtime.
HARDWARECLOCK="localtime"

# Set timezone, availables timezones at /usr/share/zoneinfo.
#TIMEZONE="Europe/Bucharest"

# Keymap to load, see loadkeys(8).
KEYMAP="us-acentos"

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
chroot /mnt $XBPS_ARCH xbps-install -y base-system linux-firmware linux-firmware-intel linux-firmware-network linux-firmware-nvidia linux-firmware-broadcom light kbdlight arp-scan xev opendoas base-devel zstd bash-completion minised nocache parallel util-linux bcache-tools necho ncdu starship linux-lts linux-lts-headers efivar dropbear neovim base-devel gummiboot ripgrep dust exa zoxide fzf xtools lm_sensors inxi lshw intel-ucode zsh alsa-utils vim git wget curl efibootmgr btrfs-progs  nano ntfs-3g mtools dosfstools sysfsutils htop dbus-elogind dbus-elogind-libs dbus-elogind-x11 vsv vpm polkit chrony neofetch dust duf lua bat glow bluez bluez-alsa sof-firmware xdg-user-dirs xdg-utils --yes
chroot /mnt xbps-remove base-voidstrap --yes
#chroot /mnt xbps-install -y base-minimal zstd linux5.10 linux-base neovim chrony tlp intel-ucode zsh curl opendoas tlp xorg-minimal libx11 xinit xorg-video-drivers xf86-input-evdev xf86-video-intel xf86-input-libinput libinput-gestures dbus dbus-x11 xorg-input-drivers xsetroot xprop xbacklight xrdb
#chroot /mnt xbps-remove -oORvy sudo

# Install Xorg base & others
chroot /mnt xbps-install -Sy xorg-minimal xorg-server-xdmx xrdb xsetroot xprop xrefresh  xorg-fonts xdpyinfo xclipboard xcursorgen mkfontdir mkfontscale xcmsdb  libXinerama-devel xf86-input-libinput libinput-gestures setxkbmap fuse-exfat fatresize xauth xrandr arandr font-misc-misc terminus-font dejavu-fonts-ttf alsa-plugins-pulseaudio netcat lsscsi dialog --yes

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
# chroot /mnt xbps-install -S xf86-video-intel --yes

# Intel Video Drivers
chroot /mnt xbps-install -S xf86-video-nouveau mesa-dri --yes

#chroot /mnt xbps-install -Sy libva-utils libva-vdpau-driver vdpauinfo

# "Mons is a Shell script to quickly manage 2-monitors display using xrandr."
chroot /mnt xbps-install -S mons --yes

#File Management
chroot /mnt xbps-install -S gvfs gvfs-smb gvfs-mtp gvfs-afc avahi avahi-discover udisks2 tumbler ffmpegthumbnailer libgsf libopenraw --yes

# PACKAGES FOR SYSTEM LOGGING
chroot /mnt xbps-install -S socklog-void --yes

# NFS
chroot /mnt xbps-install -S nfs-utils sv-netmount --yes



# Set zsh as default
chroot /mnt chsh -s /usr/bin/zsh root

# Define user and root password
chroot /mnt sh -c 'echo "root:200291" | chpasswd -c SHA512'
chroot /mnt useradd juca -m -c "Reinaldo P JR" -s /bin/bash
chroot /mnt sh -c 'echo "juca:200291" | chpasswd -c SHA512'
chroot /mnt usermod -aG wheel,floppy,audio,video,optical,kvm,lp,storage,cdrom,xbuilder,input juca
chroot /mnt sed -i 's/^#\s*\(%wheel\s*ALL=(ALL)\)/\1/' /etc/sudoers
chroot /mnt sed -i 's/^#\s*\(%wheel\s*ALL=(ALL)\s*NOPASSWD:\s*ALL\)/\1/' /etc/sudoers
chroot /mnt usermod -a -G socklog juca

# Gerar initcpio
chroot /mnt xbps-reconfigure -fa

# Touchpad
mkdir -pv /mnt/etc/X11/xorg.conf.d/
cat << EOF > /mnt/etc/X11/xorg.conf.d/30-touchpad.conf
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

cat << EOF > /mnt/etc/X11/xorg.conf.d/20-nouveau.conf
Section "Device"
    Identifier "Nvidia card"
    Driver "nouveau"
EndSection
EOF

cat << EOF > /mnt/etc/X11/xorg.conf.d/00-keyboard.conf
Section "InputClass"
        Identifier              "system-keyboard"
        MatchIsKeyboard         "on"
        Option "XkbLayout"      "us"
        # Option "XkbModel"     "pc105"
        Option "XkbVariant"     "mac"
        Option "Backspace"      "guess"
EndSection
EOF

cat << EOF > /mnt/etc/X11/xorg.conf.d/99-killx.conf
Section "ServerFlags"
        Option  "DontZap"       "false"
EndSection

Section "InputClass"
        Identifier      "Keyboard Defaults"
        MatchIsKeyboard "yes"
        Option          "XkbOptions"    "terminate:crtl_alt_bksp"
EndSection
EOF


#Runit por default
chroot /mnt ln -sv /etc/sv/dhcpcd /etc/runit/runsvdir/default/
chroot /mnt ln -sv /etc/sv/acpid /etc/runit/runsvdir/default/
# chroot /mnt ln -sv /etc/sv/wpa_supplicant /etc/runit/runsvdir/default/
chroot /mnt ln -sv /etc/sv/chronyd /etc/runit/runsvdir/default/
# chroot /mnt ln -sv /etc/sv/scron /etc/runit/runsvdir/default/
# chroot /mnt ln -sv /etc/sv/tlp /etc/runit/runsvdir/default/
chroot /mnt ln -sv /etc/sv/dropbear /etc/runit/runsvdir/default/
chroot /mnt ln -sv /etc/sv/NetworkManager /etc/runit/runsvdir/default/
chroot /mnt ln -srvf /etc/sv/dbus /etc/runit/runsvdir/default/
chroot /mnt ln -srvf /etc/sv/polkitd /etc/runit/runsvdir/default/
# chroot /mnt ln -srvf /etc/sv/elogind /etc/runit/runsvdir/default/
chroot /mnt ln -srvf /etc/sv/bluetoothd /etc/runit/runsvdir/default/
chroot /mnt ln -srvf /etc/sv/avahi-daemon /etc/runit/runsvdir/default/

# NFS
chroot /mnt ln -srvf /etc/sv/rpcbind /etc/runit/runsvdir/default/
chroot /mnt ln -srvf /etc/sv/statd /etc/runit/runsvdir/default/
chroot /mnt ln -srvf /etc/sv/netmount /etc/runit/runsvdir/default/


# Enable socklog, a syslog implementation from the author of runit.
chroot /mnt ln -sv /etc/sv/socklog-unix /etc/runit/runsvdir/default/
chroot /mnt ln -sv /etc/sv/nanoklogd /etc/runit/runsvdir/default/

# Enable the iNet Wireless Daemon for Wi-Fi support
chroot /mnt ln -sv /etc/sv/iwd /etc/runit/runsvdir/default/

# Config zsh

# alias dissh="export DISPLAY=:0.0"
# alias bquit="bspc quit"



# MakeSwap
chroot /mnt touch /swapfile
chroot /mnt chmod 600 /swapfile
chroot /mnt chattr +C /swapfile
chroot /mnt lsattr /swapfile
chroot /mnt dd if=/dev/zero of=/swapfile bs=1M count=8192 status=progress
chroot /mnt mkswap /swapfile
chroot /mnt swapon /swapfile

# Add to fstab
echo " " >> /mnt/etc/fstab
echo "# Swap" >> /mnt/etc/fstab
echo "/swapfile      none     swap      defaults  0 0" >> /mnt/etc/fstab

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


#Install Gummiboot
mount --bind /sys/firmware/efi/efivars /mnt/sys/firmware/efi/efivars
chroot /mnt mount -t efivarfs efivarfs /sys/firmware/efi/efivars
chroot /mnt gummiboot install

chroot /mnt bash -c 'echo "options root=/dev/sda2 rootflags=subvol=@ rw quiet loglevel=0 console=tty2 acpi_osi=Darwin acpi_mask_gpe=0x06 udev.log_level=0 vt.global_cursor_default=0 zswap.enabled=1 zswap.compressor=zstd zswap.max_pool_percent=10 zswap.zpool=zsmalloc mitigations=off nowatchdog msr.allow_writes=on pcie_aspm=force module.sig_unenforce intel_idle.max_cstate=1 cryptomgr.notests initcall_debug intel_iommu=igfx_off net.ifnames=0 no_timer_check noreplace-smp page_alloc.shuffle=1 rcupdate.rcu_expedited=1 tsc=reliable" >> /boot/loader/entries/void-5.10.**'
# chroot /mnt bash -c 'echo "options root=/dev/sda2 rootflags=subvol=@ rw quiet splash loglevel=3 acpi_osi=Darwin acpi_mask_gpe=0x06 mitigations=off nowatchdog msr.allow_writes=on pcie_aspm=force module.sig_unenforce intel_idle.max_cstate=1 cryptomgr.notests initcall_debug intel_iommu=igfx_off net.ifnames=0 no_timer_check noreplace-smp page_alloc.shuffle=1 rcupdate.rcu_expedited=1 tsc=reliable" >> /boot/loader/entries/void-5.10.**'


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
