#!/usr/bin/env bash
set -euo pipefail

# Minimal dependencies
apt update
apt install -y gdisk debootstrap btrfs-progs lsb-release wget curl gpg ca-certificates arch-install-scripts

# 🧭 Drive + partition paths
DRIVE="/dev/sda"

# SYSTEM_PART="${DRIVE}1"
# EFI_PART="${DRIVE}2"
# ROOT_PART="${DRIVE}3"

SYSTEM_PART="${DRIVE}2"
EFI_PART="${DRIVE}3"
ROOT_PART="${DRIVE}4"
# SWAP_PART="${DRIVE}5"

# 🔖 Labels
ROOT_LABEL="Linux"
SYSTEM_LABEL="BOOT"
EFI_LABEL="ESP"

# ⚙️ Btrfs options (simplificado para hardware antigo - removido autodefrag que pode causar problemas)
BTRFS_OPTS="noatime,ssd,compress=zstd:3,space_cache=v2,commit=120,discard=async"
NIX_OPTS="noatime,ssd,compress=zstd:3,space_cache=v2,commit=20,discard=async"
BTRFS_OPTS2="noatime,ssd,compress=zstd:3,space_cache=v2,commit=120,discard=async"

# 📁 Mount point
MOUNTPOINT="/mnt"

# ---- Partitioning (removida swap partition; root usa todo o espaço restante)
echo "🧱 Wiping partition table and creating new partitions on ${DRIVE} (DESTRUCTIVE!)"
sgdisk --zap-all "${DRIVE}"
sleep 1
parted -s -a optimal "${DRIVE}" mklabel gpt

sgdisk -n 1:0:+1M      -t 1:EF02 -c 1:"BIOS BOOT"       "${DRIVE}"
sgdisk -n 2:0:+1G      -t 2:8301 -c 2:"SYSTEM RESERVED" "${DRIVE}"
sgdisk -n 3:0:+100M    -t 3:EF00 -c 3:"EFI SYSTEM"      "${DRIVE}"
sgdisk -n 4:0:0        -t 4:8300 -c 4:"Linux Root"      "${DRIVE}"

# sgdisk -n 1:0:+1M      -t 1:EF02 -c 1:"BIOS BOOT"       "${DRIVE}"
# sgdisk -n 2:0:+1G      -t 2:8301 -c 2:"SYSTEM RESERVED" "${DRIVE}"
# sgdisk -n 3:0:+600M    -t 3:EF00 -c 3:"EFI SYSTEM"      "${DRIVE}"
# sgdisk -n 4:0:-6G      -t 4:8300 -c 4:"Linux Root"      "${DRIVE}"
# sgdisk -n 5:0:0        -t 4:8200 -c 5:"SWAP Filesystem" "${DRIVE}"

# sgdisk -n 1:0:+1G      -t 1:8301 -c 1:"SYSTEM RESERVED" "${DRIVE}"
# sgdisk -n 2:0:+600M    -t 2:EF00 -c 2:"EFI SYSTEM"      "${DRIVE}"
# sgdisk -n 3:0:0        -t 3:8300 -c 3:"Linux Root"      "${DRIVE}"

sgdisk -p "${DRIVE}"

# ---- Formatting (removido swap)
echo "🧼 Formatting partitions..."
mkfs.ext4 -F -L "${SYSTEM_LABEL}" "${SYSTEM_PART}"
mkfs.fat  -F32 -n "${EFI_LABEL}" "${EFI_PART}"
mkfs.btrfs -f -L "${ROOT_LABEL}" "${ROOT_PART}"

# ---- Btrfs subvolumes on root (mantidos todos + novo @swap para swapfile)
echo "🎯 Creating btrfs subvolumes on root..."
mkdir -p "${MOUNTPOINT}"
mount "${ROOT_PART}" "${MOUNTPOINT}"
for sv in @ @home @opt @nix @gdm @libvirt @spool @log @tmp @apt @snapshots @swap; do
    btrfs subvolume create "${MOUNTPOINT}/${sv}"
done
umount -Rv "${MOUNTPOINT}"

# ---- Mounting subvolumes (com opts otimizados + montar @swap)
echo "📦 Mounting subvolumes..."
mount -o "${BTRFS_OPTS2},subvol=@" "/dev/disk/by-label/${ROOT_LABEL}" "${MOUNTPOINT}"
mkdir -pv "${MOUNTPOINT}/"{boot,home,opt,nix,.snapshots,var/{tmp,spool,log,cache/apt,lib/{gdm,libvirt}},swap}

mount -o "${BTRFS_OPTS},subvol=@home" "/dev/disk/by-label/${ROOT_LABEL}" "${MOUNTPOINT}/home"
mount -o "${BTRFS_OPTS},subvol=@opt" "/dev/disk/by-label/${ROOT_LABEL}" "${MOUNTPOINT}/opt"
mount -o "${BTRFS_OPTS},subvol=@gdm" "/dev/disk/by-label/${ROOT_LABEL}" "${MOUNTPOINT}/var/lib/gdm"
mount -o "${BTRFS_OPTS},subvol=@libvirt" "/dev/disk/by-label/${ROOT_LABEL}" "${MOUNTPOINT}/var/lib/libvirt"
mount -o "${BTRFS_OPTS2},subvol=@log" "/dev/disk/by-label/${ROOT_LABEL}" "${MOUNTPOINT}/var/log"
mount -o "${NIX_OPTS},subvol=@nix" "/dev/disk/by-label/${ROOT_LABEL}" "${MOUNTPOINT}/nix"
mount -o "${BTRFS_OPTS},subvol=@spool" "/dev/disk/by-label/${ROOT_LABEL}" "${MOUNTPOINT}/var/spool"
mount -o "${BTRFS_OPTS2},subvol=@tmp" "/dev/disk/by-label/${ROOT_LABEL}" "${MOUNTPOINT}/var/tmp"
mount -o "${BTRFS_OPTS},subvol=@apt" "/dev/disk/by-label/${ROOT_LABEL}" "${MOUNTPOINT}/var/cache/apt"
mount -o "${BTRFS_OPTS},subvol=@snapshots" "/dev/disk/by-label/${ROOT_LABEL}" "${MOUNTPOINT}/.snapshots"
mount -o "${BTRFS_OPTS2},subvol=@swap" "/dev/disk/by-label/${ROOT_LABEL}" "${MOUNTPOINT}/swap"

echo "⏏️ Mounting boot and EFI..."
mount "/dev/disk/by-label/${SYSTEM_LABEL}" "${MOUNTPOINT}/boot"
mkdir -pv "${MOUNTPOINT}/boot/efi"
mount -t vfat -o defaults,noatime,nodiratime "/dev/disk/by-label/${EFI_LABEL}" "${MOUNTPOINT}/boot/efi"

# ---- Generate /etc/fstab entries (using LABEL=) - atualizado para swapfile
BOOT_UUID=$(blkid -s UUID -o value $SYSTEM_PART)
ESP_UUID=$(blkid -s UUID -o value $EFI_PART)
ROOT_UUID=$(blkid -s UUID -o value $ROOT_PART)

echo "📝 Generating /etc/fstab in ${MOUNTPOINT}/etc/fstab"
mkdir -p "${MOUNTPOINT}/etc"
cat > "${MOUNTPOINT}/etc/fstab" <<EOF
# <file system> <mount point> <type> <options> <dump> <pass>
LABEL=${SYSTEM_LABEL}   /boot            ext4    defaults,noatime 0 2
# UUID=${BOOT_UUID}     /boot            ext4    defaults,noatime 0 2
LABEL=${EFI_LABEL}      /boot/efi        vfat    defaults,noatime,nodiratime 0 1
# UUID=${ESP_LABEL}     /boot/efi        vfat    defaults,noatime,nodiratime 0 1
LABEL=${ROOT_LABEL}     /                btrfs   ${BTRFS_OPTS2},subvol=@ 0 1
# UUID=${ROOT_UUID}     /                btrfs   ${BTRFS_OPTS2},subvol=@ 0 1
LABEL=${ROOT_LABEL}     /home            btrfs   ${BTRFS_OPTS},subvol=@home 0 2
# UUID=${ROOT_UUID}     /home            btrfs   ${BTRFS_OPTS},subvol=@home 0 2
LABEL=${ROOT_LABEL}     /opt             btrfs   ${BTRFS_OPTS},subvol=@opt 0 2
# UUID=${ROOT_UUID}     /opt             btrfs   ${BTRFS_OPTS},subvol=@opt 0 2
LABEL=${ROOT_LABEL}     /var/lib/gdm     btrfs   ${BTRFS_OPTS},subvol=@gdm 0 2
# UUID=${ROOT_UUID}     /var/lib/gdm     btrfs   ${BTRFS_OPTS},subvol=@gdm 0 2
LABEL=${ROOT_LABEL}     /var/lib/libvirt btrfs   ${BTRFS_OPTS},subvol=@libvirt 0 2
# UUID=${ROOT_UUID}     /var/lib/libvirt btrfs   ${BTRFS_OPTS},subvol=@libvirt 0 2
LABEL=${ROOT_LABEL}     /var/log         btrfs   ${BTRFS_OPTS2},subvol=@log 0 2
# UUID=${ROOT_UUID}     /var/log         btrfs   ${BTRFS_OPTS2},subvol=@log 0 2
LABEL=${ROOT_LABEL}     /nix             btrfs   ${NIX_OPTS},subvol=@nix 0 2
# UUID=${ROOT_UUID}     /nix             btrfs   ${NIX_OPTS},subvol=@nix 0 2
LABEL=${ROOT_LABEL}     /var/spool       btrfs   ${BTRFS_OPTS},subvol=@spool 0 2
# UUID=${ROOT_UUID}     /var/spool       btrfs   ${BTRFS_OPTS},subvol=@spool 0 2
LABEL=${ROOT_LABEL}     /var/tmp         btrfs   ${BTRFS_OPTS2},subvol=@tmp 0 2
# UUID=${ROOT_UUID}     /var/tmp         btrfs   ${BTRFS_OPTS2},subvol=@tmp 0 2
LABEL=${ROOT_LABEL}     /var/cache/apt   btrfs   ${BTRFS_OPTS},subvol=@apt 0 2
# UUID=${ROOT_UUID}     /var/cache/apt   btrfs   ${BTRFS_OPTS},subvol=@apt 0 2
LABEL=${ROOT_LABEL}     /.snapshots      btrfs   ${BTRFS_OPTS},subvol=@snapshots 0 2
# UUID=${ROOT_UUID}     /.snapshots      btrfs   ${BTRFS_OPTS},subvol=@snapshots 0 2
LABEL=${ROOT_LABEL}     /swap            btrfs   ${BTRFS_OPTS2},subvol=@swap 0 2
# UUID=${ROOT_UUID}     /swap            btrfs   ${BTRFS_OPTS2},subvol=@swap 0 2
# swapfile
/swap/swapfile          none             swap    sw 0 0
EOF

echo "✅ Done. Partitions created, filesystems formatted, subvolumes created and mounted."
echo "Next steps: debootstrap or install your distro into ${MOUNTPOINT} and configure bootloader."

### Debian VARS
Architecture="amd64"
CODENAME="trixie"
username="juca"
hostname="anubis"

  # --include=apt,bash,zsh,neovim,ssh,curl,locales,wpasupplicant,zstd,apt-utils,btrfs-progs,iputils-ping,dbus-broker,dbus-user-session,libpam-systemd,wget,curl,tzdata,ca-certificates,systemd-sysv,grub-efi-amd64,login,passwd,procps,e2fsprogs,network-manager,sudo \
  # --include=apt,bash,cpio,kmod,initramfs-tools,neovim,ssh,curl,locales,zstd,apt-utils,btrfs-progs,iputils-ping,dbus-broker,dbus-user-session,libpam-systemd,wget,curl,tzdata,ca-certificates,systemd-sysv,grub-efi-amd64,login,passwd,procps,e2fsprogs,network-manager,sudo \
debootstrap \
  --arch=${Architecture} \
  --variant=minbase \
  --no-check-gpg \
  --include=apt,bash,cpio,kmod,initramfs-tools,dkms,neovim,ssh,curl,locales,zstd,apt-utils,btrfs-progs,iputils-ping,dbus-broker,dbus-user-session,libpam-systemd,wget,curl,tzdata,ca-certificates,systemd-sysv,grub-efi-amd64,login,passwd,procps,e2fsprogs,network-manager,sudo \
  ${CODENAME} /mnt \
  http://debian.c3sl.ufpr.br/debian

echo "🔧 Mounting system filesystems..."
udevadm trigger
mkdir -p $MOUNTPOINT/{proc,sys,dev/pts}
mount -t proc     proc      $MOUNTPOINT/proc
mount -t sysfs    sysfs     $MOUNTPOINT/sys
mount --rbind     /dev      $MOUNTPOINT/dev
mount -t devpts   devpts    $MOUNTPOINT/dev/pts
mount -t efivarfs efivarfs  $MOUNTPOINT/sys/firmware/efi/efivars

chroot /mnt update-ca-certificates
chroot /mnt apt install --reinstall ca-certificates -y
chroot /mnt update-ca-certificates

chroot /mnt apt purge ifupdown --yes
mkdir -pv /mnt/etc/network/
touch /mnt/etc/network/interfaces
cat <<EOF > /mnt/etc/network/interfaces
auto lo
iface lo inet loopback
EOF

chroot /mnt update-alternatives --install /usr/bin/editor editor /usr/bin/nvim 100
chroot /mnt apt --fix-broken install --yes

# dracut configs (refinados para Mac + hostonly strict + resume garantido)
# Correção: Comentando toda a seção de dracut, pois estamos trocando para initramfs-tools para melhor compatibilidade com Debian e evitar hangs no initramfs. Dracut pode não incluir todos os módulos necessários para hardware Mac e Btrfs com subvolumes/swapfiles.
# mkdir -pv /mnt/etc/dracut.conf.d
# touch /mnt/etc/dracut.conf.d/debian.conf
# cat <<EOF > /mnt/etc/dracut.conf.d/debian.conf
# do_prelink="no"
# hostonly="yes"
# hostonly_mode="strict"
# early_microcode=yes
# add_dracutmodules+=" systemd btrfs resume kernel-modules "
# filesystems+=" btrfs "
# install_items+=" /lib/firmware /etc/modprobe.d /etc/udev/rules.d "
# EOF
#
# touch /mnt/etc/dracut.conf.d/force-drivers.conf
# cat <<EOF > /mnt/etc/dracut.conf.d/force-drivers.conf
# # force_drivers+=" i915 hid_apple wl snd_hda_intel "
# force_drivers+=" i915 hid_apple brcmsmac snd_hda_intel "
# EOF
#
# touch /mnt/etc/dracut.conf.d/plymouth.conf
# cat <<EOF > /mnt/etc/dracut.conf.d/plymouth.conf
# omit_dracutmodules+=" plymouth "
# EOF
#
# touch /mnt/etc/dracut.conf.d/override.conf
# cat <<EOF > /mnt/etc/dracut.conf.d/override.conf
# uefi="no"
# uefi_stub=""
# compress="zstd"
# compressargs="--ultra -19"
# EOF
#
# touch /mnt/etc/dracut.conf.d/kernel.conf
# cat <<EOF > /mnt/etc/dracut.conf.d/kernel.conf
# kernel_cmdline=" rootflags=subvol=@ rw quiet security=apparmor apparmor=1 lsm=landlock lockdown yama apparmor bpf "
# EOF
#
# touch /mnt/etc/dracut.conf.d/quiet.conf
# cat <<EOF > /mnt/etc/dracut.conf.d/quiet.conf
# omit_dracutmodules+=" crypt "
# EOF
#
# touch /mnt/etc/dracut.conf.d/resume.conf
# cat <<EOF > /mnt/etc/dracut.conf.d/resume.conf
# # resume_offset="0"   # se usar swapfile; para partição, dracut cuida
# EOF

touch /mnt/etc/environment
cat <<EOF >/mnt/etc/environment
# # Set locale
# LANG="en_US.UTF-8"
EOF

# rm /mnt/apt/sources.list
touch /mnt/etc/apt/sources.list.d/debian.sources

rm /mnt/etc/apt/sources.list

### NEW WAY ###
mkdir -pv /mnt/etc/apt/sources.list.d
cat >/mnt/etc/apt/sources.list.d/debian.sources <<HEREDOC
Types: deb deb-src
URIs: http://debian.c3sl.ufpr.br/debian/
Suites: trixie
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

Types: deb deb-src
URIs: http://debian.c3sl.ufpr.br/debian/
Suites: trixie-updates
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

Types: deb deb-src
URIs: http://security.debian.org/debian-security/
Suites: trixie-security
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

Types: deb deb-src
URIs: http://deb.debian.org/debian
Suites: bookworm-backports
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

# Types: deb deb-src
# URIs: http://deb.debian.org/debian
# Suites: bullseye
# Components: main contrib non-free
# Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

# Types: deb deb-src
# URIs: http://archive.debian.org/debian
# Suites: buster-backports
# Components: main contrib non-free
# Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

#Types: deb deb-src
#URIs: http://debian.c3sl.ufpr.br/debian/
#Suites: trixie-backports
#Components: main contrib non-free non-free-firmware
#Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

#Types: deb deb-src
#URIs: http://debian.c3sl.ufpr.br/debian/
#Suites: unstable
#Components: main contrib non-free non-free-firmware
#Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

#Types: deb deb-src
#URIs: http://debian.c3sl.ufpr.br/debian/
#Suites: experimental
#Components: main contrib non-free non-free-firmware
#Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

# Types: deb deb-src
# URIs: https://packagecloud.io/get-edi/debian/debian/
# Suites: buster-oldstable
# Components: main contrib non-free
# Signed-By: /etc/apt/keyrings/get-edi_debian-archive-keyring.gpg
HEREDOC

mkdir -pv /mnt/etc/apt/apt.conf.d

touch /mnt/etc/apt/apt.conf.d/00recommends
cat >/mnt/etc/apt/apt.conf.d/00recommends <<HEREDOC
APT::Install-Recommends "false";
HEREDOC

touch /mnt/etc/apt/apt.conf.d/70debconf
cat >/mnt/etc/apt/apt.conf.d/70debconf <<HEREDOC
// Pre-configure all packages with debconf before they are installed.
// DPkg::Pre-Install-Pkgs {"/usr/sbin/dpkg-preconfigure --apt || true";};
HEREDOC

touch /mnt/etc/apt/apt.conf.d/99suggests
cat >/mnt/etc/apt/apt.conf.d/99suggests <<HEREDOC
APT::Install-Suggests "0";
HEREDOC

touch /mnt/etc/apt/apt.conf.d/99snapshot
cat >/mnt/etc/apt/apt.conf.d/99snapshot <<HEREDOC
Acquire::Check-Valid-Until "false";
HEREDOC

touch /mnt/etc/apt/apt.conf.d/01autoremove 
cat >/mnt/etc/apt/apt.conf.d/01autoremove <<HEREDOC
APT
{
  NeverAutoRemove
  {
        "^firmware-linux.*";
        "^linux-firmware$";
  };

  VersionedKernelPackages
  {
        "linux-image";
        "linux-headers";
        "linux-image-extra";
        "linux-modules";
        "linux-modules-extra";
        "linux-signed-image";
        "linux-.*";
        "kfreebsd-.*";
        "kfreebsd-image";
        "kfreebsd-headers";
        "gnumach-image";
        "gnumach-.*";
        ".*-modules";
        ".*-kernel";
        "linux-backports-modules-.*";
        "linux-modules-.*";
        "linux-tools";
  };

  Never-MarkAuto-Sections
  {
        "metapackages";
        "tasks";
  };

  Move-Autobit-Sections
  {
        "oldlibs";
  };
}
HEREDOC

echo 'APT::Default-Release "trixie";' | tee /mnt/etc/apt/apt.conf.d/99default-release

mkdir -pv /mnt/etc/apt/preferences.d

touch /mnt/etc/apt/preferences.d/99trixie.pref
touch /mnt/etc/apt/preferences.d/50testing.pref
touch /mnt/etc/apt/preferences.d/10unstable.pref
touch /mnt/etc/apt/preferences.d/1experimental.pref
# touch /mnt/etc/apt/preferences.d/no-initramfs-tools  # Correção: Comentando a criação deste arquivo, pois estamos removendo a preferência negativa para initramfs-tools. Vamos usá-lo em vez de dracut para compatibilidade Debian.
touch /mnt/etc/apt/preferences.d/bookworm-backports
touch /mnt/etc/apt/preferences.d/buster-kernel
touch /mnt/etc/apt/preferences.d/liquorix

cat >/mnt/etc/apt/preferences.d/99trixie.pref <<HEREDOC
Package: *
Pin: release a=trixie
Pin-Priority: 900
HEREDOC

cat >/mnt/etc/apt/preferences.d/50testing.pref <<HEREDOC
Package: *
Pin: release a=testing
Pin-Priority: 400
HEREDOC

cat >/mnt/etc/apt/preferences.d/10unstable.pref <<HEREDOC
Package: *
Pin: release a=unstable
Pin-Priority: 50
HEREDOC

cat >/mnt/etc/apt/preferences.d/1experimental.pref <<HEREDOC
Package: *
Pin: release a=experimental
Pin-Priority: 1
HEREDOC

# cat >/mnt/etc/apt/preferences.d/no-initramfs-tools <<HEREDOC  # Correção: Comentando esta preferência, pois queremos instalar initramfs-tools sem restrições.
# Package: initramfs-tools
# Pin: release *
# Pin-Priority: -1
# HEREDOC

cat >/mnt/etc/apt/preferences.d/bookworm-backports <<HEREDOC
# Package: *
# Pin: release n=bookworm-backports
# Pin-Priority: 100 # só instala se você pedir explicitamente.
HEREDOC

cat >/mnt/etc/apt/preferences.d/bullseye-kernel <<HEREDOC
# Package: *
# Pin: origin liquorix.net
# Pin-Priority: 50 # nunca instala automaticamente
HEREDOC

cat >/mnt/etc/apt/preferences.d/bullseye-kernel <<HEREDOC
# Package: *
# Pin: release n=bullseye
# Pin-Priority: 50 # tudo do Bullseye = prioridade baixa

# Package: linux-image-amd64
# Pin: release n=bullseye # kernel meta-package = permitido
# Pin-Priority: 990

# Package: linux-headers-amd64
# Pin: release n=bullseye
# Pin-Priority: 990

# Package: linux-image-5.10*
# Pin: release n=bullseye # kernel 5.10 = prioridade máxima
# Pin-Priority: 1001
HEREDOC

cat >/mnt/etc/apt/preferences.d/buster-kernel <<HEREDOC
# Package: *
# Pin: release n=buster-backports
# Pin-Priority: 1

# Package: linux-image-5.4*
# Pin: release n=buster-backports
# Pin-Priority: 1001

# Package: linux-headers-5.4*
# Pin: release n=buster-backports
# Pin-Priority: 1001
HEREDOC

chroot /mnt apt update
chroot /mnt apt upgrade --yes

# Install recommended packages (adicionado zram-tools para otimização RAM/swap)
# chroot /mnt apt install -y firmware-brcm80211 broadcom-sta-dkms \
    # intel-microcode firmware-linux-nonfree tlp macfanctld zram-tools

# chroot /mnt apt install -y firmware-brcm80211 \
#     intel-microcode firmware-linux-nonfree tlp macfanctld zram-tools

chroot /mnt apt install -y intel-microcode firmware-linux-nonfree tlp macfanctld zram-tools
chroot /mnt apt install -y locales

chroot /mnt echo "America/Sao_Paulo" >/mnt/etc/timezone
chroot /mnt dpkg-reconfigure -f noninteractive tzdata
sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /mnt/etc/locale.gen
sed -i -e 's/# pt_BR.UTF-8 UTF-8/pt_BR.UTF-8 UTF-8/' /mnt/etc/locale.gen
chroot /mnt dpkg-reconfigure -f noninteractive locales
# chroot /mnt dpkg-reconfigure --frontend=noninteractive locales

chroot /mnt apt update
touch /mnt/etc/vconsole.conf
echo 'KEYMAP="us"' >/mnt/etc/vconsole.conf
echo 'KEYMAP_TOGGLE="br-abnt2"' >> /mnt/etc/vconsole.conf


chroot /mnt apt update
chroot /mnt apt upgrade
chroot /mnt apt autoremove
chroot /mnt apt autoclean

chroot /mnt sh -c 'echo "root:200291" | chpasswd -c SHA512'
chroot /mnt useradd $username -m -c "Reinaldo P Jr" -s /bin/bash
chroot /mnt sh -c 'echo "juca:200291" | chpasswd -c SHA512'
chroot /mnt usermod -aG floppy,audio,sudo,video,systemd-journal,lp,cdrom,netdev $username
chroot /mnt usermod -aG sudo $username

chroot /mnt systemctl disable dbus-daemon.service
chroot /mnt systemctl enable dbus-broker.service

mkdir -pv /mnt/etc/modprobe.d
cat <<EOF >/mnt/etc/modprobe.d/blacklist.conf
# Disable watchdog
install iTCO_wdt /bin/true
install iTCO_vendor_support /bin/true

blacklist evbug
blacklist usbmouse
blacklist usbkbd
blacklist eepro100
blacklist de4x5
blacklist eth1394
# blacklist snd_intel8x0m

# blacklist prism54
blacklist garmin_gps
# blacklist asus_acpi
# blacklist snd_pcsp
# blacklist pcspkr
# blacklist amd76x_edac

# Blacklist drivers Broadcom ruins (prioriza wl)
blacklist bcm43xx
blacklist brcmsmac
blacklist wl
blacklist bcma
blacklist b43
blacklist ssb
EOF

cat << EOF > /mnt/etc/modprobe.d/i915.conf
options i915 enable_rc6=1 enable_fbc=1 enable_psr=0 fastboot=1
EOF

# hid_apple para teclas Fn no Mac
cat <<EOF > /mnt/etc/modprobe.d/hid_apple.conf
options hid_apple fnmode=2
EOF

mkdir -pv /mnt/etc/modules-load.d
touch /mnt/etc/modules-load.d/iptables.conf
cat << EOF > /mnt/etc/modules-load.d/iptables.conf
ip6_tables
ip6table_nat
ip_tables
iptable_nat
EOF

touch /mnt/etc/modules-load.d/brcm.conf
cat << EOF > /mnt/etc/modules-load.d/brcm.conf
# brcmsmac
EOF

mkdir -pv /mnt/etc/sysctl.d
cat <<EOF >/mnt/etc/sysctl.d/00-swap.conf
# Otimizações RAM/swap para máquina antiga (low RAM)
vm.vfs_cache_pressure=50
vm.swappiness=10
vm.dirty_background_ratio=5
vm.dirty_ratio=20
vm.dirty_expire_centisecs=3000
vm.dirty_writeback_centisecs=500
vm.overcommit_memory=1  # Permite overcommit para apps Nix
vm.min_free_kbytes=65536  # Reserva para lowmem
EOF

cat <<EOF >/mnt/etc/sysctl.d/99-allow-ping.conf
net.ipv4.ping_group_range=0 2147483647
EOF

cat <<EOF >/mnt/etc/sysctl.d/10-console-messages.conf
kernel.printk=4 4 1 7
EOF

cat <<EOF >/mnt/etc/sysctl.d/99-dmesg.conf
kernel.dmesg_restrict=0
EOF

cat <<EOF >/mnt/etc/sysctl.d/10-ipv6-privacy.conf
net.ipv6.conf.all.use_tempaddr = 2
net.ipv6.conf.default.use_tempaddr = 2
EOF

cat <<EOF >/mnt/etc/sysctl.d/10-kernel-hardening.conf
kernel.kptr_restrict = 1
EOF

cat <<EOF >/mnt/etc/sysctl.d/10-network-security.conf
net.ipv4.conf.default.rp_filter=2
net.ipv4.conf.all.rp_filter=2
EOF

cat <<EOF >/mnt/etc/sysctl.d/10-zeropage.conf
vm.mmap_min_addr = 65536
EOF

cat <<EOF >/mnt/etc/hostname
${hostname}
EOF

touch /mnt/etc/hosts
cat <<EOF >/mnt/etc/hosts
127.0.0.1   localhost
127.0.1.1   ${hostname}.localdomain ${hostname}
::1         localhost ip6-localhost ip6-loopback
EOF

touch /mnt/etc/host.conf
cat <<EOF >/mnt/etc/host.conf
multi on
EOF

touch /mnt/etc/nsswitch.conf
cat <<EOF >/mnt/etc/nsswitch.conf
passwd:     files systemd
shadow:     files systemd
group:      files [SUCCESS=merge] systemd
hosts:      files myhostname mdns4_minimal [NOTFOUND=return] resolve [!UNAVAIL=return] dns
services:   files
netgroup:   files
automount:  files

aliases:    files
ethers:     files
gshadow:    files systemd
networks:   files dns
protocols:  files
publickey:  files
rpc:        files
EOF

# Cria swapfile e calcula resume_offset (tamanho 8 GB, ajuste se necessário)
chroot /mnt btrfs filesystem mkswapfile --size 8g /swap/swapfile
RESUME_OFFSET=$(chroot /mnt btrfs inspect-internal map-swapfile -r /swap/swapfile)
chroot /mnt swapon /swap/swapfile

chroot /mnt apt install apparmor \
    apparmor-utils auditd -y

mkdir -pv /mnt/var/log/audit
chown root:root /mnt/var/log/audit
chmod 0700 /mnt/var/log/audit

chroot /mnt apt install gvfs gvfs-backends smbclient cifs-utils avahi-daemon -y

mkdir -pv /mnt/usr/lib/sysctl.d
touch /mnt/usr/lib/sysctl.d/50-default.conf
echo "net.ipv4.ping_group_range = 0 2147483647" >> /mnt/usr/lib/sysctl.d/50-default.conf

chroot /mnt apt install -y pulseaudio-utils pipewire-audio wireplumber pipewire-pulse pipewire-alsa libspa-0.2-bluetooth libspa-0.2-jack 

chroot /mnt systemctl --user enable wireplumber.service
chroot /mnt systemctl --user disable pulseaudio.service pulseaudio.socket
chroot /mnt systemctl --user mask pulseaudio 
chroot /mnt systemctl --user enable pipewire pipewire-pulse

chroot /mnt apt install -y rtkit

chroot /mnt apt install -y gdisk bash-completion pciutils xz-utils curl unzip

mkdir -pv /mnt/run/polkit-1/rules.d
chmod 755 /mnt/run/polkit-1/rules.d

mkdir -pv /mnt/etc/polkit-1/localauthority/50-local.d
cat <<EOF >/mnt/etc/polkit-1/localauthority/50-local.d/50-udisks.pkla
[udisks]
Identity=unix-group:sudo
Action=org.freedesktop.udisks2.filesystem-mount-system
ResultAny=yes
ResultInactive=no
ResultActive=yes
EOF

mkdir -pv /mnt/etc/polkit-1/rules.d
cat >/mnt/etc/polkit-1/rules.d/10-udisks2.rules <<HEREDOC
polkit.addRule(function(action, subject) {
    if ((action.id == "org.freedesktop.udisks2.filesystem-mount" ||
        action.id == "org.freedesktop.udisks2.filesystem-mount-system") &&
        subject.isInGroup("sudo")) {
        return polkit.Result.YES;
    }
});
HEREDOC

cat >/mnt/etc/polkit-1/rules.d/10-logs.rules <<HEREDOC
polkit.addRule(function(action, subject) {
  polkit.log("user " +  subject.user + " is attempting action " + action.id + " from PID " + subject.pid);
});
HEREDOC

cat >/mnt/etc/polkit-1/rules.d/10-commands.rules << HEREDOC
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

chmod 644 /mnt/etc/polkit-1/rules.d/10-udisks2.rules
chmod 644 /mnt/etc/polkit-1/rules.d/10-commands.rules
chmod 644 /mnt/etc/polkit-1/rules.d/10-logs.rules
chown root:root /mnt/etc/polkit-1/rules.d/10-udisks2.rules
chown root:root /mnt/etc/polkit-1/rules.d/10-commands.rules
chown root:root /mnt/etc/polkit-1/rules.d/10-logs.rules

chroot /mnt apt install -y efibootmgr grub-efi-amd64 os-prober

chroot /mnt apt install -y chrony

chroot /mnt apt install -y earlyoom powertop tlp thermald irqbalance
chroot /mnt systemctl enable earlyoom
chroot /mnt systemctl enable powertop
chroot /mnt systemctl enable tlp
chroot /mnt systemctl enable thermald
chroot /mnt systemctl enable irqbalance

# TLP otimizado para MacBook antigo (bateria)
chroot /mnt apt install -y tlp-rdw
cat <<EOF > /mnt/etc/tlp.conf
# CPU (Core 2 Duo antigo – powersave agressivo)
CPU_SCALING_GOVERNOR_ON_BAT="powersave"
CPU_SCALING_GOVERNOR_ON_AC="ondemand"
CPU_ENERGY_PERF_POLICY_ON_BAT="power"
CPU_ENERGY_PERF_POLICY_ON_AC="balance_performance"
CPU_MIN_PERF_ON_BAT=0
CPU_MAX_PERF_ON_BAT=60     # Limita turbo/boost para economia (evita aquecimento)
CPU_BOOST_ON_BAT=0         # Desliga turbo em bateria

# Plataforma / Intel
PLATFORM_PROFILE_ON_BAT="low-power"

# Wi-Fi (Broadcom BCM43224 – wl driver já priorizado)
WIFI_PWR_ON_BAT="on"       # Economia máxima

# USB / periféricos (desliga autosuspend se não usa)
USB_AUTOSUSPEND=1
USB_EXCLUDE_BTUSB=0        # Se usa Bluetooth, mude para 1

# Runtime PM (economia em dispositivos PCI)
RUNTIME_PM_ON_BAT="auto"

# Disco / SSD (seu SSD antigo beneficia)
SATA_LINKPWR_ON_BAT="min_power"

# Outros
DEVICES_TO_DISABLE_ON_STARTUP="bluetooth"  # Se não usa BT
SOUND_POWER_SAVE_ON_BAT=1
SOUND_POWER_SAVE_CONTROLLER=N

# Desliga Wi-Fi quando suspenso (rdw ajuda)
WIFI_RADIO_SWITCH_ON_BAT=1
EOF

mkdir -pv /mnt/etc/X11/xorg.conf.d/
touch /mnt/etc/X11/xorg.conf.d/30-touchpad.conf
cat <<EOF >/mnt/etc/X11/xorg.conf.d/30-touchpad.conf
Section "InputClass"
  Identifier          "libinput touchpad catchall"
  Driver              "libinput"
  MatchIsTouchpad     "on"
  MatchDevicePath     "/dev/input/event*"
  Option              "Tapping"   			                "on"
  Option 		          "NaturalScrolling"		            "true"
EndSection
EOF

touch /mnt/etc/X11/xorg.conf.d/40-keyboard.conf
cat <<EOF >/mnt/etc/X11/xorg.conf.d/40-keyboard.conf
Section "InputClass"
    Identifier "system-keyboard"
    MatchIsKeyboard "on"
    Option "XkbModel" "apple"
    Option "XkbLayout" "us"
    Option "XkbVariant" "mac"
EndSection
EOF

chroot /mnt apt install bluez bluez-tools -y
chroot /mnt systemctl enable bluetooth

touch /mnt/etc/default/console-setup

# ────────────────────────────────────────────────────────────────
# Install console-setup and configure keyboard/font non-interactively
# ────────────────────────────────────────────────────────────────
# Install console-setup (if not already)
chroot /mnt apt install -y console-setup keyboard-configuration

# Option A: Debconf preseeding – set model to "apple" + layout "us" (recommended for Mac)
# This makes console closer to macOS defaults (e.g., better Option/Alt behavior)
chroot /mnt /bin/bash -c '
cat <<EOF | debconf-set-selections
console-setup console-setup/charmap47 select UTF-8
console-setup console-setup/codeset47 select # Latin1 and Latin5 - western Europe and Brazil
console-setup console-setup/fontface47 select Terminus
console-setup console-setup/fontsize-text47 select 16x32 (framebuffer only)
console-setup console-setup/modelcode select apple
console-setup console-setup/layoutcode select us
console-setup console-setup/variantcode select mac   # or empty; "mac" variant exists for some layouts
console-setup console-setup/optionscode select
EOF

dpkg-reconfigure -f noninteractive keyboard-configuration
dpkg-reconfigure -f noninteractive console-setup
setupcon --force
'

# ── OR Option B: Direct /etc/default/keyboard file (simpler, overrides debconf)
# chroot /mnt /bin/bash -c 'cat > /etc/default/keyboard <<EOF
# XKBMODEL="apple"
# XKBLAYOUT="us"
# XKBVARIANT="mac"
# XKBOPTIONS="terminate:ctrl_alt_bksp"  # optional: Ctrl+Alt+Backspace to kill X if needed
# BACKSPACE="guess"
# EOF
# setupcon --force'

chroot /mnt chsh -s /usr/bin/bash root

chroot /mnt systemctl disable systemd-networkd.service
chroot /mnt systemctl disable systemd-networkd.socket
chroot /mnt systemctl disable systemd-networkd-wait-online.service

chroot /mnt systemctl mask systemd-networkd.service
chroot /mnt systemctl mask systemd-networkd.socket
chroot /mnt systemctl mask systemd-networkd-wait-online.service

# chroot /mnt systemctl enable wpa_supplicant.service
chroot /mnt systemctl enable NetworkManager.service
chroot /mnt systemctl enable ssh.service
chroot /mnt systemctl enable rtkit-daemon.service
chroot /mnt systemctl enable chrony.service
chroot /mnt systemctl enable fstrim.timer

# Kernel padrão (comentado, usando Liquorix como default)
chroot /mnt apt install linux-image-amd64 linux-headers-amd64 --yes

# Instalar Kernel Liquorix como default (otimizado para performance + bateria)
# echo 'deb http://liquorix.net/debian sid main' | tee /mnt/etc/apt/sources.list.d/liquorix.list
# curl https://liquorix.net/liquorix-keyring.gpg | gpg --dearmor | tee /mnt/usr/share/keyrings/liquorix-archive-keyring.gpg
## echo 'deb [signed-by=/usr/share/keyrings/liquorix-archive-keyring.gpg] http://liquorix.net/debian sid main' | tee -a /mnt/etc/apt/sources.list.d/liquorix.list
# echo 'deb [signed-by=/usr/share/keyrings/liquorix-archive-keyring.gpg] http://liquorix.net/debian sid main' | sudo tee /etc/apt/sources.list.d/liquorix.list  # Sobrescreve o arquivo inteiro, evitando append
chroot /mnt apt update
# chroot /mnt apt install -y linux-image-liquorix-amd64 linux-headers-liquorix-amd64

# Correção: Comentando instalação e uso de dracut, instalando initramfs-tools em vez disso para compatibilidade Debian. Adicionamos módulos necessários para MacBook (i915, ahci, etc.) em /etc/initramfs-tools/modules.
# chroot /mnt apt install dracut -y
chroot /mnt apt install initramfs-tools -y
# Correção: Comentando purge de initramfs-tools, pois agora estamos usando ele.
# chroot /mnt apt autoremove
# chroot /mnt apt purge initramfs-tools tiny-initramfs -y
# chroot /mnt apt autoclean
# Correção: Usando update-initramfs em vez de dracut para gerar o initramfs.
# chroot /mnt dracut --regenerate-all --force
chroot /mnt update-initramfs -u -k all

# Correção: Criando /etc/initramfs-tools/modules para forçar inclusão de módulos essenciais (semelhante ao force-drivers.conf do dracut).
mkdir -pv /mnt/etc/initramfs-tools
touch /mnt/etc/initramfs-tools/modules
cat <<EOF >> /mnt/etc/initramfs-tools/modules
i915
hid_apple
# brcmsmac
snd_hda_intel
ahci  # Para detecção de SSD no MacBook
btrfs  # Para suporte Btrfs completo
EOF

# Correção: Removido resume_offset do initramfs para evitar problemas de boot.
# O zram já fornece swap comprimido que é mais simples e confiável para hardware antigo.
# Se quiser usar hibernação com swapfile, você precisará configurar manualmente depois.
mkdir -pv /mnt/etc/initramfs-tools/conf.d
touch /mnt/etc/initramfs-tools/conf.d/resume
# cat <<EOF >/mnt/etc/initramfs-tools/conf.d/resume
# RESUME=UUID=${ROOT_UUID} resume_offset=${RESUME_OFFSET}
# EOF

chroot /mnt grub-install --target=x86_64-efi --bootloader-id="Debian" --efi-directory=/boot/efi --recheck --force

# GRUB cmdline otimizado (com resume para hibernação + bateria extra + resume_offset para swapfile)
cat <<EOF >/mnt/etc/default/grub
GRUB_DEFAULT=saved
GRUB_TIMEOUT=5
GRUB_DISABLE_SUBMENU=false
GRUB_DISTRIBUTOR="Debian"
# GRUB_CMDLINE_LINUX_DEFAULT="quiet splash pci=noaer acpi_backlight=vendor psi=1 i8042.nopnp usbcore.autosuspend=-1 apparmor=1 security=apparmor vt.global_cursor_default=0 loglevel=0 rd.systemd.show_status=auto rd.udev.log_level=0 i915.enable_psr=0 i915.modeset=1 i915.enable_rc6=1 i915.enable_fbc=1 i915.fastboot=1 i915.enable_dc=0 intel_idle.max_cstate=1 zswap.enabled=1 zswap.compressor=lz4 zswap.zpool=z3fold resume=UUID=${ROOT_UUID} resume_offset=${RESUME_OFFSET}"
# GRUB_CMDLINE_LINUX_DEFAULT="quiet splash pci=noaer nomodeset psi=1 i8042.nopnp usbcore.autosuspend=-1 apparmor=1 security=apparmor vt.global_cursor_default=0 loglevel=0 rd.systemd.show_status=auto rd.udev.log_level=0 i915.enable_psr=0 i915.enable_rc6=1 i915.enable_fbc=1 i915.fastboot=1 i915.enable_dc=0 pcie_aspm=force intel_idle.max_cstate=1 zswap.enabled=1 zswap.compressor=lz4 zswap.zpool=z3fold nohz_full=1 mitigations=auto,nosmt resume=LABEL=${ROOT_LABEL} resume_offset=${RESUME_OFFSET}"
# GRUB_CMDLINE_LINUX_DEFAULT="quiet splash pci=noaer acpi_backlight=vendor psi=1 i8042.nopnp usbcore.autosuspend=-1 apparmor=1 security=apparmor vt.global_cursor_default=0 loglevel=0 rd.systemd.show_status=auto rd.udev.log_level=0 i915.enable_psr=0 i915.modeset=1 i915.enable_rc6=1 i915.enable_fbc=1 i915.fastboot=1 i915.enable_dc=0 intel_idle.max_cstate=1 zswap.enabled=1 zswap.compressor=lz4 zswap.zpool=z3fold resume=LABEL=${ROOT_LABEL} resume_offset=${RESUME_OFFSET}"
# GRUB_CMDLINE_LINUX_DEFAULT="pci=noaer acpi_backlight=vendor psi=1 i8042.nopnp usbcore.autosuspend=-1 apparmor=1 security=apparmor vt.global_cursor_default=0 loglevel=0 rd.systemd.show_status=auto rd.udev.log_level=0 i915.enable_psr=0 i915.modeset=1 i915.enable_rc6=1 i915.enable_fbc=1 i915.fastboot=1 i915.enable_dc=0 intel_idle.max_cstate=1 zswap.enabled=1 zswap.compressor=lz4 zswap.zpool=z3fold resume=LABEL=${ROOT_LABEL} resume_offset=${RESUME_OFFSET}"
# Correção: Removido acpi=off que estava causando travamento no boot. 
# Parâmetros otimizados para MacBook Air 4,1 (Core 2 Duo) - simplificados para maior compatibilidade.
GRUB_CMDLINE_LINUX_DEFAULT="root=UUID=${ROOT_UUID} rootflags=subvol=@ quiet splash i915.modeset=1 i915.enable_rc6=1 i915.enable_fbc=1 i915.fastboot=1 apparmor=1 security=apparmor"
# Parâmetros originais mantidos para referência (comentados):
# GRUB_CMDLINE_LINUX_DEFAULT="root=UUID=${ROOT_UUID} rootflags=subvol=@ pci=noaer acpi_backlight=vendor psi=1 i8042.nopnp usbcore.autosuspend=-1 apparmor=1 security=apparmor vt.global_cursor_default=0 rd.systemd.show_status=auto i915.enable_psr=0 i915.modeset=1 i915.enable_rc6=1 i915.enable_fbc=1 i915.fastboot=1 i915.enable_dc=0 intel_idle.max_cstate=1 zswap.enabled=1 zswap.compressor=lz4 zswap.zpool=z3fold nomodeset intel_iommu=off reboot=pci acpi=off"
GRUB_DISABLE_OS_PROBER=false
GRUB_ENABLE_BLSCFG=true
EOF

chroot /mnt update-grub

chroot /mnt efibootmgr

rm -rf /mnt/vmlinuz.old
rm -rf /mnt/vmlinuz
rm -rf /mnt/initrd.img
rm -rf /mnt/initrd.img.old
rm -rf /mnt/debootstrap

# Config zram para otimização RAM (50% da RAM como swap comprimido, prioridade alta)
# cat <<EOF > /mnt/etc/default/zramswap
# ALLOCATION=50
# PRIORITY=100
# COMPRESSION_ALGORITHM=lz4
# SWAPPINESS=150  # Mais agressivo para usar zram antes de swap disco
# EOF

# chroot /mnt systemctl enable zramswap.service

# # Configuração extra para hibernação (force resume service)
# chroot /mnt systemctl enable systemd-hibernate-resume.service

# echo "Instalação concluída com todas as otimizações para MacBook Air 4,1, incluindo swapfile!"
# echo "Kernel Liquorix instalado como default. Reinicie e selecione no GRUB se necessário."
# echo "Teste hibernação com: systemctl hibernate"
# echo "Verifique swap: swapon -s (deve mostrar zram + /swap/swapfile)"
# echo "Para bateria: sudo tlp-stat -b"