#!/usr/bin/env bash
# ==============================================================================
# Script de Instalação do Debian (Trixie) para MacBook Pro 4,1 (Late 2008)
# Hardware Alvo:
#   - CPU: Intel Core 2 Duo (64-bit Penryn)
#   - GPU: NVIDIA GeForce 8600M GT (G84M)
#   - RAM: 6GB DDR2 (2GB + 4GB Canal Assimétrico)
#   - Wi-Fi: Broadcom BCM43xx (com NetworkManager + nm-applet)
#   - Boot: GPT com Partição BIOS Boot (2MB EF02) + EFI (512MB EF00)
#   - FS: Btrfs com subvolumes e compressão ZSTD
#   - Splash: Plymouth com Animação de Boot
#   - Desktop: XFCE4 (Catppuccin Mocha / Arc-Dark, Whisker Menu) + LightDM + Firefox
#   - Package Manager: Nix Multi-User (Flakes & nix-command habilitados)
# ==============================================================================

set -euo pipefail

# --- Cores para Terminal ---
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${CYAN}[INFO]${NC} $1"; }
log_ok()   { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[AVISO]${NC} $1"; }
log_err()  { echo -e "${RED}[ERRO]${NC} $1"; }

# --- Verificação de Root ---
if [ "$(id -u)" -ne 0 ]; then
    log_err "Este script deve ser executado como ROOT (ou via sudo)!"
    exit 1
fi

# --- Seleção do Disco Alvo ---
DRIVE="${1:-/dev/sda}"

log_warn "=========================================================================="
log_warn " ATENÇÃO: O disco ${DRIVE} será COMPLETAMENTE FORMATADO!"
log_warn " Instalação do Debian Trixie com XFCE4, Plymouth, Firefox & Nix para MacBook Pro 4,1."
log_warn "=========================================================================="
echo -n "Deseja continuar? (s/N): "
read -r CONFIRM
if [[ ! "$CONFIRM" =~ ^[sS]$ ]]; then
    log_info "Operação cancelada pelo usuário."
    exit 0
fi

# --- Sincronização do Relógio do Host e APT ---
log_info "Verificando relógio e sincronizando data do sistema..."
HTTP_DATE=$(curl -sI http://deb.debian.org | grep -i '^Date:' | cut -d' ' -f2- || true)
if [ -n "$HTTP_DATE" ]; then
    date -s "$HTTP_DATE" 2>/dev/null || true
fi

APT_OPT=("-o" "Acquire::Check-Valid-Until=false" "-o" "Acquire::Check-Date=false" "-o" "Acquire::AllowInsecureRepositories=true")

# --- Verificação de Dependências no Host ---
log_info "Verificando ferramentas necessárias no sistema live/host..."
PACKAGES_TO_INSTALL=()
if ! command -v debootstrap &>/dev/null; then PACKAGES_TO_INSTALL+=(debootstrap); fi
if ! command -v mkfs.btrfs &>/dev/null; then PACKAGES_TO_INSTALL+=(btrfs-progs); fi
if ! command -v sgdisk &>/dev/null; then PACKAGES_TO_INSTALL+=(gdisk); fi
if ! command -v parted &>/dev/null; then PACKAGES_TO_INSTALL+=(parted); fi
if ! command -v mkfs.vfat &>/dev/null; then PACKAGES_TO_INSTALL+=(dosfstools); fi
if ! command -v wipefs &>/dev/null; then PACKAGES_TO_INSTALL+=(util-linux); fi
if ! command -v wget &>/dev/null; then PACKAGES_TO_INSTALL+=(wget); fi
if ! command -v curl &>/dev/null; then PACKAGES_TO_INSTALL+=(curl); fi

if [ ${#PACKAGES_TO_INSTALL[@]} -ne 0 ]; then
    log_info "Instalando dependências ausentes no host: ${PACKAGES_TO_INSTALL[*]}..."
    apt-get update "${APT_OPT[@]}" -qq || true
    for pkg in "${PACKAGES_TO_INSTALL[@]}"; do
        apt-get install "${APT_OPT[@]}" -y "$pkg" || true
    done
fi

if ! command -v debootstrap &>/dev/null; then
    log_err "Não foi possível instalar o utilitário 'debootstrap' no sistema host/live!"
    exit 1
fi

# --- Desmontagem e Limpeza Agressiva de Partições no Disco ---
log_info "Parando automounters (udisks2) e liberando o disco ${DRIVE}..."
systemctl stop udisks2 udisks tracker 2>/dev/null || true

for mnt in $(grep "${DRIVE}" /proc/mounts 2>/dev/null | awk '{print $2}' | sort -r); do
    log_info "Desmontando ponto ativo: $mnt..."
    umount -R -f "$mnt" 2>/dev/null || true
done

swapoff -a 2>/dev/null || true
umount -R -f /mnt 2>/dev/null || true
umount -l "${DRIVE}"* 2>/dev/null || true
btrfs device scan --forget 2>/dev/null || true
fuser -k -9 "${DRIVE}"1 "${DRIVE}"2 "${DRIVE}"3 2>/dev/null || true
vgchange -an 2>/dev/null || true
dmsetup remove_all -f 2>/dev/null || true
losetup -D 2>/dev/null || true

log_info "Zerando assinaturas MBR/GPT antigas em ${DRIVE}..."
wipefs --all --force "${DRIVE}" 2>/dev/null || true
dd if=/dev/zero of="${DRIVE}" bs=1M count=10 status=none 2>/dev/null || true
sync

DISK_SECTORS=$(blockdev --getsz "${DRIVE}" 2>/dev/null || echo 0)
if [ "$DISK_SECTORS" -gt 2048 ]; then
    BACKUP_START=$((DISK_SECTORS - 2048))
    dd if=/dev/zero of="${DRIVE}" seek="${BACKUP_START}" bs=512 count=2048 status=none 2>/dev/null || true
    sync
fi

blockdev --rereadpt "${DRIVE}" 2>/dev/null || partprobe "${DRIVE}" 2>/dev/null || true
udevadm settle 2>/dev/null || true
sleep 2

# --- Particionamento GPT com BIOS Boot (2MB) + EFI (512MB) + Btrfs Root ---
log_info "Criando tabela de partições GPT no disco ${DRIVE}..."
set +e
parted -s -a optimal "${DRIVE}" -- \
    mklabel gpt \
    mkpart primary 2048s 6143s \
    set 1 bios_grub on \
    mkpart primary fat32 6144s 1054719s \
    set 2 esp on \
    mkpart primary btrfs 1054720s 100% 2>/dev/null

if [ $? -ne 0 ]; then
    log_warn "Aplicando segunda tentativa com sgdisk..."
    sgdisk -Z "${DRIVE}" 2>/dev/null || true
    sgdisk -n 1:2048:+2M -t 1:ef02 -c 1:"BIOS Boot Partition" "${DRIVE}" 2>/dev/null || true
    sgdisk -n 2:0:+512M -t 2:ef00 -c 2:"EFI System Partition" "${DRIVE}" 2>/dev/null || true
    sgdisk -n 3:0:0 -t 3:8300 -c 3:"Debian Btrfs System" "${DRIVE}" 2>/dev/null || true
fi
set -e

if [[ "${DRIVE}" =~ "nvme" ]] || [[ "${DRIVE}" =~ "mmcblk" ]]; then
    PART_BIOS="${DRIVE}p1"; PART_EFI="${DRIVE}p2"; PART_ROOT="${DRIVE}p3"
else
    PART_BIOS="${DRIVE}1"; PART_EFI="${DRIVE}2"; PART_ROOT="${DRIVE}3"
fi

blockdev --rereadpt "${DRIVE}" 2>/dev/null || partprobe "${DRIVE}" 2>/dev/null || true
udevadm settle 2>/dev/null || true
sleep 3

# Aguarda nós de dispositivos
for i in {1..10}; do
    if [ -b "${PART_EFI}" ] && [ -b "${PART_ROOT}" ]; then
        break
    fi
    sleep 1
done

log_ok "Partições criadas com sucesso em ${DRIVE}:"
lsblk "${DRIVE}" || true

# --- Formatação dos Sistemas de Arquivos ---
log_info "Formatando a Partição EFI em FAT32..."
mkfs.vfat -F32 "${PART_EFI}" -n "EFI"

log_info "Formatando a Partição Root em Btrfs..."
btrfs device scan --forget 2>/dev/null || true
wipefs -a -f "${PART_ROOT}" 2>/dev/null || true
udevadm settle 2>/dev/null || true
sleep 2

if ! mkfs.btrfs -f -L "Debian" "${PART_ROOT}"; then
    log_warn "Liberando trava temporária do udev na partição ${PART_ROOT} para nova tentativa..."
    btrfs device scan --forget 2>/dev/null || true
    fuser -k -9 "${PART_ROOT}" 2>/dev/null || true
    sleep 3
    mkfs.btrfs -f -L "Debian" "${PART_ROOT}"
fi

# --- Criação de Subvolumes Btrfs ---
log_info "Criando subvolumes Btrfs..."
BTRFS_OPTS="noatime,ssd,compress-force=zstd:2,space_cache=v2,commit=120,discard=async"

mount -o "${BTRFS_OPTS}" "${PART_ROOT}" /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@snapshots
btrfs subvolume create /mnt/@var_log
btrfs subvolume create /mnt/@var_cache_apt
btrfs subvolume create /mnt/@swap
umount -v /mnt

# --- Montagem da Estrutura de Diretórios ---
log_info "Montando estrutura de diretórios e subvolumes Btrfs em /mnt..."
mount -o "${BTRFS_OPTS},subvol=@" "${PART_ROOT}" /mnt
mkdir -pv /mnt/{boot/efi,home,.snapshots,var/log,var/cache/apt,swap}

mount -o "${BTRFS_OPTS},subvol=@home" "${PART_ROOT}" /mnt/home
mount -o "${BTRFS_OPTS},subvol=@snapshots" "${PART_ROOT}" /mnt/.snapshots
mount -o "${BTRFS_OPTS},subvol=@var_log" "${PART_ROOT}" /mnt/var/log
mount -o "${BTRFS_OPTS},subvol=@var_cache_apt" "${PART_ROOT}" /mnt/var/cache/apt
mount -o "${BTRFS_OPTS},subvol=@swap" "${PART_ROOT}" /mnt/swap
mount -t vfat -o noatime,nodiratime "${PART_EFI}" /mnt/boot/efi

# --- Debootstrap do Debian Trixie (64-bit Testing) ---
log_info "Executando debootstrap para Debian Trixie (amd64)..."
CODENAME="trixie"
MIRROR="http://deb.debian.org/debian"

debootstrap --variant=minbase \
    --include=apt,apt-utils,ca-certificates,sudo,neovim,locales,e2fsprogs,initramfs-tools,console-setup,dosfstools,btrfs-progs,kmod,less,gdisk,ncurses-base,netbase,procps,systemd,systemd-sysv,udev,iproute2,iputils-ping,bash,whiptail \
    --arch=amd64 "${CODENAME}" /mnt "${MIRROR}"

# --- Configuração do APT e Repositórios ---
log_info "Configurando repositórios oficiais Debian Trixie (main, contrib, non-free, non-free-firmware)..."
mkdir -pv /mnt/etc/apt/apt.conf.d /mnt/etc/apt/sources.list.d
rm -f /mnt/etc/apt/sources.list

cat <<EOF >/mnt/etc/apt/apt.conf.d/99no-recommends
APT::Install-Recommends "0";
APT::Install-Suggests "0";
EOF

cat <<EOF >/mnt/etc/apt/sources.list.d/debian.list
deb ${MIRROR} ${CODENAME} main contrib non-free non-free-firmware
deb-src ${MIRROR} ${CODENAME} main contrib non-free non-free-firmware

deb ${MIRROR} ${CODENAME}-updates main contrib non-free non-free-firmware
deb-src ${MIRROR} ${CODENAME}-updates main contrib non-free non-free-firmware

deb http://security.debian.org/debian-security ${CODENAME}-security main contrib non-free non-free-firmware
deb-src http://security.debian.org/debian-security ${CODENAME}-security main contrib non-free non-free-firmware
EOF

# --- Montagem de Sistemas de Arquivos Virtuais para Chroot ---
log_info "Montando pseudo-sistemas de arquivos para chroot..."
for dir in dev proc sys run; do
    mount --rbind "/$dir" "/mnt/$dir"
    mount --make-rslave "/mnt/$dir"
done

# --- Configuração de FSTAB ---
log_info "Gerando arquivo /etc/fstab..."
ROOT_UUID=$(blkid -s UUID -o value "${PART_ROOT}")
EFI_UUID=$(blkid -s UUID -o value "${PART_EFI}")

cat <<EOF >/mnt/etc/fstab
# /etc/fstab: static file system information.
# <file system>                           <mount point>   <type>  <options>                                             <dump>  <pass>
UUID=${ROOT_UUID}                         /               btrfs   rw,${BTRFS_OPTS},subvol=@                             0       0
UUID=${ROOT_UUID}                         /home           btrfs   rw,${BTRFS_OPTS},subvol=@home                         0       0
UUID=${ROOT_UUID}                         /.snapshots     btrfs   rw,${BTRFS_OPTS},subvol=@snapshots                    0       0
UUID=${ROOT_UUID}                         /var/log        btrfs   rw,${BTRFS_OPTS},subvol=@var_log                      0       0
UUID=${ROOT_UUID}                         /var/cache/apt  btrfs   rw,${BTRFS_OPTS},subvol=@var_cache_apt                0       0
UUID=${ROOT_UUID}                         /swap           btrfs   rw,${BTRFS_OPTS},subvol=@swap                         0       0

# EFI System Partition
UUID=${EFI_UUID}                          /boot/efi       vfat    rw,noatime,nodiratime,umask=0077,fmask=0022,dmask=0022 0       2

# Swapfile em Btrfs
/swap/swapfile                            none            swap    defaults,pri=100                                      0       0

# Tempfs em RAM
tmpfs                                     /tmp            tmpfs   noatime,mode=1777,nosuid,nodev                        0       0
EOF

# --- Configurações Básicas do Sistema (Hostname, Locales, Timezone) ---
log_info "Configurando Hostname (rocinante), Timezone e Locales..."
echo "rocinante" > /mnt/etc/hostname

cat <<EOF >/mnt/etc/hosts
127.0.0.1   localhost
127.0.1.1   rocinante
::1         localhost ip6-localhost ip6-loopback
ff02::1     ip6-allnodes
ff02::2     ip6-allrouters
EOF

chroot /mnt ln -sf /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime

cat <<EOF >/mnt/etc/locale.gen
en_US.UTF-8 UTF-8
pt_BR.UTF-8 UTF-8
EOF

log_info "Atualizando pacotes e gerando locales no chroot..."
chroot /mnt apt-get update -qq
chroot /mnt apt-get install -y locales || true
chroot /mnt locale-gen

cat <<EOF >/mnt/etc/default/locale
LANG=en_US.UTF-8
LC_ALL=en_US.UTF-8
EOF

# --- Instalação do Kernel, Microcode e Firmwares Apple/Broadcom Wi-Fi ---
log_info "Instalando Kernel Linux LTS, Microcode Intel e Drivers Wi-Fi Broadcom..."
chroot /mnt apt-get install -y --no-install-recommends \
    linux-image-amd64 \
    linux-headers-amd64 \
    intel-microcode \
    firmware-linux-free \
    firmware-linux-nonfree \
    firmware-misc-nonfree \
    firmware-b43-installer \
    b43-fwcutter \
    firmware-brcm80211 \
    broadcom-sta-dkms \
    wireless-regdb

# --- Instalação da Aceleração Gráfica Nouveau / Mesa / VDPAU (NVIDIA 8600M GT) ---
log_info "Instalando drivers de aceleração gráfica Nouveau / Mesa / VDPAU para NVIDIA 8600M GT..."
chroot /mnt apt-get install -y --no-install-recommends \
    xserver-xorg-video-nouveau \
    mesa-va-drivers \
    mesa-vdpau-drivers \
    vdpau-driver-all \
    va-driver-all \
    libgl1-mesa-dri \
    libvdpau1 \
    vdpauinfo \
    vainfo

# --- Instalação do Gerenciador de Rede, Applet Wi-Fi e SSH ---
log_info "Instalando NetworkManager com Widget nm-applet para a barra de tarefas..."
chroot /mnt apt-get install -y --no-install-recommends \
    network-manager \
    network-manager-gnome \
    rfkill \
    wireless-tools \
    wpasupplicant \
    openssh-server \
    openssh-client \
    curl \
    wget \
    rsync

mkdir -pv /mnt/etc/NetworkManager/conf.d
cat <<EOF >/mnt/etc/NetworkManager/NetworkManager.conf
[main]
plugins=ifupdown,keyfile

[ifupdown]
managed=true

[device]
wifi.scan-rand-mac-address=no
EOF

# --- Instalação do Plymouth (Splash Screen com Animação de Boot) ---
log_info "Instalando e configurando animação de boot Plymouth..."
chroot /mnt apt-get install -y --no-install-recommends \
    plymouth \
    plymouth-themes \
    plymouth-x11

# Define tema moderno de animação (spinner / bgrt)
chroot /mnt plymouth-set-default-theme -R spinner 2>/dev/null || chroot /mnt plymouth-set-default-theme -R bgrt 2>/dev/null || true

# --- Instalação das Ferramentas Térmicas e de Energia (MacBook Pro) ---
log_info "Instalando ferramentas térmicas e de energia (mbpfan, tlp, powertop, earlyoom)..."
chroot /mnt apt-get install -y --no-install-recommends \
    mbpfan \
    tlp \
    powertop \
    thermald \
    irqbalance \
    earlyoom \
    zram-tools \
    chrony \
    rsyslog

cat <<EOF >/mnt/etc/mbpfan.conf
[general]
min_fan1_speed = 2000
max_fan1_speed = 6000
low_temp = 55
high_temp = 72
max_temp = 86
polling_interval = 2
EOF

# --- Instalação de Utilitários CLI Modernos e Navegador Firefox ---
log_info "Instalando Firefox ESR, utilitários CLI modernos (eza, bat, duf, fzf, ripgrep, btop)..."
chroot /mnt apt-get install -y --no-install-recommends \
    firefox-esr \
    firefox-esr-l10n-pt-br \
    eza \
    bat \
    duf \
    fzf \
    ripgrep \
    htop \
    btop \
    zstd \
    bash-completion \
    lm-sensors \
    pciutils \
    usbutils \
    sysfsutils \
    acpid \
    dkms

# --- Tuning de Memória Virtual para 6GB RAM (Canal Assimétrico) ---
log_info "Aplicando tuning de sysctl para 6GB RAM assimétrica..."
mkdir -pv /mnt/etc/sysctl.d
cat <<EOF >/mnt/etc/sysctl.d/99-macbook-memory.conf
vm.swappiness=60
vm.vfs_cache_pressure=50
vm.dirty_background_ratio=5
vm.dirty_ratio=15
vm.dirty_writeback_centisecs=1500
dev.i915.perf_stream_paranoid=0
EOF

cat <<EOF >/mnt/etc/default/zram-tools
ALGO=zstd
PERCENT=50
PRIORITY=100
EOF

# --- Criação do Swapfile Btrfs (6GB) de Forma Segura ---
log_info "Criando arquivo de swap de 6GB no subvolume Btrfs @swap..."
# Desabilita CoW explicitamente no arquivo antes de alocar blocos
truncate -s 0 /mnt/swap/swapfile
chmod 600 /mnt/swap/swapfile
chroot /mnt chattr +C /swap/swapfile 2>/dev/null || true
chroot /mnt btrfs property set /swap/swapfile compression none 2>/dev/null || true
dd if=/dev/zero of=/mnt/swap/swapfile bs=1M count=6144 status=progress
mkswap /mnt/swap/swapfile

# --- Criação de Usuário e Senhas ---
log_info "Configurando usuários e permissões..."
echo "root:200291" | chroot /mnt chpasswd -c SHA512
chroot /mnt useradd juca -m -c "Reinaldo P JR" -s /bin/bash
echo "juca:200291" | chroot /mnt chpasswd -c SHA512
chroot /mnt usermod -aG sudo,audio,video,systemd-journal,input,netdev,render juca

# ==============================================================================
# --- INSTALAÇÃO E CONFIGURAÇÃO DO AMBIENTE XFCE4 (TEMAS ELEGANTES & WIDGETS) ---
# ==============================================================================
log_info "Instalando ambiente XFCE4, Whisker Menu, LightDM, Thunar e áudio Pipewire..."
chroot /mnt apt-get install -y --no-install-recommends \
    xorg \
    xserver-xorg-core \
    xserver-xorg-video-nouveau \
    xserver-xorg-input-libinput \
    x11-xserver-utils \
    xinit \
    xfce4-session \
    xfwm4 \
    xfdesktop4 \
    xfce4-panel \
    xfce4-terminal \
    xfce4-settings \
    xfce4-power-manager \
    xfce4-pulseaudio-plugin \
    xfce4-whiskermenu-plugin \
    xfce4-netload-plugin \
    xfce4-wavelan-plugin \
    xfce4-screenshooter \
    xfce4-taskmanager \
    thunar \
    thunar-volman \
    thunar-archive-plugin \
    mousepad \
    lightdm \
    lightdm-gtk-greeter \
    pipewire \
    pipewire-audio-client-libraries \
    pipewire-pulse \
    wireplumber \
    pavucontrol \
    pamixer \
    brightnessctl \
    papirus-icon-theme \
    arc-theme \
    greybird-gtk-theme \
    fonts-inter \
    fonts-roboto \
    fonts-firacode \
    fonts-font-awesome

chroot /mnt apt-get install -y --no-install-recommends polkit-1-auth-agent 2>/dev/null || \
chroot /mnt apt-get install -y --no-install-recommends lxpolkit 2>/dev/null || \
chroot /mnt apt-get install -y --no-install-recommends policykit-1-gnome 2>/dev/null || true

# --- Configuração do Display Manager LightDM ---
log_info "Configurando o gerenciador de login LightDM com tema escuro elegante..."
mkdir -pv /mnt/etc/lightdm/lightdm.conf.d
cat <<EOF >/mnt/etc/lightdm/lightdm.conf.d/01-xfce.conf
[Seat:*]
user-session=xfce
greeter-session=lightdm-gtk-greeter
EOF

cat <<EOF >/mnt/etc/lightdm/lightdm-gtk-greeter.conf
[greeter]
theme-name = Arc-Dark
icon-theme-name = Papirus-Dark
font-name = Inter 10
background = #1e1e2e
EOF

# --- Configurações de Estética e Terminal XFCE4 para o Usuário juca ---
USER_HOME="/mnt/home/juca"
mkdir -pv "${USER_HOME}/.config/"{xfce4/terminal,xfce4/xfconf/xfce-perchannel-xml,autostart}

# Autostart do Widget de Wi-Fi nm-applet
cat <<'EOF' > "${USER_HOME}/.config/autostart/nm-applet.desktop"
[Desktop Entry]
Type=Application
Name=Network
Comment=Manage your network connections
Icon=nm-device-wireless
Exec=nm-applet
Terminal=false
StartupNotify=false
EOF

log_info "Configurando cores Catppuccin Mocha / RedTheme no XFCE Terminal..."
cat <<'EOF' > "${USER_HOME}/.config/xfce4/terminal/terminalrc"
[Configuration]
FontName=Fira Code 11
ColorPalette=#1e1e2e;#ff2a4b;#40ff7d;#ffe066;#89b4fa;#cba6f7;#94e2d5;#cdd6f4;#585b70;#ff4060;#50fa7b;#ffb86c;#8be9fd;#bd93f9;#ff79c6;#f2f4fc
ColorForeground=#f2f4fc
ColorBackground=#1e1e2e
ColorCursor=#ff2a4b
ColorBold=#f2f4fc
TabActivityColor=#ff6600
ScrollingBar=TERMINAL_SCROLLING_BAR_OFF
MiscCursorBlinks=FALSE
MiscDefaultGeometry=110x32
EOF

# Pré-configurar Tema Escuro e Fontes no XFCE4
cat <<'EOF' > "${USER_HOME}/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml"
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xsettings" version="1.0">
  <property name="Net" type="empty">
    <property name="ThemeName" type="string" value="Arc-Dark"/>
    <property name="IconThemeName" type="string" value="Papirus-Dark"/>
    <property name="CursorThemeName" type="string" value="Adwaita"/>
  </property>
  <property name="Gtk" type="empty">
    <property name="FontName" type="string" value="Inter 10"/>
    <property name="MonospaceFontName" type="string" value="Fira Code 10"/>
  </property>
</channel>
EOF

cat <<'EOF' > "${USER_HOME}/.config/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml"
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfwm4" version="1.0">
  <property name="general" type="empty">
    <property name="theme" type="string" value="Arc-Dark"/>
    <property name="title_font" type="string" value="Inter Bold 10"/>
    <property name="box_resize" type="bool" value="false"/>
    <property name="cycle_minimum" type="bool" value="true"/>
  </property>
</channel>
EOF

chroot /mnt chown -R juca:juca /home/juca/.config

# ==============================================================================
# --- INSTALAÇÃO E CONFIGURAÇÃO DO GERENCIADOR DE PACOTES NIX ---
# ==============================================================================
log_info "Instalando e configurando o gerenciador de pacotes Nix..."
chroot /mnt apt-get install -y --no-install-recommends nix-bin nix-setup-systemd 2>/dev/null || true

mkdir -pv /mnt/etc/nix
cat <<EOF >/mnt/etc/nix/nix.conf
experimental-features = nix-command flakes
trusted-users = root juca
substituters = https://cache.nixos.org/
trusted-substituters = https://cache.nixos.org/
EOF

chroot /mnt groupadd -r nix-users 2>/dev/null || true
chroot /mnt usermod -aG nix-users juca 2>/dev/null || true

cat <<'EOF' >> /mnt/home/juca/.bashrc

# Nix Package Manager environment setup
if [ -e /etc/profile.d/nix.sh ]; then
    . /etc/profile.d/nix.sh
fi
EOF

cat <<'EOF' >> /mnt/root/.bashrc

# Nix Package Manager environment setup
if [ -e /etc/profile.d/nix.sh ]; then
    . /etc/profile.d/nix.sh
fi
EOF

chroot /mnt chown juca:juca /home/juca/.bashrc

# --- Instalação dos Bootloaders (GRUB Legacy i386-pc + GRUB EFI x86_64) ---
log_info "Instalando pacotes do GRUB (grub-pc, grub-pc-bin, grub-efi-amd64-bin e efibootmgr)..."
chroot /mnt apt-get install -y --no-install-recommends \
    grub-pc \
    grub-pc-bin \
    grub-efi-amd64-bin \
    efibootmgr

log_info "Instalando o GRUB BIOS (i386-pc) em ${DRIVE} para inicializar a VBIOS da NVIDIA 8600M GT..."
chroot /mnt grub-install --target=i386-pc "${DRIVE}"

log_info "Instalando o GRUB EFI (x86_64-efi) em /boot/efi como fallback..."
chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot/efi --no-nvram --removable --recheck

# --- Configuração do arquivo /etc/default/grub com Suporte a Plymouth e Hibernação ---
log_info "Configurando parâmetros de boot no GRUB (com animação Plymouth)..."
cat <<EOF >/mnt/etc/default/grub
GRUB_DEFAULT=0
GRUB_TIMEOUT=2
GRUB_DISTRIBUTOR="Debian"
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash plymouth.ignore-serial-consoles apparmor=1 security=apparmor i915.modeset=0 nouveau.modeset=1 pcie_aspm=force zswap.enabled=1 zswap.compressor=zstd mitigations=off nowatchdog"
GRUB_CMDLINE_LINUX=""
GRUB_GFXMODE=1280x800x32
GRUB_COLOR_NORMAL="light-gray/black"
GRUB_COLOR_HIGHLIGHT="white/blue"
EOF

# Configurar parâmetro de hibernação (resume_offset) no GRUB
if command -v filefrag &>/dev/null; then
    OFFSET=$(filefrag -v /mnt/swap/swapfile | awk '$1=="0:" {print substr($4, 1, length($4)-2)}' | head -n1 || true)
    if [ -n "$OFFSET" ]; then
        log_info "Configurando resume offset para hibernação: resume=UUID=${ROOT_UUID} resume_offset=${OFFSET}..."
        sed -i "s/GRUB_CMDLINE_LINUX=\"\"/GRUB_CMDLINE_LINUX=\"resume=UUID=${ROOT_UUID} resume_offset=${OFFSET}\"/g" /mnt/etc/default/grub
    fi
fi

chroot /mnt update-grub
chroot /mnt update-initramfs -u -k all

# --- Ativação dos Serviços do Systemd ---
log_info "Ativando serviços essenciais no systemd (incluindo o Display Manager LightDM)..."
chroot /mnt systemctl enable NetworkManager.service 2>/dev/null || true
chroot /mnt systemctl enable ssh.service 2>/dev/null || true
chroot /mnt systemctl enable lightdm.service 2>/dev/null || true
chroot /mnt systemctl enable earlyoom.service 2>/dev/null || true
chroot /mnt systemctl enable mbpfan.service 2>/dev/null || true
chroot /mnt systemctl enable tlp.service 2>/dev/null || true
chroot /mnt systemctl enable thermald.service 2>/dev/null || true
chroot /mnt systemctl enable irqbalance.service 2>/dev/null || true
chroot /mnt systemctl enable zramswap.service 2>/dev/null || chroot /mnt systemctl enable zram-tools.service 2>/dev/null || true
chroot /mnt systemctl enable nix-daemon.service 2>/dev/null || true

# --- Desmontagem Limpa do Sistema ao Final da Instalação ---
log_info "Desmontando pontos de montagem temporários de /mnt..."
swapoff -a 2>/dev/null || true
umount -R -f /mnt 2>/dev/null || true

log_ok "=========================================================================="
log_ok " Instalação do Debian com XFCE4, Plymouth, Firefox & Nix concluída com SUCESSO!"
log_ok "=========================================================================="
log_info "Você já pode reiniciar o computador e remover a mídia de instalação."
log_info "Ao reiniciar, a animação do Plymouth e a tela gráfica do LightDM carregarão."
log_info "Faça login com o usuário 'juca' (senha: 200291) no ambiente XFCE4."
