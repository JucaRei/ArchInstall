#!/bin/bash

# Variables
DRIVE="/dev/sda"
SYSTEM_PART="${DRIVE}2"
EFI_PART="${DRIVE}3"
ROOT_PART="${DRIVE}4"
# HOME_PART="${DRIVE}p5"

# MAPPER_NAME="secure_btrfs"
MOUNTPOINT="/mnt"
ROOT_LABEL="Archlinux"
# HOME_LABEL="HOME_FILESYSTEM"
BIOS_LABEL="Bios_Boot"
SWAP_LABEL="SWAP"
EFI_LABEL="ESP"
SYSTEM_LABEL="System_Boot"
BTRFS_OPTS="noatime,nodatasum,nodatacow,ssd,compress-force=zstd:8,space_cache=v2,nodatacow,commit=120,discard=async"
BTRFS_OPTS_HOME="noatime,nodatasum,nodatacow,ssd,compress-force=zstd:15,space_cache=v2,nodatacow,commit=120,discard=async"

pacman -Sy archlinux-keyring --noconfirm

# Enable pacman Color
sed -i '1n; /^#UseSyslog/i ILoveCandy' /etc/pacman.conf
sed -i '/Color/s/^#//' /etc/pacman.conf
sed -i '3n; /^#UseSyslog/i DisableDownloadTimeout' /etc/pacman.conf
sed -i 's/#ParallelDownloads = 5/ParallelDownloads = 4/g' /etc/pacman.conf

pacman -Syyy

# =======================================================================================================================================================
# Create Partitions and Encrypt
### Partition
echo "Creating partitions on $DRIVE..."
sgdisk --zap-all $DRIVE
sgdisk -n 0:0:+1M      -t 1:EF02 -c 1:"${BIOS_LABEL} Filesystem"                           $DRIVE
sgdisk -n 0:0:+1G      -t 2:8301 -c 2:"${SYSTEM_LABEL} Filesystem"                         $DRIVE
sgdisk -n 0:0:+600M    -t 3:EF00 -c 3:"${EFI_LABEL} Filesystem"                            $DRIVE
sgdisk -n 0:0:0        -t 4:8300 -c 4:"${ROOT_LABEL} Root Filesystem"                      $DRIVE
# sgdisk -n 0:0:+70G     -t 5:8302 -c 5:"${HOME_LABEL} Home Filesystem"                    $DRIVE
sgdisk -p ${DRIVE}

echo "Formatting partitions on $DRIVE..."
echo "🧼 Formatting partitions..."

mkfs.ext4   -L      	  "$SYSTEM_LABEL"      "$SYSTEM_PART"
mkfs.fat   -F32 -n      "$EFI_LABEL"         "$EFI_PART"
mkfs.btrfs -f   -L      "$ROOT_LABEL"        "$ROOT_PART"
# mkfs.btrfs -f   -L    "$HOME_LABEL"        "$HOME_PART"

udevadm trigger
echo "Partitions formatted successfully on $DRIVE."
# =======================================================================================================================================================

echo "Creating Btrfs subvolumes..."
mount "$ROOT_PART" "$MOUNTPOINT"
# for sv in @root @cache @opt @gdm @libvirt @spool @log @tmp @snapshots @nix; do
#   btrfs subvolume create "$MOUNTPOINT/$sv"
# done

for sv in @root @cache @pacman @opt @gdm @libvirt @spool @log @tmp @snapshots @nix @home; do
   btrfs subvolume create "$MOUNTPOINT/$sv"
done
umount -Rvf "$MOUNTPOINT"

# 🏠 Create @home subvolume on home partition
# mkdir -p "$MOUNTPOINT"/home-temp
# mount /dev/disk/by-label/"$HOME_LABEL" "$MOUNTPOINT"/home-temp
# btrfs subvolume create "$MOUNTPOINT"/home-temp/@home
# umount -Rvf "$MOUNTPOINT"/home-temp
echo "Btrfs subvolumes created successfully."

echo "Mounting subvolumes and boot partition..."
### Mount subvolumes
mount -o $BTRFS_OPTS,subvol=@root /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT
mkdir -pv $MOUNTPOINT/{boot,home,opt,nix,.snapshots,var/{tmp,spool,log,cache,lib/{pacman,libvirt,gdm}}}

# mount -o $BTRFS_OPTS_HOME,subvol=@home /dev/disk/by-label/$HOME_LABEL $MOUNTPOINT/home
mount -o $BTRFS_OPTS,subvol=@home /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/home
mount -o $BTRFS_OPTS_HOME,subvol=@nix /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/nix
mount -o $BTRFS_OPTS_HOME,subvol=@opt /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/opt
mount -o $BTRFS_OPTS,subvol=@gdm /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/var/lib/gdm
mount -o $BTRFS_OPTS_HOME,subvol=@libvirt /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/var/lib/libvirt
mount -o $BTRFS_OPTS_HOME,subvol=@pacman /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/var/lib/pacman
mount -o $BTRFS_OPTS,subvol=@log /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/var/log
mount -o $BTRFS_OPTS,subvol=@spool /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/var/spool
mount -o $BTRFS_OPTS,subvol=@tmp /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/var/tmp
mount -o $BTRFS_OPTS,subvol=@cache /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/var/cache
mount -o $BTRFS_OPTS_HOME,subvol=@snapshots /dev/disk/by-label/$ROOT_LABEL $MOUNTPOINT/.snapshots
mount "/dev/disk/by-label/${SYSTEM_LABEL}" "$MOUNTPOINT/boot"
# mount /dev/disk/by-label/BOOT /mnt/boot
mkdir -pv $MOUNTPOINT/boot/efi
mount -t vfat -o defaults,noatime,nodiratime /dev/disk/by-label/$EFI_LABEL $MOUNTPOINT/boot/efi
echo "Subvolumes and boot partition mounted successfully."
# =======================================================================================================================================================

# pacstrap /mnt linux base base-devel sof-firmware networkmanager archlinux-keyring sysfsutils git zsh neovim duf mtools dosfstools btrfs-progs pacman-contrib efibootmgr grub --ignore linux  linux-firmware-nvidia linux-firmware-atheros linux-firmware-radeon linux-firmware-broadcom linux-firmware-amdgpu linux-firmware-amdgpu vi --noconfirm

# Base packages LTS kernel
pacstrap /mnt base linux-zen linux-zen-headers linux-firmware sof-firmware archlinux-keyring sysfsutils git zsh neovim duf reflector mtools dosfstools \
   btrfs-progs pacman-contrib --ignore linux linux-firmware-nvidia linux-firmware-atheros linux-firmware-radeon linux-firmware-broadcom linux-firmware-amdgpu linux-firmware-amdgpu vi --noconfirm
# base-devel

# Generate fstab
# genfstab -U /mnt >>/mnt/etc/fstab

BOOT_UUID=$(blkid -s UUID -o value $SYSTEM_PART)
ESP_UUID=$(blkid -s UUID -o value $EFI_PART)
ROOT_UUID=$(blkid -s UUID -o value $ROOT_PART)
HOME_UUID=$(blkid -s UUID -o value $HOME_PART)

touch /mnt/etc/fstab
cat <<EOF >/mnt/etc/fstab
# <file system>           <dir>               <type>    <options>                               <dump> <pass>

### ROOTFS ###
# UUID="${ROOT_UUID}"     /                   btrfs     rw,$BTRFS_OPTS,subvol=@root                0     0
LABEL="${ROOT_LABEL}"     /                   btrfs     rw,$BTRFS_OPTS,subvol=@root                0     0

# UUID="${ROOT_UUID}"     /.snapshots         btrfs     rw,$BTRFS_OPTS,subvol=@snapshots           0     0
LABEL="${ROOT_LABEL}"     /.snapshots         btrfs     rw,$BTRFS_OPTS,subvol=@snapshots           0     0

# UUID="${ROOT_UUID}"     /nix                btrfs     rw,$BTRFS_OPTS_HOME,subvol=@nix            0     0
LABEL="${ROOT_LABEL}"     /nix                btrfs     rw,$BTRFS_OPTS_HOME,subvol=@nix            0     0

# UUID="${ROOT_UUID}"     /var/log            btrfs     rw,$BTRFS_OPTS,subvol=@log                 0     0
LABEL="${ROOT_LABEL}"     /var/log            btrfs     rw,$BTRFS_OPTS,subvol=@log                 0     0

# UUID="${ROOT_UUID}"     /var/tmp            btrfs     rw,$BTRFS_OPTS,subvol=@tmp                 0     0
LABEL="${ROOT_LABEL}"     /var/tmp            btrfs     rw,$BTRFS_OPTS,subvol=@tmp                 0     0

# UUID="${ROOT_UUID}"     /var/spool          btrfs     rw,$BTRFS_OPTS,subvol=@spool               0     0
LABEL="${ROOT_LABEL}"     /var/spool          btrfs     rw,$BTRFS_OPTS,subvol=@spool               0     0

# UUID="${ROOT_UUID}"     /var/cache          btrfs     rw,$BTRFS_OPTS,subvol=@cache               0     0
LABEL="${ROOT_LABEL}"     /var/cache          btrfs     rw,$BTRFS_OPTS,subvol=@cache               0     0

# UUID="${ROOT_UUID}"     /var/lib/pacman     btrfs     rw,$BTRFS_OPTS_HOME,subvol=@pacman         0     0
LABEL="${ROOT_LABEL}"     /var/lib/pacman     btrfs     rw,$BTRFS_OPTS_HOME,subvol=@pacman         0     0

# UUID="${ROOT_UUID}"     /var/lib/libvirt    btrfs     rw,$BTRFS_OPTS,subvol=@libvirt             0     0
LABEL="${ROOT_LABEL}"     /var/lib/libvirt    btrfs     rw,$BTRFS_OPTS,subvol=@libvirt             0     0

# UUID="${ROOT_UUID}"     /var/lib/gdm        btrfs     rw,$BTRFS_OPTS,subvol=@gdm                 0     0
LABEL="${ROOT_LABEL}"     /var/lib/gdm        btrfs     rw,$BTRFS_OPTS,subvol=@gdm                 0     0

# UUID="${ROOT_UUID}"     /opt                btrfs     rw,$BTRFS_OPTS,subvol=@opt                 0     0
LABEL="${ROOT_LABEL}"     /opt                btrfs     rw,$BTRFS_OPTS,subvol=@opt                 0     0

### HOME_FS ###
# UUID="${ROOT_UUID}"     /home               btrfs     rw,$BTRFS_OPTS_HOME,subvol=@home           0     0
LABEL="${ROOT_LABEL}"     /home               btrfs     rw,$BTRFS_OPTS_HOME,subvol=@home           0     0

### BOOT ###
# UUID="${BOOT_UUID}"     /boot               ext4      rw,relatime                                0     1
LABEL="${SYSTEM_LABEL}"   /boot               ext4      rw,relatime                                0     1

### EFI ###
# UUID="${ESP_UUID}"      /boot/efi           vfat      defaults,noatime,nodiratime                0     2
LABEL="${EFI_LABEL}"      /boot/efi           vfat      defaults,noatime,nodiratime                0     2

### Swap ###
# UUID="${SWAP_UUID}"     none                swap      defaults,noatime                           0     0
# LABEL="${SWAP_LABEL}"   none                swap      defaults,noatime                           0     0

#Swapfile
# LABEL="${ROOT_UUID}"    none                swap      defaults,noatime
# /swap/swapfile          none                swap      sw                                         0     0

### Tmp ###
# tmpfs                   /tmp                tmpfs     defaults,nosuid,nodev,noatime              0     0
# tmpfs                   /tmp                tmpfs     noatime,mode=1777,nosuid,nodev             0     0
EOF

##################################################################################################
##################################################################################################
##################################################################################################

hostname="hyprtest"
username="juca"

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
echo "$hostname" >>/etc/hostname
echo "127.0.0.1 localhost" >>/etc/hosts
echo "::1       localhost" >>/etc/hosts
echo "127.0.1.1 $hostname.localdomain $hostname" >>/etc/hosts
sh -c 'echo "root:200291" | chpasswd -c SHA512'
useradd juca -m -c "Reinaldo P JR" -s /bin/bash
sh -c 'echo "juca:200291" | chpasswd -c SHA512'


# Enable pacman Color
sed -i '1n; /^#UseSyslog/i ILoveCandy' /etc/pacman.conf
sed -i '3n; /^#UseSyslog/i DisableDownloadTimeout' /etc/pacman.conf
sed -i '/Color/s/^#//' /etc/pacman.conf
sed -i 's/#ParallelDownloads = 5/ParallelDownloads = 5/g' /etc/pacman.conf

# Enable multilib repo
sed -i "/\[multilib\]/,/Include/"'s/^#//' /etc/pacman.conf
sed -i "/\[lib32\]/,/Include/"'s/^#//' /etc/pacman.conf

# Setting package signing option to require signature
sed -i '/\[core\]/a SigLevel\ =\ PackageRequired' /etc/pacman.conf
sed -i '/\[multilib\]/a SigLevel\ =\ PackageRequired' /etc/pacman.conf
sed -i '/\[community\]/a SigLevel\ =\ PackageRequired' /etc/pacman.conf
sed -i '/\[extra\]/a SigLevel\ =\ PackageRequired' /etc/pacman.conf

# Add Chaotic repo
pacman-key --init
pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com
pacman-key --lsign-key 3056513887B78AEB
pacman -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'

# Add Liquorix
# pacman-key --keyserver hkps://keyserver.ubuntu.com --recv-keys 9AE4078033F8024D
# pacman-key --lsign-key 9AE4078033F8024D
# pacman-key --populate

cat <<EOF >>/etc/pacman.conf

[chaotic-aur]
Include = /etc/pacman.d/chaotic-mirrorlist
EOF

# sed -i -e '$a [andontie-aur]' /mnt/etc/pacman.conf
# sed -i -e '$a Server = https://aur.andontie.net/$arch' /mnt/etc/pacman.conf

pacman -Syu

mkdir -pv /media

pacman -Syyy

touch /etc/modules-load.d/zram.conf
cat <<EOF >/etc/modules-load.d/zram.conf
zram
EOF
touch /etc/udev/rules.d/99-zram.rules
cat <<EOF >/etc/udev/rules.d/99-zram.rules
ACTION=="add", KERNEL=="zram0", ATTR{initstate}=="0", ATTR{comp_algorithm}="zstd", ATTR{disksize}="4G", TAG+="systemd"
EOF

cat <<EOF >> /etc/fstab

/dev/zram0 none swap defaults,discard,pri=100,x-systemd.makefs 0 0
EOF

cat <<EOF >/etc/sysctl.d/99-vm-zram-parameters.conf
vm.swappiness = 180
vm.watermark_boost_factor = 0
vm.watermark_scale_factor = 125
vm.page-cluster = 0
EOF

mkdir -p /etc/systemd/zram-generator.d
touch /etc/systemd/zram-generator.d/zram.conf
cat <<EOF >/etc/systemd/zram-generator.d/zram.conf
[zram0]
# zram-size = ram / 2
zram-size = ram 
compression-algorithm = lz4
EOF

pacman -S zram-generator

# Boot loader
pacman -S efibootmgr grub os-prober --noconfirm

# Network & Utilities
# pacman -S networkmanager network-manager-applet dialog wireless_tools avahi gvfs gvfs-smb gvfs-wsdd inetutils dnsutils reflector
pacman -S openssh networkmanager-iwd wireless_tools avahi gvfs gvfs-smb gvfs-wsdd inetutils dnsutils reflector nss-mdns --noconfirm

# Bluetooth
# pacman -S bluez bluez-utils bluez-tools --noconfirm

# Supervisor doas
# pacman -S doas --noconfirm

# Tools and Utilities
pacman -S base-devel tar pam_mount chrony irqbalance ananicy-cpp preload htop dialog xdg-user-dirs xdg-utils bash-completion ntfs-3g --noconfirm

# Flatpak and nix
pacman -S flatpak nix --noconfirm

#  grub-btrfs

# Virt-manager & lxd
# pacman -S lxd distrobuilder virt-manager virt-viewer qemu bridge-utils dnsmasq vde2 ebtables openbsd-netcat vde2 edk2-ovmf iptables-nft ipset libguestfs

# apci & tlp
# pacman -S acpi acpi_call-dkms acpid tlp

grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=Archlinux --recheck
# sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet"/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=2 quiet apci_osi=Linux udev.log_level=0 acpi_backlight=video gpt acpi=force intel_pstate=active init_on_alloc=0 zswap.enabled=1 zswap.compressor=lz4hc zswap.max_pool_percent=10 zswap.zpool=z3fold mitigations=off nowatchdog msr.allow_writes=on pcie_aspm=force module.sig_unenforce intel_idle.max_cstate=1 cryptomgr.notests initcall_debug nvidia-drm.modeset=1 intel_iommu=on,igfx_off net.ifnames=0 no_timer_check noreplace-smp page_alloc.shuffle=1 rcupdate.rcu_expedited=1 tsc=reliable"/g' /etc/default/grub
sed -i 's/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=3 quiet"/GRUB_CMDLINE_LINUX_DEFAULT="loglevel=2 quiet apci_osi=Linux udev.log_level=0 acpi_backlight=video gpt acpi=force zswap.enabled=0 init_on_alloc=0 mitigations=off nowatchdog msr.allow_writes=on pcie_aspm=force module.sig_unenforce intel_idle.max_cstate=1 cryptomgr.notests initcall_debug intel_iommu=on,igfx_off net.ifnames=0 no_timer_check noreplace-smp page_alloc.shuffle=1 rcupdate.rcu_expedited=1 tsc=reliable"/g' /etc/default/grub
sed -i 's/GRUB_COLOR_NORMAL="light-blue/black"/GRUB_COLOR_NORMAL="red/black"/g' /etc/default/grub
sed -i 's/#GRUB_COLOR_HIGHLIGHT="light-cyan/blue"/GRUB_COLOR_HIGHLIGHT="yellow/black"/g' /etc/default/grub
grub-mkconfig -o /boot/grub/grub.cfg

systemctl enable NetworkManager
systemctl enable sshd
# systemctl enable bluetooth
# systemctl enable iwd
# systemctl enable dropbear
systemctl enable irqbalance
systemctl enable preload
systemctl enable ananicy-cpp
# systemctl enable smbd
# systemctl enable nmbd
systemctl enable chronyd
#systemctl enable cups.service
systemctl enable sshd
# systemctl enable dropbear
systemctl enable avahi-daemon
# You can comment this command out if you didn't install tlp, see above
# systemctl enable tlp
systemctl enable reflector.timer
systemctl enable fstrim.timer
# OLDPC don`t need it
# systemctl enable libvirtd
systemctl enable firewalld
# systemctl enable acpid

echo "juca ALL=(ALL) ALL" >>/etc/sudoers.d/juca
#echo "junior ALL=(ALL) NOPASSWD: ALL" >>/mnt/etc/sudoers.d/junior

# mkinitcpio -P linux-lqx

touch /etc/rc.local
# cat <<EOF >/etc/rc.local
# # PowerTop
# powertop --auto-tune

# # echo 60000 > /sys/bus/usb/devices/2-1.5/power/autosuspend_delay_ms
# # echo 60000 > /sys/bus/usb/devices/2-1.6/power/autosuspend_delay_ms
# # echo 60000 > /sys/bus/usb/devices/3-1.5/power/autosuspend_delay_ms
# # echo 60000 > /sys/bus/usb/devices/3-1.6/power/autosuspend_delay_ms
# # echo 60000 > /sys/bus/usb/devices/4-1.5/power/autosuspend_delay_ms
# # echo 60000 > /sys/bus/usb/devices/4-1.6/power/autosuspend_delay_ms

# # Preload
# # preload
# EOF

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
cat <<EOF >/etc/udev/rules.d/99-udisks2.rules
# UDISKS_FILESYSTEM_SHARED
# ==1: mount filesystem to a shared directory (/media/VolumeName)
# ==0: mount filesystem to a private directory (/run/media/$username/VolumeName)
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

# usermod -aG storage $USER

# Doas Set user permition
# cat <<EOF >/etc/doas.conf
# # allow user but require password
# permit keepenv :$username

# # allow user and dont require a password to execute commands as root
# # permit nopass keepenv :$username

# # mount drives
# permit nopass :$username cmd mount
# permit nopass :$username cmd umount

# # musicpd service start and stop
# #permit nopass :$username cmd service args musicpd onestart
# #permit nopass :$username cmd service args musicpd onestop

# # pkg update
# #permit nopass :$username cmd vpm args update

# # run personal scripts as root without prompting for a password,
# # requires entering the full path when running with doas
# #permit nopass :$username cmd /home/username/bin/somescript

# # root as root
# #permit nopass keepenv root as root
# EOF

# chown -c root:root /etc/doas.conf

sed -i '1n; /^# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/i %wheel ALL=(ALL:ALL) ALL' /etc/sudoers

touch /etc/modprobe.d/i915.conf
# cat <<EOF >/etc/modprobe.d/i915.conf
# options i915 enable_guc=2 enable_dc=4 enable_hangcheck=0 error_capture=0 enable_dp_mst=0 fastboot=1
# EOF

# ZRAM

# cat <<EOF > /etc/modules-load.d/zram.conf
# zram
# EOF

# cat << EOF > /etc/udev/rules.d/99-zram.rules
# ACTION=="add", KERNEL=="zram0", ATTR{comp_algorithm}="zstd", ATTR{disksize}="3G", RUN="/usr/bin/mkswap -U clear /dev/%k", TAG+="systemd"
# EOF

# cat <<EOF >> /etc/fstab
# /dev/zram0 none swap defaults,pri=100 0 0
# EOF

# cat <<EOF > /etc/sysctl.d/99-vm-zram-parameters.conf
# vm.swappiness = 180
# vm.watermark_boost_factor = 0
# vm.watermark_scale_factor = 125
# vm.page-cluster = 0
# EOF

# MakeSwap
# touch /swap/swapfile
# chmod 600 /swap/swapfile
# chattr +C /swap/swapfile
# lsattr /swap/swapfile
# dd if=/dev/zero of=/swap/swapfile bs=1M count=6144 status=progress
# mkswap /swap/swapfile
# swapon /swap/swapfile

# # Add to fstab
# echo " " >> /etc/fstab
# echo "# Swap" >> /etc/fstab
# SWAP_UUID=$(blkid -s UUID -o value /dev/vda2)
# mount -o defaults,noatime,subvol=@swap ${DRIVE}2 /mnt/swap
# echo "UUID=$SWAP_UUID /swap btrfs defaults,noatime,subvol=@swap 0 0" >> /etc/fstab
# echo "/swapfile      none     swap      sw  0 0" >> /etc/fstab

### Resume from Swap
# mkdir -pv /tmp
# cd /tmp
# wget -c https://raw.githubusercontent.com/osandov/osandov-linux/master/scripts/btrfs_map_physical.c
# gcc -O2 -o btrfs_map_physical btrfs_map_physical.c
# ./btrfs_map_physical /swap/swapfile >btrfs_map_physical.txt
# filefrag -v /swap/swapfile | awk '$1=="0:" {print substr($4, 1, length($4)-2)}' >/tmp/resume.txt
# set -e
# RESUME_OFFSET=$(cat /tmp/resume.txt)
# ROOT_UUID=$(blkid -s UUID -o value /dev/vda2)
# export ROOT_UUID
# export RESUME_OFFSET
# sed -i 's/GRUB_CMDLINE_LINUX=""/GRUB_CMDLINE_LINUX="'"resume=UUID=$ROOT_UUID resume_offset=$RESUME_OFFSET"'"/g' /etc/default/grub

# Mkinitcpio
sed -i 's/MODULES=()/MODULES=(btrfs)/g' /etc/mkinitcpio.conf
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

mkinitcpio -p linux-zen

# usermod -aG wheel,libvirt,storage $username
usermod -aG wheel,storage $username

paccache -rk0

printf "\e[1;32mDone! Type exit, umount -a and reboot.\e[0m"


# sudo pacman -S mesa libva-intel-driver libva-utils vulkan-intel # i965
# sudo pacman -S mesa libva-mesa-driver libva-utils vulkan-intel # iris

sudo pacman -S xorg-server xorg-apps xorg-xinit
sudo pacman -S plasma-meta kde-applications-meta
sudo pacman -S breeze-gtk kde-gtk-config
sudo pacman -S plasma-wayland-protocols
sudo pacman -S sddm
sudo systemctl enable sddm