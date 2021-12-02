#!/bin/bash

#Formate e crie Pelo menos 3 partições para o: sistema, boot e home . Swap pode ser feito depois, com zram ou zramen
# Baixe o tarball e entre na pasta do arquivo como ex: cd Downloads
# wget or curl https://alpha.de.repo.voidlinux.org/live/current/void-x86_64-ROOTFS-20210930.tar.xz

xbps-install -Su xbps xz

set -e

BTRFS_OPTS="noatime,ssd,compress-force=zstd:18,space_cache=v2,commit=120,discard=async"
# Mude de acordo com sua partição
mount -o $BTRFS_OPTS /dev/sdX /mnt

#Cria os subvolumes

btrfs su cr /mnt/@
# btrfs su cr /mnt/@home
btrfs su cr /mnt/@snapshots
btrfs su cr /mnt/@var_log
btrfs su cr /mnt/@var_cache_xbps

# Remove a partição
umount -v /mnt

# Monta com os valores selecionados
# Lembre-se de mudar os valores de sdX

mount -o $BTRFS_OPTS,subvol=@ /dev/sdX /mnt
mkdir -pv /mnt/boot/efi
mkdir -pv /mnt/boot/grub
mkdir -pv /mnt/home
mkdir -pv /mnt/.snapshots
mkdir -pv /mnt/var/log
mkdir -pv /mnt/var/cache/xbps
mount -o $BTRFS_OPTS,subvol=@home /dev/sdX /mnt/home
mount -o $BTRFS_OPTS,subvol=@snapshots /dev/sdX /mnt/.snapshots
mount -o $BTRFS_OPTS,subvol=@var_log /dev/sdX /mnt/var/log
mount -o $BTRFS_OPTS,subvol=@var_cache_xbps /dev/sdX /mnt/var/cache/xbps
mount -t vfat -o defaults,noatime,nodiratime /dev/sdX /mnt/boot/efi

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
add_drivers+=" i915 btrfs nvidia"
omit_dracutmodules+=" lvm luks"
compress="zstd"
EOF

# Arrumar placa intel
mkdir -pv /mnt/etc/X11/xorg.conf.d
cat << EOF > /mnt/etc/X11/xorg.conf.d/20-intel.conf
Section "Device"
	Identifier "Intel Graphics"
	Driver "modesetting"
EndSection
EOF

#Alternatively, you can use the nvidia-xconfig utility to insert these changes into xorg.conf with a single command:
# nvidia-xconfig --busid=PCI:3:0:0 --sli=AA

# Arrumar placa nvidia
mkdir -pv /mnt/etc/X11/xorg.conf.d
cat << EOF > /mnt/etc/X11/xorg.conf.d/20-nvidia.conf
Section "Device"
        Identifier "Nvidia Card"
        Driver "nvidia"
        VendorName "NVIDIA Corporation"
        BoardName "GeForce GTX 1050"
EndSection
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

UEFI_UUID=$(blkid -s UUID -o value /dev/sdX)
ROOT_UUID=$(blkid -s UUID -o value /dev/sdX2)
echo $UEFI_UUID
echo $ROOT_UUID
cat << EOF > /mnt/etc/fstab
#
# See fstab(5).
#
# <file system> <dir> <type> <options> <dump> <pass>

# ROOTFS
UUID=$ROOT_UUID /               btrfs rw,noatime,ssd,compress-force=zstd:18,space_cache=v2,commit=120,discard=async,subvol=@               0 1
UUID=$ROOT_UUID /home           btrfs rw,noatime,ssd,compress-force=zstd:18,space_cache=v2,commit=120,discard=async           0 2
UUID=$ROOT_UUID /.snapshots     btrfs rw,noatime,ssd,compress-force=zstd:18,space_cache=v2,commit=120,discard=async,subvol=@snapshots      0 2
UUID=$ROOT_UUID /var/log        btrfs rw,noatime,ssd,compress-force=zstd:18,space_cache=v2,commit=120,discard=async,subvol=@var_log        0 2
UUID=$ROOT_UUID /var/cache/xbps btrfs rw,noatime,ssd,compress-force=zstd:18,space_cache=v2,commit=120,discard=async,subvol=@var_cache_xbps 0 2

# EFI
UUID=$UEFI_UUID /boot/efi vfat rw,noatime,nodiratime,fmask=0022,dmask=0022,codepage=437,iocharset=iso8859-1,shortname=mixed,utf8,errors=remount-ro 0 2

tmpfs /tmp tmpfs defaults,nosuid,nodev,noatime 0 0
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

cat << EOF > /mnt/etc/rc.conf
# /etc/rc.conf - system configuration for void

# Set the host name.
#
# NOTE: it's preferred to declare the hostname in /etc/hostname instead:
#       - echo myhost > /etc/hostname
#
#HOSTNAME="GL552V"

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

chroot /mnt export PS1="(chroot) ${PS1}"
chroot /mnt ln -sfv /usr/share/zoneinfo/America/SãoPaulo /etc/localtime

#Locales
chroot /mnt sed -i 's/^# *\(en_US.UTF-8\sUTF-8\)/\1/' /etc/default/libc-locales
chroot /mnt sed -i 's/^# *\(pt_BR.UTF-8\sUTF-8\)/\1/' /etc/default/libc-locales
chroot /mnt xbps-reconfigure -f glibc-locales

# Update and install base system
chroot /mnt xbps-install -Suy xbps
chroot /mnt xbps-install -uy
chroot /mnt xbps-install -y base-minimal zstd linux-lts linux-lts-headers neovim dbus grub-x86_64-efi tlp intel-ucode zsh alsa-utils vim git wget curl efibootmgr btrfs-progs nano ntfs-3g mtools dosfstools grub-x86_64-efi elogind vsv vpm polkit chrony neofetch duf lua bat glow bluez bluez-alsa xdg-user-dirs xdg-utils
#chroot /mnt xbps-install -y base-minimal zstd linux5.10 linux-base neovim chrony grub-x86_64-efi tlp intel-ucode zsh curl opendoas
#chroot /mnt xbps-remove -oORvy sudo
chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id="VOID"
chroot /mnt update-grub

# GRUB Configuration

cat << EOF > /mnt/etc/default/grub
#
# Configuration file for GRUB.
#
GRUB_DEFAULT=0
#GRUB_HIDDEN_TIMEOUT=0
#GRUB_HIDDEN_TIMEOUT_QUIET=false
GRUB_TIMEOUT=5
GRUB_DISTRIBUTOR="VOID"
GRUB_CMDLINE_LINUX_DEFAULT="loglevel=4 mitigations=off intel_iommu=igfx_off"
# Uncomment to use basic console
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
chroot /mnt echo root:200291 | chpasswd
chroot /mnt junior -m -c "Reinaldo P JR" -s /bin/bash
chroot /mnt echo junior:200291 | chpasswd
chroot /mnt usermod -aG wheel,audio,video,optical,kvm,lp,storage junior
chroot /mnt sed -i 's/^#\s*\(%wheel\s*ALL=(ALL)\)/\1/' /etc/sudoers
chroot /mnt sed -i 's/^#\s*\(%wheel\s*ALL=(ALL)\s*NOPASSWD:\s*ALL\)/\1/' /etc/sudoers

# Gerar initcpio
chroot /mnt xbps-reconfigure -fa

#Runit por default
chroot /mnt ln -sv /etc/sv/dhcpcd /etc/runit/runsvdir/default/
# chroot /mnt ln -sv /etc/sv/wpa_supplicant /etc/runit/runsvdir/default/
chroot /mnt ln -sv /etc/sv/chronyd /etc/runit/runsvdir/default/
# chroot /mnt ln -sv /etc/sv/scron /etc/runit/runsvdir/default/
chroot /mnt ln -sv /etc/sv/tlp /etc/runit/runsvdir/default/
chroot /mnt ln -sv /etc/sv/sshd /etc/runit/runsvdir/default/
chroot /mnt ln -sv /etc/sv/NetworkManager /etc/runit/runsvdir/default/
chroot /mnt ln -srvf /etc/sv/{dbus,polkitd,elogind} /etc/runit/runsvdir/default/

