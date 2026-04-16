#!/usr/bin/env bash
set -euo pipefail

dnf install gdisk arch-install-scripts -y

########################################
# CONFIG
########################################

# Detect drive (VMs often use /dev/vda, physical uses /dev/sda)
if [ -b /dev/vda ]; then
    DRIVE="/dev/vda"
else
    DRIVE="/dev/sda"
fi

MNT="/mnt"
FEDORA_VER="43"
username="juca"
hostname="fedoravm"
userpass="200291"

BOOT_PART="${DRIVE}1" # Partição /boot (ext4)
EFI_PART="${DRIVE}2"  # Partição EFI (FAT32)
HOME_PART="${DRIVE}3" # Partição home (Btrfs com subvolumes)
ROOT_PART="${DRIVE}4" # Partição root (Btrfs com subvolumes)
# SWAP_PART="${DRIVE}5" # Partição de swap

# Rótulos para as partições (usados no fstab para montagem por label)
BOOT_LABEL="BOOT"
HOME_LABEL="Home"
ROOT_LABEL="Linux"
EFI_LABEL="ESP"
# SWAP_LABEL="Swap"

# BTRFS Mount Options
BTRFS_OPTS="noatime,ssd,compress-force=zstd:8,space_cache=v2,commit=120,discard=async"
BTRFS_OPTS2="noatime,ssd,compress-force=zstd:3,space_cache=v2,commit=120,discard=async"
NIX_OPTS="noatime,ssd,compress=zstd:22,space_cache=v2,commit=120,discard=async"
BTRFS_OPTS_HOME="noatime,ssd,compress=zstd:10,space_cache=v2,commit=60,discard=async"

########################################
# PARTITIONING
########################################


# Disable swap if already active
# if [ -b /dev/disk/by-label/"${SWAP_LABEL}" ]; then
#     swapoff /dev/disk/by-label/"${SWAP_LABEL}"
# fi

umount -Rvf "${DRIVE}" || true
sleep 2
umount -Rvf "${MNT}" || true
sleep 2
sgdisk --zap-all "${DRIVE}"
sleep 2
parted -s -a optimal "${DRIVE}" mklabel gpt
sgdisk -n 1:0:+1G   -t 1:8301 -c 1:"SYSTEM_RESERVED"      "${DRIVE}"  # Partição /boot (1G, ext4)
sgdisk -n 2:0:+600M -t 2:EF00 -c 2:"EFI_SYSTEM"           "${DRIVE}"  # Partição EFI (600M, FAT32)
sgdisk -n 3:0:40G   -t 3:8302 -c 3:"HOME_DATA"            "${DRIVE}"  # Partição home (40G)
sgdisk -n 4:0:-5G   -t 4:8300 -c 4:"ROOT_SYSTEM"          "${DRIVE}"  # Partição root
# sgdisk -n 5:0:0     -t 5:8200 -c 5:"SWAP_FILESYSTEM"      "${DRIVE}"  # Partição de swap
sgdisk -p "${DRIVE}"


########################################
# FORMAT
########################################

echo "🧼 Formatting partitions..."
mkfs.ext4  -F    -L  "${BOOT_LABEL}" "${BOOT_PART}"
mkfs.fat   -F32  -n  "${EFI_LABEL}"  "${EFI_PART}"
mkfs.btrfs -f    -L  "${HOME_LABEL}" "${HOME_PART}"
mkfs.btrfs -f    -L  "${ROOT_LABEL}" "${ROOT_PART}"
# mkswap     -L        "${SWAP_LABEL}" "${SWAP_PART}"
# swapon               "${SWAP_PART}"

# Wait for udev to create /dev/disk/by-label/* symlinks
udevadm settle
sleep 2

# Detect UUIDs after formatting
BOOT_UUID=$(blkid -s UUID -o value $BOOT_PART)
EFI_UUID=$(blkid -s UUID -o value $EFI_PART)
HOME_UUID=$(blkid -s UUID -o value $HOME_PART)
ROOT_UUID=$(blkid -s UUID -o value $ROOT_PART)
# SWAP_UUID=$(blkid -s UUID -o value $SWAP_PART)

########################################
# MOUNT STRUCTURE
########################################

# Verify labels are detected
echo "🔍 Verifying partition labels..."
ls -la /dev/disk/by-label/

echo "🎯 Creating btrfs subvolumes..."
mkdir -pv "${MNT}"
mount "${ROOT_PART}" "${MNT}"
for sv in @ @opt @nix @gdm @libvirt @spool @log @tmp @cache @snapshots; do
  btrfs subvolume create "$MNT/$sv"
done
umount -Rvf "${MNT}"

# 🏠 Create @home subvolume on home partition
mkdir -pv "$MNT/home-temp"
mount "$HOME_PART" "$MNT/home-temp"
btrfs subvolume create "$MNT/home-temp/@home"
umount "$MNT/home-temp"

echo "📦 Mounting subvolumes..."
mount -o $BTRFS_OPTS2,subvol=@ /dev/disk/by-label/"$ROOT_LABEL" "$MNT"
mkdir -pv "$MNT"/{boot,home,opt,nix,.snapshots,var/{tmp,spool,log,cache/apt,lib/{gdm,libvirt}}}

mount -o $BTRFS_OPTS_HOME,subvol=@home            /dev/disk/by-label/"$HOME_LABEL" "$MNT/home"
mount -o $BTRFS_OPTS,subvol=@opt            /dev/disk/by-label/"$ROOT_LABEL" "$MNT/opt"
mount -o $BTRFS_OPTS,subvol=@gdm            /dev/disk/by-label/"$ROOT_LABEL" "$MNT/var/lib/gdm"
mount -o $BTRFS_OPTS,subvol=@libvirt        /dev/disk/by-label/"$ROOT_LABEL" "$MNT/var/lib/libvirt"
mount -o $BTRFS_OPTS2,subvol=@log            /dev/disk/by-label/"$ROOT_LABEL" "$MNT/var/log"
mount -o $NIX_OPTS,subvol=@nix              /dev/disk/by-label/"$ROOT_LABEL" "$MNT/nix"
mount -o $BTRFS_OPTS,subvol=@spool          /dev/disk/by-label/"$ROOT_LABEL" "$MNT/var/spool"
mount -o $BTRFS_OPTS2,subvol=@tmp            /dev/disk/by-label/"$ROOT_LABEL" "$MNT/var/tmp"
mount -o $BTRFS_OPTS,subvol=@cache          /dev/disk/by-label/"$ROOT_LABEL" "$MNT/var/cache"
mount -o $BTRFS_OPTS,subvol=@snapshots      /dev/disk/by-label/"$ROOT_LABEL" "$MNT/.snapshots"

echo "⏏️ Mounting boot and EFI..."
mount /dev/disk/by-label/"$BOOT_LABEL" "$MNT/boot"
sleep 2
mkdir -pv "$MNT/boot/efi"
mount -t vfat -o defaults,noatime,nodiratime /dev/disk/by-label/"$EFI_LABEL" "$MNT/boot/efi"

########################################
# PREP CHROOT
########################################

udevadm trigger
export MNT=/mnt

mkdir -p $MNT/dev $MNT/dev/pts $MNT/proc $MNT/sys $MNT/run $MNT/sys/firmware/efi/efivars

for i in dev dev/pts proc sys run; do
    mount --rbind /$i $MNT/$i
    mount --make-rslave $MNT/$i
done

mount -t efivarfs efivarfs $MNT/sys/firmware/efi/efivars

########################################
# BASE SYSTEM INSTALL
########################################

dnf --installroot=$MNT \
    --releasever=${FEDORA_VER} \
    --setopt=install_weak_deps=False \
    --use-host-config \
    install @core -y

dnf --installroot=$MNT \
    --releasever=${FEDORA_VER} \
    --setopt=install_weak_deps=False \
    install \
    kernel \
    grub2-efi-x64 \
    grub2-efi-x64-modules \
    shim \
    efibootmgr \
    NetworkManager \
    selinux-policy-targeted \
    zram-generator-defaults \
    firewalld \
    openssh-server \
    neovim \
    btrfs-progs \
    tar \
    rsync \
    glibc-langpack-en \
    curl -y

########################################
# FSTAB
########################################

touch $MNT/etc/fstab
cat <<EOF > $MNT/etc/fstab
# <file system>           <dir>               <type>    <options>                               <dump> <pass>
### ROOTFS ###
# UUID=${ROOT_UUID}       /                   btrfs     rw,$BTRFS_OPTS,subvol=@                    0     0
LABEL=${ROOT_LABEL}       /                   btrfs     rw,$BTRFS_OPTS,subvol=@                    0     0

# UUID=${ROOT_UUID}       /.snapshots         btrfs     rw,$BTRFS_OPTS,subvol=@snapshots           0     0
LABEL=${ROOT_LABEL}       /.snapshots         btrfs     rw,$BTRFS_OPTS,subvol=@snapshots           0     0

# UUID=${ROOT_UUID}       /nix                btrfs     rw,$NIX_OPTS,subvol=@nix                   0     0
LABEL=${ROOT_LABEL}       /nix                btrfs     rw,$NIX_OPTS,subvol=@nix                   0     0

# UUID=${ROOT_UUID}       /var/log            btrfs     rw,$BTRFS_OPTS2,subvol=@log                0     0
LABEL=${ROOT_LABEL}       /var/log            btrfs     rw,$BTRFS_OPTS2,subvol=@log                0     0

# UUID=${ROOT_UUID}       /var/tmp            btrfs     rw,$BTRFS_OPTS2,subvol=@tmp                0     0
LABEL=${ROOT_LABEL}       /var/tmp            btrfs     rw,$BTRFS_OPTS2,subvol=@tmp                0     0

# UUID=${ROOT_UUID}       /var/spool          btrfs     rw,$BTRFS_OPTS,subvol=@spool               0     0
LABEL=${ROOT_LABEL}       /var/spool          btrfs     rw,$BTRFS_OPTS,subvol=@spool               0     0

# UUID=${ROOT_UUID}       /var/cache          btrfs     rw,$BTRFS_OPTS,subvol=@cache               0     0
LABEL=${ROOT_LABEL}       /var/cache          btrfs     rw,$BTRFS_OPTS,subvol=@cache               0     0

# UUID=${ROOT_UUID}       /var/lib/libvirt    btrfs     rw,$BTRFS_OPTS,subvol=@libvirt             0     0
LABEL=${ROOT_LABEL}       /var/lib/libvirt    btrfs     rw,$BTRFS_OPTS,subvol=@libvirt             0     0

# UUID=${ROOT_UUID}       /var/lib/gdm        btrfs     rw,$BTRFS_OPTS,subvol=@gdm                 0     0
LABEL=${ROOT_LABEL}       /var/lib/gdm        btrfs     rw,$BTRFS_OPTS,subvol=@gdm                 0     0

# UUID=${ROOT_UUID}       /opt                btrfs     rw,$BTRFS_OPTS,subvol=@opt                 0     0
LABEL=${ROOT_LABEL}       /opt                btrfs     rw,$BTRFS_OPTS,subvol=@opt                 0     0

### HOME_FS ###
# UUID=${HOME_UUID}       /home               btrfs     rw,$BTRFS_OPTS_HOME,subvol=@home           0     0
LABEL=${HOME_LABEL}       /home               btrfs     rw,$BTRFS_OPTS_HOME,subvol=@home           0     0

### BOOT ###
# UUID=${BOOT_UUID}       /boot               ext4      rw,relatime                                0     1
LABEL=${BOOT_LABEL}       /boot               ext4      rw,relatime                                0     1

### EFI ###
# UUID=${EFI_UUID}        /boot/efi           vfat      defaults,noatime,nodiratime,umask=0077     0     2
LABEL=${EFI_LABEL}        /boot/efi           vfat      defaults,noatime,nodiratime,umask=0077     0     2

### Swap ###
# UUID=                   none                swap      defaults,noatime                           0     0
# LABEL=                  none                swap      defaults,noatime                           0     0

#Swapfile
# LABEL=${ROOT_LABEL}     none                swap      defaults,noatime
# UUID=${ROOT_UUID}       none                swap      defaults,noatime
# /swap/swapfile          none                swap      sw                                         0     0
EOF

########################################
# RPM FUSION (Broadcom WiFi)
########################################

chroot $MNT dnf install -y \
    https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-${FEDORA_VER}.noarch.rpm \
    https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${FEDORA_VER}.noarch.rpm

########################################
# Dracut Modules
########################################
mkdir -pv $MNT/etc/dracut.conf.d
touch $MNT/etc/dracut.conf.d/default.conf
cat <<EOF > $MNT/etc/dracut.conf.d/default.conf
hostonly="yes"
hostonly_cmdline="yes"

# Força initramfs no /boot padrão (não em /boot/efi/MACHINE-ID)
uefi="no"  # evita paths EFI errados se usa GRUB

# kernel_cmdline=" rootflags=subvol=@ rw quiet "

# Fast compression
compress="zstd"
compressargs="-19"

# Avoid useless modules
omit_dracutmodules+=" brltty "
EOF

touch /mnt/etc/dracut.conf.d/resume.conf
cat <<EOF >/mnt/etc/dracut.conf.d/resume.conf
# resume_offset="0"   # se usar swap em arquivo
EOF

touch $MNT/etc/dracut.conf.d/systemd.conf
cat <<EOF > $MNT/etc/dracut.conf.d/systemd.conf
add_dracutmodules+=" systemd "
EOF

touch $MNT/etc/dracut.conf.d/quiet.conf
cat <<EOF > $MNT/etc/dracut.conf.d/quiet.conf
omit_dracutmodules+=" crypt tpm2-tss systemd-pcrphase "
# se não usa LUKS, silencia warnings
EOF

touch $MNT/etc/dracut.conf.d/selinux.conf
cat <<EOF > $MNT/etc/dracut.conf.d/selinux.conf
# add_dracutmodules+=" selinux "
EOF

touch $MNT/etc/dracut.conf.d/nvme.conf
cat <<EOF > $MNT/etc/dracut.conf.d/nvme.conf
# add_drivers+=" nvme "
EOF

touch $MNT/etc/dracut.conf.d/plymouth.conf
cat <<EOF > $MNT/etc/dracut.conf.d/plymouth.conf
# add_dracutmodules+=" plymouth "
EOF

touch $MNT/etc/dracut.conf.d/btrfs.conf
cat <<EOF > $MNT/etc/dracut.conf.d/btrfs.conf
# Btrfs specific configurations
add_dracutmodules+=" btrfs "

# Limit to Btrfs root filesystem
# filesystems+=" resume btrfs "
filesystems+=" btrfs "
EOF

touch $MNT/etc/dracut.conf.d/nvidia-gpu.conf
cat <<EOF > $MNT/etc/dracut.conf.d/nvidia-gpu.conf
# NVIDIA for PRIME (not primary)
#add_drivers+=" nvidia nvidia_modeset nvidia_uvm nvidia_drm "

# Prevent conflicts
#omit_drivers+=" nouveau "
EOF

touch $MNT/etc/dracut.conf.d/intel-gpu.conf
cat <<EOF > $MNT/etc/dracut.conf.d/intel-gpu.conf
# Intel GPU
# add_drivers+=" i915 "

# Intel must initialize early (Wayland + Waydroid)
# force_drivers+=" i915 "

# Avoid modesetting issues on some hardware (e.g. black screen)
#omit_drivers+=" i915 "

# omit_dracutmodules+=" amdgpu "
EOF

########################################
# ENVIRONMENT VARIABLES
########################################
touch $MNT/etc/environment
cat <<EOF > $MNT/etc/environment
### Nvidia ###
#LIBVA_DRIVER_NAME=nvidia
#MOZ_DISABLE_RDD_SANDBOX=1   # para Firefox (desabilita sandbox no decoder)
#NVD_BACKEND=direct

#Se usar driver proprietário antigo (ex: 470 ou 535 legacy), instale o pacote antigo:
#LIBVA_DRIVER_NAME=vdpau

### Intel ###
# LIBVA_DRIVER_NAME=iHD
# LIBVA_DRIVERS_PATH=/usr/lib/dri
# LIBVA_DRIVERS_PATH=/usr/lib64/dri
# PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
EOF

########################################
# ZRAM
########################################

mkdir -p $MNT/etc/systemd/zram-generator.conf.d
touch $MNT/etc/systemd/zram-generator.conf.d/99-zram.conf
cat <<EOF > $MNT/etc/systemd/zram-generator.conf.d/99-zram.conf
[zram0]
zram-size = ram * 4
compression-algorithm = lz4
swap-priority = 100
EOF

chroot $MNT systemctl enable systemd-zram-setup@zram0


########################################
# GRUB
########################################

touch $MNT/etc/default/grub
cat <<EOF > $MNT/etc/default/grub
GRUB_TIMEOUT=5
#GRUB_HIDDEN_TIMEOUT_QUIET=false
GRUB_DISTRIBUTOR="$(sed 's, release .*$,,g' /etc/system-release)"
GRUB_DEFAULT=saved
GRUB_DISABLE_SUBMENU=true
GRUB_TERMINAL_OUTPUT="console"
GRUB_CMDLINE_LINUX="rhgb quiet splash psi=1 i8042.nopnp rd.driver.blacklist=nouveau modprobe.blacklist=nouveau msr.allow_writes=on pcie_aspm=force intel_idle.max_cstate=1 no_timer_check page_alloc.shuffle=1 rcupdate.rcu_expedited=1 tsc=reliable vt.global_cursor_default=0 loglevel=0 udev.log_level=0 rcutree.rcu_idle_gp_delay=1"
# splash i915.enable_psr=0 i915.enable_fbc=1 i915.enable_guc=3 i915.modeset=1 nvidia-drm.modeset=1 nvidia-drm.fbdev=1
GRUB_DISABLE_RECOVERY="true"
GRUB_COLOR_NORMAL="light-blue/black"
GRUB_COLOR_HIGHLIGHT="light-cyan/blue"
GRUB_DISABLE_OS_PROBER=false
GRUB_ENABLE_BLSCFG=true
EOF

chroot $MNT grub2-install --target=x86_64-efi \
  --efi-directory=/boot/efi \
  --bootloader-id=fedora \
  --recheck --removable \
  --force

chroot /mnt dnf reinstall kernel kernel-core kernel-modules -y

chroot $MNT dracut --force --regenerate-all

cat <<EOF > $MNT/etc/grub.d/40_custom
#!/bin/sh
exec tail -n +3 \$0
# This file provides an easy way to add custom menu entries. Simply type the
# menu entries you want to add after this comment.  Be careful not to change
# the 'exec tail' line above.

menuentry "Reboot" {
    reboot
}

menuentry "Shutdown" {
    halt
}
EOF

chroot $MNT grub2-mkconfig -o /boot/grub2/grub.cfg

########################################
# SERVICES
########################################

chroot $MNT systemctl enable NetworkManager
chroot $MNT systemctl enable firewalld
chroot $MNT systemctl enable sshd

########################################
# USER
########################################

echo "${hostname}" > $MNT/etc/hostname
chroot $MNT useradd ${username} -m -c "Reinaldo P Jr" -s /bin/bash
chroot $MNT sh -c "echo '${username}:${userpass}' | chpasswd -c SHA512"
chroot $MNT usermod -aG wheel ${username}

chroot $MNT fixfiles -F onboot
chroot $MNT dracut --force --regenerate-all
chroot $MNT grub2-mkconfig -o /boot/grub2/grub.cfg

###################
### Environment ###
###################
touch $MNT/etc/environment
cat <<EOF > $MNT/etc/environment
### Nvidia ###
#LIBVA_DRIVER_NAME=nvidia
#MOZ_DISABLE_RDD_SANDBOX=1   # para Firefox (desabilita sandbox no decoder)
#NVD_BACKEND=direct

#Se usar driver proprietário antigo (ex: 470 ou 535 legacy), instale o pacote antigo:
#LIBVA_DRIVER_NAME=vdpau

### Intel ###
# LIBVA_DRIVER_NAME=iHD
# LIBVA_DRIVERS_PATH=/usr/lib64/dri
# LIBVA_DRIVERS_PATH=/usr/lib/dri
PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
EOF

########################################
# Sysctl
########################################
touch $MNT/etc/sysctl.d/99-allow-ping.conf
cat <<EOF > $MNT/etc/sysctl.d/99-allow-ping.conf
net.ipv4.ping_group_range=0 2147483647
EOF

touch $MNT/etc/sysctl.d/10-intel.conf
cat <<EOF > $MNT/etc/sysctl.d/10-intel.conf
# Intel Graphics
# dev.i915.perf_stream_paranoid=0
EOF

touch $MNT/etc/sysctl.d/10-console-messages.conf
cat <<EOF > $MNT/etc/sysctl.d/10-console-messages.conf
# the following stops low-level messages on console
kernel.printk=4 4 1 7
EOF

touch $MNT/etc/sysctl.d/99-dmesg.conf
cat <<EOF > $MNT/etc/sysctl.d/99-dmesg.conf
kernel.dmesg_restrict=0
EOF

touch $MNT/etc/sysctl.d/10-ipv6-privacy.conf
cat <<EOF > $MNT/etc/sysctl.d/10-ipv6-privacy.conf
# IPv6 Privacy Extensions (RFC 4941)
# ---
# IPv6 typically uses a device's MAC address when choosing an IPv6 address
# to use in autoconfiguration. Privacy extensions allow using a randomly
# generated IPv6 address, which increases privacy.
#
# Acceptable values:
#    0 - don’t use privacy extensions.
#    1 - generate privacy addresses
#    2 - prefer privacy addresses and use them over the normal addresses.
net.ipv6.conf.all.use_tempaddr = 2
net.ipv6.conf.default.use_tempaddr = 2
EOF

touch $MNT/etc/sysctl.d/10-kernel-hardening.conf
cat <<EOF > $MNT/etc/sysctl.d/10-kernel-hardening.conf
# These settings are specific to hardening the kernel itself from attack
# from userspace, rather than protecting userspace from other malicious
# userspace things.
#
#
# When an attacker is trying to exploit the local kernel, it is often
# helpful to be able to examine where in memory the kernel, modules,
# and data structures live. As such, kernel addresses should be treated
# as sensitive information.
#
# Many files and interfaces contain these addresses (e.g. /proc/kallsyms,
# /proc/modules, etc), and this setting can censor the addresses. A value
# of "0" allows all users to see the kernel addresses. A value of "1"
# limits visibility to the root user, and "2" blocks even the root user.
kernel.kptr_restrict = 1

# Access to the kernel log buffer can be especially useful for an attacker
# attempting to exploit the local kernel, as kernel addresses and detailed
# call traces are frequently found in kernel oops messages. Setting
# dmesg_restrict to "0" allows all users to view the kernel log buffer,
# and setting it to "1" restricts access to those with CAP_SYSLOG.
#
# dmesg_restrict defaults to 1 via CONFIG_SECURITY_DMESG_RESTRICT, only
# uncomment the following line to disable.
# kernel.dmesg_restrict = 0
EOF

touch $MNT/etc/sysctl.d/10-network-security.conf
cat <<EOF > $MNT/etc/sysctl.d/10-network-security.conf
# Turn on Source Address Verification in all interfaces to
# prevent some spoofing attacks.
net.ipv4.conf.default.rp_filter=2
net.ipv4.conf.all.rp_filter=2
EOF

touch $MNT/etc/sysctl.d/10-zeropage.conf
cat <<EOF > $MNT/etc/sysctl.d/10-zeropage.conf
# Protect the zero page of memory from userspace mmap to prevent kernel
# NULL-dereference attacks against potential future kernel security
# vulnerabilities.  (Added in kernel 2.6.23.)
#
# While this default is built into the Ubuntu kernel, there is no way to
# restore the kernel default if the value is changed during runtime; for
# example via package removal (e.g. wine, dosemu).  Therefore, this value
# is reset to the secure default each time the sysctl values are loaded.
vm.mmap_min_addr = 65536
EOF

### If you are on Arch/Redhat (polkit >= 106), then this would work:
mkdir -pv $MNT/etc/polkit-1/rules.d
cat >$MNT/etc/polkit-1/rules.d/10-udisks2.rules <<HEREDOC
polkit.addRule(function(action, subject) {
    if ((action.id == "org.freedesktop.udisks2.filesystem-mount" ||
        action.id == "org.freedesktop.udisks2.filesystem-mount-system") &&
        subject.isInGroup("sudo")) {
        return polkit.Result.YES;
    }
});
HEREDOC

cat >$MNT/etc/polkit-1/rules.d/10-logs.rules <<HEREDOC
/* Log authorization checks. */
polkit.addRule(function(action, subject) {
  polkit.log("user " +  subject.user + " is attempting action " + action.id + " from PID " + subject.pid);
});
HEREDOC

cat >$MNT/etc/polkit-1/rules.d/10-commands.rules << HEREDOC
polkit.addRule(function(action, subject) {
  if (
    subject.isInGroup("sudo")
      && (
        action.id == "org.freedesktop.login1.reboot" ||
        action.id == "org.freedesktop.login1.reboot-multiple-sessions" ||
        action.id == "org.freedesktop.login1.power-off" ||
        action.id == "org.freedesktop.login1.power-off-multiple-sessions" ||
        action.id == "org.freedesktop.login1.suspend" ||
        action.id == "org.freedesktop.login1.suspend-multiple-sessions"
      )
    )
  {
    return polkit.Result.YES;
  }
})
HEREDOC

chmod 644 $MNT/etc/polkit-1/rules.d/10-udisks2.rules
chmod 644 $MNT/etc/polkit-1/rules.d/10-commands.rules
chmod 644 $MNT/etc/polkit-1/rules.d/10-logs.rules
chown root:root $MNT/etc/polkit-1/rules.d/10-udisks2.rules
chown root:root $MNT/etc/polkit-1/rules.d/10-commands.rules
chown root:root $MNT/etc/polkit-1/rules.d/10-logs.rules


chroot $MNT dracut --force --regenerate-all
chroot $MNT grub2-mkconfig -o /boot/grub2/grub.cfg
chroot $MNT fixfiles -F onboot

########################################################
# KDE
# sudo dnf upgrade --refresh -y
# sudo dnf install @kde-desktop sddm -y

########################################################
# BSPWM

# dnf install lightdm lightdm-gtk-greeter -y
# sudo systemctl enable lightdm --now

# On lightdm.conf, set:
# [Seat:*]
# session=bspwm
# greeter-session=lightdm-gtk-greeter

# Create on /usr/share/xsessions/bspwm.desktop:
# [Desktop Entry]
# Name=BSPWM
# Comment=Binary Space Partition Window Manager
# Exec=/home/juca/.xsession
# Type=Application

# sudo chmod 644 /usr/share/xsessions/bspwm.desktop

# curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | \
#   sh -s -- install --no-confirm

# . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
