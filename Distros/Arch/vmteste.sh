#!/bin/bash

DRIVE="/dev/vda"

pacman -Sy archlinux-keyring --noconfirm

# Enable pacman Color
sed -i '1n; /^#UseSyslog/i ILoveCandy' /etc/pacman.conf
sed -i '/Color/s/^#//' /etc/pacman.conf
sed -i '3n; /^#UseSyslog/i DisableDownloadTimeout' /etc/pacman.conf
sed -i 's/#ParallelDownloads = 5/ParallelDownloads = 4/g' /etc/pacman.conf

cat <<\EOF >> /etc/pacman.conf

[liquorix]
Server = https://liquorix.net/archlinux/$repo/$arch
EOF

# Get Best Mirrors
# reflector --protocol https --country "Brazil" --latest 10 --sort rate --save /etc/pacman.d/mirrorlist

# Add Liquorix
pacman-key --init
pacman-key --keyserver hkps://keyserver.ubuntu.com --recv-keys 9AE4078033F8024D
pacman-key --lsign-key 9AE4078033F8024D
pacman-key --populate

pacman -Syyy

# =======================================================================================================================================================

umount -R /mnt
sleep 2
sgdisk -Z ${DRIVE}
sleep 2
sgdisk -n 0:0:512MiB ${DRIVE}
sgdisk -n 0:0:0 ${DRIVE}
sgdisk -t 1:ef00 ${DRIVE}
sgdisk -t 2:8300 ${DRIVE}
sgdisk -c 1:EFI ${DRIVE}
sgdisk -c 2:Archlinux ${DRIVE}
sgdisk -p ${DRIVE}

mkfs.vfat -F32 ${DRIVE}1 -n "Grub"
mkfs.btrfs ${DRIVE}2 -f -L "Archsys"

mount -t btrfs ${DRIVE}2 /mnt

btrfs su cr /mnt/@
btrfs su cr /mnt/@pacman
btrfs su cr /mnt/@snapshots
btrfs su cr /mnt/@var_log
btrfs su cr /mnt/@tmp
btrfs su cr /mnt/@cache
btrfs su cr /mnt/@home
btrfs su cr /mnt/@swap

umount -vR /mnt

set -e
BTRFS_OPTS="noatime,ssd,compress-force=zstd:3,space_cache=v2,commit=120,discard=async"

## Mount partitions (Nitro)
mount -o $BTRFS_OPTS,subvol=@ ${DRIVE}2 /mnt
mkdir -pv /mnt/{home,.snapshots,boot/efi,var/log,var/tmp,var/cache,var/lib/pacman,swap}

# Swap Optional
# mkdir -pv /mnt/var/swap

mount -o $BTRFS_OPTS,subvol=@pacman ${DRIVE}2 /mnt/var/lib/pacman
mount -o $BTRFS_OPTS,subvol=@home ${DRIVE}2 /mnt/home
mount -o $BTRFS_OPTS,subvol=@snapshots ${DRIVE}2 /mnt/.snapshots
mount -o $BTRFS_OPTS,subvol=@var_log ${DRIVE}2 /mnt/var/log
mount -o $BTRFS_OPTS,subvol=@cache ${DRIVE}2 /mnt/var/cache
mount -o $BTRFS_OPTS,subvol=@tmp ${DRIVE}2 /mnt/var/tmp
mount -o $BTRFS_OPTS,subvol=@swap ${DRIVE}2 /mnt/swap
mount -t vfat -o defaults,noatime,nodiratime ${DRIVE}1 /mnt/boot/efi


# Base packages LTS kernel
# pacstrap /mnt base base-devel linux-lts linux-lts-headers linux-firmware archlinux-keyring man-db perl sysfsutils python python-pip git man-pages dropbear git nano neovim intel-ucode fzf duf reflector mtools ansible dosfstools btrfs-progs pacman-contrib nfs-utils --ignore linux vi openssh

# Base packages Liquorix Kernel
pacstrap /mnt base base-devel linux-lqx linux-lqx-headers linux-firmware archlinux-keyring man-db perl sysfsutils python python-pip git man-pages dropbear git nano neovim intel-ucode fzf duf reflector mtools dosfstools btrfs-progs pacman-contrib nfs-utils --ignore linux vi

# Generate fstab
genfstab -U /mnt >>/mnt/etc/fstab

##################################################################################################
##################################################################################################
##################################################################################################

# for dir in dev proc sys run; do
#    mount --rbind /$dir /mnt/$dir
#    mount --make-rslave /mnt/$dir
# done


ln -sf /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime
hwclock --systohc
sed -i '171s/.//' /etc/locale.gen
locale-gen
# echo "LANG=en_US.UTF-8" >>/etc/locale.conf
# echo "KEYMAP=us-intl" >>/etc/vconsole.conf
# echo "KEYMAP=mac-us" >>/etc/vconsole.conf
echo "vmachine" >>/etc/hostname
echo "127.0.0.1 localhost" >>/etc/hosts
echo "::1       localhost" >>/etc/hosts
echo "127.0.1.1 vmachine.localdomain vmachine" >>/etc/hosts
sh -c 'echo "root:200291" | chpasswd -c SHA512'
useradd juca -m -c "Reinaldo P JR" -s /bin/bash
sh -c 'echo "juca:200291" | chpasswd -c SHA512'


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

# Add Chaotic repo
pacman-key --init --noconfirm
#pacman-key --recv-key FBA220DFC880C036 --keyserver keyserver.ubuntu.com
#pacman-key --lsign-key FBA220DFC880C036
#pacman -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst' --noconfirm

# Add Liquorix
pacman-key --keyserver hkps://keyserver.ubuntu.com --recv-keys 9AE4078033F8024D
pacman-key --lsign-key 9AE4078033F8024D
pacman-key --populate --noconfirm

# Add Andontie Repo
#pacman-key --recv-key B545E9B7CD906FE3
#pacman-key --lsign-key B545E9B7CD906FE3

cat <<\EOF >>/etc/pacman.conf

# [chaotic-aur]
# Include = /etc/pacman.d/chaotic-mirrorlist

EOF

# sed -i -e '$a [andontie-aur]' /mnt/etc/pacman.conf
# sed -i -e '$a Server = https://aur.andontie.net/$arch' /mnt/etc/pacman.conf

pacman -Syu

mkdir -pv /media

cat <<EOF >>/etc/fstab

# TMP
# tmpfs /tmp tmpfs defaults,nosuid,nodev,noatime 0 0
tmpfs /tmp tmpfs noatime,mode=1777 0 0
EOF

pacman -Syyy
pacman -S efibootmgr grub chrony irqbalance htop networkmanager opendoas network-manager-applet dialog avahi xdg-user-dirs xdg-utils gvfs gvfs-smb nfs-utils inetutils dnsutils bluez bluez-utils pulseaudio-bluetooth pulseaudio-alsa pulseaudio-equalizer pulseaudio-jack alsa-utils bash-completion exfat-utils rsync firewalld flatpak sof-firmware nss-mdns os-prober ntfs-3g
# ananicy-cpp preload grub-btrfs

# Virt-manager & lxd
pacman -S lxd distrobuilder virt-manager virt-viewer qemu qemu-arch-extra bridge-utils dnsmasq vde2 ebtables openbsd-netcat vde2 edk2-ovmf iptables-nft ipset libguestfs

# apci & tlp
pacman -S acpi acpi_call-dkms acpid tlp

grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=Grub
sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet"/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=2 quiet apci_osi=Linux udev.log_level=0 acpi_backlight=video gpt acpi=force intel_pstate=active init_on_alloc=0 zswap.enabled=1 zswap.compressor=lz4hc zswap.max_pool_percent=10 zswap.zpool=z3fold mitigations=off nowatchdog msr.allow_writes=on pcie_aspm=force module.sig_unenforce intel_idle.max_cstate=1 cryptomgr.notests initcall_debug nvidia-drm.modeset=1 intel_iommu=on,igfx_off net.ifnames=0 no_timer_check noreplace-smp page_alloc.shuffle=1 rcupdate.rcu_expedited=1 tsc=reliable"/g' /etc/default/grub
sed -i 's/GRUB_COLOR_NORMAL="light-blue/black"/GRUB_COLOR_NORMAL="red/black"/g' /etc/default/grub
sed -i 's/#GRUB_COLOR_HIGHLIGHT="light-cyan/blue"/GRUB_COLOR_HIGHLIGHT="yellow/black"/g' /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg

systemctl enable NetworkManager
systemctl enable bluetooth
systemctl enable iwd
# systemctl enable dropbear
systemctl enable irqbalance
# systemctl enable preload
# systemctl enable ananicy-cpp
systemctl enable smbd
systemctl enable nmbd
systemctl enable chronyd
#systemctl enable cups.service
systemctl enable sshd
# systemctl enable dropbear
systemctl enable avahi-daemon
# You can comment this command out if you didn't install tlp, see above
systemctl enable tlp
systemctl enable reflector.timer
systemctl enable fstrim.timer
# OLDPC don`t need it
systemctl enable libvirtd
systemctl enable firewalld
systemctl enable acpid

echo "juca ALL=(ALL) ALL" >>/etc/sudoers.d/juca
#echo "junior ALL=(ALL) NOPASSWD: ALL" >>/mnt/etc/sudoers.d/junior

mkinitcpio -P linux-lqx

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
# preload
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
cat <<EOF >/etc/sysctl.d/00-sysctl.conf
vm.vfs_cache_pressure=500
vm.swappiness=100
vm.dirty_background_ratio=1
vm.dirty_ratio=50
dev.i915.perf_stream_paranoid=0
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
cat <<\EOF >/etc/modprobe.d/i915.conf
options i915 enable_guc=2 enable_dc=4 enable_hangcheck=0 error_capture=0 enable_dp_mst=0 fastboot=1
EOF

# MakeSwap
touch /swap/swapfile
chmod 600 /swap/swapfile
chattr +C /swap/swapfile
lsattr /swap/swapfile
dd if=/dev/zero of=/swap/swapfile bs=1M count=6144 status=progress
mkswap /swap/swapfile
swapon /swap/swapfile

# # Add to fstab
echo " " >> /etc/fstab
echo "# Swap" >> /etc/fstab
SWAP_UUID=$(blkid -s UUID -o value /dev/vda2)
mount -o defaults,noatime,subvol=@swap ${DRIVE}2 /mnt/swap
echo "UUID=$SWAP_UUID /swap btrfs defaults,noatime,subvol=@swap 0 0" >> /etc/fstab
echo "/swapfile      none     swap      sw  0 0" >> /etc/fstab

### Resume from Swap
mkdir -pv /tmp
cd /tmp
wget -c https://raw.githubusercontent.com/osandov/osandov-linux/master/scripts/btrfs_map_physical.c
gcc -O2 -o btrfs_map_physical btrfs_map_physical.c
./btrfs_map_physical /swap/swapfile >btrfs_map_physical.txt
filefrag -v /swap/swapfile | awk '$1=="0:" {print substr($4, 1, length($4)-2)}' >/tmp/resume.txt
set -e
RESUME_OFFSET=$(cat /tmp/resume.txt)
ROOT_UUID=$(blkid -s UUID -o value /dev/vda2)
export ROOT_UUID
export RESUME_OFFSET
sed -i 's/GRUB_CMDLINE_LINUX=""/GRUB_CMDLINE_LINUX="'"resume=UUID=$ROOT_UUID resume_offset=$RESUME_OFFSET"'"/g' /etc/default/grub

# Mkinitcpio
sed -i 's/MODULES=()/MODULES=(btrfs crc32c-intel)/g' /etc/mkinitcpio.conf
sed -i 's/HOOKS=(base udev autodetect modconf block filesystems keyboard fsck)/HOOKS=(base udev autodetect modconf block filesystems keyboard resume fsck btrfs)/g' /etc/mkinitcpio.conf
# sed -i 's/HOOKS=(base udev autodetect modconf block filesystems keyboard fsck)/HOOKS=(base udev autodetect modconf block filesystems keyboard resume fsck btrfs systemd)/g' /etc/mkinitcpio.conf
# sed -i 's/#COMPRESSION="xz"/COMPRESSION="xz"/g' /etc/mkinitcpio.conf

# Systemd-Boot
#bootctl --path=/boot install
#echo "default arch.conf" >>/boot/loader/loader.conf
#touch /mnt/boot/loader/entries/arch.conf

# cat <<EOF >/mnt/boot/loader/entries/arch.conf
# title   Arch Linux
# linux   /vmlinuz-linux-lqx
# initrd  /intel-ucode.img
# initrd  /initramfs-linux-lqx.img
# options root=/dev/sda2 rootflags=subvol=@ rw quiet loglevel=0 console=tty2 acpi_osi=Darwin acpi_mask_gpe=0x06 udev.log_level=0 mitigations=off nowatchdog msr.allow_writes=on pcie_aspm=force module.sig_unenforce intel_idle.max_cstate=1 cryptomgr.notests initcall_debug net.ifnames=0 no_timer_check noreplace-smp page_alloc.shuffle=1 rcupdate.rcu_expedited=1 tsc=reliable
# EOF
# options root=/dev/sda2 rootflags=subvol=@ rw quiet splash loglevel=3 mitigations=off nowatchdog msr.allow_writes=on pcie_aspm=force module.sig_unenforce  vt.global_cursor_default=0 intel_idle.max_cstate=1 zswap.enabled=1 zswap.compressor=zstd zswap.max_pool_percent=10 zswap.zpool=zsmalloc cryptomgr.notests initcall_debug intel_iommu=igfx_off net.ifnames=0 no_timer_check noreplace-smp page_alloc.shuffle=1 rcupdate.rcu_expedited=1 tsc=reliable

mkinitcpio -p linux-lqx

usermod -aG wheel,libvirt,storage juca

paccache -rk0

printf "\e[1;32mDone! Type exit, umount -a and reboot.\e[0m"
