#!/bin/bash

ln -sf /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime
hwclock --systohc
sed -i '178s/.//' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" >>/etc/locale.conf
echo "KEYMAP=br-abnt2" >>/etc/vconsole.conf
# echo "KEYMAP=us-intl" >>/etc/vconsole.conf
# echo "KEYMAP=mac-us" >>/etc/vconsole.conf
echo "artixnitro" >>/etc/hostname
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

# Universe repo optimus-manager-runit

cat <<EOF >>/etc/pacman.conf

#[omniverse]
#Server = http://omniverse.artixlinux.org/$arch

#[universe]
#Server = https://universe.artixlinux.org/$arch
#Server = https://mirror1.artixlinux.org/universe/$arch
#Server = https://mirror.pascalpuffke.de/artix-universe/$arch
#Server = https://artixlinux.qontinuum.space:4443/artixlinux/universe/os/$arch
#Server = https://mirror1.cl.netactuate.com/artix/universe/$arch

#[liquorix]
#Server = https://liquorix.net/archlinux/$repo$arch

[chaotic-aur]
Include = /etc/pacman.d/chaotic-mirrorlist
EOF

pacman -Sy

cat <<EOF >>/etc/fstab

# tmpfs /tmp tmpfs defaults,nosuid,nodev,noatime 0 0
tmpfs /tmp tmpfs noatime,mode=1777 0 0
EOF

# MakeSwap
touch /swapfile
chmod 600 /swapfile
chattr +C /swapfile
lsattr /swapfile
dd if=/dev/zero of=/swapfile bs=1M count=8192 status=progress
mkswap /swapfile
swapon /swapfile

# Add to fstab
echo " " >>/etc/fstab
echo "# Swap" >>/etc/fstab
echo "/swapfile      none     swap      defaults  0 0" >>/etc/fstab

pacman -Syyy

sleep 3

pacman -Sy

pacman -S grub grub-btrfs efibootmgr mesa mesa-utils backlight-runit networkmanager preload reflector nfs-utils nfs-utils-runit samba samba-runit metalog metalog-runit mpd mpd-runit networkmanager-runit network-manager-applet dropbear dropbear-runit powertop thermald thermald-runit htop neofetch chrony chrony-runit dialog duf bat exa lsd rsm avahi avahi-runit xdg-user-dirs xdg-utils gvfs gvfs-smb nfs-utils inetutils dnsutils bluez bluez-runit bluez-utils pulseaudio-bluetooth pulseaudio-alsa pulseaudio-equalizer pulseaudio-jack alsa-utils alsa-utils-runit bash-completion exfat-utils cups cups-runit hplip rsync rsync-runit acpi acpid acpi_call-dkms virt-manager libvirt-runit qemu qemu-guest-agent-runit qemu-arch-extra vde2 edk2-ovmf bridge-utils dnsmasq dnsmasq-runit vde2 ebtables openbsd-netcat iptables-nft ipset firewalld firewalld-runit flatpak nss-mdns acpid-runit os-prober ntfs-3g

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

# Power top
cat <<EOF >>/etc/rc.local
# PowerTop
powertop --auto-tune

# echo 60000 > /sys/bus/usb/devices/2-1.5/power/autosuspend_delay_ms
# echo 60000 > /sys/bus/usb/devices/2-1.6/power/autosuspend_delay_ms
# echo 60000 > /sys/bus/usb/devices/3-1.5/power/autosuspend_delay_ms
# echo 60000 > /sys/bus/usb/devices/3-1.6/power/autosuspend_delay_ms
# echo 60000 > /sys/bus/usb/devices/4-1.5/power/autosuspend_delay_ms
# echo 60000 > /sys/bus/usb/devices/4-1.6/power/autosuspend_delay_ms

# Preload
preload
EOF

#Fix mount external HD
mkdir -pv /etc/udev/rules.d
cat <<EOF >/etc/udev/rules.d/99-udisks2.rules
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

ln -s /etc/runit/sv/NetworkManager /etc/runit/runsvdir/default/
# ln -s /etc/runit/sv/sshd /etc/runit/runsvdir/default/
ln -s /etc/runit/sv/thermald /etc/runit/runsvdir/default/
ln -s /etc/runit/sv/dropbear /etc/runit/runsvdir/default/
ln -s /etc/runit/sv/acpid /etc/runit/runsvdir/default/
ln -s /etc/runit/sv/ntpd /etc/runit/runsvdir/default/
ln -s /etc/runit/sv/bluetoothd /etc/runit/runsvdir/default/
#ln -s /etc/runit/sv/wpa_supplicant /etc/runit/runsvdir/default/
ln -s /etc/runit/sv/avahi-daemon /etc/runit/runsvdir/default/
ln -s /etc/runit/sv/alsa /etc/runit/runsvdir/default/
ln -s /etc/runit/sv/cupsd /etc/runit/runsvdir/default/
# ln -s /etc/runit/sv/tlp /etc/runit/runsvdir/default/
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

grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=Artix
grub-mkconfig -o /boot/grub/grub.cfg

mkinitcpio -p linux-lts

# Normal User
useradd -m junior
echo junior:200291 | chpasswd
usermod -aG libvirt junior

echo "junior ALL=(ALL) ALL" >>/etc/sudoers.d/junior

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
# sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet"/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=2 quiet udev.log_level=0 i915.fastboot=1 i915.enable_guc=2 acpi_backlight=vendor console=tty2 zswap.enabled=1 zswap.compressor=zstd zswap.max_pool_percent=10 zswap.zpool=zsmalloc mitigations=off nowatchdog msr.allow_writes=on pcie_aspm=force module.sig_unenforce intel_idle.max_cstate=1 i915.enable_dc=0 ahci.mobile_lpm_policy=1 cryptomgr.notests initcall_debug nvidia-drm.modeset=1 intel_iommu=on,igfx_off net.ifnames=0 no_timer_check noreplace-smp page_alloc.shuffle=1 rcupdate.rcu_expedited=1 tsc=reliable"/g' /etc/default/grub
# sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet"/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=2 quiet udev.log_level=0 i915.fastboot=1 i915.enable_guc=2 acpi_backlight=vendor console=tty2 zswap.enabled=1 zswap.compressor=zstd zswap.max_pool_percent=10 zswap.zpool=zsmalloc mitigations=off nowatchdog msr.allow_writes=on pcie_aspm=force module.sig_unenforce intel_idle.max_cstate=1 ahci.mobile_lpm_policy=1 cryptomgr.notests initcall_debug nvidia-drm.modeset=1 intel_iommu=on,igfx_off net.ifnames=0 no_timer_check noreplace-smp page_alloc.shuffle=1 rcupdate.rcu_expedited=1 tsc=reliable"/g' /etc/default/grub
sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet"/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=2 quiet udev.log_level=0 acpi_backlight=vendor console=tty2 zswap.enabled=1 zswap.compressor=zstd zswap.max_pool_percent=10 zswap.zpool=zsmalloc mitigations=off nowatchdog msr.allow_writes=on pcie_aspm=force module.sig_unenforce intel_idle.max_cstate=1 ahci.mobile_lpm_policy=1 cryptomgr.notests initcall_debug nvidia-drm.modeset=1 intel_iommu=on,igfx_off net.ifnames=0 no_timer_check noreplace-smp page_alloc.shuffle=1 rcupdate.rcu_expedited=1 tsc=reliable"/g' /etc/default/grub

grub-mkconfig -o /boot/grub/grub.cfg

# i915.fastboot=1

paccache -rk0

printf "\e[1;32mDone! Type exit, umount -a and reboot.\e[0m"
