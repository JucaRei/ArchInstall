#!/bin/bash

ln -sf /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime
hwclock --systohc
## Locales

sed -i '177s/.//' /etc/locale.gen
locale-gen

## Keyboard
echo "LANG=en_US.UTF-8" >>/etc/locale.conf
echo "KEYMAP=br-abnt2" >>/etc/vconsole.conf
# echo "KEYMAP=us-intl" >>/etc/vconsole.conf 
# echo "KEYMAP=mac-us" >>/etc/vconsole.conf

## Hostname
echo "artixnitro" >>/etc/hostname

## Hosts
echo "127.0.0.1 localhost" >>/etc/hosts
echo "::1       localhost" >>/etc/hosts
echo "127.0.1.1 artixnitro.localdomain artixnitro" >>/etc/hosts
echo root:200291 | chpasswd

pacman -Sy artix-archlinux-support --noconfirm
pacman -Sy artix-keyring --noconfirm
# pacman -Sy lib32-artix-archlinux-support --noconfirm
pacman-key --populate artix

pacman-key --populate archlinux

# Enable pacman Color
sed -i '1n; /^#UseSyslog/i ILoveCandy' /etc/pacman.conf
sed -i '/Color/s/^#//' /etc/pacman.conf
sed -i '3n; /^#UseSyslog/i DisableDownloadTimeout' /etc/pacman.conf
sed -i 's/#ParallelDownloads = 5/ParallelDownloads = 8/g' /etc/pacman.conf

# Enable multilib repo
sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf
sed -i "/\[lib32\]/,/Include/"'s/^#//' /etc/pacman.conf

# Setting package signing option to require signature
sed -i '/\[core\]/a SigLevel\ =\ PackageRequired' /etc/pacman.conf
sed -i '/\[multilib\]/a SigLevel\ =\ PackageRequired' /etc/pacman.conf
sed -i '/\[community\]/a SigLevel\ =\ PackageRequired' /etc/pacman.conf
sed -i '/\[extra\]/a SigLevel\ =\ PackageRequired' /etc/pacman.conf

# ADD Repos
cat <<EOF >>/etc/pacman.conf
[extra]
Include = /etc/pacman.d/mirrorlist-arch

[community]
Include = /etc/pacman.d/mirrorlist-arch

[multilib]
Include = /etc/pacman.d/mirrorlist-arch
EOF

pacman -Syyw

pacman -S archlinux-keyring --noconfirm
pacman -Syyw

# cat << EOF >> /etc/pacman.conf
# [universe]
# Server = https://universe.artixlinux.org/$arch
# Server = https://mirror1.artixlinux.org/universe/$arch
# Server = https://mirror.pascalpuffke.de/artix-universe/$arch
# Server = https://artixlinux.qontinuum.space:4443/universe/os/$arch
# Server = https://mirror.alphvino.com/artix-universe/$arch

# [omniverse]
# Server = http://omniverse.artixlinux.org/$arch
# EOF

pacman-key --populate archlinux

pacman -Syy

# paru -S auto-cpufreq
# pacman -S reflector
# pacman -S nvidia-tweaks nvidia-settings
# pacman -S glow ncdu2 btop

### Works on xanmod
# paru -S nvidia-tweaks nvidia-prime xf86-video-intel

#pacman -S zramen-runit

# Add Chaotic repo
pacman-key --recv-key FBA220DFC880C036 --keyserver keyserver.ubuntu.com
pacman-key --lsign-key FBA220DFC880C036
pacman -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst' --noconfirm

# Add Liquorix
pacman-key --keyserver hkps://keyserver.ubuntu.com --recv-keys 9AE4078033F8024D
pacman-key --lsign-key 9AE4078033F8024D

# Add Andontie Repo
pacman-key --recv-key B545E9B7CD906FE3
pacman-key --lsign-key B545E9B7CD906FE3

# Universe repo optimus-manager-runit

cat << EOF >>/etc/pacman.conf
# Other Repo's

[omniverse]
Server = http://omniverse.artixlinux.org/$arch

[universe]
Server = https://universe.artixlinux.org/$arch
Server = https://mirror1.artixlinux.org/universe/$arch
Server = https://mirror.pascalpuffke.de/artix-universe/$arch
Server = https://artixlinux.qontinuum.space:4443/artixlinux/universe/os/$arch
Server = https://mirror1.cl.netactuate.com/artix/universe/$arch
Server = https://mirror1.artixlinux.org/universe/$arch
Server = https://universe.artixlinux.org/$arch
Server = https://mirror.pascalpuffke.de/artix-universe/$arch

#[liquorix]
#Server = https://liquorix.net/archlinux/

[chaotic-aur]
Include = /etc/pacman.d/chaotic-mirrorlist

[andontie-aur]
Server = https://aur.andontie.net/$arch

[herecura]
Server = https://repo.herecura.be/herecura/x86_64
EOF


pacman -Sy

cat <<EOF >>/etc/fstab

# tmpfs /tmp tmpfs defaults,nosuid,nodev,noatime 0 0
tmpfs /tmp tmpfs noatime,mode=1777 0 0
EOF



pacman -Syyy

sleep 3

pacman -Sy
# alsa-utils alsa-utils-runit
pacman -S grub grub-btrfs efibootmgr mesa mesa-utils wget curl backlight-runit networkmanager preload reflector nfs-utils nfs-utils-runit samba samba-runit metalog metalog-runit mpd mpd-runit networkmanager-runit network-manager-applet dropbear dropbear-runit powertop thermald thermald-runit htop neofetch chrony chrony-runit dialog duf bat exa lsd rsm avahi avahi-runit xdg-user-dirs xdg-utils gvfs gvfs-smb nfs-utils inetutils dnsutils bluez bluez-runit bluez-utils pulseaudio pavucontrol pulseaudio-bluetooth paprefs pamixer pulseaudio-ctl pulseaudio-control pulseaudio-alsa pulseaudio-equalizer pulseaudio-jack pulseaudio-zeroconf pulseaudio-support bash-completion exfat-utils cups cups-runit hplip rsync rsync-runit acpi acpid acpi_call-dkms virt-manager libvirt-runit qemu vde2 edk2-ovmf bridge-utils dnsmasq dnsmasq-runit vde2 opendoas ebtables openbsd-netcat iptables-nft ipset firewalld firewalld-runit flatpak nss-mdns acpid-runit ntfs-3g

export USER="junior"
export HOME="/home/root"

groups="$(id -Gn "$USER" | tr ' ' ':')"
svdir="$HOME/.runit/sv"

exec chpst -u "$USER:$groups" runsvdir "$svdir"
EOF

#Fix mount external HD
mkdir -pv /etc/udev/rules.d
cat << EOF >/etc/udev/rules.d/99-udisks2.rules
# UDISKS_FILESYSTEM_SHARED
# ==1: mount filesystem to a shared directory (/media/VolumeName)
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


ln -s /etc/runit/sv/NetworkManager /etc/runit/runsvdir/default/
ln -s /etc/runit/sv/acpid /etc/runit/runsvdir/default/
ln -s /etc/runit/sv/thermald /etc/runit/runsvdir/default/
ln -s /etc/runit/sv/chrony /etc/runit/runsvdir/default/
ln -s /etc/runit/sv/dropbear /etc/runit/runsvdir/default/
ln -s /etc/runit/sv/bluetoothd /etc/runit/runsvdir/default/
ln -s /etc/runit/sv/avahi-daemon /etc/runit/runsvdir/default/
ln -s /etc/runit/sv/alsa /etc/runit/runsvdir/default/
ln -s /etc/runit/sv/cupsd /etc/runit/runsvdir/default/
ln -s /etc/runit/sv/libvirtd/ /etc/runit/runsvdir/default/
ln -s /etc/runit/sv/nfs-server /etc/runit/runsvdir/default/
ln -s /etc/runit/sv/nmbd /etc/runit/runsvdir/default/
ln -s /etc/runit/sv/smbd /etc/runit/runsvdir/default/
ln -s /etc/runit/sv/statd /etc/runit/runsvdir/default/
ln -s /etc/runit/sv/rpcbind /etc/runit/runsvdir/default/
ln -s /etc/runit/sv/rsyncd /etc/runit/runsvdir/default/
ln -s /etc/runit/sv/mpd /etc/runit/runsvdir/default/
ln -s /etc/runit/sv/backlight /etc/runit/runsvdir/default/
ln -s /etc/runit/sv/metalog /etc/runit/runsvdir/default/

grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=Artix --recheck
grub-mkconfig -o /boot/grub/grub.cfg

mkinitcpio -p linux-lts

# Normal User
useradd -m junior
echo junior:200291 | chpasswd
usermod -aG sys,dbus,libvirt,users,storage,optical,lp,kvm,video,scanner,uucp,input,power,audio,wheel junior

echo "junior ALL=(ALL) ALL" >>/etc/sudoers.d/junior
echo "junior ALL=(ALL) NOPASSWD: ALL" >>/etc/sudoers.d/junior

cat <<EOF >/etc/sudoers
## sudoers file.
##
## This file MUST be edited with the 'visudo' command as root.
## Failure to use 'visudo' may result in syntax or file permission errors
## that prevent sudo from running.
##
## See the sudoers man page for the details on how to write a sudoers file.
##

Defaults passwd_timeout=0
Defaults timestamp_timeout=15

##
## User privilege specification
##
root ALL=(ALL) ALL

## Uncomment to allow members of group wheel to execute any command
%wheel ALL=(ALL) ALL

## Same thing without a password
%wheel ALL=(ALL) NOPASSWD: ALL

## Run some commands without a password
%wheel ALL=(ALL) NOPASSWD: /usr/bin/pacman -Sy
%wheel ALL=(ALL) NOPASSWD: /usr/bin/pacman -Syuw
%wheel ALL=(ALL) NOPASSWD: /usr/bin/pacman -Syuw --noconfirm
%wheel ALL=(ALL) NOPASSWD: /usr/bin/pacman -Syyuw --noconfirm

## Read drop-in files from /etc/sudoers.d
@includedir /etc/sudoers.d
EOF

echo "junior ALL=(ALL) ALL" >>/etc/sudoers.d/junior

# Doas Set user permition
cat <<EOF >/etc/doas.conf
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

chown -c root:root /etc/doas.conf


# sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/g' /etc/sudoers
# sed -i 's/# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/g' /etc/sudoers
# # sed -i 's/# %sudo ALL=(ALL:ALL) ALL/%sudo ALL=(ALL:ALL) ALL/g' /etc/sudoers

# cat <<EOF >>/etc/sudoers

# ## Run some commands without a password
# %wheel ALL=(ALL) NOPASSWD: /usr/bin/pacman -Sy
# %wheel ALL=(ALL) NOPASSWD: /usr/bin/pacman -Syuw
# %wheel ALL=(ALL) NOPASSWD: /usr/bin/pacman -Syuw --noconfirm
# %wheel ALL=(ALL) NOPASSWD: /usr/bin/pacman -Syyuw --noconfirm
# EOF

# pacman -Rs linux acpi_call --noconfirm
# pacman -S acpi_call-lts --noconfirm

touch /etc/modprobe.d/i915.conf
cat <<EOF >/etc/modprobe.d/i915.conf
options i915 enable_guc=2 enable_dc=4 enable_hangcheck=0 error_capture=0 enable_dp_mst=0 fastboot=1
EOF

sudo sed -i 's/#GRUB_DISABLE_OS_PROBER=true/GRUB_DISABLE_OS_PROBER=false/g' /etc/default/grub
sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet"/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=2 quiet apci_osi=Linux udev.log_level=0 acpi_backlight=video gpt acpi=force intel_pstate=active init_on_alloc=0 console=tty2 zswap.enabled=1 zswap.compressor=zstd zswap.max_pool_percent=10 zswap.zpool=zsmalloc mitigations=off nowatchdog msr.allow_writes=on pcie_aspm=force module.sig_unenforce intel_idle.max_cstate=1 cryptomgr.notests initcall_debug nvidia-drm.modeset=1 intel_iommu=on,igfx_off net.ifnames=0 no_timer_check noreplace-smp page_alloc.shuffle=1 rcupdate.rcu_expedited=1 tsc=reliable"/g' /etc/default/grub

grub-mkconfig -o /boot/grub/grub.cfg

mkdir -pv /etc/sysctl.d
cat << EOF > /etc/sysctl.d/00-sysctl.conf
vm.vfs_cache_pressure=500
vm.swappiness=100
vm.dirty_background_ratio=1
vm.dirty_ratio=50
EOF

# MakeSwap
# touch /swapfile
# chmod 600 /swapfile
# chattr +C /swapfile
# lsattr /swapfile
# dd if=/dev/zero of=/swapfile bs=1M count=8192 status=progress
# mkswap /swapfile
# swapon /swapfile

touch /var/swap/swapfile
truncate -s 0 /var/swap/swapfile
chattr +C /var/swap/swapfile
btrfs property set /var/swap/swapfile compression none
chmod 600 /var/swap/swapfile
# dd if=/dev/zero of=/var/swap/swapfile bs=1G count=8 status=progress
dd if=/dev/zero of=/var/swap/swapfile bs=1M count=1536 status=progress
mkswap /var/swap/swapfile
swapon /var/swap/swapfile


# Add to fstab
# echo " " >>/etc/fstab
# echo "# Swap" >>/etc/fstab
# echo "/swapfile      none     swap      defaults  0 0" >>/etc/fstab

# Add to fstab
set -e
SWAP_UUID=$(blkid -s UUID -o value /dev/vda2)
echo $SWAP_UUID
echo " " >> etc/fstab
echo "# Swap" >> /etc/fstab
echo "UUID=$SWAP_UUID /var/swap btrfs defaults,compress=no,nodatacow,noatime,nodiratime,noatime,subvol=@swap 0 0" >> /etc/fstab
# echo "/var/swap/swapfile none swap defaults 0 0" >> /etc/fstab
echo "/var/swap/swapfile none swap sw 0 0" >> /etc/fstab


mkdir -pv /tmp/btrfs
cd /tmp/btrfs
wget -c https://raw.githubusercontent.com/osandov/osandov-linux/master/scripts/btrfs_map_physical.c
gcc -O2 -o btrfs_map_physical btrfs_map_physical.c
touch btrfs_map_physical.txt
./btrfs_map_physical /var/swap/swapfile > btrfs_map_physical.txt
touch resume.txt
filefrag -v /var/swap/swapfile | awk '$1=="0:" {print substr($4, 1, length($4)-2)}' > resume.txt
set -e
RESUME_OFFSET=$(cat /tmp/btrfs/resume.txt)
ROOT_UUID=$(blkid -s UUID -o value /dev/vda2)
# export ROOT_UUID
# export RESUME_OFFSET
sed -i 's/GRUB_CMDLINE_LINUX=""/GRUB_CMDLINE_LINUX="'"resume=UUID=$ROOT_UUID resume_offset=$RESUME_OFFSET"'"/g' /etc/default/grub

grub-mkconfig -o /boot/grub/grub.cfg

sed -i 's/#ParallelDownloads = 5/ParallelDownloads = 8/g' /etc/pacman.conf
sed -i 's/#HandlePowerKey=poweroff/HandlePowerKey=ignore/g' /etc/elogind/logind.conf
sed -i 's/#HandleSuspendKey=suspend/HandleSuspendKey=ignore/g' /etc/elogind/logind.conf
sed -i 's/#HandleHibernateKey=hibernate/HandleHibernateKey=ignore/g' /etc/elogind/logind.conf
sed -i 's/#HandleLidSwitch=suspend/HandleLidSwitch=ignore/g' /etc/elogind/logind.conf
sed -i 's/#HandleLidSwitchExternalPower=suspend/HandleLidSwitchExternalPower=ignore/g' /etc/elogind/logind.conf
sed -i 's/#HandleLidSwitchDocked=ignore/HandleLidSwitchDocked=ignore/g' /etc/elogind/logind.conf
sed -i 's/#HandleNvidiaSleep=no/HandleNvidiaSleep=ignore/g' /etc/elogind/logind.conf

# i915.fastboot=1
pacman -Syyu duf btop lolcat htop --noconfirm
paccache -rk0

cd /
rm -rf install.sh
printf "\e[1;32mDone! Type exit, umount -a and reboot.\e[0m"
