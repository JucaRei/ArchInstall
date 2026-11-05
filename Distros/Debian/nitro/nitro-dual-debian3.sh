#!/usr/bin/env bash
# set -euo pipefail
# IFS=$'\n\t'
# This catches errors, undefined vars, and pipeline failures immediately.

# ============================================================
# Sincronização de Data/Hora e Hostname no Ambiente Live
# ============================================================
echo "🕒 Sincronizando relógio do sistema para validação de assinaturas GPG/APT..."
if ! grep -q "127.0.1.1 nitro" /etc/hosts 2>/dev/null; then
    echo "127.0.1.1 nitro" >> /etc/hosts 2>/dev/null || true
fi

# Obter data e hora real via cabeçalho HTTP do deb.debian.org (evita erro 'Not live until' no sqv/apt)
timedatectl set-ntp true 2>/dev/null || true
HTTP_DATE=$(curl -sI --max-time 5 https://deb.debian.org 2>/dev/null | sed -n 's/^[dD]ate: //p' | tr -d '\r')
if [ -n "$HTTP_DATE" ]; then
    date -u -s "$HTTP_DATE" 2>/dev/null || true
    hwclock --systohc 2>/dev/null || true
fi

#### Update and install needed packages ####
apt update && apt install debootstrap btrfs-progs lsb-release wget exfatprogs gdisk curl gnupg -y
# apt update && apt install mmdebstrap btrfs-progs lsb-release wget -y

#### update fastest repo's
apt update

#####################################
####Gptfdisk Partitioning example####
#####################################

# Variables
hostname="nitro"
name="Developer Machine"
username="juca"
Architecture="amd64"
CODENAME=trixie #$(lsb_release --codename --short) # or CODENAME=bookworm

# ============================================================
# Disco NVMe e Partições (Acer Nitro 5 AN515-52)
# ============================================================
DRIVE="/dev/nvme0n1"

EFI_PART="${DRIVE}p1"
SYSTEM_PART="${DRIVE}p2"
ROOT_PART="${DRIVE}p7"
# MISC_PART="${DRIVE}p7"

MOUNTPOINT="/mnt"
ROOT_LABEL="Debian"
EFI_LABEL="ESP"
SYSTEM_LABEL="BOOT"
MISC_LABEL="SharedData"

# Opções Btrfs otimizadas para SSD NVMe (balanceadas: zstd:3 para sistema/compressão e zstd:1 para dados)
BTRFS_SYS="noatime,ssd,compress=zstd:3,space_cache=v2,commit=120,discard=async"
BTRFS_OPTS="noatime,ssd,compress=zstd:1,space_cache=v2,commit=120,discard=async"
BTRFS_OPTS_MAX="noatime,ssd,compress=zstd:3,space_cache=v2,commit=120,discard=async"
BTRFS_OPTS_SWAP="noatime,ssd,space_cache=v2,commit=120,discard=async"

echo "Disable SELinux temporarily..."
# setenforce 0 # disable SELInux for now

# ============================================================
# Particionamento (UEFI-only — sem BIOS Boot)
# Acer Nitro 5 AN515-52 roda em UEFI puro. Partição BIOS Boot (EF02)
# NÃO é necessária e só consome espaço / confunde o particionamento.
#
# Layout:
# 1: ESP (EFI System Partition) — FAT32 — 600 MB
# 2: BOOT (Kernel + initramfs)  — ext4  — 1 GB
# 3: Btrfs (Pool único)         — btrfs — 300 GB
# 4: SharedData                 — exFAT — restante do disco
# ============================================================
echo "🔪 Particionando $DRIVE..."
# sgdisk --zap-all "$DRIVE"
# sgdisk -n 1:0:+600M    -t 1:EF00 -c 1:"EFI System Partition"   "$DRIVE"
# sgdisk -n 2:0:+1G      -t 2:8301 -c 2:"SYSTEM RESERVED"        "$DRIVE"
# sgdisk -n 6:0:+0       -t 6:8300 -c 3:"Debian Btrfs Pool"      "$DRIVE"
# sgdisk -n 4:0:0        -t 4:0700 -c 4:"Shared exFAT Data"      "$DRIVE"

sgdisk   -c 6:"Debian Btrfs Pool"      "$DRIVE"
sgdisk   -p "$DRIVE"

# ============================================================
# Formatação
# ============================================================
echo "🧼 Formatando partições..."
# mkfs.fat  -F32 -n "$EFI_LABEL"    "$EFI_PART"
# mkfs.ext4 -F   -L "$SYSTEM_LABEL" "$SYSTEM_PART"
mkfs.btrfs -f  -L "$ROOT_LABEL"   "$ROOT_PART"
# mkfs.exfat     -n "$MISC_LABEL"   "$MISC_PART"

udevadm trigger
echo "Partições formatadas com sucesso em $DRIVE."

# ============================================================
# Subvolumes Btrfs — Sistema (Pool único de 300 GB)
# ============================================================
echo "📂 Criando subvolumes Btrfs (pool único de 300 GB)..."
mount "$ROOT_PART" "$MOUNTPOINT"
for sv in @root @home @nix @cache @opt @gdm @libvirt @containers @spool @log @tmp @apt @snapshots @swap; do
  btrfs subvolume create "$MOUNTPOINT/$sv"
done
umount -Rv "$MOUNTPOINT"

# ============================================================
# Montagem de todos os subvolumes
# ============================================================
echo "🔗 Montando subvolumes..."
mount -o "$BTRFS_SYS,subvol=@root" "$ROOT_PART" "$MOUNTPOINT"

# Criar estrutura de diretórios
mkdir -pv "$MOUNTPOINT"/{boot/efi,home,nix,opt,.snapshots,media/juca/SharedData,var/{tmp,spool,log,cache,swap,lib/{libvirt,containers,gdm}}}

# Montar todos os subvolumes
mount -o "$BTRFS_OPTS,subvol=@home"          "$ROOT_PART" "$MOUNTPOINT/home"
mount -o "$BTRFS_OPTS,subvol=@nix"           "$ROOT_PART" "$MOUNTPOINT/nix"
mount -o "$BTRFS_OPTS_MAX,subvol=@opt"       "$ROOT_PART" "$MOUNTPOINT/opt"
mount -o "$BTRFS_OPTS,subvol=@gdm"           "$ROOT_PART" "$MOUNTPOINT/var/lib/gdm"
mount -o "$BTRFS_OPTS,subvol=@log"           "$ROOT_PART" "$MOUNTPOINT/var/log"
mount -o "$BTRFS_OPTS,subvol=@spool"         "$ROOT_PART" "$MOUNTPOINT/var/spool"
mount -o "$BTRFS_OPTS,subvol=@tmp"           "$ROOT_PART" "$MOUNTPOINT/var/tmp"
mount -o "$BTRFS_OPTS,subvol=@cache"         "$ROOT_PART" "$MOUNTPOINT/var/cache"
# Criar ponto de montagem do @apt DENTRO de /var/cache após a montagem do @cache
mkdir -pv "$MOUNTPOINT/var/cache/apt"
mount -o "$BTRFS_OPTS,subvol=@apt"           "$ROOT_PART" "$MOUNTPOINT/var/cache/apt"
mount -o "$BTRFS_OPTS_MAX,subvol=@snapshots" "$ROOT_PART" "$MOUNTPOINT/.snapshots"
mount -o "$BTRFS_OPTS_SWAP,subvol=@swap"     "$ROOT_PART" "$MOUNTPOINT/var/swap"

# Libvirt e Containers: desativar CoW para performance de I/O de VMs e containers
mount -o "$BTRFS_OPTS,subvol=@libvirt"    "$ROOT_PART" "$MOUNTPOINT/var/lib/libvirt"
mount -o "$BTRFS_OPTS,subvol=@containers" "$ROOT_PART" "$MOUNTPOINT/var/lib/containers"
chattr +C "$MOUNTPOINT/var/lib/libvirt"
chattr +C "$MOUNTPOINT/var/lib/containers"
chattr +C "$MOUNTPOINT/var/swap"

# Boot e EFI
mount "$SYSTEM_PART" "$MOUNTPOINT/boot"
mkdir -pv "$MOUNTPOINT/boot/efi"
mount -t vfat -o defaults,noatime,nodiratime "$EFI_PART" "$MOUNTPOINT/boot/efi"

# ============================================================
# Swapfile no SSD (Comentado — utilizando exclusivamente zRAM)
# ============================================================
# echo "💾 Criando Swapfile de 16 GB..."
# btrfs filesystem mkswapfile --size 16g "$MOUNTPOINT/var/swap/swapfile"
# chmod 600 "$MOUNTPOINT/var/swap/swapfile"
echo "Subvolumes e boot partition montados com sucesso."

####################################################
#### Install tarball debootstrap to the mount / ####
####################################################

debootstrap \
  --variant=minbase \
  --include=apt,uidmap,bash,btrfs-compsize,btrfs-progs,duperemove,zsh,nano,extrepo,cpio,net-tools,locales,console-setup,perl-openssl-defaults,apt-utils,dosfstools,debconf-utils,wget,curl,tzdata,keyboard-configuration,zstd,ca-certificates,debian-archive-keyring,apt-transport-tor,xz-utils,kmod,gdisk,ncurses-base,systemd,udev,init,iproute2,iputils-ping \
  --arch=${Architecture} \
  ${CODENAME} /mnt \
  "http://debian.c3sl.ufpr.br/debian/ ${CODENAME} contrib non-free non-free-firmware"

########################################################
#### Mount points for chroot, just like arch-chroot ####
########################################################

# Bind essential virtual filesystems
for dir in dev proc sys run; do
    mount --rbind /$dir /mnt/$dir
    mount --make-rslave /mnt/$dir
done

# Ensure devpts is mounted for pseudo-terminal support
mount -t devpts devpts /mnt/dev/pts

# Evitar diálogos interativos do debconf no chroot
export DEBIAN_FRONTEND=noninteractive

# Desativar PackageKit D-Bus durante a instalação no chroot para evitar erros no apt
mkdir -p /mnt/etc/apt/apt.conf.d
echo 'APT::PackageKit::Enable "false";' > /mnt/etc/apt/apt.conf.d/99no-packagekit

# Configurar locales e timezone imediatamente para evitar centenas de avisos de perl/locale
echo "America/Sao_Paulo" > /mnt/etc/timezone
ln -sf /usr/share/zoneinfo/America/Sao_Paulo /mnt/etc/localtime
sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /mnt/etc/locale.gen 2>/dev/null || true
sed -i -e 's/# pt_BR.UTF-8 UTF-8/pt_BR.UTF-8 UTF-8/' /mnt/etc/locale.gen 2>/dev/null || true
chroot /mnt locale-gen 2>/dev/null || true
chroot /mnt update-locale LANG=pt_BR.UTF-8 LC_ALL=pt_BR.UTF-8 2>/dev/null || true

chroot /mnt apt --fix-broken install --yes

######################
### Dracut Modules ###
######################
mkdir -pv /mnt/etc/dracut.conf.d

touch /mnt/etc/dracut.conf.d/10-debian.conf
cat <<EOF > /mnt/etc/dracut.conf.d/10-debian.conf
do_prelink="no"
hostonly="yes"
# add_dracutmodules+=" systemd tpm2 crypt resume btrfs "
add_dracutmodules+=" systemd "
# force_drivers+=" nvme ahci hid_generic iwlwifi "
early_microcode=yes
EOF

cat <<EOF >/mnt/etc/dracut.conf.d/selinux.conf
# force_drivers+=" securityfs selinuxfs "
EOF

cat <<EOF >/mnt/etc/dracut.conf.d/10-custom.conf
# Host-specific image
hostonly_cmdline="yes"

# Fast compression
compress="zstd -3"

# Don’t strip away any Plymouth bits
# (remove any omit_dracutmodules line for plymouth)
omit_dracutmodules+=" amdgpu "


# Limit to Btrfs root filesystem
# filesystems+=" resume btrfs "
filesystems+=" btrfs "

# Kernel command-line: enable SELinux, show splash, keep messages quiet
kernel_cmdline=" rootflags=subvol=@root rw quiet security=apparmor apparmor=1 lsm=landlock lockdown yama apparmor bpf "

# Ensure Plymouth theme files are embedded
# install_items+="/usr/share/plymouth/themes/solar/* \
#  /etc/plymouth/plymouthd.conf"

EOF

touch /mnt/etc/dracut.conf.d/input.conf
cat <<EOF >/mnt/etc/dracut.conf.d/input.conf
add_drivers+=" psmouse "
EOF

########################
#### Fastest Repo's ####
########################

rm /mnt/etc/apt/sources.list
touch /mnt/etc/apt/sources.list.d/debian.sources

### NEW WAY ###
cat >/mnt/etc/apt/sources.list.d/debian.sources <<HEREDOC
Types: deb deb-src
# URIs: https://deb.debian.org/debian/
URIs: http://debian.c3sl.ufpr.br/debian/
Suites: trixie
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

Types: deb deb-src
# URIs: https://deb.debian.org/debian/
URIs: http://debian.c3sl.ufpr.br/debian/
Suites: trixie-updates
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

Types: deb deb-src
# URIs: https://deb.debian.org/debian/
URIs: http://debian.c3sl.ufpr.br/debian/
Suites: trixie-backports
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

Types: deb deb-src
# URIs: http://deb.debian.org/debian/
URIs: http://debian.c3sl.ufpr.br/debian/
Suites: unstable
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

Types: deb deb-src
# URIs: http://deb.debian.org/debian/
URIs: http://debian.c3sl.ufpr.br/debian/
Suites: experimental
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
HEREDOC

# ============================================================
# Repositório MX Linux (fontes, chaves GPG e pinning)
# ============================================================
echo "📦 Configurando repositório e chaves do MX Linux..."

mkdir -p /mnt/usr/share/keyrings /mnt/etc/apt/trusted.gpg.d /mnt/etc/apt/sources.list.d /mnt/etc/apt/preferences.d

if [ ! -f /mnt/usr/share/keyrings/mx-25-archive-keyring.gpg ]; then
    echo "📦 Baixando pacote mx25-archive-keyring..."
    (curl -fsSL --insecure "https://mxrepo.com/mx/repo/pool/main/m/mx25-archive-keyring/mx25-archive-keyring_2025.03_all.deb" -o /tmp/mx25-keyring.deb || \
     wget -q --no-check-certificate "https://mxrepo.com/mx/repo/pool/main/m/mx25-archive-keyring/mx25-archive-keyring_2025.03_all.deb" -O /tmp/mx25-keyring.deb) 2>/dev/null && \
    dpkg-deb -x /tmp/mx25-keyring.deb /mnt/ 2>/dev/null || true
    rm -f /tmp/mx25-keyring.deb
fi

if [ ! -f /mnt/usr/share/keyrings/mx-25-archive-keyring.gpg ]; then
    echo "⚠️ Baixando chave MX Linux via keyserver / gpg..."
    gpg --no-default-keyring --keyring /tmp/mx-temp.gpg \
        --keyserver keyserver.ubuntu.com --recv-keys 7857E44E4EB89A4B 8B819E5171128B47 2>/dev/null || true
    if [ -f /tmp/mx-temp.gpg ]; then
        cp -f /tmp/mx-temp.gpg /mnt/usr/share/keyrings/mx-25-archive-keyring.gpg
        rm -f /tmp/mx-temp.gpg
    fi
fi

chmod -R a+rX /mnt/usr/share/keyrings /mnt/etc/apt/trusted.gpg.d 2>/dev/null || true

cat << 'MX_SOURCES_EOF' > /mnt/etc/apt/sources.list.d/mxlinux.sources
Types: deb
URIs: http://mxrepo.com/mx/repo/
Suites: trixie
Components: main non-free ahs
Signed-By: /usr/share/keyrings/mx-25-archive-keyring.gpg
MX_SOURCES_EOF

cat << 'MX_PREF_EOF' > /mnt/etc/apt/preferences.d/20mxlinux.pref
Package: *
Pin: origin mxrepo.com
Pin-Priority: 100
MX_PREF_EOF

# ============================================================
# Repositório XanMod Kernel (Atualizado para Trixie)
# ============================================================
echo "📦 Configurando repositório e chaves do XanMod Kernel..."
mkdir -p /mnt/etc/apt/keyrings /mnt/etc/apt/sources.list.d
(curl -fsSL https://dl.xanmod.org/archive.key || wget -qO - https://dl.xanmod.org/archive.key) | \
  gpg --dearmor --yes -o /mnt/etc/apt/keyrings/xanmod-archive-keyring.gpg 2>/dev/null || true
chmod 644 /mnt/etc/apt/keyrings/xanmod-archive-keyring.gpg 2>/dev/null || true

cat << EOF > /mnt/etc/apt/sources.list.d/xanmod.sources
Types: deb
URIs: https://deb.xanmod.org
Suites: ${CODENAME}
Components: main non-free
Architectures: amd64
Signed-By: /etc/apt/keyrings/xanmod-archive-keyring.gpg
EOF

######################################
#### Optimize apt package manager ####
######################################

mkdir -pv /mnt/etc/apt/apt.conf.d
touch /mnt/etc/apt/apt.conf.d/99norecommends
cat >/mnt/etc/apt/apt.conf.d/99norecommends <<HEREDOC
APT::Install-Recommends "0";
APT::Install-Suggests "0";
HEREDOC

touch /mnt/etc/apt/apt.conf.d/99assumeyes
cat >/mnt/etc/apt/apt.conf.d/99assumeyes <<HEREDOC
APT::Get::Assume-Yes "true";
HEREDOC

echo 'APT::Default-Release "trixie";' | tee /mnt/etc/apt/apt.conf.d/99default-release

mkdir -pv /mnt/etc/apt/preferences.d

touch /mnt/etc/apt/preferences.d/99stable.pref
touch /mnt/etc/apt/preferences.d/50testing.pref
touch /mnt/etc/apt/preferences.d/10unstable.pref
touch /mnt/etc/apt/preferences.d/1experimental.pref
touch /mnt/etc/apt/preferences.d/no-initramfs-tools

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

cat >/mnt/etc/apt/preferences.d/no-initramfs-tools <<HEREDOC
Package: initramfs-tools
Pin: release *
Pin-Priority: -1
HEREDOC


chroot /mnt apt update
chroot /mnt apt upgrade --yes

chroot /mnt apt install firmware-iwlwifi firmware-realtek firmware-misc-nonfree firmware-intel-graphics firmware-intel-misc firmware-intel-sound firmware-sof-signed intel-microcode --yes

chroot /mnt apt update

### Network
chroot /mnt apt install network-manager iwd wireless-regdb rfkill --yes

#########################
#### Setting Locales ####
#########################

chroot /mnt echo "America/Sao_Paulo" >/mnt/etc/timezone
chroot /mnt dpkg-reconfigure -f noninteractive tzdata
sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /mnt/etc/locale.gen
sed -i -e 's/# pt_BR.UTF-8 UTF-8/pt_BR.UTF-8 UTF-8/' /mnt/etc/locale.gen
chroot /mnt dpkg-reconfigure -f noninteractive locales
chroot /mnt apt update
touch /mnt/etc/vconsole.conf
echo 'KEYMAP="br-abnt2"' >/mnt/etc/vconsole.conf
echo 'KEYMAP_TOGGLE="us-intl"' >> /mnt/etc/vconsole.conf

chroot /mnt apt update

##############
#### sudo ####
##############

chroot /mnt apt install sudo -y

##############################
#### User's and passwords ####
##############################

chroot /mnt sh -c 'echo "root:200291" | chpasswd -c SHA512'
chroot /mnt useradd $username -m -c "Reinaldo P Jr" -s /bin/bash
chroot /mnt sh -c 'echo "juca:200291" | chpasswd -c SHA512'
chroot /mnt usermod -aG floppy,audio,sudo,video,systemd-journal,lp,cdrom,netdev,input,plugdev,libvirt,kvm $username
chroot /mnt usermod -aG sudo $username

chmod 755 /mnt/home/$username

chroot /mnt apt install --yes dbus-broker dbus-user-session libpam-systemd

chroot /mnt systemctl disable dbus-daemon.service 2>/dev/null || true
chroot /mnt systemctl enable dbus-broker.service 2>/dev/null || true


##################################################
#### Disable some features for optimal system ####
##################################################
########################################
#### real hardware modprobe modules ####
########################################

mkdir -pv /mnt/etc/modprobe.d
cat <<EOF >/mnt/etc/modprobe.d/blacklist.conf
install iTCO_wdt /bin/true
install iTCO_vendor_support /bin/true
blacklist evbug
blacklist usbmouse
blacklist usbkbd
blacklist eepro100
blacklist de4x5
blacklist eth1394
blacklist snd_aw2
blacklist bcm43xx
blacklist garmin_gps
EOF

cat <<EOF >/mnt/etc/modprobe.d/iwlwifi.conf
options iwlwifi enable_ini=0
options iwlwifi disable_11ac=0
options iwlwifi disable_11ax=0
EOF

mkdir -pv /mnt/etc/modules-load.d
touch /mnt/etc/modules-load.d/iptables.conf
cat << EOF > /mnt/etc/modules-load.d/iptables.conf
ip6_tables
ip6table_nat
ip_tables
iptable_nat
EOF

cat << EOF > /mnt/etc/modules-load.d/iwlwifi.conf
iwlwifi
EOF

#######################################
#### Kernel params for tune system ####
#######################################
#######################
#### real hardware ####
#######################

mkdir -pv /mnt/etc/sysctl.d
cat <<EOF >/mnt/etc/sysctl.d/00-swap.conf
vm.vfs_cache_pressure=100
vm.swappiness=100
vm.page-cluster=0
vm.dirty_background_ratio=1
vm.dirty_ratio=50
EOF

cat <<EOF >/mnt/etc/sysctl.d/10-conf.conf
net.ipv4.ping_group_range=0 2147483647
EOF

cat <<EOF >/mnt/etc/sysctl.d/10-intel.conf
dev.i915.perf_stream_paranoid=0
EOF

cat <<EOF >/mnt/etc/sysctl.d/10-console-messages.conf
kernel.printk = 4 4 1 7
EOF

cat <<EOF >/mnt/etc/sysctl.d/99-dmesg.conf
kernel.dmesg_restrict = 0
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

################--------------------------------
#### Update package manager ####
################--------------------------------

chroot /mnt apt update
chroot /mnt apt upgrade
chroot /mnt apt autoremove
chroot /mnt apt autoclean

######################
#### Set Hostname ####
######################

cat <<EOF >/mnt/etc/hostname
${hostname}
EOF

touch /mnt/etc/hosts
cat <<EOF >/mnt/etc/hosts
127.0.0.1   localhost
127.0.1.1   ${hostname}.localdomain ${hostname}
::1         localhost ip6-localhost ip6-loopback
ff02::1     ip6-allnodes
ff02::2     ip6-allrouters
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

BOOT_UUID=$(blkid -s UUID -o value $SYSTEM_PART)
# ============================================================
# Gerar /etc/fstab
# ============================================================
echo "📝 Gerando /etc/fstab..."
cat << EOF > "$MOUNTPOINT/etc/fstab"
LABEL=${ROOT_LABEL}    /                   btrfs rw,${BTRFS_SYS},subvol=@root                    0 0
LABEL=${ROOT_LABEL}    /home               btrfs rw,${BTRFS_OPTS},subvol=@home                   0 0
LABEL=${ROOT_LABEL}    /nix                btrfs rw,${BTRFS_OPTS},subvol=@nix                    0 0
LABEL=${ROOT_LABEL}    /.snapshots         btrfs rw,${BTRFS_OPTS_MAX},subvol=@snapshots          0 0
LABEL=${ROOT_LABEL}    /var/log            btrfs rw,${BTRFS_OPTS},subvol=@log                    0 0
LABEL=${ROOT_LABEL}    /var/tmp            btrfs rw,${BTRFS_OPTS},subvol=@tmp                    0 0
LABEL=${ROOT_LABEL}    /var/spool          btrfs rw,${BTRFS_OPTS},subvol=@spool                  0 0
LABEL=${ROOT_LABEL}    /var/cache          btrfs rw,${BTRFS_OPTS},subvol=@cache                  0 0
LABEL=${ROOT_LABEL}    /var/cache/apt      btrfs rw,${BTRFS_OPTS},subvol=@apt                    0 0
LABEL=${ROOT_LABEL}    /var/lib/libvirt    btrfs rw,${BTRFS_OPTS},subvol=@libvirt                0 0
LABEL=${ROOT_LABEL}    /var/lib/containers btrfs rw,${BTRFS_OPTS},subvol=@containers             0 0
LABEL=${ROOT_LABEL}    /var/lib/gdm        btrfs rw,${BTRFS_OPTS},subvol=@gdm                    0 0
LABEL=${ROOT_LABEL}    /opt                btrfs rw,${BTRFS_OPTS_MAX},subvol=@opt                0 0
LABEL=${ROOT_LABEL}    /var/swap           btrfs rw,${BTRFS_OPTS_SWAP},subvol=@swap              0 0
LABEL=${SYSTEM_LABEL}  /boot               ext4  rw,relatime                                     0 1
LABEL=${EFI_LABEL}     /boot/efi           vfat  defaults,noatime,nodiratime                     0 2
LABEL=${MISC_LABEL}    /media/juca/SharedData  exfat  defaults,nofail,uid=1000,gid=1000,dmask=0022,fmask=0133  0 0
tmpfs                  /tmp                tmpfs noatime,mode=1777,nosuid,nodev                  0 0
EOF

#####################################
#### Install additional packages ####
#####################################

##############
## AppArmor ##
##############

chroot /mnt apt install apparmor apparmor-utils auditd --no-install-recommends -y

mkdir -p /mnt/var/log/audit
chown root:root /mnt/var/log/audit
chmod 0700 /mnt/var/log/audit

#############
## Network ##
#############

chroot /mnt apt install gvfs gvfs-backends smbclient cifs-utils avahi-daemon openssh-client openssh-server -y

########################################################
#### Config iwd as backend instead of wpasupplicant ####
########################################################

mkdir -pv /mnt/etc/NetworkManager/conf.d /mnt/etc/systemd/system/NetworkManager.service.d
cat << 'NM_IWD_EOF' > /mnt/etc/systemd/system/NetworkManager.service.d/iwd.conf
[Unit]
After=iwd.service
Wants=iwd.service
NM_IWD_EOF

cat <<EOF >/mnt/etc/NetworkManager/conf.d/wifi_backend.conf
[device]
wifi.backend=iwd
wifi.iwd.autoconnect=yes
EOF

cat <<EOF >/mnt/etc/NetworkManager/conf.d/10-wlan.conf
[keyfile]
unmanaged-devices=none
EOF

mkdir -pv /mnt/etc/iwd
touch /mnt/etc/iwd/main.conf
cat <<EOF >/mnt/etc/iwd/main.conf
[General]
EnableNetworkConfiguration=false
EOF

##################
### SOCKET RAW ###
##################

mkdir -pv /mnt/usr/lib/sysctl.d
touch /mnt/usr/lib/sysctl.d/50-default.conf
echo "-net.ipv4.ping_group_range = 0 2147483647" >> /mnt/usr/lib/sysctl.d/50-default.conf

###############
#### Audio ####
###############

chroot /mnt apt install pipewire-audio wireplumber pipewire-pulse pipewire-alsa libspa-0.2-bluetooth libspa-0.2-jack -y

chroot /mnt systemctl --user enable wireplumber.service 2>/dev/null || true
chroot /mnt systemctl --user disable pulseaudio.service pulseaudio.socket 2>/dev/null || true
chroot /mnt systemctl --user mask pulseaudio 2>/dev/null || true
chroot /mnt systemctl --user enable pipewire pipewire-pulse 2>/dev/null || true

chroot /mnt apt install rtkit -y

###############
#### Utils ####
###############
chroot /mnt apt install gdisk acpi acpid bash-completion pciutils debian-keyring xz-utils htop wget unzip sysfsutils -y

##############
### Polkit ###
##############
chroot /mnt apt install -y polkitd pkexec udisks2 udisks2-btrfs dconf-cli dconf-gsettings-backend acl xdg-user-dirs

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
/* Log authorization checks. */
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

chmod 644 /mnt/etc/polkit-1/rules.d/10-udisks2.rules \
  /mnt/etc/polkit-1/rules.d/10-commands.rules \
  /mnt/etc/polkit-1/rules.d/10-logs.rules

chown root:root /mnt/etc/polkit-1/rules.d/10-udisks2.rules \
  /mnt/etc/polkit-1/rules.d/10-commands.rules \
  /mnt/etc/polkit-1/rules.d/10-logs.rules

cat >/mnt/etc/sudoers.d/sysctl <<HEREDOC
${username} ALL = NOPASSWD: /bin/systemctl
HEREDOC

chroot /mnt apt install software-properties-common apt-transport-https ca-certificates curl gnupg -y

############
### BOOT ###
############
chroot /mnt apt install shim-signed grub-efi-amd64-signed mokutil sbsigntool efibootmgr os-prober -y

############
### TIME ###
############
chroot /mnt apt install chrony -y

#############################
#### Optimizations Tools ####
#############################

chroot /mnt apt install earlyoom powertop tlp thermald irqbalance systemd-zram-generator -y
chroot /mnt systemctl enable earlyoom
chroot /mnt systemctl enable powertop
chroot /mnt systemctl enable tlp
chroot /mnt systemctl enable thermald
chroot /mnt systemctl enable irqbalance

mkdir -pv /mnt/etc/systemd /mnt/etc/sysctl.d
cat <<EOF >/mnt/etc/systemd/zram-generator.conf
[zram0]
zram-size = ram * 3
compression-algorithm = zstd
swap-priority = 100
EOF

cat <<EOF >/mnt/etc/sysctl.d/99-zram.conf
vm.swappiness = 180
vm.watermark_boost_factor = 0
vm.watermark_scale_factor = 125
vm.page-cluster = 0
EOF

# ============================================================
# Xorg, LightDM e BSPWM
# ============================================================
echo "🖥️ Instalando Xorg, LightDM, GTK Greeter e utilitários de exibição..."
chroot /mnt apt install -y \
    xserver-xorg \
    xserver-xorg-video-intel \
    xserver-xorg-input-libinput \
    x11-xserver-utils \
    xinit \
    xauth \
    xinput \
    xterm \
    lightdm \
    lightdm-gtk-greeter \
    lightdm-gtk-greeter-settings \
    libpam-gnome-keyring \
    xwayland || true

echo "⚙️ Configurando LightDM e sessão BSPWM..."
mkdir -p /mnt/etc/lightdm /mnt/etc/lightdm/lightdm.conf.d /mnt/usr/share/xsessions /mnt/usr/local/bin

cat << 'LIGHTDM_CONF_EOF' > /mnt/etc/lightdm/lightdm.conf
[LightDM]
run-directory=/run/lightdm

[Seat:*]
greeter-session=lightdm-gtk-greeter
user-session=bspwm
session-wrapper=/etc/X11/Xsession
greeter-hide-users=false
logind-check-graphical=true
LIGHTDM_CONF_EOF

cat << 'LIGHTDM_USERS_EOF' > /mnt/etc/lightdm/users.conf
[UserList]
minimum-uid=1000
hidden-users=nobody nobody4 noaccess nixbld1 nixbld2 nixbld3 nixbld4 nixbld5 nixbld6 nixbld7 nixbld8 nixbld9 nixbld10 nixbld11 nixbld12 nixbld13 nixbld14 nixbld15 nixbld16 nixbld17 nixbld18 nixbld19 nixbld20 nixbld21 nixbld22 nixbld23 nixbld24 nixbld25 nixbld26 nixbld27 nixbld28 nixbld29 nixbld30 nixbld31 nixbld32
hidden-shells=/bin/false /usr/sbin/nologin /sbin/nologin
LIGHTDM_USERS_EOF

cat << 'LIGHTDM_GREETER_EOF' > /mnt/etc/lightdm/lightdm-gtk-greeter.conf
[greeter]
background=#1e1e2e
theme-name=Adwaita-dark
icon-theme-name=Papirus-Dark
font-name=Inter 10
xft-antialias=true
xft-hintstyle=hintslight
xft-rgba=rgb
clock-format=%a, %d %b %H:%M
indicators=~host;~spacer;~clock;~spacer;~layout;~session;~power
default-user-image=#avatar-default
hide-user-image=false
position=50%,center 50%,center
LIGHTDM_GREETER_EOF

cat << 'BSPWM_DESKTOP_EOF' > /mnt/usr/share/xsessions/bspwm.desktop
[Desktop Entry]
Name=BSPWM
Comment=Binary Space Partitioning Window Manager
Exec=bspwm
Type=Application
DesktopNames=bspwm
BSPWM_DESKTOP_EOF

mkdir -p /mnt/home/$username
cat << 'DMRC_EOF' > /mnt/home/$username/.dmrc
[Desktop]
Session=bspwm
DMRC_EOF
chown $username:$username /mnt/home/$username/.dmrc 2>/dev/null || true
chmod 644 /mnt/home/$username/.dmrc 2>/dev/null || true

mkdir -pv /mnt/etc/X11/xorg.conf.d/
touch /mnt/etc/X11/xorg.conf.d/30-touchpad.conf
cat <<EOF >/mnt/etc/X11/xorg.conf.d/30-touchpad.conf
Section "InputClass"
    Identifier          "libinput touchpad catchall"
    Driver              "libinput"
    MatchIsTouchpad     "on"
    MatchDevicePath     "/dev/input/event*"
    Option              "Tapping"   			                "on"
    Option 		          "NaturalScrolling" 			          "true"
EndSection
EOF

touch /mnt/etc/rc.local
cat <<EOF >/mnt/etc/rc.local
#PowerTop
powertop --auto-tune
EOF

chroot /mnt apt install -y bluez blueman solaar snapd flatpak

# ============================================================
# Virt-Manager, QEMU/KVM e Libvirt (Nativo)
# ============================================================
echo "🖥️ Instalando e configurando Virt-Manager, QEMU/KVM e Libvirt..."
chroot /mnt apt install -y \
  virt-manager \
  qemu-system \
  libvirt-daemon-system \
  ovmf \
  swtpm \
  swtpm-tools \
  qemu-utils \
  bridge-utils \
  dnsmasq-base \
  spice-vdagent \
  gir1.2-spiceclientgtk-3.0 \
  virtinst

if [ -f /mnt/etc/libvirt/qemu.conf ]; then
  sed -i -E 's/^[# ]*user[ ]*=.*/user = "'"$username"'"/' /mnt/etc/libvirt/qemu.conf
  sed -i -E 's/^[# ]*group[ ]*=.*/group = "'"$username"'"/' /mnt/etc/libvirt/qemu.conf
  if ! grep -q '^user = "'"$username"'"' /mnt/etc/libvirt/qemu.conf; then
    cat << EOF >> /mnt/etc/libvirt/qemu.conf
user = "$username"
group = "$username"
EOF
  fi
else
  mkdir -p /mnt/etc/libvirt
  cat << EOF > /mnt/etc/libvirt/qemu.conf
user = "$username"
group = "$username"
EOF
fi

mkdir -p /mnt/etc/polkit-1/rules.d
cat << 'POLKIT_LIBVIRT_EOF' > /mnt/etc/polkit-1/rules.d/80-libvirt.rules
polkit.addRule(function(action, subject) {
  if (action.id.indexOf("org.libvirt") == 0 && subject.isInGroup("libvirt")) {
    return polkit.Result.YES;
  }
});
POLKIT_LIBVIRT_EOF
chmod 644 /mnt/etc/polkit-1/rules.d/80-libvirt.rules

# ============================================================
# Nix Daemon Setup
# ============================================================
echo "❄️ Configurando Nix Daemon e permissões de usuário..."
chroot /mnt apt install -y nix-bin nix-setup-systemd

chroot /mnt groupadd -r nixbld 2>/dev/null || true
chroot /mnt groupadd -r nix-users 2>/dev/null || true
chroot /mnt usermod -aG nixbld,nix-users $username

chown root:root /mnt/nix /mnt/nix/var /mnt/nix/var/nix /mnt/nix/var/nix/profiles /mnt/nix/var/nix/gcroots 2>/dev/null || true
chmod 755 /mnt/nix /mnt/nix/var /mnt/nix/var/nix /mnt/nix/var/nix/profiles /mnt/nix/var/nix/gcroots 2>/dev/null || true
mkdir -p /mnt/nix/store /mnt/nix/var/nix/daemon-socket /mnt/nix/var/nix/profiles/per-user /mnt/nix/var/nix/gcroots/per-user
chown root:nixbld /mnt/nix/store 2>/dev/null || true
chmod 1775 /mnt/nix/store 2>/dev/null || true
chown root:nix-users /mnt/nix/var/nix/daemon-socket 2>/dev/null || true
chmod 0777 /mnt/nix/var/nix/daemon-socket 2>/dev/null || true
chmod 1777 /mnt/nix/var/nix/profiles/per-user /mnt/nix/var/nix/gcroots/per-user 2>/dev/null || true

mkdir -p /mnt/etc/systemd/system/nix-daemon.socket.d /mnt/etc/tmpfiles.d
cat << 'NIX_SOCK_OVERRIDE_EOF' > /mnt/etc/systemd/system/nix-daemon.socket.d/override.conf
[Socket]
SocketMode=0666
SocketUser=root
SocketGroup=nix-users
NIX_SOCK_OVERRIDE_EOF

cat << 'NIX_SOCK_TMPFILES_EOF' > /mnt/etc/tmpfiles.d/nix-daemon-socket.conf
d /nix/var/nix/daemon-socket 0777 root nix-users -
d /nix/var/nix/profiles/per-user 1777 root root -
d /nix/var/nix/gcroots/per-user 1777 root root -
NIX_SOCK_TMPFILES_EOF
chroot /mnt systemd-tmpfiles --create /etc/tmpfiles.d/nix-daemon-socket.conf 2>/dev/null || true

mkdir -p /mnt/etc/nix
cat << 'NIX_CONF_EOF' > /mnt/etc/nix/nix.conf
build-users-group = nixbld
trusted-users = root juca @nixbld @nix-users
allowed-users = *
experimental-features = nix-command flakes
max-jobs = auto
cores = 0
NIX_CONF_EOF

chroot /mnt systemctl enable nix-daemon.service

# ============================================================
# Instalação do Kernel (LLVM + Debian + XanMod)
# ============================================================
echo "🐧 Instalando dependências LLVM, Kernels e Bootloader..."
chroot /mnt apt update || true

# Instala toolchain LLVM/Clang (exigida pelo XanMod para compilação DKMS) + Kernels
chroot /mnt apt install -y --no-install-recommends dkms libelf-dev clang lld llvm
chroot /mnt apt install -y linux-image-amd64 linux-headers-amd64 intel-microcode dracut dracut-core
chroot /mnt apt install -y linux-xanmod-x64v3 || echo "⚠️ Aviso: Repositório XanMod temporariamente indisponível; utilizando kernel Debian padrão."

# ============================================================
# Configuração de Secure Boot e Chaves MOK
# ============================================================
echo "🔐 Configurando Secure Boot e chaves MOK..."
chroot /mnt mkdir -p /root/secureboot-keys
chroot /mnt bash -c '
  if [ ! -f /root/secureboot-keys/MOK.key ]; then
    openssl req -new -x509 -newkey rsa:2048 \
      -keyout /root/secureboot-keys/MOK.key \
      -out    /root/secureboot-keys/MOK.crt \
      -nodes -days 36500 -subj "/CN=My Kernel Module Signing/"
    openssl x509 -in /root/secureboot-keys/MOK.crt -outform DER -out /root/secureboot-keys/MOK.der
  fi
'

printf "200291\n200291\n" | chroot /mnt mokutil --import /root/secureboot-keys/MOK.der || true

chroot /mnt bash -c '
  for kver in $(ls /lib/modules 2>/dev/null); do
    vmlinuz="/boot/vmlinuz-${kver}"
    if [ -f "$vmlinuz" ]; then
      sbsign --key /root/secureboot-keys/MOK.key --cert /root/secureboot-keys/MOK.crt --output "${vmlinuz}.signed" "$vmlinuz"
      mv -f "${vmlinuz}.signed" "$vmlinuz"
    fi
  done
'

mkdir -pv /mnt/etc/dkms/post-build.d
cat << 'EOF' > /mnt/etc/dkms/post-build.d/99-sign-with-mok
#!/bin/bash
KEY=/root/secureboot-keys/MOK.key
DER=/root/secureboot-keys/MOK.der
sf=$(find /usr/src/linux-headers-*/scripts -name sign-file 2>/dev/null | head -n1)
[ -x "$sf" ] || exit 0
find /lib/modules -type f -name '*.ko' -print0 2>/dev/null | \
  xargs -0 -I{} "$sf" sha256 "$KEY" "$DER" "{}"
EOF
chmod +x /mnt/etc/dkms/post-build.d/99-sign-with-mok

# ============================================================
# Driver NVIDIA Proprietário e DKMS
# ============================================================
echo "🎮 Instalando Driver NVIDIA e utilitários de vídeo..."
chroot /mnt apt install -y \
  nvidia-driver \
  nvidia-smi \
  nvidia-settings \
  nvidia-vulkan-icd \
  libcuda1 \
  libnvcuvid1 \
  intel-media-va-driver-non-free \
  vainfo \
  mesa-va-drivers \
  mpv

chroot /mnt bash -c '
  for kver in $(ls /lib/modules 2>/dev/null); do
    dkms autoinstall -k "$kver" || true
  done
  /etc/dkms/post-build.d/99-sign-with-mok || true
'

# ============================================================
# Geração de Initramfs via Dracut e Instalação do GRUB
# ============================================================
echo "📦 Gerando initramfs via Dracut e configurando GRUB..."
for kver in $(ls /mnt/lib/modules 2>/dev/null); do
  chroot /mnt dracut --kver "$kver" --force
done

cat <<EOF >/mnt/etc/default/grub
GRUB_DEFAULT=saved
GRUB_TIMEOUT=5
GRUB_DISABLE_SUBMENU=false
GRUB_DISTRIBUTOR=\$(lsb_release -i -s 2>/dev/null || echo Debian)
GRUB_DISABLE_OS_PROBER=false
GRUB_CMDLINE_LINUX_DEFAULT="rhgb quiet intel_iommu=on iommu=pt i915.enable_psr=0 i915.enable_fbc=1 nvidia-drm.modeset=1 msr.allow_writes=on nowatchdog split_lock_detect=off apparmor=1 security=apparmor"
GRUB_DISABLE_RECOVERY="true"
GRUB_GFXMODE=1920x1080x32
GRUB_COLOR_NORMAL="light-blue/black"
GRUB_COLOR_HIGHLIGHT="light-cyan/blue"
EOF

chroot /mnt grub-install \
  --target=x86_64-efi \
  --efi-directory=/boot/efi \
  --bootloader-id=debian \
  --recheck

chroot /mnt update-grub
chroot /mnt efibootmgr

chroot /mnt apt install extrepo -y
chroot /mnt apt autoremove --purge -y
chroot /mnt apt clean
chroot /mnt apt autoclean

rm -rf /mnt/vmlinuz.old /mnt/vmlinuz /mnt/initrd.img /mnt/initrd.img.old /mnt/debootstrap

# ============================================================
# Hook de Retenção de Kernels (Máximo 3 versões)
# ============================================================
echo "🧹 Configurando hook de retenção de kernels..."
mkdir -p /mnt/usr/local/sbin /mnt/etc/apt/apt.conf.d /mnt/etc/kernel/postinst.d

cat << 'TRIM_KERNELS_EOF' > /mnt/usr/local/sbin/trim-kernels
#!/bin/bash
set -euo pipefail
MAX_KERNELS=3
LOCK_FILE="/run/lock/trim-kernels.lock"
log() { echo "trim-kernels: $*"; logger -t trim-kernels "$*" 2>/dev/null || true; }
exec 200>"$LOCK_FILE"
flock -n 200 || exit 0
CURRENT_KERNEL="$(uname -r)"
INSTALLED_IMAGES=$(dpkg-query -W -f='${Package} ${Status}\n' 'linux-image-[0-9]*' 2>/dev/null | grep -E ' (installed|half-configured)$' | awk '{print $1}' || true)
[ -z "$INSTALLED_IMAGES" ] && exit 0
VERSIONS=()
for pkg in $INSTALLED_IMAGES; do ver="${pkg#linux-image-0}"; VERSIONS+=("$ver"); done
TOTAL_KERNELS="${#VERSIONS[@]}"
[ "$TOTAL_KERNELS" -le "$MAX_KERNELS" ] && exit 0
SORTED_VERSIONS=($(printf "%s\n" "${VERSIONS[@]}" | sort -V -r))
KEEP=("$CURRENT_KERNEL")
for ver in "${SORTED_VERSIONS[@]}"; do
    if [ "${#KEEP[@]}" -ge "$MAX_KERNELS" ]; then break; fi
    already_kept=false
    for k in "${KEEP[@]}"; do [ "$k" = "$ver" ] && already_kept=true; done
    [ "$already_kept" = false ] && KEEP+=("$ver")
done
PKGS_TO_PURGE=()
for ver in "${SORTED_VERSIONS[@]}"; do
    keep_this=false
    for k in "${KEEP[@]}"; do [ "$k" = "$ver" ] && keep_this=true; done
    if [ "$keep_this" = false ]; then
        for p in "linux-image-$ver" "linux-headers-$ver"; do
            dpkg-query -W -f='${Status}' "$p" 2>/dev/null | grep -qE "installed|half-configured" && PKGS_TO_PURGE+=("$p")
        done
    fi
done
[ "${#PKGS_TO_PURGE[@]}" -eq 0 ] && exit 0
DEBIAN_FRONTEND=noninteractive apt-get purge -y "${PKGS_TO_PURGE[@]}"
TRIM_KERNELS_EOF
chmod +x /mnt/usr/local/sbin/trim-kernels

cat << 'APT_HOOK_EOF' > /mnt/etc/apt/apt.conf.d/99trim-kernels
DPkg::Post-Invoke { "command -v systemd-run >/dev/null 2>&1 && systemd-run --no-block /usr/local/sbin/trim-kernels || true"; };
APT_HOOK_EOF

cat << 'KERNEL_HOOK_EOF' > /mnt/etc/kernel/postinst.d/zz-trim-kernels
#!/bin/sh
command -v systemd-run >/dev/null 2>&1 && systemd-run --no-block /usr/local/sbin/trim-kernels
exit 0
KERNEL_HOOK_EOF
chmod +x /mnt/etc/kernel/postinst.d/zz-trim-kernels

# ============================================================
# Scripts de Validação de Assinaturas e Secure Boot
# ============================================================
cat << 'EOF' >/mnt/usr/local/bin/check-kernel-signatures.sh
#!/bin/bash
echo " [Kernels Instalados] Verificando assinaturas..."
for k in /boot/vmlinuz-*; do
    [ -f "$k" ] || continue
    KERNEL_NAME=$(basename "$k")
    echo ""
    echo " Verificando $KERNEL_NAME..."
    if sbverify --list "$k" 2>/dev/null | grep -q "CN=My Kernel Module Signing"; then
        echo " $KERNEL_NAME está assinado corretamente com sua chave MOK"
    else
        echo " $KERNEL_NAME NÃO está assinado ou tem assinatura inválida"
    fi
done
EOF
chmod +x /mnt/usr/local/bin/check-kernel-signatures.sh

cat << 'EOF' >/mnt/usr/local/bin/check-secureboot.sh
#!/bin/bash
echo " [Secure Boot] Verificando status..."
if mokutil --sb-state 2>/dev/null | grep -q "SecureBoot enabled"; then
    echo " Secure Boot está ATIVADO"
else
    echo " Secure Boot está DESATIVADO"
fi
echo ""
echo " [Shim/GRUB] Verificando binários EFI..."
EFI_DIR="/boot/efi/EFI/debian"
for bin in shimx64.efi grubx64.efi; do
    if sbverify --list "$EFI_DIR/$bin" &>/dev/null; then
        echo " $bin está assinado corretamente"
    else
        echo " $bin NÃO está assinado ou está corrompido"
    fi
done
echo ""
echo " [DKMS] Verificando módulos DKMS..."
FOUND_DKMS=false
for kver in $(ls /lib/modules 2>/dev/null); do
    DKMS_DIR="/lib/modules/${kver}/updates/dkms"
    if [ -d "$DKMS_DIR" ]; then
        FOUND_DKMS=true
        echo " Módulos para kernel $kver:"
        for mod in "$DKMS_DIR"/*.ko*; do
            [ -f "$mod" ] || continue
            if modinfo "$mod" 2>/dev/null | grep -q "signer"; then
                echo "  $(basename "$mod") está assinado"
            else
                echo "  $(basename "$mod") NÃO está assinado"
            fi
        done
    fi
done
[ "$FOUND_DKMS" = false ] && echo "ℹ Nenhum módulo DKMS encontrado em /lib/modules"
EOF
chmod +x /mnt/usr/local/bin/check-secureboot.sh

echo "🔍 Executando verificação final de assinaturas e Secure Boot..."
chroot /mnt /usr/local/bin/check-kernel-signatures.sh || true
chroot /mnt /usr/local/bin/check-secureboot.sh || true

echo "✨ Script executado e corrigido com sucesso!"
