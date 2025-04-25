#!/bin/bash

#Formate e crie Pelo menos 3 partições para o: sistema, boot e home . Swap pode ser feito depois, com zram ou zramen
# Baixe o tarball e entre na pasta do arquivo como ex: cd Downloads
#curl or wget -c https://alpha.de.repo.voidlinux.org/live/current/void-x86_64-ROOTFS-20210930.tar.xz

# Instalando pela wifi

# cp /etc/wpa_supplicant/wpa_supplicant.conf /etc/wpa_supplicant/wpa_supplicant-<wlan-interface>.conf
# wpa_passphrase <ssid> <passphrase> >> /etc/wpa_supplicant/wpa_supplicant-<wlan-interface>.conf
# sv restart dhcpcd
# ip link set up <interface>


### Variables ###
DRIVE="/dev/vda"
USER="juca"
HOSTNAME="qemu"
BOOT_PARTITION="$DRIVE"1
ROOT_PARTITION="$DRIVE"2
SWAP_PARTITION="$DRIVE"3
BTRFS_OPTS="noatime,nodatacow,compress-force=zstd:9,acl,space_cache=v2,commit=60,discard=async"

xbps-install -Su wget xbps xz gptfdisk parted --yes

wget -c https://repo-default.voidlinux.org/live/current/void-x86_64-ROOTFS-20250202.tar.xz


# Print partition table
sgdisk -p $DRIVE
sgdisk -Z $DRIVE

parted --script --fix --align optimal $DRIVE mklabel gpt
parted --script --fix --align optimal $DRIVE mkpart primary fat32 1MiB 512MiB
parted --script $DRIVE -- set 1 boot on
parted --script --align optimal --fix -- $DRIVE mkpart primary 512MiB -4GiB
parted --script --align optimal --fix -- $DRIVE mkpart primary -4GiB 100%

# Change the name of partition
sgdisk -c 1:"Boot EFI Partition" $DRIVE
sgdisk -c 2:"Voidlinux FileSystem" $DRIVE
sgdisk -c 3:"Swap FileSystem" $DRIVE
sgdisk -p $DRIVE

# Change Types
# sgdisk --list-types
sgdisk -t 1:ef00 $DRIVE
sgdisk -t 2:8200 $DRIVE
sgdisk -t 3:8300 $DRIVE

# Zap entire device
# sgdisk -Z /dev/vda

mkfs.vfat -F32 $BOOT_PARTITION -n "BOOT"
mkfs.btrfs $ROOT_PARTITION -f -L "VOID"
mkswap $SWAP_PARTITION -L "SWAP"

set -e
XBPS_ARCH="x86_64"
# Mude de acordo com sua partição
mount -o $BTRFS_OPTS $ROOT_PARTITION /mnt

#Cria os subvolumes

btrfs su cr /mnt/@root
btrfs su cr /mnt/@home
btrfs su cr /mnt/@snapshots
btrfs su cr /mnt/@var_log
btrfs su cr /mnt/@var_cache_xbps

# Remove a partição
umount -v /mnt

# Monta com os valores selecionados
# Lembre-se de mudar os valores de sdX

mount -o $BTRFS_OPTS,subvol=@root $ROOT_PARTITION /mnt

mkdir -pv /mnt/{boot,home,.snapshots,var}
mkdir -pv /mnt/var/{log,cache}
mkdir -pv /mnt/var/cache/xbps
# mkdir -pv /mnt/home
# mkdir -pv /mnt/.snapshots
# mkdir -pv /mnt/var/log
# mkdir -pv /mnt/var/cache/xbps

mount -o $BTRFS_OPTS,subvol=@home $ROOT_PARTITION /mnt/home
mount -o $BTRFS_OPTS,subvol=@snapshots $ROOT_PARTITION /mnt/.snapshots
mount -o $BTRFS_OPTS,subvol=@var_log $ROOT_PARTITION /mnt/var/log
mount -o $BTRFS_OPTS,subvol=@var_cache_xbps $ROOT_PARTITION /mnt/var/cache/xbps
mount -t vfat -o defaults,noatime,nodiratime $BOOT_PARTITION /mnt/boot

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
add_drivers+=" btrfs "
omit_dracutmodules+=" lvm luks "
compress="zstd"
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
$HOSTNAME
EOF

# Hosts

cat << EOF > /mnt/etc/hosts
127.0.0.1 localhost
::1 localhost
127.0.1.1 $HOSTNAME.localdomain $HOSTNAME
EOF

# fstab

UEFI_UUID=$(blkid -s UUID -o value $BOOT_PARTITION)
ROOT_UUID=$(blkid -s UUID -o value $ROOT_PARTITION)
SWAP_UUID=$(blkid -s UUID -o value $SWAP_PARTITION)
echo $UEFI_UUID
echo $ROOT_UUID
echo $SWAP_UUID

cat << EOF > /mnt/etc/fstab
#
# See fstab(5).
#
# <file system> <dir> <type> <options> <dump> <pass>

# ROOTFS
UUID=$ROOT_UUID /               btrfs $BTRFS_OPTS,subvol=@root                       0 1
UUID=$ROOT_UUID /.snapshots     btrfs $BTRFS_OPTS,subvol=@snapshots                  0 2
UUID=$ROOT_UUID /var/log        btrfs $BTRFS_OPTS,subvol=@var_log                    0 2
UUID=$ROOT_UUID /var/cache/xbps btrfs $BTRFS_OPTS,subvol=@var_cache_xbps             0 2

#HOME_FS
UUID=$ROOT_UUID /home           btrfs $BTRFS_OPTS,subvol=@home                       0 2

# EFI
UUID=$UEFI_UUID /boot           vfat noatime,nodiratime,defaults                        0 2

### Swap ###
UUID=$SWAP_UUID                 none swap defaults,noatime                              0 0

tmpfs /tmp                      tmpfs defaults,nosuid,nodev,noatime                     0 0
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

cat << EOF > /mnt/etc/rc.conf
# /etc/rc.conf - system configuration for void

# Set the host name.
#
# NOTE: it's preferred to declare the hostname in /etc/hostname instead:
#       - echo myhost > /etc/hostname
#
#HOSTNAME="$HOSTNAME"

# Set RTC to UTC or localtime.
HARDWARECLOCK="UTC"

# Set timezone, availables timezones at /usr/share/zoneinfo.
#TIMEZONE="Europe/Bucharest"

# Keymap to load, see loadkeys(8).
KEYMAP="br-abnt2"

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
chroot /mnt $XBPS_ARCH xbps-install -y void-repo-multilib void-repo-multilib-nonfree void-repo-nonfree base-system zstd bash-completion linux-lts linux-lts-headers efivar nano base-devel gummiboot xtools lm_sensors alsa-utils vim git wget curl efibootmgr btrfs-progs ntfs-3g mtools dosfstools sysfsutils htop dbus-elogind dbus-elogind-libs dbus-elogind-x11 vsv vpm polkit chrony duf bluez bluez-alsa sof-firmware xdg-user-dirs xdg-utils xdg-desktop-portal-gtk --yes
chroot /mnt xbps-remove base-container-full -R --yes
#chroot /mnt xbps-install -y base-minimal zstd linux5.10 linux-base neovim chrony tlp intel-ucode zsh curl opendoas tlp xorg-minimal libx11 xinit xorg-video-drivers xf86-input-evdev xf86-video-intel xf86-input-libinput libinput-gestures dbus dbus-x11 xorg-input-drivers xsetroot xprop xbacklight xrdb
#chroot /mnt xbps-remove -oORvy sudo

# Install Xorg base & others
chroot /mnt xbps-install -Sy xorg-minimal xorg-server-xdmx xrdb xsetroot xbacklight xprop  xrefresh  xorg-fonts xdpyinfo xclipboard xcursorgen mkfontdir mkfontscale xcmsdb  libXinerama-devel xf86-input-libinput libinput-gestures setxkbmap fuse-exfat fatresize xauth xrandr arandr font-misc-misc terminus-font dejavu-fonts-ttf alsa-plugins-pulseaudio netcat lsscsi dialog --yes

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
#chroot /mnt xbps-install -S xf86-video-nouveau mesa-nouveau-dri --yes

# Intel Video Drivers
#chroot /mnt xbps-install -S xf86-video-intel --yes

chroot /mnt xbps-install -S xf86-video-vesa --yes

#chroot /mnt xbps-install -Sy libva-utils libva-vdpau-driver vdpauinfo

# "Mons is a Shell script to quickly manage 2-monitors display using xrandr."

#File Management
chroot /mnt xbps-install -S gvfs gvfs-smb udisks2 tumbler ffmpegthumbnailer libgsf libopenraw --yes

# PACKAGES FOR SYSTEM LOGGING
chroot /mnt xbps-install -S socklog-void --yes


#Install Gummiboot
mount --bind /sys/firmware/efi/efivars /mnt/sys/firmware/efi/efivars
# chroot /mnt mount -t efivarfs efivarfs /sys/firmware/efi/efivars
# chroot /mnt gummiboot --path=/boot install
chroot /mnt bootctl --path=/boot install

# chroot /mnt bash -c 'echo "options root=/dev/vda2 rootflags=subvol=@ rw quiet splash video=1920x1080 loglevel=3 mitigations=off nowatchdog msr.allow_writes=on pcie_aspm=force module.sig_unenforce intel_idle.max_cstate=1 cryptomgr.notests initcall_debug intel_iommu=igfx_off net.ifnames=0 no_timer_check noreplace-smp page_alloc.shuffle=1 rcupdate.rcu_expedited=1 tsc=reliable" >> /boot/loader/entries/void-6.1.**'

chroot /mnt bash -c 'echo "options root=/dev/vda2 rootflags=subvol=@root rw quiet splash video=1920x1080 loglevel=3 mitigations=off nowatchdog msr.allow_writes=on pcie_aspm=force module.sig_unenforce intel_idle.max_cstate=1 cryptomgr.notests initcall_debug intel_iommu=igfx_off net.ifnames=0 no_timer_check noreplace-smp page_alloc.shuffle=1 rcupdate.rcu_expedited=1 tsc=reliable" >> /boot/loader/void-options.conf'

# resume=UUID=$SWAP_UUID

# GRUB Configuration

# cat << EOF > /mnt/etc/default/grub
#
# Configuration file for GRUB.
#
# GRUB_DEFAULT=0
# GRUB_HIDDEN_TIMEOUT=0
# GRUB_HIDDEN_TIMEOUT_QUIET=false
# GRUB_TIMEOUT=7
# GRUB_DISTRIBUTOR="VOID"
# GRUB_CMDLINE_LINUX_DEFAULT="loglevel=4 mitigations=off intel_iommu=igfx_off i915.modeset=1"
# GRUB_CMDLINE_LINUX_DEFAULT="loglevel=4 mitigations=off nowatchdog nvidia-drm.modeset=1 intel_iommu=igfx_off"
# Uncomment to use basic console
# GRUB_TERMINAL_INPUT="console"
# Uncomment to disable graphical terminal
# GRUB_TERMINAL_OUTPUT=console
# GRUB_BACKGROUND=/home/bastilla.jpg
# GRUB_GFXMODE=1920x1080x32,1366x768x32,auto
# GRUB_DISABLE_LINUX_UUID=true
# GRUB_DISABLE_RECOVERY=true
# Uncomment and set to the desired menu colors.  Used by normal and wallpaper
# modes only.  Entries specified as foreground/background.
# GRUB_COLOR_NORMAL="red/black"
# GRUB_COLOR_HIGHLIGHT="yellow/black"
# GRUB_DISABLE_OS_PROBER=false
# EOF

# Set zsh as default
# chroot /mnt chsh -s /usr/bin/zsh root

# Define user and root password
chroot /mnt sh -c 'echo "root:200291" | chpasswd -c SHA512'
chroot /mnt useradd $USER -m -c "Reinaldo P JR" -s /bin/bash
chroot /mnt sh -c 'echo "$USER:200291" | chpasswd -c SHA512'
chroot /mnt usermod -aG wheel,floppy,audio,video,optical,kvm,lp,storage,cdrom,xbuilder,input $USER
chroot /mnt sed -i 's/^#\s*\(%wheel\s*ALL=(ALL)\)/\1/' /etc/sudoers
chroot /mnt sed -i 's/^#\s*\(%wheel\s*ALL=(ALL)\s*NOPASSWD:\s*ALL\)/\1/' /etc/sudoers
chroot /mnt usermod -a -G socklog $USER

cat > /mnt/etc/sudoers.d/sysctl <<HEREDOC
"$USER" ALL = NOPASSWD: /bin/systemctl
HEREDOC

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

# Touchpad
mkdir -pv /mnt/etc/X11/xorg.conf.d/
cat << EOF > /mnt/etc/X11/xorg.conf.d/30-touchpad.conf
section "InputClass"
        Identifier "SynPS/2 Synaptics TouchPad"
        MatchIsTouchpad "on"
        Driver "libinput"
        Option "Tapping" "on"
EndSection
EOF

cat << EOF > /mnt/etc/X11/xorg.conf.d/00-keyboard.conf
Section "InputClass"
        Identifier "system-keyboard"
        MatchIsKeyboard "on"
        # Option "XkbLayout" "us"
        Option "XkbLayout" "br"
        Option "XkbModel" "pc105"
        # Option "XkbVariant" "mac"
EndSection
EOF

#Runit por default
chroot /mnt ln -sv /etc/sv/dhcpcd /etc/runit/runsvdir/default/
# chroot /mnt ln -sv /etc/sv/wpa_supplicant /etc/runit/runsvdir/default/
chroot /mnt ln -sv /etc/sv/chronyd /etc/runit/runsvdir/default/
# chroot /mnt ln -sv /etc/sv/scron /etc/runit/runsvdir/default/
# chroot /mnt ln -sv /etc/sv/tlp /etc/runit/runsvdir/default/
chroot /mnt ln -sv /etc/sv/sshd /etc/runit/runsvdir/default/
chroot /mnt ln -sv /etc/sv/NetworkManager /etc/runit/runsvdir/default/
chroot /mnt ln -srvf /etc/sv/dbus /etc/runit/runsvdir/default/
chroot /mnt ln -srvf /etc/sv/polkitd /etc/runit/runsvdir/default/
chroot /mnt ln -srvf /etc/sv/elogind /etc/runit/runsvdir/default/
chroot /mnt ln -srvf /etc/sv/bluetoothd /etc/runit/runsvdir/default/

# Enable socklog, a syslog implementation from the author of runit.
chroot /mnt ln -sv /etc/sv/socklog-unix /etc/runit/runsvdir/default/
chroot /mnt ln -sv /etc/sv/nanoklogd /etc/runit/runsvdir/default/

# Enable the iNet Wireless Daemon for Wi-Fi support
chroot /mnt ln -sv /etc/sv/iwd /etc/runit/runsvdir/default/

# Config zsh

# alias dissh="export DISPLAY=:0.0"
# alias bquit="bspc quit"


#chroot /mnt sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
# spaceship theme
# git clone https://github.com/denysdovhan/spaceship-prompt.git "$ZSH_CUSTOM/themes/spaceship-prompt"
# ln -s "$ZSH_CUSTOM/themes/spaceship-prompt/spaceship.zsh-theme" "$ZSH_CUSTOM/themes/spaceship.zsh-theme"
# ZSH_THEME="spaceship"

# cat <<\EOF >> /home/juca/.zshrc
# SPACESHIP_PROMPT_ORDER=(
#   user          # Username section
#   dir           # Current directory section
#   host          # Hostname section
#   git           # Git section (git_branch + git_status)
#   hg            # Mercurial section (hg_branch  + hg_status)
#   exec_time     # Execution time
#   line_sep      # Line break
#   vi_mode       # Vi-mode indicator
#   jobs          # Background jobs indicator
#   exit_code     # Exit code section
#   char          # Prompt character
# )
# SPACESHIP_USER_SHOW=always
# SPACESHIP_PROMPT_ADD_NEWLINE=false
# SPACESHIP_CHAR_SYMBOL="❯"
# SPACESHIP_CHAR_SUFFIX=" "
# EOF

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
