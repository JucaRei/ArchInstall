#!/usr/bin/env bash
# set -euo pipefail
# IFS=$'\n\t'
# This catches errors, undefined vars, and pipeline failures immediately.

# ============================================================
# Sincronização de Data/Hora e Hostname no Ambiente Live
# ============================================================
echo "🕒 Sincronizando relógio do sistema para validação de assinaturas GPG/APT..."
if ! grep -q "127.0.1.1 virtualvm" /etc/hosts 2>/dev/null; then
    echo "127.0.1.1 virtualvm" >> /etc/hosts 2>/dev/null || true
fi

# Obter data e hora real via cabeçalho HTTP do deb.debian.org (evita erro 'Not live until' no sqv/apt)
timedatectl set-ntp true 2>/dev/null || true
HTTP_DATE=$(curl -sI --max-time 5 https://deb.debian.org 2>/dev/null | sed -n "s/^[dD]ate: //p" | tr -d "
")
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
hostname="virtualvm"
name="Testing Machine"
username="juca"
Architecture="amd64"
CODENAME=trixie #$(lsb_release --codename --short) # or CODENAME=bookworm

# ============================================================
# Disco NVMe e Partições (virtualvm)
# ============================================================
DRIVE="/dev/vda"

EFI_PART="${DRIVE}1"
SYSTEM_PART="${DRIVE}2"
ROOT_PART="${DRIVE}3"
# MISC_PART="${DRIVE}4"

MOUNTPOINT="/mnt"
ROOT_LABEL="Debian"
EFI_LABEL="ESP"
SYSTEM_LABEL="BOOT"
# MISC_LABEL="SharedData"

# Opções Btrfs otimizadas para SSD NVMe (balanceadas: zstd:3 para sistema/compressão e zstd:1 para dados)
BTRFS_SYS="noatime,ssd,compress=zstd:3,space_cache=v2,commit=120,discard=async"
BTRFS_OPTS="noatime,ssd,compress=zstd:1,space_cache=v2,commit=120,discard=async"
BTRFS_OPTS_MAX="noatime,ssd,compress=zstd:6,space_cache=v2,commit=120,discard=async"
BTRFS_OPTS_SWAP="noatime,ssd,space_cache=v2,commit=120,discard=async"

echo "Disable SELinux temporarily..."
# setenforce 0 # disable SELInux for now

# ============================================================
# Particionamento (UEFI-only — sem BIOS Boot)
# Máquina Virtual configurada em UEFI puro (OVMF). Partição BIOS Boot (EF02)
# NÃO é necessária.
#
# Layout:
# 1: ESP (EFI System Partition) — FAT32 — 600 MB
# 2: BOOT (Kernel + initramfs)  — ext4  — 1 GB
# 3: Btrfs (Pool único)         — btrfs — 300 GB
# 4: SharedData                 — exFAT — restante do disco
# ============================================================
echo "🔪 Particionando $DRIVE..."
sgdisk --zap-all "$DRIVE"
sgdisk -n 1:0:+600M    -t 1:EF00 -c 1:"EFI System Partition"   "$DRIVE"
sgdisk -n 2:0:+1G      -t 2:8301 -c 2:"SYSTEM RESERVED"        "$DRIVE"
sgdisk -n 3:0:0        -t 3:8300 -c 3:"Debian Btrfs Pool"      "$DRIVE"
# sgdisk -n 6:0:+0     -t 6:8300 -c 3:"Debian Btrfs Pool"      "$DRIVE"
# sgdisk -n 4:0:0      -t 4:0700 -c 4:"Shared exFAT Data"      "$DRIVE"

sgdisk   -c 3:"Debian Btrfs Pool"      "$DRIVE"
sgdisk   -p "$DRIVE"

# ============================================================
# Formatação
# ============================================================
echo "🧼 Formatando partições..."
mkfs.fat  -F32 -n "$EFI_LABEL"    "$EFI_PART"
mkfs.ext4 -F   -L "$SYSTEM_LABEL" "$SYSTEM_PART"
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
# Swapfile de 16 GB no SSD (prioridade baixa, atrás do zRAM)
# ============================================================
echo "💾 Criando Swapfile de 16 GB..."
btrfs filesystem mkswapfile --size 5G "$MOUNTPOINT/var/swap/swapfile"
chmod 600 "$MOUNTPOINT/var/swap/swapfile"
echo "Subvolumes e boot partition montados com sucesso."

####################################################
#### Install tarball debootstrap to the mount / ####
####################################################

# debootstrap --variant=minbase --include=apt,apt-utils,extrepo,cpio,cron,zstd,ca-certificates,perl-openssl-defaults,sudo,neovim,initramfs-tools,console-setup,dosfstools,console-setup-linux,keyboard-configuration,debian-archive-keyring,locales,busybox,btrfs-progs,dmidecode,kmod,less,gdisk,gpgv,neovim,ncurses-base,netbase,procps,systemd,systemd-sysv,udev,ifupdown,init,iproute2,iputils-ping,bash,whiptail --arch amd64 ${CODENAME} /mnt "http://debian.c3sl.ufpr.br/debian/ ${CODENAME} contrib non-free non-free-firmware"

# debootstrap --variant=minbase --include=apt,bash,btrfs-compsize,btrfs-progs,duperemove,zsh,nano,extrepo,cpio,net-tools,locales,console-setup,perl-openssl-defaults,apt-utils,dosfstools,debconf-utils,wget,tzdata,keyboard-configuration,zstd,dracut,ca-certificates,debian-archive-keyring,xz-utils,kmod,gdisk,ncurses-base,systemd,udev,ifupdown,init,iproute2,iputils-ping --arch ${Architecture} bookworm /mnt "http://debian.c3sl.ufpr.br/debian/ bookworm contrib non-free non-free-firmware"

debootstrap \
  --variant=minbase \
  --include=apt,bash,btrfs-compsize,btrfs-progs,duperemove,zsh,nano,extrepo,cpio,net-tools,locales,console-setup,perl-openssl-defaults,apt-utils,dosfstools,debconf-utils,wget,curl,tzdata,keyboard-configuration,zstd,ca-certificates,debian-archive-keyring,apt-transport-tor,xz-utils,kmod,gdisk,ncurses-base,systemd,udev,init,iproute2,iputils-ping \
  --arch=${Architecture} \
  ${CODENAME} /mnt \
  "http://debian.c3sl.ufpr.br/debian/ ${CODENAME} contrib non-free non-free-firmware"

# deb http://debian.c3sl.ufpr.br/debian/ main contrib non-free non-free-firmware
# mmdebstrap --variant=minbase --include=apt,apt-utils,extrepo,cpio,cron,zstd,dhcpcd5,ca-certificates,perl-openssl-defaults,sudo,neovim,initramfs-tools,initramfs-tools-core,dracut,console-setup,dosfstools,console-setup-linux,keyboard-configuration,debian-archive-keyring,locales,locales-all,btrfs-progs,dmidecode,kmod,less,gdisk,gpgv,neovim,ncurses-base,netbase,procps,systemd,systemd-sysv,udev,ifupdown,init,iproute2,iputils-ping,bash,whiptail --arch=amd64 bookworm /mnt "http://debian.c3sl.ufpr.br/debian/ bookworm contrib non-free non-free-firmware"

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
add_dracutmodules+=" systemd btrfs "
EOF

cat <<EOF >/mnt/etc/dracut.conf.d/selinux.conf
# force_drivers+=" securityfs selinuxfs "
EOF

cat <<EOF >/mnt/etc/dracut.conf.d/10-custom.conf
# Host-specific image
hostonly="yes"
hostonly_cmdline="yes"

# Fast compression for VM
compress="zstd -3"

# Limit to Btrfs root filesystem
filesystems+=" btrfs "

# VirtIO & QXL drivers for VM
add_drivers+=" virtio_pci virtio_scsi virtio_blk virtio_net virtio_balloon virtio_console qxl bochs_drm "

# Kernel command-line
kernel_cmdline=" rootflags=subvol=@root rw quiet security=apparmor apparmor=1 lsm=landlock lockdown yama apparmor bpf "
EOF

touch /mnt/etc/dracut.conf.d/input.conf
cat <<EOF >/mnt/etc/dracut.conf.d/input.conf
add_drivers+=" psmouse "
EOF

########################
#### Fastest Repo's ####
########################

rm /mnt/etc/apt/sources.list
# touch /mnt/etc/apt/sources.list.d/{debian.list,various.list,sid.list}
touch /mnt/etc/apt/sources.list.d/debian.sources

#### OLD WAY ####
# cat >/mnt/etc/apt/sources.list.d/debian.list <<HEREDOC
# ####################
# ### Debian repos ###
# ####################

# deb https://deb.debian.org/debian/ $CODENAME main contrib non-free non-free-firmware
# deb-src https://deb.debian.org/debian/ $CODENAME main contrib non-free non-free-firmware

# #deb https://security.debian.org/debian-security $CODENAME-security main contrib non-free non-free-firmware
# #deb-src https://security.debian.org/debian-security $CODENAME-security main contrib non-free non-free-firmware

# deb https://deb.debian.org/debian/ $CODENAME-updates main contrib non-free non-free-firmware
# deb-src https://deb.debian.org/debian/ $CODENAME-updates main contrib non-free non-free-firmware

# deb https://deb.debian.org/debian/ $CODENAME-backports main contrib non-free non-free-firmware
# deb-src https://deb.debian.org/debian/ $CODENAME-backports main contrib non-free non-free-firmware

# #######################
# ### Debian unstable ###
# #######################

# ##Debian Testing
# # deb http://deb.debian.org/debian/ testing main contrib non-free non-free-firmware
# # deb-src http://deb.debian.org/debian/ testing main contrib non-free non-free-firmware


# ##Debian Unstable (Sid)
# # deb http://deb.debian.org/debian unstable main contrib non-free non-free-firmware
# # deb-src http://deb.debian.org/debian unstable main contrib non-free non-free-firmware
# ##Debian Experimental
# # deb http://deb.debian.org/debian experimental main contrib non-free non-free-firmware
# # deb-src http://deb.debian.org/debian experimental main contrib non-free non-free-firmware

# ###################
# ### Tor com apt ###
# ###################
# # In particular, once you have the apt-transport-tor package installed, the following entries should work in your sources list for a Debian system:

# # deb tor+http://vwakviie2ienjx6t.onion/debian stable main

# # deb  tor+http://2s4yqjx5ul6okpp3f2gaunr2syex5jgbfpfvhxxbbjwnrsvbk5v3qbid.onion/debian          bookworm            main
# # deb  tor+http://2s4yqjx5ul6okpp3f2gaunr2syex5jgbfpfvhxxbbjwnrsvbk5v3qbid.onion/debian          bookworm-updates    main
# # deb  tor+http://5ajw6aqf3ep7sijnscdzw77t7xq4xjpsy335yb2wiwgouo7yfxtjlmid.onion/debian-security bookworm/updates    main

# # deb tor+http://2s4yqjx5ul6okpp3f2gaunr2syex5jgbfpfvhxxbbjwnrsvbk5v3qbid.onion/debian          bookworm-backports  main

# ## The old onion services using version 2 of Tor's onion protocol continue to work for now:
# # deb  tor+http://vwakviie2ienjx6t.onion/debian          bookworm            main
# # deb  tor+http://vwakviie2ienjx6t.onion/debian          bookworm-updates    main
# # deb  tor+http://sgvtcaew4bxjd7ln.onion/debian-security bookworm/updates    main

# # deb tor+http://vwakviie2ienjx6t.onion/debian          bookworm-backports  main

# HEREDOC

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

# Types: deb deb-src
# # URIs: https://deb.debian.org/debian/
# URIs: http://debian.c3sl.ufpr.br/debian/
# Suites: trixie-security
# Components: main contrib non-free non-free-firmware
# Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

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

# Types: deb
# URIs: tor+http://2s4yqjx5ul6okpp3f2gaunr2syex5jgbfpfvhxxbbjwnrsvbk5v3qbid.onion/debian/
# Suites: trixie
# Components: main
# Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

# Types: deb
# URIs: tor+http://2s4yqjx5ul6okpp3f2gaunr2syex5jgbfpfvhxxbbjwnrsvbk5v3qbid.onion/debian/
# Suites: trixie-updates
# Components: main
# Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

# Types: deb
# URIs: tor+http://2s4yqjx5ul6okpp3f2gaunr2syex5jgbfpfvhxxbbjwnrsvbk5v3qbid.onion/debian/
# Suites: trixie-backports
# Components: main
# Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
HEREDOC

# ============================================================
# Repositório MX Linux (fontes, chaves GPG e pinning)
# ============================================================
echo "📦 Configurando repositório e chaves do MX Linux..."

# Baixar e extrair o keyring oficial do MX Linux (mx25-archive-keyring para Trixie)
mkdir -p /mnt/usr/share/keyrings /mnt/etc/apt/trusted.gpg.d /mnt/etc/apt/sources.list.d /mnt/etc/apt/preferences.d

if [ ! -f /mnt/usr/share/keyrings/mx-25-archive-keyring.gpg ]; then
    echo "📦 Baixando pacote mx25-archive-keyring..."
    (curl -fsSL --insecure "https://mxrepo.com/mx/repo/pool/main/m/mx25-archive-keyring/mx25-archive-keyring_2025.03_all.deb" -o /tmp/mx25-keyring.deb || \
     wget -q --no-check-certificate "https://mxrepo.com/mx/repo/pool/main/m/mx25-archive-keyring/mx25-archive-keyring_2025.03_all.deb" -O /tmp/mx25-keyring.deb) 2>/dev/null && \
    dpkg-deb -x /tmp/mx25-keyring.deb /mnt/ 2>/dev/null || true
    rm -f /tmp/mx25-keyring.deb
fi

# Fallback se ainda não existir
if [ ! -f /mnt/usr/share/keyrings/mx-25-archive-keyring.gpg ]; then
    echo "⚠️ Baixando chave MX Linux via keyserver / gpg..."
    gpg --no-default-keyring --keyring /tmp/mx-temp.gpg \
        --keyserver keyserver.ubuntu.com --recv-keys 7857E44E4EB89A4B 8B819E5171128B47 2>/dev/null || true
    if [ -f /tmp/mx-temp.gpg ]; then
        cp -f /tmp/mx-temp.gpg /mnt/usr/share/keyrings/mx-25-archive-keyring.gpg
        rm -f /tmp/mx-temp.gpg
    fi
fi

# Garantir permissão de leitura universal (0644) para o usuário _apt e sqv
chmod -R a+rX /mnt/usr/share/keyrings /mnt/etc/apt/trusted.gpg.d 2>/dev/null || true

# Repositório MX Linux em formato deb822
cat << 'MX_SOURCES_EOF' > /mnt/etc/apt/sources.list.d/mxlinux.sources
Types: deb
URIs: http://mxrepo.com/mx/repo/
Suites: trixie
Components: main non-free ahs
Signed-By: /usr/share/keyrings/mx-25-archive-keyring.gpg
MX_SOURCES_EOF

# Prioridade controlada para o repositório MX Linux
cat << 'MX_PREF_EOF' > /mnt/etc/apt/preferences.d/20mxlinux.pref
# Prioridade 100: permite instalar utilitários do MX Linux sob demanda
# sem sobrescrever pacotes essenciais do Debian.
Package: *
Pin: origin mxrepo.com
Pin-Priority: 100
MX_PREF_EOF

# cat >/mnt/etc/apt/sources.list.d/extrepo_librewolf.sources <<HEREDOC
# Types: deb
# Architectures: amd64 arm64
# Components: main
# Uris: https://repo.librewolf.net
# Suites: librewolf
# Signed-By: /var/lib/extrepo/keys/librewolf.asc
# HEREDOC

# cat >/mnt/etc/apt/sources.list.d/vscode.list <<HEREDOC
# ### THIS FILE IS AUTOMATICALLY CONFIGURED ###
# # You may comment out this entry, but any other modifications may be lost.
# Types: deb
# URIs: https://packages.microsoft.com/repos/code
# Suites: stable
# Components: main
# Architectures: amd64,arm64,armhf
# Signed-By: /usr/share/keyrings/microsoft.gpg
# HEREDOC

# cat >/mnt/etc/apt/sources.list.d/waydroid.list <<HEREDOC
# deb [signed-by=/usr/share/keyrings/waydroid.gpg] https://repo.waydro.id/ bookworm main
# HEREDOC

# cat >/mnt/etc/apt/sources.list.d/xanmod-kernel.list <<HEREDOC
# deb [signed-by=/usr/share/keyrings/xanmod.gpg] http://deb.xanmod.org releases main
# HEREDOC

# chroot /mnt apt install gnupg2 curl -y
# chroot /mnt apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 86F7D09EE734E623
# chroot /mnt curl -fsSL https://dl.xanmod.org/gpg.key | gpg --dearmor | tee /etc/apt/trusted.gpg.d/xanmod.gpg > /dev/null


######################################
#### Optimize apt package manager ####
######################################

mkdir -pv /mnt/etc/apt/apt.conf.d
touch /mnt/etc/apt/apt.conf.d/99norecommends
cat >/mnt/etc/apt/apt.conf.d/99norecommends <<HEREDOC
#Recommends are as of now abused in many packages
APT::Install-Recommends "0";        # Prevents auto-installing recommended packages
APT::Install-Suggests "0";          # Skips suggested packages (often unnecessary)

# // no install recommends/suggests packages
# APT::Install-Recommends "false";
# APT::Install-Suggests "false";

### For install testing packages
#APT::Default-Release "testing";    # Commented out, but useful if you want to prioritize testing selectively
HEREDOC

touch /mnt/etc/apt/apt.conf.d/99assumeyes
cat >/mnt/etc/apt/apt.conf.d/99assumeyes <<HEREDOC
# assume yes install packages
// assume yes install packages
APT::Get::Assume-Yes "true";
HEREDOC

# echo 'APT::Default-Release "stable";' | sudo tee /etc/apt/apt.conf.d/99default-release
echo 'APT::Default-Release "trixie";' | tee /mnt/etc/apt/apt.conf.d/99default-release

mkdir -pv /mnt/etc/apt/preferences.d

touch /mnt/etc/apt/preferences.d/99stable.pref
touch /mnt/etc/apt/preferences.d/50testing.pref
touch /mnt/etc/apt/preferences.d/10unstable.pref
touch /mnt/etc/apt/preferences.d/1experimental.pref
touch /mnt/etc/apt/preferences.d/no-initramfs-tools

cat >/mnt/etc/apt/preferences.d/99trixie.pref <<HEREDOC
# 500 <= P < 990: causes a version to be installed unless there is a
# version available belonging to the target release or the installed
# version is more recent

Package: *
# Pin: release a=stable
# Pin: release a=${CODENAME}
Pin: release a=trixie
Pin-Priority: 900
HEREDOC

cat >/mnt/etc/apt/preferences.d/50testing.pref <<HEREDOC
# 100 <= P < 500: causes a version to be installed unless there is a
# version available belonging to some other distribution or the installed
# version is more recent

Package: *
Pin: release a=testing
Pin-Priority: 400
HEREDOC

cat >/mnt/etc/apt/preferences.d/10unstable.pref <<HEREDOC
# 0 < P < 100: causes a version to be installed only if there is no
# installed version of the package

Package: *
Pin: release a=unstable
Pin-Priority: 50
HEREDOC

cat >/mnt/etc/apt/preferences.d/1experimental.pref <<HEREDOC
# 0 < P < 100: causes a version to be installed only if there is no
# installed version of the package

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

chroot /mnt apt update

### Network
chroot /mnt apt install network-manager --yes

## dbus initilized
# chroot /mnt dbus-uuidgen > /var/lib/dbus/machine-id

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
chroot /mnt usermod -aG floppy,audio,sudo,video,systemd-journal,lp,cdrom,netdev,input,plugdev $username
chroot /mnt usermod -aG sudo $username

# Permissão 755 na home para que Display Managers e Nix acessem perfis e sessões desktop
chmod 755 /mnt/home/$username

# chroot /mnt apt install --yes dbus dbus-bin dbus-daemon dbus-session-bus-common dbus-system-bus-common dbus-user-session libpam-systemd
chroot /mnt apt install --yes dbus-broker dbus-user-session libpam-systemd

chroot /mnt systemctl disable dbus-daemon.service 2>/dev/null || true
chroot /mnt systemctl enable dbus-broker.service 2>/dev/null || true

## Disable verification ##
# touch /mnt/etc/apt/apt.conf.d/99verify-peer.conf \
# && echo >> /mnt/etc/apt/apt.conf.d/99verify-peer.conf "Acquire { https::Verify-Peer false }"


##################################################
#### Disable some features for optimal system ####
##################################################
########################################
#### real hardware modprobe modules ####
########################################

mkdir -pv /mnt/etc/modprobe.d
cat <<EOF >/mnt/etc/modprobe.d/blacklist.conf
# Disable watchdog
install iTCO_wdt /bin/true
install iTCO_vendor_support /bin/true

# This file lists those modules which we don't want to be loaded by
# alias expansion, usually so some other driver will be loaded for the
# device instead.

# evbug is a debug tool that should be loaded explicitly
blacklist evbug

# these drivers are very simple, the HID drivers are usually preferred
blacklist usbmouse
blacklist usbkbd

# replaced by e100
blacklist eepro100

# replaced by tulip
blacklist de4x5

# causes no end of confusion by creating unexpected network interfaces
blacklist eth1394

# snd_intel8x0m can interfere with snd_intel8x0, doesn't seem to support much
# hardware on its own (Ubuntu bug #2011, #6810)
# blacklist snd_intel8x0m

# Conflicts with dvb driver (which is better for handling this device)
blacklist snd_aw2

# replaced by p54pci
# blacklist prism54

# replaced by b43 and ssb.
blacklist bcm43xx

# most apps now use garmin usb driver directly (Ubuntu: #114565)
blacklist garmin_gps

# replaced by asus-laptop (Ubuntu: #184721)
# blacklist asus_acpi

# low-quality, just noise when being used for sound playback, causes
# hangs at desktop session start (Ubuntu: #246969)
# blacklist snd_pcsp

# ugly and loud noise, getting on everyone's nerves; this should be done by a
# nice pulseaudio bing (Ubuntu: #77010)
# blacklist pcspkr

# EDAC driver for amd76x clashes with the agp driver preventing the aperture
# from being initialised (Ubuntu: #297750). Blacklist so that the driver
# continues to build and is installable for the few cases where its
# really needed.
# blacklist amd76x_e0dac
EOF

mkdir -pv /mnt/etc/modules-load.d
touch /mnt/etc/modules-load.d/iptables.conf
cat << EOF > /mnt/etc/modules-load.d/iptables.conf
ip6_tables
ip6table_nat
ip_tables
iptable_nat
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

cat <<EOF >/mnt/etc/sysctl.d/10-console-messages.conf
# the following stops low-level messages on console
kernel.printk = 4 4 1 7
EOF

cat <<EOF >/mnt/etc/sysctl.d/99-dmesg.conf
kernel.dmesg_restrict = 0
EOF

cat <<EOF >/mnt/etc/sysctl.d/10-ipv6-privacy.conf
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

cat <<EOF >/mnt/etc/sysctl.d/10-kernel-hardening.conf
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

cat <<EOF >/mnt/etc/sysctl.d/10-network-security.conf
# Turn on Source Address Verification in all interfaces to
# prevent some spoofing attacks.
net.ipv4.conf.default.rp_filter=2
net.ipv4.conf.all.rp_filter=2
EOF

cat <<EOF >/mnt/etc/sysctl.d/10-zeropage.conf
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

############################
#### Set default editor ####
############################

# chroot /mnt update-alternatives --install /usr/bin/editor editor /usr/bin/nvim 100

################################
#### Update package manager ####
################################

chroot /mnt apt update
chroot /mnt apt upgrade
chroot /mnt apt autoremove
chroot /mnt apt autoclean

######################
#### Set Hostname ####
######################
# VM: virtualvm

cat <<EOF >/mnt/etc/hostname
${hostname}
EOF

# Hosts
touch /mnt/etc/hosts
cat <<EOF >/mnt/etc/hosts
# Loopback entries; do not change.
127.0.0.1   localhost
127.0.1.1   ${hostname}.localdomain ${hostname}
# The following lines are desirable for IPv6 capable hosts
::1         localhost ip6-localhost ip6-loopback
ff02::1     ip6-allnodes
ff02::2     ip6-allrouters
# See hosts(5) for proper format and other examples:
# 192.168.1.10 foo.example.org foo
# 192.168.1.13 bar.example.org bar
EOF

touch /mnt/etc/host.conf
cat <<EOF >/mnt/etc/host.conf
multi on
EOF

touch /mnt/etc/nsswitch.conf
cat <<EOF >/mnt/etc/nsswitch.conf
# Generated by authselect
# Do not modify this file manually, use authselect instead. Any user changes will be overwritten.
# You can stop authselect from managing your configuration by calling 'authselect opt-out'.
# See authselect(8) for more details.

# In order of likelihood of use to accelerate lookup.
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
# /etc/fstab — Gerado automaticamente pelo script de instalação
# Debian $CODENAME — Máquina Virtual (virtualvm)

# === Btrfs Pool Único (300 GB) ===
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

# === Boot e EFI ===
LABEL=${SYSTEM_LABEL}  /boot               ext4  rw,relatime                                     0 1
LABEL=${EFI_LABEL}     /boot/efi           vfat  defaults,noatime,nodiratime                     0 2

# === Swap (Prioridade 10) ===
/var/swap/swapfile     none                swap  defaults,pri=10                                 0 0

# === Partição de Dados Compartilhados (exFAT) ===
# LABEL=${MISC_LABEL}    /media/juca/SharedData  exfat  defaults,nofail,uid=1000,gid=1000,dmask=0022,fmask=0133  0 0

# === Tmpfs ===
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
## Selinux ##
#############

# chroot /mnt apt purge apparmor apparmor-utils

# chroot /mnt systemctl disable apparmor # --now
# chroot /mnt apt install selinux-basics selinux-policy-default selinux-utils policycoreutils auditd 
# chroot /mnt selinux-activate
# # Verify
# chroot /mnt sestatus
# # Switch to Enforcing Mode
# chroot /mnt setenforce 1

# mkdir -pv /mnt/etc/selinux
# touch /mnt/etc/selinux/config
# cat <<EOF >/mnt/etc/selinux/config
# SELINUX=enforcing
# SELINUXTYPE=targeted
# SETLOCALDEFS=0
# EOF

# chroot /mnt fixfiles -F onboot


## Extra tools: Configure Policies
# chroot /mnt apt install policycoreutils-python-utils --no-install-recommends --y
## Allow HTTP/HTTPS ports:
# chroot /mnt semanage port -a -t http_port_t -p tcp 80
# chroot /mnt semanage port -a -t http_port_t -p tcp 443

#############
## Network ##
#############

chroot /mnt apt install gvfs gvfs-backends smbclient cifs-utils avahi-daemon
# ssh
chroot /mnt apt install openssh-client openssh-server 

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
# Configuração do iWD integrada ao NetworkManager
# NetworkManager gerencia IP e DHCP; o iWD gerencia autenticação e rádio Wi-Fi
[General]
EnableNetworkConfiguration=false
EOF

##################
### SOCKET RAW ###
##################

mkdir -pv /mnt/usr/lib/sysctl.d
touch /mnt/usr/lib/sysctl.d/50-default.conf
echo "-net.ipv4.ping_group_range = 0 2147483647" >> /mnt/usr/lib/sysctl.d/50-default.conf


### BTRFS
# chroot /mnt apt install btrfs-progs btrfs-compsize udisks2-btrfs duperemove 

###############
#### Audio ####
###############

## Pulseaudio
# chroot /mnt apt install alsa-utils bluetooth rfkill bluez bluez-tools pulseaudio pulseaudio-module-bluetooth pavucontrol 

## Pipewire
# chroot /mnt apt purge pipewire* pipewire-bin -y
chroot /mnt apt install pipewire-audio wireplumber pipewire-pulse pipewire-alsa libspa-0.2-bluetooth libspa-0.2-jack 

# Enable WirePlumber session manager:
chroot /mnt systemctl --user enable wireplumber.service 2>/dev/null || true
# Symlink resolv.conf for systemd-resolved (optional):
# ln -sf /run/systemd/resolve/resolv.conf /mnt/etc/resolv.conf
# Disable PulseAudio:
chroot /mnt systemctl --user disable pulseaudio.service pulseaudio.socket 2>/dev/null || true
chroot /mnt systemctl --user mask pulseaudio 2>/dev/null || true
# Enable PipeWire services:
chroot /mnt systemctl --user enable pipewire pipewire-pulse 2>/dev/null || true

## RealtimeKit
chroot /mnt apt install rtkit

###############
#### Utils ####
###############
chroot /mnt apt install gdisk acpi acpid bash-completion pciutils debian-keyring xz-utils htop wget unzip sysfsutils  
# dkms

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

### If you are on Arch/Redhat (polkit >= 106), then this would work:
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

### XANMOD KERNEL ###
chroot /mnt apt install software-properties-common apt-transport-https ca-certificates curl gnupg 

############
### BOOT ###
############
# chroot /mnt apt install efibootmgr grub-efi-amd64 os-prober

############################
### BOOTLOADER (GRUB EFI) ###
############################
chroot /mnt apt install shim-signed grub-efi-amd64-signed efibootmgr os-prober

############
### TIME ###
############
chroot /mnt apt install chrony

# apt install linux-headers-$(uname -r|sed 's/[^-]*-[^-]*-//')


# chroot /mnt update-initramfs -c -k all

#############################
#### Optimizations Tools ####
#############################

chroot /mnt apt install -y earlyoom irqbalance systemd-zram-generator qemu-guest-agent spice-vdagent
chroot /mnt systemctl enable earlyoom
chroot /mnt systemctl enable irqbalance
chroot /mnt systemctl enable qemu-guest-agent

# Configuração do zRAM (Swap comprimido em RAM de 4 GB via zstd com prioridade máxima)
mkdir -pv /mnt/etc/systemd /mnt/etc/sysctl.d
cat <<EOF >/mnt/etc/systemd/zram-generator.conf
# /etc/systemd/zram-generator.conf — Configuração do zRAM (virtualvm)
[zram0]
zram-size = min(ram / 2, 4096)
compression-algorithm = zstd
swap-priority = 100
EOF

cat <<EOF >/mnt/etc/sysctl.d/99-zram.conf
# Otimizações de kernel para zRAM de alta performance
vm.swappiness = 100
vm.page-cluster = 0
EOF

# Microcode, Dracut e Kernel são instalados na seção posterior de boot/kernel


##################################################
#### Xorg, LightDM e Sessão DWM (Home Manager) ###
##################################################
echo "🖥️ Instalando Xorg, LightDM, GTK Greeter e utilitários de exibição..."
chroot /mnt apt install -y \
    xserver-xorg \
    xserver-xorg-video-qxl \
    xserver-xorg-video-all \
    libgl1-mesa-dri \
    mesa-vulkan-drivers \
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

echo "⚙️ Configurando LightDM e sessão DWM do Home Manager..."
mkdir -p /mnt/etc/lightdm /mnt/etc/lightdm/lightdm.conf.d /mnt/usr/share/xsessions /mnt/usr/local/bin

# 1. Configuração do LightDM: Greeter padrão e sessão padrão DWM
cat << 'LIGHTDM_CONF_EOF' > /mnt/etc/lightdm/lightdm.conf
[LightDM]
run-directory=/run/lightdm

[Seat:*]
greeter-session=lightdm-gtk-greeter
user-session=dwm
session-wrapper=/etc/X11/Xsession
greeter-hide-users=false
logind-check-graphical=true
LIGHTDM_CONF_EOF

# 2. Ocultar usuários de compilação do Nix (nixbld1..nixbld32) da lista do greeter
cat << 'LIGHTDM_USERS_EOF' > /mnt/etc/lightdm/users.conf
[UserList]
minimum-uid=1000
hidden-users=nobody nobody4 noaccess nixbld1 nixbld2 nixbld3 nixbld4 nixbld5 nixbld6 nixbld7 nixbld8 nixbld9 nixbld10 nixbld11 nixbld12 nixbld13 nixbld14 nixbld15 nixbld16 nixbld17 nixbld18 nixbld19 nixbld20 nixbld21 nixbld22 nixbld23 nixbld24 nixbld25 nixbld26 nixbld27 nixbld28 nixbld29 nixbld30 nixbld31 nixbld32
hidden-shells=/bin/false /usr/sbin/nologin /sbin/nologin
LIGHTDM_USERS_EOF

# 3. Configuração visual do Greeter GTK (Catppuccin Mocha / Dark)
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

# 4. Wrapper de Inicialização da Sessão DWM com Carregamento do Nix e Fallback
cat << 'DWM_WRAPPER_EOF' > /mnt/usr/local/bin/start-dwm-session
#!/usr/bin/env bash
# Carregar profiles do Nix para o ambiente gráfico do X11
if [ -e /etc/profile.d/nix.sh ]; then
    . /etc/profile.d/nix.sh
elif [ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
    . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
fi
if [ -e "$HOME/.nix-profile/etc/profile.d/nix.sh" ]; then
    . "$HOME/.nix-profile/etc/profile.d/nix.sh"
fi

# 1. Prioridade máxima: wrapper start-dwm gerado pelo Home Manager
if [ -x "$HOME/.local/bin/start-dwm" ]; then
    exec "$HOME/.local/bin/start-dwm"
fi

# 2. Segunda opção: ~/.xsession gerado pelo Home Manager
if [ -x "$HOME/.xsession" ]; then
    exec "$HOME/.xsession"
fi

# 3. Terceira opção: binário dwm no PATH
if command -v dwm >/dev/null 2>&1; then
    exec dwm
fi

# 4. Fallback amigável se o Home Manager ainda não foi aplicado
xsetroot -solid '#1e1e2e' 2>/dev/null || true
MSG="=====================================================\nSessão DWM iniciada!\n\nO Home Manager ainda não gerou as configurações do DWM.\nPara gerar o desktop completo (dwm-titus, Quickshell, Slstatus),\nexecute no terminal abaixo:\n\n    home-manager switch --flake .#juca@virtualvm\n\nApós o switch, faça logout e login novamente no LightDM.\n====================================================="
if command -v xterm >/dev/null 2>&1; then
    xterm -geometry 90x25 -title "Setup DWM Home Manager" -e bash -c "echo -e '$MSG'; exec bash"
elif command -v x-terminal-emulator >/dev/null 2>&1; then
    x-terminal-emulator -e bash -c "echo -e '$MSG'; exec bash"
else
    exec x-session-manager
fi
DWM_WRAPPER_EOF
chmod 755 /mnt/usr/local/bin/start-dwm-session

# 5. Entrada da Sessão X11 em /usr/share/xsessions/dwm.desktop
cat << 'DWM_DESKTOP_EOF' > /mnt/usr/share/xsessions/dwm.desktop
[Desktop Entry]
Name=DWM
Comment=Dynamic Window Manager (Home Manager)
Exec=/usr/local/bin/start-dwm-session
Type=Application
DesktopNames=dwm
DWM_DESKTOP_EOF

# 6. Sessão padrão do usuário juca no ~/.dmrc
mkdir -p /mnt/home/$username
cat << 'DMRC_EOF' > /mnt/home/$username/.dmrc
[Desktop]
Session=dwm
DMRC_EOF
chown $username:$username /mnt/home/$username/.dmrc 2>/dev/null || true
chmod 644 /mnt/home/$username/.dmrc 2>/dev/null || true

###########################
#### Some XORG configs ####
###########################

# Touchpad tap to click
mkdir -pv /mnt/etc/X11/xorg.conf.d/
touch /mnt/etc/X11/xorg.conf.d/30-touchpad.conf
cat <<EOF >/mnt/etc/X11/xorg.conf.d/30-touchpad.conf
Section "InputClass"
    # Identifier "SynPS/2 Synaptics TouchPad"
    # Identifier "SynPS/2 Synaptics TouchPad"
    # MatchIsTouchpad                                     "on"
    # Driver            "libinput"
    # Option            "Tapping"                         "on"

    Identifier          "libinput touchpad catchall"
    Driver              "libinput"
    MatchIsTouchpad     "on"
    MatchDevicePath     "/dev/input/event*"
    Option              "Tapping"   			                "on"
    Option 		          "NaturalScrolling" 			          "true"
EndSection
EOF

# Bluetooth não necessário em ambiente de Máquina Virtual
# chroot /mnt apt install -y bluez blueman


#################################
#### Infrastructure packages ####
#################################

#Python, snap and flatpak
# chroot /mnt apt install python3 python3-pip snapd flatpak 
chroot /mnt apt install snapd flatpak 

##################################################
### Virt-Manager, QEMU/KVM e Libvirt (Nativo)  ###
##################################################
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

# Configurar QEMU para executar sob o usuário local juca
# Isso resolve erros de "Permission denied" ao acessar ISOs e armazenamentos em /media/juca/...
if [ -f /mnt/etc/libvirt/qemu.conf ]; then
  sed -i -E 's/^[# ]*user[ ]*=.*/user = "'"$username"'"/' /mnt/etc/libvirt/qemu.conf
  sed -i -E 's/^[# ]*group[ ]*=.*/group = "'"$username"'"/' /mnt/etc/libvirt/qemu.conf
  if ! grep -q '^user = "'"$username"'"' /mnt/etc/libvirt/qemu.conf; then
    cat << EOF >> /mnt/etc/libvirt/qemu.conf

# Usuário e grupo para execução de máquinas virtuais (desktop pessoal)
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

# Regra de Polkit para permitir gerenciamento de VMs sem pedir senha para o grupo libvirt
mkdir -p /mnt/etc/polkit-1/rules.d
cat << 'POLKIT_LIBVIRT_EOF' > /mnt/etc/polkit-1/rules.d/80-libvirt.rules
polkit.addRule(function(action, subject) {
  if (action.id.indexOf("org.libvirt") == 0 && subject.isInGroup("libvirt")) {
    return polkit.Result.YES;
  }
});
POLKIT_LIBVIRT_EOF
chmod 644 /mnt/etc/polkit-1/rules.d/80-libvirt.rules

##############
### Podman ###
##############

# sudo apt install curl gpg gnupg2 software-properties-common apt-transport-https lsb-release ca-certificates -y

# source /etc/os-release
# wget http://downloadcontent.opensuse.org/repositories/home:/alvistack/Debian_$VERSION_ID/Release.key -O alvistack_key
# cat alvistack_key | gpg --dearmor | sudo tee /etc/apt/trusted.gpg.d/alvistack.gpg >/dev/null

# echo "deb http://downloadcontent.opensuse.org/repositories/home:/alvistack/Debian_$VERSION_ID/ /" | sudo tee /etc/apt/sources.list.d/alvistack.list

# sudo apt update
# sudo apt install podman python3-podman-compose

##############
####  Nix  ###
##############
echo "❄️ Configurando Nix Daemon e permissões de usuário..."

# Instalar pacotes do Nix no Debian
chroot /mnt apt install -y nix-bin nix-setup-systemd

# 1. Adicionar o usuário juca aos grupos nixbld e nix-users
chroot /mnt groupadd -r nixbld 2>/dev/null || true
chroot /mnt groupadd -r nix-users 2>/dev/null || true
chroot /mnt usermod -aG nixbld,nix-users $username

# Garantir propriedade e permissões seguras da árvore /nix (elimina unsafe path transition no tmpfiles)
chown root:root /mnt/nix /mnt/nix/var /mnt/nix/var/nix /mnt/nix/var/nix/profiles /mnt/nix/var/nix/gcroots 2>/dev/null || true
chmod 755 /mnt/nix /mnt/nix/var /mnt/nix/var/nix /mnt/nix/var/nix/profiles /mnt/nix/var/nix/gcroots 2>/dev/null || true
mkdir -p /mnt/nix/store /mnt/nix/var/nix/daemon-socket /mnt/nix/var/nix/profiles/per-user /mnt/nix/var/nix/gcroots/per-user
chown root:nixbld /mnt/nix/store 2>/dev/null || true
chmod 1775 /mnt/nix/store 2>/dev/null || true
chown root:nix-users /mnt/nix/var/nix/daemon-socket 2>/dev/null || true
chmod 0777 /mnt/nix/var/nix/daemon-socket 2>/dev/null || true
chmod 1777 /mnt/nix/var/nix/profiles/per-user /mnt/nix/var/nix/gcroots/per-user 2>/dev/null || true

# Configurar SocketMode=0666 para o nix-daemon.socket
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

# 2. Configurar o /etc/nix/nix.conf para permitir o uso do daemon por usuários comuns
mkdir -p /mnt/etc/nix
cat << 'NIX_CONF_EOF' > /mnt/etc/nix/nix.conf
build-users-group = nixbld
trusted-users = root juca @nixbld @nix-users
allowed-users = *
experimental-features = nix-command flakes
max-jobs = auto
cores = 0
NIX_CONF_EOF

# Configurar canal nixpkgs-unstable para juca e root
echo "📦 Configurando canal nixpkgs-unstable..."
mkdir -p /mnt/home/$username/.nix-defexpr/channels /mnt/root/.nix-defexpr/channels
echo "https://nixos.org/channels/nixpkgs-unstable nixpkgs" > /mnt/home/$username/.nix-channels
echo "https://nixos.org/channels/nixpkgs-unstable nixpkgs" > /mnt/root/.nix-channels
chown -R $username:$username /mnt/home/$username/.nix-channels /mnt/home/$username/.nix-defexpr 2>/dev/null || true

# 3. Exportar variáveis globais no perfil do sistema (/etc/profile.d/nix-env.sh)
cat << 'NIX_PROFILE_EOF' > /mnt/etc/profile.d/nix-env.sh
# Carregar o ambiente do daemon do Nix se disponível
if [ -e /etc/profile.d/nix.sh ]; then
    . /etc/profile.d/nix.sh
elif [ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
    . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
fi

export NIX_REMOTE=daemon
export NIX_PATH="nixpkgs=https://nixos.org/channels/nixpkgs-unstable:$HOME/.nix-defexpr/channels" 

# PATH para os binários do Home Manager e perfis do Nix
export PATH="$HOME/.nix-profile/bin:/etc/profiles/per-user/$USER/bin:$PATH"

# XDG_DATA_DIRS para que aplicativos (.desktop), ícones e temas apareçam em qualquer Display Manager / Desktop
export XDG_DATA_DIRS="$HOME/.nix-profile/share:/etc/profiles/per-user/$USER/share:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
NIX_PROFILE_EOF
chmod +x /mnt/etc/profile.d/nix-env.sh

# 4. Ativar o serviço do Nix Daemon no boot
chroot /mnt systemctl enable nix-daemon.service

# ==== Wrappers Setuid (Polkit + Screen Lockers) para o Home Manager ====
echo "🔐 Configurando /run/wrappers/bin e regras de PAM..."

mkdir -p /mnt/etc/tmpfiles.d /mnt/etc/pam.d

# 1. Regra de tmpfiles.d para recriar os links dos helpers setuid a cada boot
cat << 'NIX_WRAPPERS_EOF' > /mnt/etc/tmpfiles.d/nix-wrappers.conf
d /run/wrappers 0755 root root -
d /run/wrappers/bin 0755 root root -
L+ /run/wrappers/bin/unix_chkpwd - - - - /usr/sbin/unix_chkpwd
L+ /run/wrappers/bin/polkit-agent-helper-1 - - - - /usr/lib/polkit-1/polkit-agent-helper-1
NIX_WRAPPERS_EOF

# Aplicar a regra imediatamente no ambiente chroot
chroot /mnt systemd-tmpfiles --create /etc/tmpfiles.d/nix-wrappers.conf || true

# 2. Regras de PAM dedicadas para screen lockers (Hyprlock, Swaylock, Noctalia)
cat << 'PAM_LOCK_EOF' > /mnt/etc/pam.d/hyprlock
#%PAM-1.0
@include common-auth
@include common-account
@include common-password
@include common-session
PAM_LOCK_EOF

cp -f /mnt/etc/pam.d/hyprlock /mnt/etc/pam.d/swaylock
cp -f /mnt/etc/pam.d/hyprlock /mnt/etc/pam.d/noctalia
cp -f /mnt/etc/pam.d/hyprlock /mnt/etc/pam.d/i3lock

# ==== Suporte a Display Managers (SDDM, LightDM, GDM) e Home Manager ====
mkdir -p /mnt/etc/sddm.conf.d /mnt/usr/share/wayland-sessions /mnt/usr/share/xsessions

# 1. SDDM: Ocultar contas nixbld e registrar diretórios de sessões
cat << 'SDDM_USERS_EOF' > /mnt/etc/sddm.conf.d/hide-nix-users.conf
[Users]
HideShells=/sbin/nologin,/usr/sbin/nologin,/bin/false,/usr/bin/false
MaximumUid=29999
SDDM_USERS_EOF

cat << 'SDDM_SESSIONS_EOF' > /mnt/etc/sddm.conf.d/sessions.conf
[Wayland]
SessionDir=/usr/share/wayland-sessions:/home/juca/.local/share/wayland-sessions

[X11]
SessionDir=/usr/share/xsessions:/home/juca/.local/share/xsessions
SDDM_SESSIONS_EOF

# 2. Compatibilidade universal de sessões para QUALQUER Display Manager (GDM, LightDM, SDDM)
# DMs como GDM e LightDM buscam exclusivamente em /usr/share/*-sessions.
# Provisionamos symlinks automáticos via tmpfiles para as sessões do Home Manager:
cat << 'DM_SESSIONS_TMPFILES_EOF' > /mnt/etc/tmpfiles.d/nix-desktop-sessions.conf
L+ /usr/share/wayland-sessions/hyprland.desktop - - - - /home/juca/.local/share/wayland-sessions/hyprland.desktop
L+ /usr/share/wayland-sessions/mango.desktop    - - - - /home/juca/.local/share/wayland-sessions/mango.desktop
L+ /usr/share/xsessions/dwm.desktop            - - - - /home/juca/.local/share/xsessions/dwm.desktop
L+ /usr/share/xsessions/bspwm.desktop          - - - - /home/juca/.local/share/xsessions/bspwm.desktop
DM_SESSIONS_TMPFILES_EOF

############################
#### BTRFS Backup tools ####
############################

# chroot /mnt apt install snapper snapper-gui 

#################################
#### Plymouth animation boot ####
#################################

# chroot /mnt apt install plymouth plymouth-themes 
# chroot /mnt plymouth-set-default-theme -R solar

# mkdir -pv /mnt/etc/plymouth
# touch /mnt/etc/plymouth/plymouth.conf
# cat <<EOF >/mnt/etc/plymouth/plymouth.conf
# Administrator customizations go in this file
# [Daemon]
# Theme=solar
# ShowDelay=5
# EOF

###########################
#### Setup resolv.conf ####
###########################
# touch /mnt/etc/resolv.conf
# cat <<EOF >/mnt/etc/resolv.conf
# nameserver 9.9.9.9
# # nameserver 8.8.8.8
# # nameserver 8.8.4.4
# # nameserver 1.1.1.1
# EOF

################################
#### Setup default keyboard ####
################################

mkdir -pv /mnt/etc/default/
touch /mnt/etc/default/keyboard
cat <<EOF >/mnt/etc/default/keyboard
# KEYBOARD CONFIGURATION FILE

# Consult the keyboard(5) manual page.

XKBMODEL="pc105"
XKBLAYOUT="us,br"
XKBVARIANT="alt-intl,abnt2"
XKBOPTIONS="grp:alt_shift_toggle"
BACKSPACE="guess"
EOF

touch /mnt/etc/default/console-setup
cat <<EOF >/mnt/etc/default/console-setup
# CONFIGURATION FILE FOR SETUPCON

ACTIVE_CONSOLES="/dev/tty[1-6]"
CHARMAP="UTF-8"
# CODESET="Lat15"
CODESET="guess"
# FONTFACE="Terminus"
FONTFACE="Fixed"
# FONTSIZE="16x32"
FONTSIZE="8x16"
EOF

# chroot /mnt apt install console-setup fonts-terminus

chroot /mnt setupcon --save
# chroot /mnt service keyboard-setup restart
# setxkbmap -layout us,br -variant intl, -option grp:alt_shift_toggle

# GSETTINGS
# gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'us'), ('xkb', 'br')]"
# gsettings set org.gnome.desktop.input-sources xkb-options "['grp:alt_shift_toggle']"

#############################
#### Set bash as default ####
#############################

chroot /mnt chsh -s /usr/bin/bash root

# AppArmor podman fix

# mkdir -pv /mnt/etc/apparmor.d/local/
# touch /mnt/etc/apparmor.d/local/usr.sbin.dnsmasq
# cat << EOF >> /mnt/etc/apparmor.d/local/usr.sbin.dnsmasq
# owner /run/user/[0-9]*/containers/cni/dnsname/*/dnsmasq.conf r,
# owner /run/user/[0-9]*/containers/cni/dnsname/*/addnhosts r,
# owner /run/user/[0-9]*/containers/cni/dnsname/*/pidfile rw,
# EOF

# chroot /mnt apparmor_parser -R /etc/apparmor.d/usr.sbin.dnsmasq
# chroot /mnt apparmor_parser /etc/apparmor.d/usr.sbin.dnsmasq

############################################################
#### NetworkManager config as default instead of dhcpd5 ####
############################################################

# chroot /mnt apt install ifupdown # comment if using systemd-network

# cat <<EOF >/mnt/etc/NetworkManager/NetworkManager.conf
# [main]
# plugins=ifupdown,keyfile

# [ifupdown]
# managed=true
# EOF

# touch /mnt/etc/NetworkManager/dispatcher.d/wlan_auto_toggle.sh
# chroot /mnt chmod +x /etc/NetworkManager/dispatcher.d/wlan_auto_toggle.sh
# cat <<EOF >/mnt/etc/NetworkManager/dispatcher.d/wlan_auto_toggle.sh
# #!/bin/sh

# # Use dispatcher to automatically toggle wireless depending on LAN cable being plugged in
# # replacing LAN_interface with yours

# # if [ "$1" = "LAN_interface" ]; then
# if [ "$1" = "eth0" ]; then
#     case "$2" in
#         up)
#             nmcli radio wifi off
#             ;;
#         down)
#             nmcli radio wifi on
#             ;;
#     esac
# # elif [ "$(nmcli -g GENERAL.STATE device show LAN_interface)" = "20 (unavailable)" ]; then
# elif [ "$(nmcli -g GENERAL.STATE device show eth0)" = "20 (unavailable)" ]; then
#     nmcli radio wifi on
# fi
# EOF

#########################
#### Enable Services ####
#########################

## Network
# chroot /mnt systemctl enable systemd-networkd.service # Desativado em favor do NetworkManager para desktop
chroot /mnt systemctl disable systemd-networkd.service 2>/dev/null || true
chroot /mnt systemctl mask systemd-networkd.socket 2>/dev/null || true
chroot /mnt systemctl mask systemd-networkd-wait-online.service 2>/dev/null || true
chroot /mnt systemctl enable NetworkManager.service
chroot /mnt systemctl enable ssh.service
# chroot /mnt systemctl enable --user pulseaudio.service
chroot /mnt systemctl enable rtkit-daemon.service
chroot /mnt systemctl enable chrony.service
chroot /mnt systemctl enable fstrim.timer
chroot /mnt systemctl enable lightdm.service 2>/dev/null || true
chroot /mnt systemctl enable qemu-guest-agent.service 2>/dev/null || true
chroot /mnt systemctl enable spice-vdagent.service 2>/dev/null || true

## Audio
## Pipewire
# chroot /mnt systemctl --user --now enable pipewire{,-pulse}.{socket,service}
# chroot /mnt systemctl --user --now disable pulseaudio.service pulseaudio.socket
# chroot /mnt systemctl --user mask pulseaudio.{socket,service}

# chroot /mnt systemctl --user daemon-reload

##Pulseaudio
# chroot /mnt systemctl --user enable pulseaudio.{socket,service}
#chroot /mnt systemctl --user --now disable pipewire{,-pulse}.{socket,service}
# chroot /mnt systemctl --user --now mask pipewire{,-pulse}.{socket,service}

# Allow run as root
# sed -i -e 's/ConditionUser=!root/#ConditionUser=!root/' /mnt/usr/lib/systemd/user/pipewire.socket
# sed -i -e 's/ConditionUser=!root/#ConditionUser=!root/' /mnt/etc/xdg/systemd/user/pipewire-pulse.service
# sed -i -e 's/ConditionUser=!root/#ConditionUser=!root/' /mnt/etc/xdg/systemd/user/sockets.target.wants/pipewire.socket
# sed -i -e 's/ConditionUser=!root/#ConditionUser=!root/' /mnt/etc/xdg/systemd/user/pipewire-pulse.socket
# sed -i -e 's/ConditionUser=!root/#ConditionUser=!root/' /mnt/etc/xdg/systemd/user/default.target.wants/pipewire.service

## Pulseaudio
# chroot /mnt systemctl --user enable pulseaudio

## Tune chrony ##
# touch /mnt/etc/chrony/chrony.conf
sed -i -E 's/^(pool[ \t]+.*)$/\1\nserver time.google.com iburst prefer\nserver time.windows.com iburst prefer/g' /mnt/etc/chrony/chrony.conf
# cat <<EOF >>/mnt/etc/chrony/chrony.conf
# server time.windows.com iburst prefer
# EOF

## Update initramfs
# chroot /mnt update-initramfs -c -k all


######################
#### Install grub ####
######################

# chroot /mnt grub-install --target=x86_64-efi --bootloader-id="${ROOT_LABEL}" --efi-directory=/boot/efi --no-nvram --removable --recheck
# chroot /mnt grub-install --target=x86_64-efi --bootloader-id="${ROOT_LABEL}" --efi-directory=/boot/efi --removable --recheck

##################################################
### Instalação do Kernel, Dracut e Bootloader ###
##################################################
echo "🐧 Instalando Kernel, Dracut e Bootloader com suporte a Secure Boot..."
chroot /mnt apt install -y \
  linux-image-amd64 linux-headers-amd64 \
  dracut dracut-core \
  shim-signed grub-efi-amd64-signed efibootmgr os-prober

##################################################
### Drivers de Vídeo VM e Multimídia           ###
##################################################
echo "🎮 Instalando Drivers de Vídeo VirtIO/QXL, Mesa, Vulkan e MPV..."
chroot /mnt apt install -y \
  xserver-xorg-video-qxl \
  xserver-xorg-video-all \
  libgl1-mesa-dri \
  mesa-vulkan-drivers \
  mpv

##################################################
### Gerar Initramfs via Dracut para os Kernels ###
##################################################
echo "📦 Gerando initramfs via Dracut..."
for kver in $(ls /mnt/lib/modules 2>/dev/null); do
  echo "Gerando Dracut initramfs para kernel $kver..."
  chroot /mnt dracut --kver "$kver" --force
done

#####################################
### Configuração e Instalação GRUB ###
#####################################
echo "⚙️ Configurando e instalando GRUB..."

cat <<EOF >/mnt/etc/default/grub
#
# Configuration file for GRUB — Virtual Machine (virt-manager)
#
GRUB_DEFAULT=saved
GRUB_TIMEOUT=3
GRUB_DISABLE_SUBMENU=false
GRUB_DISTRIBUTOR=\$(lsb_release -i -s 2>/dev/null || echo Debian)
GRUB_DISABLE_OS_PROBER=false
GRUB_CMDLINE_LINUX_DEFAULT="quiet rhgb apparmor=1 security=apparmor"
GRUB_DISABLE_RECOVERY="true"
GRUB_GFXMODE=1920x1080x32,auto
GRUB_COLOR_NORMAL="light-blue/black"
GRUB_COLOR_HIGHLIGHT="light-cyan/blue"
EOF

# Instalar GRUB EFI com Shim
chroot /mnt grub-install \
  --target=x86_64-efi \
  --efi-directory=/boot/efi \
  --bootloader-id=debian \
  --recheck

# Garantir cópia de fallback padrão em EFI/BOOT/BOOTX64.EFI (resolve Access Denied no OVMF)
mkdir -p /mnt/boot/efi/EFI/BOOT
if [ -f /mnt/boot/efi/EFI/debian/shimx64.efi ]; then
  cp -f /mnt/boot/efi/EFI/debian/shimx64.efi /mnt/boot/efi/EFI/BOOT/BOOTX64.EFI 2>/dev/null || true
  cp -f /mnt/boot/efi/EFI/debian/grubx64.efi /mnt/boot/efi/EFI/BOOT/grubx64.efi 2>/dev/null || true
  cp -f /mnt/boot/efi/EFI/debian/mmx64.efi /mnt/boot/efi/EFI/BOOT/mmx64.efi 2>/dev/null || true
  cp -f /mnt/boot/efi/EFI/debian/fbx64.efi /mnt/boot/efi/EFI/BOOT/fbx64.efi 2>/dev/null || true
fi

# Atualizar configuração do GRUB
chroot /mnt update-grub
chroot /mnt efibootmgr

chroot /mnt apt install extrepo -y
# chroot /mnt extrepo enable librewolf

chroot /mnt apt autoremove --purge -y
chroot /mnt apt clean
chroot /mnt apt autoclean

rm -rf /mnt/vmlinuz.old
rm -rf /mnt/vmlinuz
rm -rf /mnt/initrd.img
rm -rf /mnt/initrd.img.old
rm -rf /mnt/debootstrap
rm -f /mnt/etc/apt/apt.conf.d/99no-packagekit



# cmake -B build \
#   -DCMAKE_RELEASE_TYPE=Release \
#   -D[ENABLE_SYSTEMD=on] -D[USE_BPF_PROC_IMPL=on] [STATIC=on] \
#   -S .
# cmake --build build --target ananicy-cpp
# sudo cmake --install build --component Runtime

# gnome-disk-utilities
# nosuid,nodev,nofail,x-gvfs-show,auto
# https://github.com/fkortsagin/Simple-Debian-Setup

# virt-install \
# --name nixos \
# --boot uefi \
# --ram 8196 \
# --vcpus 4 \
# --network bridge:virbr0 \
# --os-variant nixos-unstable \
# --disk path=/var/lib/libvirt/images/nixos.qcow2,size=100 \
# --console pty,target_type=serial \
# --cdrom ~/Downloads/nixos-minimal-*-x86_64-linux.iso

# sudo apt install task-xfce-desktop

###########################
### VM POST-SETUP CHECK ###
###########################
touch /mnt/usr/local/bin/check-vm-setup.sh
cat << 'EOF' > /mnt/usr/local/bin/check-vm-setup.sh
#!/bin/bash
# Verificação rápida da instalação da Máquina Virtual (virtualvm)

echo "=========================================="
echo "🔍 Verificando status da Máquina Virtual"
echo "=========================================="

echo -n "1. EFI Bootloader (Shim & GRUB Signed): "
if [ -f "/boot/efi/EFI/debian/shimx64.efi" ]; then
    echo "OK (/boot/efi/EFI/debian/shimx64.efi assinado presente)"
elif [ -f "/boot/efi/EFI/debian/grubx64.efi" ]; then
    echo "OK (/boot/efi/EFI/debian/grubx64.efi presente)"
else
    echo "FALHA (bootloader não encontrado)"
fi

echo -n "2. Kernel e Dracut: "
KERNELS=$(ls /boot/vmlinuz-* 2>/dev/null | wc -l)
INITRDS=$(ls /boot/initramfs-*.img /boot/initrd.img-* 2>/dev/null | wc -l)
echo "$KERNELS kernel(s), $INITRDS initramfs gerado(s)"

echo -n "3. Sessão DWM (LightDM): "
if [ -f "/usr/share/xsessions/dwm.desktop" ] && [ -x "/usr/local/bin/start-dwm-session" ]; then
    echo "OK (dwm.desktop e start-dwm-session configurados)"
else
    echo "FALHA (arquivo de sessão ou wrapper ausente)"
fi

echo -n "4. QEMU Guest Agent e SPICE: "
if command -v qemu-ga >/dev/null 2>&1 || [ -x "/usr/sbin/qemu-ga" ]; then
    echo "OK (qemu-guest-agent presente)"
else
    echo "Aviso (verifique qemu-guest-agent)"
fi

echo -n "5. Nix Daemon: "
if [ -f "/etc/nix/nix.conf" ] && [ -f "/etc/profile.d/nix-env.sh" ]; then
    echo "OK (nix.conf e nix-env.sh presentes)"
else
    echo "Aviso (verifique /etc/nix/nix.conf)"
fi

echo "=========================================="
echo "💡 Próximo passo após reiniciar a VM:"
echo "   Faça login como '$username' e execute:"
echo "   home-manager switch --flake .#juca@virtualvm"
echo "=========================================="
EOF
chmod +x /mnt/usr/local/bin/check-vm-setup.sh

echo "🔍 Executando verificação de pós-instalação da VM..."
chroot /mnt /usr/local/bin/check-vm-setup.sh || true


### As sudo
# nix-env --install --file '<nixpkgs>' --attr nix cacert -I nixpkgs=channel:nixpkgs-unstable

# nix-shell -p nix-info --run "nix-info -m"
