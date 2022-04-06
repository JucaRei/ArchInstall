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

pacman -S artix-archlinux-support
pacman -S artix-keyring
pacman-key --populate artix

pacman-key --populate archlinux

# ADD Repos
cat <<EOF >>/etc/pacman.conf
[extra]
Include = /etc/pacman.d/mirrorlist-arch

[community]
Include = /etc/pacman.d/mirrorlist-arch

[multilib]
Include = /etc/pacman.d/mirrorlist-arch
EOF

pacman -Syyy

pacman -S archlinux-keyring
pacman -Syyy

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
# pacman -S nvidia-lts nvidia-utils nvidia-settings
# pacman -S glow ncdu2 btop

### Works on xanmod
# paru -S nvidia-tweaks nvidia-prime xf86-video-intel

#pacman -S zramen-runit

# function install_paru() {
#     # use build directory to intall pary as "nobody" user
#     # change the directory's group to "nobody" and make it sticky
#     # so that all files within get the same properties
#     mkdir -pv /home/build
#     cd /home/build
#     chgrp nobody /home/build
#     chmod g+ws /home/build
#     setfacl -m u::rwx,g::rwx /home/build
#     setfacl -d --set u::rwx,g::rwx,o::- /home/build

#     # clone the repo
#     git clone --depth=1 https://aur.archlinux.org/paru-bin.git paru
#     chmod 777 paru
#     cd paru

#     # make the package as "nobody"
#     sudo -u nobody makepkg

#     # install the package as root
#     pacman --noconfirm -U paru-bin*.zst

#     # clean up
#     cd
#     rm -rf /home/build
# }

# install_paru

# Enable pacman Color
sed -i '/Color/s/^#//' /etc/pacman.conf
sed -i 's/#ParallelDownloads = 5/ParallelDownloads = 5/g' /etc/pacman.conf

# Enable multilib repo
sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf

# Setting package signing option to require signature
sed -i '/\[core\]/a SigLevel\ =\ PackageRequired' /etc/pacman.conf
sed -i '/\[multilib\]/a SigLevel\ =\ PackageRequired' /etc/pacman.conf
sed -i '/\[community\]/a SigLevel\ =\ PackageRequired' /etc/pacman.conf
sed -i '/\[extra\]/a SigLevel\ =\ PackageRequired' /etc/pacman.conf

# Add Chaotic repo
pacman-key --recv-key FBA220DFC880C036 --keyserver keyserver.ubuntu.com
pacman-key --lsign-key FBA220DFC880C036
pacman -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'

cat <<EOF >>/etc/pacman.conf

[chaotic-aur]
Include = /etc/pacman.d/chaotic-mirrorlist
EOF

# Add Liquorix
pacman-key --keyserver hkps://keyserver.ubuntu.com --recv-keys 9AE4078033F8024D
pacman-key --lsign-key 9AE4078033F8024D

cat <<EOF >>/etc/pacman.conf

#[liquorix]
#Server = https://liquorix.net/archlinux/$repo$arch
EOF

cat <<EOF >>/etc/fstab

tmpfs /tmp tmpfs defaults,nosuid,nodev,noatime 0 0
EOF

pacman -Syy

pacman -S grub grub-btrfs efibootmgr mesa mesa-utils networkmanager nfs-utils nfs-utils-runit samba samba-runit metalog metalog-runit mpd mpd-runit networkmanager-runit network-manager-applet dropbear dropbear-runit thermald thermald-runit htop neofetch chrony chrony-runit dialog duf bat exa rsm avahi avahi-runit xdg-user-dirs xdg-utils gvfs gvfs-smb nfs-utils inetutils dnsutils bluez bluez-runit bluez-utils pulseaudio-bluetooth pulseaudio-alsa pulseaudio-equalizer pulseaudio-jack alsa-utils alsa-utils-runit bash-completion exfat-utils cups cups-runit hplip rsync rsync-runit acpi acpid acpi_call-dkms virt-manager libvirt-runit qemu qemu-guest-agent-runit qemu-arch-extra vde2 edk2-ovmf bridge-utils dnsmasq dnsmasq-runit vde2 ebtables openbsd-netcat iptables-nft ipset firewalld firewalld-runit flatpak nss-mdns acpid-runit os-prober ntfs-3g

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
sudo ln -s /etc/runit/sv/nfs-server /etc/runit/runsvdir/default/
sudo ln -s /etc/runit/sv/nmbd /etc/runit/runsvdir/default/
sudo ln -s /etc/runit/sv/smbd /etc/runit/runsvdir/default/
sudo ln -s /etc/runit/sv/statd /etc/runit/runsvdir/default/
sudo ln -s /etc/runit/sv/rpcbind /etc/runit/runsvdir/default/
sudo ln -s /etc/runit/sv/mpd /etc/runit/runsvdir/default/
sudo ln -s /etc/runit/sv/metalog /etc/runit/runsvdir/default/

grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=Artix
grub-mkconfig -o /boot/grub/grub.cfg

mkinitcpio -p linux-lts

useradd -m junior
echo junior:200291 | chpasswd
usermod -aG libvirt junior

sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/g' /etc/sudoers
sed -i 's/# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/g' /etc/sudoers
# sed -i 's/# %sudo ALL=(ALL:ALL) ALL/%sudo ALL=(ALL:ALL) ALL/g' /etc/sudoers

echo "junior ALL=(ALL) ALL" >>/etc/sudoers.d/junior

# pacman -Rs linux acpi_call --noconfirm
# pacman -S acpi_call-lts --noconfirm

# running makepkg as nobody user
# mkdir /home/build
# chgrp nobody /home/build
# chmod g+ws /home/build
# setfacl -m u::rwx,g::rwx /home/build
# setfacl -d --set u::rwx,g::rwx,o::- /home/build

sudo sed -i 's/#GRUB_DISABLE_OS_PROBER=true/GRUB_DISABLE_OS_PROBER=false/g' /etc/default/grub
# sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet"/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=2 quiet udev.log_level=0 i915.fastboot=1 i915.enable_guc=2 acpi_backlight=vendor console=tty2 zswap.enabled=1 zswap.compressor=zstd zswap.max_pool_percent=10 zswap.zpool=zsmalloc mitigations=off nowatchdog msr.allow_writes=on pcie_aspm=force module.sig_unenforce intel_idle.max_cstate=1 i915.enable_dc=0 ahci.mobile_lpm_policy=1 cryptomgr.notests initcall_debug nvidia-drm.modeset=1 intel_iommu=on,igfx_off net.ifnames=0 no_timer_check noreplace-smp page_alloc.shuffle=1 rcupdate.rcu_expedited=1 tsc=reliable"/g' /etc/default/grub
sudo sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet"/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=2 quiet udev.log_level=0 i915.fastboot=1 i915.enable_guc=2 acpi_backlight=vendor console=tty2 zswap.enabled=1 zswap.compressor=zstd zswap.max_pool_percent=10 zswap.zpool=zsmalloc mitigations=off nowatchdog msr.allow_writes=on pcie_aspm=force module.sig_unenforce intel_idle.max_cstate=1 ahci.mobile_lpm_policy=1 cryptomgr.notests initcall_debug nvidia-drm.modeset=1 intel_iommu=on,igfx_off net.ifnames=0 no_timer_check noreplace-smp page_alloc.shuffle=1 rcupdate.rcu_expedited=1 tsc=reliable"/g' /etc/default/grub

grub-mkconfig -o /boot/grub/grub.cfg

# i915.fastboot=1

printf "\e[1;32mDone! Type exit, umount -a and reboot.\e[0m"
