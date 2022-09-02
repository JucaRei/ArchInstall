#!/bin/bash

ln -sf /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime
hwclock --systohc
sed -i '177s/.//' /etc/locale.gen
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

# ARTIX LINUX
# ADD Repos
cat <<\EOF >>/etc/pacman.conf

[universe]
Server = https://universe.artixlinux.org/$arch
Server = https://mirror1.artixlinux.org/universe/$arch
Server = https://mirror.pascalpuffke.de/artix-universe/$arch
Server = https://artixlinux.qontinuum.space/artixlinux/universe/os/$arch
Server = https://mirror1.cl.netactuate.com/artix/universe/$arch
Server = https://ftp.crifo.org/artix-universe/
EOF

pacman -Sy

pacman-key --init && pacman-key --populate archlinux artix

pacman -Syyy

# ADD Repos
cat << \EOF >> /etc/pacman.conf
[extra]
Include = /etc/pacman.d/mirrorlist-arch

[community]
Include = /etc/pacman.d/mirrorlist-arch

[multilib]
Include = /etc/pacman.d/mirrorlist-arch
EOF

pacman -Syy


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


# paru -S auto-cpufreq
# pacman -S reflector
# pacman -S nvidia-lts nvidia-utils nvidia-settings
# pacman -S glow ncdu2 btop

### Works on xanmod
# paru -S nvidia-tweaks nvidia-prime xf86-video-intel

#pacman -S zramen-s6

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

# Add Chaotic repo
pacman-key --recv-key FBA220DFC880C036 --keyserver keyserver.ubuntu.com
pacman-key --lsign-key FBA220DFC880C036
pacman -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'

cat << \EOF >> /etc/pacman.conf

[chaotic-aur]
Include = /etc/pacman.d/chaotic-mirrorlist
EOF

# Add Liquorix
pacman-key --keyserver hkps://keyserver.ubuntu.com --recv-keys 9AE4078033F8024D
pacman-key --lsign-key 9AE4078033F8024D

cat << \EOF >> /etc/pacman.conf

#[liquorix]
#Server = https://liquorix.net/archlinux/$repo$arch
EOF

# Add Andontie Repo
pacman-key --recv-key B545E9B7CD906FE3
pacman-key --lsign-key B545E9B7CD906FE3

cat <<\EOF >>/etc/fstab

# tmpfs /tmp tmpfs defaults,nosuid,nodev,noatime 0 0
tmpfs /tmp tmpfs noatime,mode=1777 0 0
EOF

cat << \EOF >>/etc/pacman.conf


[omniverse] 
Server = http://omniverse.artixlinux.org/$arch 

#[liquorix]
#Server = https://liquorix.net/archlinux/

[chaotic-aur]
Include = /etc/pacman.d/chaotic-mirrorlist

[andontie-aur]
Server = https://aur.andontie.net/$arch

[herecura]
Server = https://repo.herecura.be/$repo/$arch
EOF

pacman -Syy

### Swap file

# touch var/swap/swapfile
# truncate -s 0 /var/swap/swapfile
# chattr +C /var/swap/swapfile
# btrfs property set /var/swap/swapfile compression none
# chmod 600 /var/swap/swapfile
# dd if=/dev/zero of=/var/swap/swapfile bs=1G count=8 status=progress
# mkswap /var/swap/swapfile
# swapon /var/swap/swapfile

# Add to fstab
# set -e
# SWAP_UUID=$(blkid -s UUID -o value /dev/sda6)
# echo $SWAP_UUID
# echo " " >> etc/fstab
# echo "# Swap" >> /etc/fstab
# echo "UUID=$SWAP_UUID /var/swap btrfs defaults,noatime,subvol=@swap 0 0" >> /etc/fstab
# echo "/var/swap/swapfile none swap sw 0 0" >> /etc/fstab

# cd ArchInstall/Arch/Arch_pkgs
# pacman -U paru-1.9.2-1-x86_64.pkg.tar.zst

# cd /

pacman -Syu

pacman -S grub grub-btrfs efibootmgr mesa mesa-utils backlight-s6 preload reflector nfs-utils nfs-utils-s6 powertop lsd samba samba-s6 metalog metalog-s6 mpd mpd-s6 networkmanager networkmanager-s6 network-manager-applet thermald thermald-s6 htop neofetch chrony chrony-s6 dialog gvfs gvfs-smb duf bat exa avahi avahi-s6 xdg-user-dirs xdg-utils gvfs gvfs-smb nfs-utils inetutils dnsutils bluez bluez-s6 bluez-utils pulseaudio-bluetooth pulseaudio-alsa pulseaudio-equalizer pulseaudio-jack alsa-utils alsa-utils-s6 bash-completion exfat-utils cups cups-s6 hplip  rsync rsync-s6 acpi acpid acpi_call-dkms virt-manager libvirt-s6 qemu qemu-guest-agent-s6 qemu-arch-extra vde2 edk2-ovmf bridge-utils dnsmasq dnsmasq-s6 vde2 ebtables openbsd-netcat iptables-nft ipset firewalld firewalld-s6 flatpak sof-firmware nss-mdns acpid-s6 os-prober ntfs-3g
pacman -S zramen zramen-s6 --noconfirm

cat <<\EOF >/etc/samba/smb.conf
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
touch /etc/rc.local
cat <<\EOF >/etc/rc.local
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
cat <<\EOF >/etc/udev/rules.d/99-udisks2.rules
# UDISKS_FILESYSTEM_SHARED
# ==1: mount filesystem to a shared directory (/media/VolumeName)
# ==0: mount filesystem to a private directory (/run/media/$USER/VolumeName)
# See udisks(8)
ENV{ID_FS_USAGE}=="filesystem|other|crypto", ENV{UDISKS_FILESYSTEM_SHARED}="1"
EOF

# Not asking for password

mkdir -pv /etc/polkit-1/rules.d
cat <<\EOF >/etc/polkit-1/rules.d/10-udisks2.rules
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

cat <<\EOF >/etc/polkit-1/rules.d/00-mount-internal.rules
polkit.addRule(function(action, subject) {
   if ((action.id == "org.freedesktop.udisks2.filesystem-mount-system" &&
      subject.local && subject.active && subject.isInGroup("storage")))
      {
         return polkit.Result.YES;
      }
});
EOF



# s6 services
# s6-rc-bundle -c /etc/s6/rc/compiled add default NetworkManager dropbear thermald acpid chrony bluetoothd qemu-guest-agent dnsmasq avahi-daemon alsa cupsd libvirtd

touch /etc/s6/adminsv/default/contents.d/NetworkManager
touch /etc/s6/adminsv/default/contents.d/dropbear
touch /etc/s6/adminsv/default/contents.d/avahi-daemon
touch /etc/s6/adminsv/default/contents.d/zramen
touch /etc/s6/adminsv/default/contents.d/nfs-server
touch /etc/s6/adminsv/default/contents.d/nmbd
touch /etc/s6/adminsv/default/contents.d/smbd
touch /etc/s6/adminsv/default/contents.d/statd
touch /etc/s6/adminsv/default/contents.d/rpcbind
touch /etc/s6/adminsv/default/contents.d/rsyncd
touch /etc/s6/adminsv/default/contents.d/mpd
touch /etc/s6/adminsv/default/contents.d/backlight
touch /etc/s6/adminsv/default/contents.d/metalog
touch /etc/s6/adminsv/default/contents.d/acpid
touch /etc/s6/adminsv/default/contents.d/chronyd
touch /etc/s6/adminsv/default/contents.d/bluetoothd
touch /etc/s6/adminsv/default/contents.d/qemu-guest-agent
touch /etc/s6/adminsv/default/contents.d/dnsmasq
touch /etc/s6/adminsv/default/contents.d/alsa
touch /etc/s6/adminsv/default/contents.d/cupsd
touch /etc/s6/adminsv/default/contents.d/libvirtd
s6-db-reload


grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=Artix --recheck
grub-mkconfig -o /boot/grub/grub.cfg

mkinitcpio -p linux-lts

useradd -m junior
echo junior:200291 | chpasswd
usermod -aG sys,dbus,libvirt,users,storage,optical,lp,kvm,video,scanner,uucp,input,power,audio,wheel junior


sed -i 's/# %wheel ALL=(ALL:ALL) ALL/%wheel ALL=(ALL:ALL) ALL/g' /etc/sudoers
sed -i 's/# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/g' /etc/sudoers
sed -i 's/# %sudo ALL=(ALL:ALL) ALL/%sudo ALL=(ALL:ALL) ALL/g' /etc/sudoers


echo "junior ALL=(ALL) ALL" >>/etc/sudoers.d/junior

touch /etc/modprobe.d/i915.conf
cat <<\EOF >/etc/modprobe.d/i915.conf
options i915 enable_guc=2 enable_dc=4 enable_hangcheck=0 error_capture=0 enable_dp_mst=0 fastboot=1
EOF

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
sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet"/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=2 quiet apci_osi=Linux udev.log_level=0 acpi_backlight=video gpt acpi=force intel_pstate=active init_on_alloc=0 console=tty2 zswap.enabled=1 zswap.compressor=zstd zswap.max_pool_percent=10 zswap.zpool=zsmalloc mitigations=off nowatchdog msr.allow_writes=on pcie_aspm=force module.sig_unenforce intel_idle.max_cstate=1 cryptomgr.notests initcall_debug nvidia-drm.modeset=1 intel_iommu=on,igfx_off net.ifnames=0 no_timer_check noreplace-smp page_alloc.shuffle=1 rcupdate.rcu_expedited=1 tsc=reliable"/g' /etc/default/grub


grub-mkconfig -o /boot/grub/grub.cfg

mkdir -pv /etc/sysctl.d
touch /etc/sysctl.d/00-sysctl.conf
cat << \EOF > /etc/sysctl.d/00-sysctl.conf
vm.vfs_cache_pressure=500
vm.swappiness=100
vm.dirty_background_ratio=1
vm.dirty_ratio=50
EOF


paccache -rk0


# i915.fastboot=1


printf "\e[1;32mDone! Type exit, umount -a and reboot.\e[0m"

