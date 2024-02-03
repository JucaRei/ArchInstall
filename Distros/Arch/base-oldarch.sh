#!/bin/bash

# Arch Linux

pacman -Sy archlinux-keyring --noconfirm

# Enable pacman Color
sed -i '1n; /^#UseSyslog/i ILoveCandy' /etc/pacman.conf
sed -i '/Color/s/^#//' /etc/pacman.conf
sed -i '3n; /^#UseSyslog/i DisableDownloadTimeout' /etc/pacman.conf
sed -i 's/#ParallelDownloads = 5/ParallelDownloads = 4/g' /etc/pacman.conf

cat <<\ EOF >> /etc/pacman.conf

[liquorix]
Server = https://liquorix.net/archlinux/$repo/$arch

EOF

pacman -Syyy


#####################
###### OldMac #######
#####################

# if [ -d /sys/firmware/efi ]; then UEFI=true; else UEFI=false; fi
if [ -d /sys/firmware/efi ]; then UEFI=false; else UEFI=false; fi

pacman -Sy
pacman -S --noconfirm --needed --noprogressbar --quiet reflector
reflector -l 3 --sort rate --save /etc/pacman.d/mirrorlist

pacman -S --noconfirm --needed --noprogressbar --quiet awk

DRIVE="/dev/sda"

if [ $UEFI == false ]
then
  parted -s -a optimal ${DRIVE} -- mklabel msdos \
       mkpart primary ext4 1MiB 100MiB \
       set 1 boot on \
       mkpart primary linux-swap 100MiB 6GiB\
    #    mkpart primary ext4 8GiB 55% \
    #    mkpart primary ext4 55% 100% 
       mkpart primary btrfs 6GiB 100% \ 
       align-check ${DRIVE}
else
  parted -s ${DRIVE} -- mklabel gpt \
      mkpart primary ext4 0% 1GiB \
      set 1 boot on \
      mkpart primary linux-swap 1GiB 16GiB \
      mkpart primary ext4 16GiB 55% \
      mkpart primary ext4 55% 100%  
fi

mkfs.vfat -F32 ${DRIVE}1 -n "BOOT"
mkswap ${DRIVE}2 -L "SWAP"
mkfs.btrfs ${DRIVE}3 -f -L "Archlinux"


mount -t btrfs /dev/disk/by-label/Archlinux /mnt

btrfs su cr /mnt/@
btrfs su cr /mnt/@pacman
btrfs su cr /mnt/@snapshots
btrfs su cr /mnt/@var_log
# btrfs su cr /mnt/@swap
btrfs su cr /mnt/@tmp
btrfs su cr /mnt/@cache
btrfs su cr /mnt/@home

umount -v /mnt

set -e
BTRFS_OPTS="noatime,ssd,compress-force=zstd:8,space_cache=v2,commit=120,discard=async"

## Mount partitions (Oldmac)
mount -o $BTRFS_OPTS,subvol=@ /dev/disk/by-label/Archlinux /mnt
mkdir -pv /mnt/{home,.snapshots,boot/grub,var/log,var/tmp,var/cache,var/lib/pacman}

# Swap Optional
# mkdir -pv /mnt/var/swap

mount -o $BTRFS_OPTS,subvol=@home /dev/disk/by-label/Archlinux /mnt/home
mount -o $BTRFS_OPTS,subvol=@snapshots /dev/disk/by-label/Archlinux /mnt/.snapshots
mount -o $BTRFS_OPTS,subvol=@var_log /dev/disk/by-label/Archlinux /mnt/var/log
mount -o $BTRFS_OPTS,subvol=@cache /dev/disk/by-label/Archlinux /mnt/var/cache
mount -o $BTRFS_OPTS,subvol=@tmp /dev/disk/by-label/Archlinux /mnt/var/tmp
# mount -o $BTRFS_OPTS,subvol=@swap /dev/disk/by-label/Archlinux /mnt/var/swap
mount -o $BTRFS_OPTS,subvol=@pacman /dev/disk/by-label/Archlinux /mnt/var/lib/pacman
mount -t vfat -o defaults,noatime,nodiratime /dev/disk/by-label/BOOT /mnt/boot
swapon /dev/disk/by-label/SWAP

### Old Mac
# pacstrap /mnt base base-devel linux linux-headers linux-firmware intel-ucode btrfs-progs archlinux-keyring git neovim nano reflector dropbear duf exa fzf ripgrep pacman-contrib --ignore vi openssh
pacstrap /mnt base base-devel linux-lts linux-lts-headers linux-firmware zsh intel-ucode btrfs-progs archlinux-keyring git dropbear duf pacman-contrib --ignore vi openssh linux linux-headers

# Generate fstab
genfstab -U /mnt >>/mnt/etc/fstab


===========================================================================================================================================
===========================================================================================================================================
===========================================================================================================================================

# arch-chroot /mnt
ln -sf /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime
hwclock --systohc
sed -i '171s/.//' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" >>/etc/locale.conf
echo "KEYMAP=br-abnt2" >>/etc/vconsole.conf
# echo "KEYMAP=us-intl" >>/etc/vconsole.conf
# echo "KEYMAP=mac-us" >>/etc/vconsole.conf
echo "oldarch" >>/etc/hostname
echo "127.0.0.1 localhost" >>/etc/hosts
echo "::1       localhost" >>/etc/hosts
echo "127.0.1.1 oldarch.localdomain oldarch" >>/etc/hosts
echo root:200291 | chpasswd

# Some pacman confs
sed -i '1n; /^#UseSyslog/i ILoveCandy' /etc/pacman.conf
sed -i '3n; /^#UseSyslog/i DisableDownloadTimeout' /etc/pacman.conf
sed -i '/Color/s/^#//' /etc/pacman.conf
sed -i 's/#ParallelDownloads = 5/ParallelDownloads = 8/g' /etc/pacman.conf

# Enable multilib repo
sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf
sed -i "/\[lib32\]/,/Include/"'s/^#//' /etc/pacman.conf

# Setting package signing option to require signature
sed -i '/\[core\]/a SigLevel\ =\ PackageRequired' /etc/pacman.conf
sed -i '/\[multilib\]/a SigLevel\ =\ PackageRequired' /etc/pacman.conf
sed -i '/\[community\]/a SigLevel\ =\ PackageRequired' /etc/pacman.conf
sed -i '/\[extra\]/a SigLevel\ =\ PackageRequired' /etc/pacman.conf

pacman -Syyw

pacman-key --init

# Add Liquorix
pacman-key --keyserver hkps://keyserver.ubuntu.com --recv-keys 9AE4078033F8024D
pacman-key --lsign-key 9AE4078033F8024D

set -e 
USER="junior"

mkdir -pv /media/$USER

# Fix Tmpfs
cat <<EOF >>/etc/fstab

# tmpfs /tmp tmpfs defaults,nosuid,nodev,noatime 0 0
tmpfs /tmp tmpfs noatime,mode=1777 0 0
EOF

pacman -Sy grub grub-btrfs efibootmgr chrony preload irqbalance ananicy-cpp networkmanager iwd samba dialog avahi xdg-user-dirs xdg-utils gvfs gvfs-smb nfs-utils inetutils dnsutils bluez bluez-utils pulseaudio-bluetooth pulseaudio-alsa pulseaudio-equalizer pulseaudio-jack alsa-utils bash-completion exfat-utils firewalld nss-mdns os-prober ntfs-3g
# apci & tlp
pacman -S acpi acpi_call-lts tlp

# Create config file to make NetworkManager use iwd as the Wi-Fi backend instead of wpa_supplicant
mkdir -pv /etc/NetworkManager/conf.d/
touch /etc/NetworkManager/conf.d/wifi_backend.conf
cat <<EOF >>/etc/NetworkManager/conf.d/wifi_backend.conf
[device]
wifi.backend=iwd
wifi.iwd.autoconnect=yes
EOF

# Config iwd
mkdir -pv /etc/iwd
touch /etc/iwd/main.conf
cat << EOF > main.conf
[General]
EnableNetworkConfiguration=true

[Network]
NameResolvingService=systemd
RouterPriorityOffset=30
EOF

pacman -S grub os-prober --noconfirm
grub-install --target=i386-pc --recheck /dev/sda
sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet"/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=2 quiet apci_osi=Linux udev.log_level=0 acpi_backlight=vendor acpi=force init_on_alloc=0 zswap.enabled=1 zswap.compressor=zstd zswap.max_pool_percent=10 zswap.zpool=z3fold acpi_mask_gpe=0x06  mitigations=off nowatchdog msr.allow_writes=on pcie_aspm=force module.sig_unenforce intel_idle.max_cstate=1 cryptomgr.notests initcall_debug intel_iommu=on,igfx_off no_timer_check noreplace-smp page_alloc.shuffle=1 rcupdate.rcu_expedited=1 tsc=reliable"/g' /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg

set -e
USER=junior

useradd -m $USER
echo $USER:200291 | chpasswd
useradd -m -g users -G wheel -s /bin/zsh $USER
sed -i 's/# %wheel ALL=(ALL) NOPASSWD/%wheel ALL=(ALL) NOPASSWD/g' /etc/sudoers
# usermod -aG wheel $USER

echo "$USER ALL=(ALL) ALL" >>/etc/sudoers.d/$USER
echo "$USER ALL=(ALL) NOPASSWD: ALL" >>/etc/sudoers.d/$USER

chsh -s /bin/zsh root

systemctl enable NetworkManager
systemctl enable bluetooth
systemctl enable dropbear
systemctl enable irqbalance
systemctl enable preload
systemctl enable ananicy-cpp
systemctl enable smb
systemctl enable nmb
systemctl enable chronyd
#systemctl enable sshd
systemctl enable dropbear
systemctl enable avahi-daemon
systemctl enable tlp
systemctl enable reflector.timer
systemctl enable fstrim.timer
systemctl enable firewalld
systemctl enable acpid

cd /tmp
git clone https://aur.archlinux.org/package-query.git
chown -R $USER package-query
cd package-query
sudo -u $USER makepkg
pacman -U package-query-*.pkg.tar.xz --noconfirm

cd /tmp
git clone https://aur.archlinux.org/yay.git
chown -R $USER yay
cd yay
sudo -u $USER makepkg
pacman -U yay-*.pkg.tar.xz --noconfirm

cat <<- EOF > /mnt/user.sh
yay -S --noconfirm
    bullet-train-oh-my-zsh-theme-git \
    # discord \
    # discord-canary \
    consolas-font \
    # google-chrome \
    # mirage \
    # i3-gaps \
    # rofi \
    oh-my-zsh-git \
    lib32-nvidia-340xx-utils \
    nvidia-340xx-lts-dkms \
    nvidia-340xx-utils \
    # ttf-google-fonts-git \
    # ttf-symbola \
    # google-chrome \
    # visual-studio-code-bin \
    # polybar \
# git clone --bare https://github.com/buttars/.dotfiles $HOME/.dotfiles
# alias dotfiles="/usr/bin/git --git-dir=$HOME/.dotfiles/ --work-tree=$HOME"
# dotfiles config --local status.showUntrackedFiles no
# dotfiles checkout
EOF


# Power top
touch /etc/rc.local
cat <<EOF >/etc/rc.local
# PowerTop
powertop --auto-tune

# Preload
preload
EOF

#Samba
mkdir -p /etc/samba
cat <<EOF >/etc/samba/smb.conf
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

### systemctl
mkdir -pv /etc/sysctl.d
touch /etc/sysctl.d/00-sysctl.conf
cat << EOF >/etc/sysctl.d/00-sysctl.conf
vm.vfs_cache_pressure=500
vm.swappiness=100
vm.dirty_background_ratio=1
vm.dirty_ratio=50
dev.i915.perf_stream_paranoid=0
net.ipv4.ping_group_range=0 $MAX_GID
EOF


#Fix mount external HD
mkdir -pv /etc/udev/rules.d
cat << EOF >/etc/udev/rules.d/99-udisks2.rules
# UDISKS_FILESYSTEM_SHARED
# ==1: mount filesystem to a shared directory (/media/$USER/VolumeName)
# ==0: mount filesystem to a private directory (/run/media/$USER/VolumeName)
# See udisks(8)
ENV{ID_FS_USAGE}=="filesystem|other|crypto", ENV{UDISKS_FILESYSTEM_SHARED}="1"
EOF

# Not asking for password

mkdir -pv /etc/polkit-1/rules.d
cat <<EOF >/etc/polkit-1/rules.d/10-udisks2.rules
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

cat <<EOF >/etc/polkit-1/rules.d/00-mount-internal.rules
polkit.addRule(function(action, subject) {
   if ((action.id == "org.freedesktop.udisks2.filesystem-mount-system" &&
      subject.local && subject.active && subject.isInGroup("storage")))
      {
         return polkit.Result.YES;
      }
});
EOF


# Doas Set user permition
cat <<EOF >/etc/doas.conf
# allow user but require password
permit keepenv :$USER

# allow user and dont require a password to execute commands as root
permit nopass keepenv :$USER

# mount drives
permit nopass :$USER cmd mount
permit nopass :$USER cmd umount

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

chown -c root:root /etc/doas.conf

sed -i 's/MODULES=()/MODULES=(btrfs crc32c-intel nvidia)/g' /etc/mkinitcpio.conf
sed -i 's/HOOKS=(base udev autodetect modconf block filesystems keyboard fsck)/HOOKS=(base udev autodetect modconf block filesystems keyboard resume fsck btrfs grub-btrfs-overlayfs)/g' /etc/mkinitcpio.conf
sed -i 's/#COMPRESSION="zstd"/COMPRESSION="zstd"/g' /etc/mkinitcpio.conf
mkinitcpio -P linux-lts

paccache -rk0