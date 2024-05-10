#!/bin/bash

ln -sf /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime
hwclock --systohc
sed -i '171s/.//' /etc/locale.gen
locale-gen
# echo "LANG=en_US.UTF-8" >>/etc/locale.conf
# echo "KEYMAP=us-intl" >>/etc/vconsole.conf
# echo "KEYMAP=mac-us" >>/etc/vconsole.conf
echo "anubis" >>/etc/hostname
echo "127.0.0.1 localhost" >>/etc/hosts
echo "::1       localhost" >>/etc/hosts
echo "127.0.1.1 anubis.localdomain anubis" >>/etc/hosts
echo root:200291 | chpasswd

# Enable pacman Color
sed -i '1n; /^#UseSyslog/i ILoveCandy' /etc/pacman.conf
sed -i '3n; /^#UseSyslog/i DisableDownloadTimeout' /etc/pacman.conf
sed -i '/Color/s/^#//' /etc/pacman.conf
sed -i 's/#ParallelDownloads = 5/ParallelDownloads = 4/g' /etc/pacman.conf

# Enable multilib repo
sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf
sed -i "/\[lib32\]/,/Include/"'s/^#//' /etc/pacman.conf

# Setting package signing option to require signature
sed -i '/\[core\]/a SigLevel\ =\ PackageRequired' /etc/pacman.conf
sed -i '/\[multilib\]/a SigLevel\ =\ PackageRequired' /etc/pacman.conf
sed -i '/\[community\]/a SigLevel\ =\ PackageRequired' /etc/pacman.conf
sed -i '/\[extra\]/a SigLevel\ =\ PackageRequired' /etc/pacman.conf

pacman -Syyw

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

cat <<EOF >>/etc/pacman.conf
#[liquorix]
#Server = https://liquorix.net/archlinux/

# [chaotic-aur]
# Include = /etc/pacman.d/chaotic-mirrorlist

EOF

# sed -i -e '$a [andontie-aur]' /etc/pacman.conf
# sed -i -e '$a Server = https://aur.andontie.net/$arch' /etc/pacman.conf

pacman -Sy

mkdir -pv /media/juca

cat <<EOF >>/etc/fstab

# tmpfs /tmp tmpfs defaults,nosuid,nodev,noatime 0 0
# tmpfs /tmp tmpfs noatime,mode=1777 0 0
tmpfs           /tmp               tmpfs noatime,mode=1777                  0 0

EOF

# pacman -S archlinux-keyring wpa_supplicant dialog preload ananicy-cpp
pacman -S grub os-prober efibootmgr intel-ucode earlyoom opendoas thermald chrony  irqbalance networkmanager iwd  exfat-utils htop udisks2 dropbear bash-completion wireless_tools mtools dosfstools bluez bluez-utils pulseaudio pulseaudio-bluetooth alsa-utils ntfs-3g firewalld rsync gvfs gvfs-smb nfs-utils inetutils dnsutils nss-mdns avahi tlp breeze-plymouth plymouth powertop
# xdg-utils xdg-user-dirs
# apci & tlp
pacman -S acpi acpid --noconfirm

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
cat << EOF > /etc/iwd/main.conf
[General]
EnableNetworkConfiguration=true

[Network]
NameResolvingService=systemd
RouterPriorityOffset=30
EOF


systemctl enable NetworkManager
systemctl enable bluetooth
systemctl enable iwd
systemctl enable dropbear
systemctl enable earlyoom
systemctl enable powertop
systemctl enable tlp
systemctl enable irqbalance
# systemctl enable preload
# systemctl enable ananicy-cpp
# systemctl enable smbd
# systemctl enable nmbd
systemctl enable chronyd
systemctl enable avahi-daemon
systemctl enable reflector.timer
systemctl enable fstrim.timer
systemctl enable firewalld
systemctl enable acpid

useradd -m juca
echo juca:200291 | chpasswd
usermod -aG wheel juca

echo "juca ALL=(ALL) ALL" >>/etc/sudoers.d/juca
echo "juca ALL=(ALL) NOPASSWD: ALL" >>/etc/sudoers.d/juca

# pacman -Rs linux acpi_call --noconfirm

# pacman -S acpi_call-lts --noconfirm

mkinitcpio -P linux-zen

mkdir -pv /etc/default/
touch /etc/default/keyboard
cat <<EOF >/etc/default/keyboard
# KEYBOARD CONFIGURATION FILE

# Consult the keyboard(5) manual page.

XKBMODEL="pc105"
XKBLAYOUT="us"
XKBVARIANT="mac"
# XKBOPTIONS="terminate:ctrl_alt_bksp"
EOF

# sed -i 's/#GRUB_DISABLE_OS_PROBER=true/GRUB_DISABLE_OS_PROBER=false/g' /etc/default/grub
# sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet"/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=2 quiet udev.log_level=0 i915.fastboot=1 i915.enable_guc=2 acpi_backlight=vendor console=tty2 zswap.enabled=1 zswap.compressor=zstd zswap.max_pool_percent=10 zswap.zpool=zsmalloc mitigations=off nowatchdog msr.allow_writes=on pcie_aspm=force module.sig_unenforce intel_idle.max_cstate=1 i915.enable_dc=0 ahci.mobile_lpm_policy=1 cryptomgr.notests initcall_debug nvidia-drm.modeset=1 intel_iommu=on,igfx_off net.ifnames=0 no_timer_check noreplace-smp page_alloc.shuffle=1 rcupdate.rcu_expedited=1 tsc=reliable"/g' /etc/default/grub
sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT=""quiet splash applesmc acpi_backlight=vendor kernel.unprivileged_userns_clone vt.global_cursor_default=0 loglevel=0 gpt init_on_alloc=0 udev.log_level=0 intel_iommu=on i915.modeset=1 zswap.enabled=1 zswap.compressor=lz4hc zswap.max_pool_percent=10 zswap.zpool=z3fold mitigations=off nowatchdog msr.allow_writes=on pcie_aspm=force module.sig_unenforce intel_idle.max_cstate=1 cryptomgr.notests initcall_debug no_timer_check noreplace-smp page_alloc.shuffle=1 rcupdate.rcu_expedited=1 tsc=reliable"/g' /etc/default/grub
sed -i 's/GRUB_COLOR_NORMAL="light-blue/black"/GRUB_COLOR_NORMAL="red/black"/g'
sed -i 's/#GRUB_COLOR_HIGHLIGHT="light-cyan/blue"/GRUB_COLOR_HIGHLIGHT="yellow/black"/g'
# sudo sed -i 's/#GRUB_DISABLE_OS_PROBER=true/GRUB_DISABLE_OS_PROBER=false/g' /etc/default/grub
grub-install --target=x86_64-efi --bootloader-id=GRUB --efi-directory=/boot/efi --no-nvram --removable --recheck
# grub-install --target=x86_64-efi --bootloader-id=Arch --efi-directory=/boot/efi --no-nvram --removable --recheck --no-rs-codes --modules="btrfs zstd part_gpt part_msdos"
grub-mkconfig -o /boot/grub/grub.cfg

# Power top
touch /etc/rc.local
cat <<EOF >/etc/rc.local
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

# intel Graphics and acceleration
# mesa
pacman -S mesa-amber vulkan-intel


# Touchpad tap to click
mkdir -pv /etc/X11/xorg.conf.d/
touch /etc/X11/xorg.conf.d/30-touchpad.conf
cat <<EOF >/etc/X11/xorg.conf.d/30-touchpad.conf
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

touch /etc/X11/xorg.conf.d/20-modesetting.conf
cat <<EOF >/etc/X11/xorg.conf.d/20-modesetting.conf
Section "Device"
#   Identifier "Intel Graphics 630"
#   Driver "intel"
#   Option "AccelMethod" "sna"
#   Option "TearFree" "True"
#   Option "Tiling" "True"
#   Option "SwapbuffersWait" "True"
#   Option "DRI" "3"

   Identifier  "Intel Graphics"
   Driver      "modesetting"
   Option      "TearFree"        "false"
   Option      "TripleBuffer"    "false"
   Option      "SwapbuffersWait" "false"
   # Option      "TearFree"        "True"
   Option      "AccelMethod"     "uxa"
   Option      "AccelMethod"     "glamor"
   Option      "DRI"             "3"
EndSection
EOF

touch /etc/X11/xorg.conf.d/20-intel.conf
cat <<EOF >/etc/X11/xorg.conf.d/20-intel.conf
# Section "Device"
#     Identifier          "Intel Graphics"
#     MatchDriver         "i915"
#     Driver              "intel"
#     Option              "DRI"               "3"
#     Option              "TearFree"          "1"
# EndSection
EOF

# Option      "TearFree"        "false"
# Option      "TripleBuffer"    "false"
# Option      "SwapbuffersWait" "false"
### systemctl
mkdir -pv /etc/sysctl.d
touch /etc/sysctl.d/00-sysctl.conf
cat <<EOF >/etc/sysctl.d/00-sysctl.conf
# vm.vfs_cache_pressure=500
vm.vfs_cache_pressure=40
# vm.swappiness=100
vm.swappiness=20 #10
vm.dirty_background_ratio=1
vm.dirty_bytes" = 335544320
vm.dirty_background_bytes" = 167772160
vm.dirty_ratio=50
dev.i915.perf_stream_paranoid=0
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

cat <<EOF >/etc/polkit-1/rules.d/00-mount-internal.rules
polkit.addRule(function(action, subject) {
   if ((action.id == "org.freedesktop.udisks2.filesystem-mount-system" &&
      subject.local && subject.active && subject.isInGroup("storage")))
      {
         return polkit.Result.YES;
      }
});
EOF

# usermod -aG storage junior

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

touch /etc/modprobe.d/i915.conf
cat <<EOF >/etc/modprobe.d/i915.conf
options i915 enable_dc=4 enable_hangcheck=0 error_capture=0 enable_dp_mst=0 fastboot=1
EOF

# SWAP

# touch /var/swap/swapfile
# truncate -s 0 /var/swap/swapfile
# chattr +C /var/swap/swapfile
# btrfs property set /var/swap/swapfile compression none (não necessário)
# chmod 600 /var/swap/swapfile
# dd if=/dev/zero of=/var/swap/swapfile bs=1M count=4096 status=progress
# mkswap /var/swap/swapfile
# swapon /var/swap/swapfile

# Add to fstab
# set -e
# SWAP_UUID=$(blkid -s UUID -o value /dev/sda4)
# echo $SWAP_UUID
# echo " " >>/etc/fstab
# echo "# Swap" >>/etc/fstab
# echo "UUID=$SWAP_UUID /var/swap btrfs defaults,noatime,subvol=@swap 0 0" >>/etc/fstab
# echo "/var/swap/swapfile none swap sw 0 0" >>/etc/fstab

# MakeSwap
# touch /var/swap/swapfile
# chmod 600 /swapfile
# chattr +C /swapfile
# lsattr /swapfile
# dd if=/dev/zero of=/swapfile bs=1M count=4096 status=progress
# mkswap /swapfile
# swapon /swapfile

# # Add to fstab
# echo " " >> /etc/fstab
# echo "# Swap" >> /etc/fstab
# echo "/swapfile      none     swap      defaults  0 0" >> /etc/fstab

# Systemd-Boot
# bootctl --path=/boot install
# echo "default arch.conf" >>/boot/loader/loader.conf
# touch /boot/loader/entries/arch.conf

# cat <<EOF >/boot/loader/entries/arch.conf
# title   Arch Linux
# linux   /vmlinuz-linux-lts
# initrd  /intel-ucode.img
# initrd  /initramfs-linux-lts.img
# options root=/dev/sda4 rootflags=subvol=@ rw quiet loglevel=0 console=tty2 acpi_osi=Darwin acpi_mask_gpe=0x06 udev.log_level=0 mitigations=off nowatchdog msr.allow_writes=on pcie_aspm=force module.sig_unenforce intel_idle.max_cstate=1 cryptomgr.notests initcall_debug net.ifnames=0 no_timer_check noreplace-smp page_alloc.shuffle=1 rcupdate.rcu_expedited=1 tsc=reliable
# EOF
# options root=/dev/sda2 rootflags=subvol=@ rw quiet splash loglevel=3 mitigations=off nowatchdog msr.allow_writes=on pcie_aspm=force module.sig_unenforce  vt.global_cursor_default=0 intel_idle.max_cstate=1 zswap.enabled=1 zswap.compressor=zstd zswap.max_pool_percent=10 zswap.zpool=zsmalloc cryptomgr.notests initcall_debug intel_iommu=igfx_off net.ifnames=0 no_timer_check noreplace-smp page_alloc.shuffle=1 rcupdate.rcu_expedited=1 tsc=reliable

# Mkinitcpio
sudo sed -i 's/MODULES=()/MODULES=(btrfs i915 crc32c-intel)/g' /etc/mkinitcpio.conf
sudo sed -i 's/HOOKS=(base udev autodetect modconf block filesystems keyboard fsck)/HOOKS=(base udev autodetect modconf block filesystems keyboard resume fsck btrfs)/g' /etc/mkinitcpio.conf
sudo sed -i 's/#COMPRESSION="xz"/COMPRESSION="zstd"/g' /etc/mkinitcpio.conf

mkinitcpio -P linux-zen

printf "\e[1;32mDone! Type exit, umount -a and reboot.\e[0m"
