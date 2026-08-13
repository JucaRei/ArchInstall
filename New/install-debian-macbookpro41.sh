#!/usr/bin/env bash
# ==============================================================================
# Script de Instalação do Debian (Bookworm) para MacBook Pro 4,1 (Late 2008)
# Hardware Alvo:
#   - CPU: Intel Core 2 Duo (64-bit Penryn)
#   - GPU: NVIDIA GeForce 8600M GT (G84M)
#   - RAM: 6GB DDR2 (2GB + 4GB Canal Assimétrico)
#   - Wi-Fi: Broadcom BCM43xx
#   - Boot: GPT Híbrido com Partição BIOS Boot (2MB EF02) + EFI (EF00)
#   - FS: Btrfs com subvolumes e compressão ZSTD
#   - Desktop: Hyprland (Wayland) + Waybar + Wofi + Foot (Estética Catppuccin)
#   - Package Manager: Nix Multi-User (Flakes & nix-command habilitados)
# ==============================================================================

set -euo pipefail

# --- Cores para saída gráfica ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m'

log_info()  { echo -e "${BLUE}[INFO]${NC} $1"; }
log_ok()    { echo -e "${GREEN}[OK]${NC} $1"; }
log_warn()  { echo -e "${YELLOW}[AVISO]${NC} $1"; }
log_error() { echo -e "${RED}[ERRO]${NC} $1"; exit 1; }

# --- Verificação de Privilégios de Root ---
if [ "$(id -u)" -ne 0 ]; then
    log_error "Este script deve ser executado como root (sudo)."
fi

# --- Seleção do Disco Alvo ---
DRIVE="${1:-/dev/sda}"

log_warn "=========================================================================="
log_warn " ATENÇÃO: O disco ${DRIVE} será COMPLETAMENTE FORMATADO!"
log_warn " Instalação do Debian Bookworm com Hyprland & Nix para MacBook Pro 4,1."
log_warn "=========================================================================="
echo -n "Deseja continuar? (s/N): "
read -r CONFIRM
if [[ ! "$CONFIRM" =~ ^[sS]$ ]]; then
    log_info "Operação cancelada pelo usuário."
    exit 0
fi

# --- Sincronização do Relógio do Host e APT ---
log_info "Verificando relógio e atualizando lista do APT no host (ignorando validação estrita de data)..."
# Tenta sincronizar a data do sistema com servidor NTP se houver rede
if command -v ntpdate &>/dev/null; then
    ntpdate -s pool.ntp.org 2>/dev/null || true
elif command -v chronyd &>/dev/null; then
    chronyd -q 'server pool.ntp.org iburst' 2>/dev/null || true
fi

# Passa flags do APT para evitar erro "Release file is not valid yet" em mídias live com data desalinhada
APT_OPT=("-o" "Acquire::Check-Valid-Until=false" "-o" "Acquire::Check-Date=false")

# --- Verificação de Dependências no Host ---
log_info "Verificando ferramentas necessárias no sistema live/host..."
HOST_DEPS=(debootstrap btrfs-progs sgdisk parted mkfs.vfat wget curl wipefs)
FOR_INSTALL=()
for dep in "${HOST_DEPS[@]}"; do
    if ! command -v "$dep" &>/dev/null; then
        FOR_INSTALL+=("$dep")
    fi
done

if [ ${#FOR_INSTALL[@]} -ne 0 ]; then
    log_info "Instalando dependências ausentes no host: ${FOR_INSTALL[*]}..."
    apt-get update "${APT_OPT[@]}" -qq || true
    apt-get install "${APT_OPT[@]}" -y -qq "${FOR_INSTALL[@]}" || true
fi

# --- Desmontagem e Limpeza Agressiva de Partições no Disco ---
log_info "Desmontando e liberando todas as partições ativas em ${DRIVE}..."
swapoff -a 2>/dev/null || true
umount -R /mnt 2>/dev/null || true
umount -l "${DRIVE}"* 2>/dev/null || true
vgchange -an 2>/dev/null || true
dmsetup remove_all -f 2>/dev/null || true

log_info "Limpando assinaturas antigas de sistema de arquivos (wipefs / zap-all)..."
wipefs --all --force "${DRIVE}" 2>/dev/null || true
sgdisk --zap-all "${DRIVE}" 2>/dev/null || true
partprobe "${DRIVE}" 2>/dev/null || true
udevadm settle 2>/dev/null || true
sleep 3
sgdisk -Z "${DRIVE}"
parted -s -a optimal "${DRIVE}" mklabel gpt

# Partição 1: BIOS Boot Partition (2MB) - Necessária para o GRUB i386-pc inicializar a VBIOS da GPU NVIDIA 8600M GT
log_info "Criando Partição 1: BIOS Boot Partition (2MB, tipo EF02)..."
sgdisk -n 1:2048:+2M -t 1:ef02 -c 1:"BIOS Boot Partition" "${DRIVE}"

# Partição 2: EFI System Partition (512MB) - Suporte a boot EFI
log_info "Criando Partição 2: EFI System Partition (512MB, tipo EF00)..."
sgdisk -n 2:0:+512M -t 2:ef00 -c 2:"EFI System Partition" "${DRIVE}"

# Partição 3: Linux Root Btrfs (Restante do disco)
log_info "Criando Partição 3: Btrfs Linux Root (tipo 8300)..."
sgdisk -n 3:0:0 -t 3:8300 -c 3:"Debian Btrfs System" "${DRIVE}"

# Detectar nomes das partições (suporta /dev/sdaX e /dev/nvme0n1pX)
if [[ "${DRIVE}" =~ "nvme" ]] || [[ "${DRIVE}" =~ "mmcblk" ]]; then
    PART_BIOS="${DRIVE}p1"
    PART_EFI="${DRIVE}p2"
    PART_ROOT="${DRIVE}p3"
else
    PART_BIOS="${DRIVE}1"
    PART_EFI="${DRIVE}2"
    PART_ROOT="${DRIVE}3"
fi

partprobe "${DRIVE}" 2>/dev/null || true
udevadm settle 2>/dev/null || true
sleep 3

# --- Formatação dos Sistemas de Arquivos ---
log_info "Formatando a Partição EFI em FAT32..."
mkfs.vfat -F32 "${PART_EFI}" -n "EFI"

log_info "Formatando a Partição Root em Btrfs..."
mkfs.btrfs -f -L "Debian" "${PART_ROOT}"

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

# --- Montagem dos Subvolumes ---
log_info "Montando estrutura de diretórios e subvolumes Btrfs em /mnt..."
mount -o "${BTRFS_OPTS},subvol=@" "${PART_ROOT}" /mnt
mkdir -pv /mnt/{boot/efi,home,.snapshots,var/log,var/cache/apt,swap}

mount -o "${BTRFS_OPTS},subvol=@home" "${PART_ROOT}" /mnt/home
mount -o "${BTRFS_OPTS},subvol=@snapshots" "${PART_ROOT}" /mnt/.snapshots
mount -o "${BTRFS_OPTS},subvol=@var_log" "${PART_ROOT}" /mnt/var/log
mount -o "${BTRFS_OPTS},subvol=@var_cache_apt" "${PART_ROOT}" /mnt/var/cache/apt
mount -o "${BTRFS_OPTS},subvol=@swap" "${PART_ROOT}" /mnt/swap
mount -t vfat -o noatime,nodiratime "${PART_EFI}" /mnt/boot/efi

# --- Debootstrap do Debian 12 Bookworm (64-bit) ---
log_info "Executando debootstrap para Debian Bookworm (amd64)..."
CODENAME="bookworm"
MIRROR="http://deb.debian.org/debian"

debootstrap --variant=minbase \
    --include=apt,apt-utils,ca-certificates,sudo,neovim,initramfs-tools,console-setup,dosfstools,btrfs-progs,kmod,less,gdisk,ncurses-base,netbase,procps,systemd,systemd-sysv,udev,iproute2,iputils-ping,bash,whiptail \
    --arch=amd64 "${CODENAME}" /mnt "${MIRROR}"

# --- Configuração do APT e Repositórios ---
log_info "Configurando repositórios oficiais Debian (main, contrib, non-free, non-free-firmware)..."
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

deb https://security.debian.org/debian-security ${CODENAME}-security main contrib non-free non-free-firmware
deb-src ${MIRROR} ${CODENAME}-security main contrib non-free non-free-firmware

deb ${MIRROR} ${CODENAME}-backports main contrib non-free non-free-firmware
deb-src ${MIRROR} ${CODENAME}-backports main contrib non-free non-free-firmware
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

# Swapfile
/swap/swapfile                            none            swap    sw,pri=100                                            0       0

# Tempfs em RAM
tmpfs                                     /tmp            tmpfs   noatime,mode=1777,nosuid,nodev                        0       0
EOF

# --- Configurações Básicas do Sistema (Hostname, Locales, Timezone) ---
log_info "Configurando Hostname, Timezone e Locales..."
echo "macbookpro41" > /mnt/etc/hostname

cat <<EOF >/mnt/etc/hosts
127.0.0.1   localhost
127.0.1.1   macbookpro41
::1         localhost ip6-localhost ip6-loopback
ff02::1     ip6-allnodes
ff02::2     ip6-allrouters
EOF

chroot /mnt ln -sf /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime

cat <<EOF >/mnt/etc/locale.gen
en_US.UTF-8 UTF-8
pt_BR.UTF-8 UTF-8
EOF

chroot /mnt locale-gen
cat <<EOF >/mnt/etc/default/locale
LANG=en_US.UTF-8
LC_ALL=en_US.UTF-8
EOF

# --- Atualização do banco de dados de pacotes no chroot ---
log_info "Atualizando pacotes dentro do chroot..."
chroot /mnt apt-get update -qq

# --- Instalação do Kernel, Microcode e Firmwares Apple/Broadcom ---
log_info "Instalando Kernel Linux LTS, Microcode Intel e Firmwares..."
chroot /mnt apt-get install -y --no-install-recommends \
    linux-image-amd64 \
    linux-headers-amd64 \
    intel-microcode \
    firmware-linux-free \
    firmware-linux-nonfree \
    firmware-misc-nonfree \
    firmware-b43-installer \
    firmware-brcm80211 \
    broadcom-sta-dkms

# --- Instalação da Aceleração Gráfica Nouveau / Mesa / VDPAU (NVIDIA 8600M GT) ---
log_info "Instalando drivers de aceleração gráfica Nouveau / Mesa / VDPAU para NVIDIA 8600M GT..."
chroot /mnt apt-get install -y --no-install-recommends \
    xserver-xorg-video-nouveau \
    mesa-va-drivers \
    mesa-vdpau-drivers \
    vdpau-driver-all \
    libgl1-mesa-dri \
    libvdpau-va-gl

# --- Instalação do Gerenciador de Rede e Conectividade ---
log_info "Instalando gerenciador de rede NetworkManager, IWD e SSH..."
chroot /mnt apt-get install -y --no-install-recommends \
    network-manager \
    iwd \
    rfkill \
    wireless-tools \
    wpasupplicant \
    openssh-server \
    openssh-client \
    curl \
    wget \
    rsync

mkdir -pv /mnt/etc/NetworkManager/conf.d
cat <<EOF >/mnt/etc/NetworkManager/conf.d/iwd.conf
[device]
wifi.backend=iwd
wifi.iwd.autoconnect=yes
EOF

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

# --- Instalação de Utilitários CLI ---
log_info "Instalando utilitários CLI modernos (eza, bat, duf, fzf, ripgrep, htop, btop)..."
chroot /mnt apt-get install -y --no-install-recommends \
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

# --- Criação do Swapfile Btrfs (6GB) ---
log_info "Criando arquivo de swap de 6GB no subvolume Btrfs @swap..."
touch /mnt/swap/swapfile
chmod 600 /mnt/swap/swapfile
chroot /mnt chattr +C /swap/swapfile || true
dd if=/dev/zero of=/mnt/swap/swapfile bs=1M count=6144 status=progress
mkswap /mnt/swap/swapfile

# --- Criação de Usuário e Senhas ---
log_info "Configurando usuários e permissões..."
echo "root:200291" | chroot /mnt chpasswd -c SHA512
chroot /mnt useradd juca -m -c "Reinaldo P JR" -s /bin/bash
echo "juca:200291" | chroot /mnt chpasswd -c SHA512
chroot /mnt usermod -aG sudo,audio,video,systemd-journal,input,netdev,render juca

# ==============================================================================
# --- INSTALAÇÃO E CONFIGURAÇÃO DO HYPRLAND & AMBIENTE WAYLAND ---
# ==============================================================================
log_info "Instalando Hyprland, Waybar, Wofi, Foot, Dunst e Pipewire..."
chroot /mnt apt-get install -y --no-install-recommends \
    hyprland \
    hyprpaper \
    xdg-desktop-portal-hyprland \
    xdg-desktop-portal-gtk \
    waybar \
    wofi \
    foot \
    dunst \
    sddm \
    polkit-kde-agent-1 \
    pipewire \
    pipewire-audio-client-libraries \
    pipewire-pulse \
    wireplumber \
    pavucontrol \
    pamixer \
    brightnessctl \
    grim \
    slurp \
    wl-clipboard \
    fonts-firacode \
    fonts-font-awesome \
    qt5-wayland \
    qt6-wayland

# --- Configuração do Session Desktop Entry para o Hyprland no Display Manager (SDDM) ---
mkdir -pv /mnt/usr/share/wayland-sessions
cat <<EOF >/mnt/usr/share/wayland-sessions/hyprland.desktop
[Desktop Entry]
Name=Hyprland
Comment=An intelligent dynamic tiling Wayland compositor
Exec=Hyprland
Type=Application
DesktopNames=Hyprland
Keywords=wayland;compositor;tiling;
EOF

USER_HOME="/mnt/home/juca"
mkdir -pv "${USER_HOME}/.config/"{hypr,waybar,wofi,foot,dunst}

# --- Archivo de Configuração do Hyprland (~/.config/hypr/hyprland.conf) ---
log_info "Gerando configuração estética e eficiente do Hyprland (~/.config/hypr/hyprland.conf)..."
cat <<'EOF' > "${USER_HOME}/.config/hypr/hyprland.conf"
# ==============================================================================
# Configuração do Hyprland para MacBook Pro 4,1 (Debian 12 Bookworm)
# Estética: Catppuccin Mocha com Acentos Vermelho/Laranja (#ff2a4b / #ff6600)
# ==============================================================================

# --- Monitores ---
# Monitor nativo do MacBook Pro 15" (1280x800 @ 60Hz)
monitor=LVDS-1,1280x800@60,0x0,1
monitor=,preferred,auto,1

# --- Variáveis de Ambiente para Wayland & GPU Nouveau ---
env = XDG_CURRENT_DESKTOP,Hyprland
env = XDG_SESSION_TYPE,wayland
env = XDG_SESSION_DESKTOP,Hyprland
env = GDK_BACKEND,wayland,x11,*
env = QT_QPA_PLATFORM,wayland;xcb
env = MOZ_ENABLE_WAYLAND,1
env = WLR_NO_HARDWARE_CURSORS,1
env = LIBGL_ALWAYS_SOFTWARE,0

# --- Autostart ---
exec-once = dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP
exec-once = systemctl --user import-environment WAYLAND_DISPLAY XDG_CURRENT_DESKTOP
exec-once = /usr/lib/x86_64-linux-gnu/libexec/polkit-kde-authentication-agent-1
exec-once = waybar &
exec-once = dunst &
exec-once = pipewire & wireplumber &

# --- Programas Padrão ---
$terminal = foot
$menu = wofi --show drun
$fileManager = foot -e yazi

# --- Aparência e Decoração ---
general {
    gaps_in = 4
    gaps_out = 8
    border_size = 2
    col.active_border = rgba(ff2a4bee) rgba(ff6600ee) 45deg
    col.inactive_border = rgba(313248aa)
    layout = dwindle
    allow_tearing = false
}

decoration {
    rounding = 8
    active_opacity = 0.96
    inactive_opacity = 0.90
    drop_shadow = true
    shadow_range = 10
    shadow_render_power = 3
    col.shadow = rgba(1a1a1aee)
    
    blur {
        enabled = true
        size = 3
        passes = 1
        vibrancy = 0.1696
    }
}

animations {
    enabled = true
    bezier = myBezier, 0.05, 0.9, 0.1, 1.05
    animation = windows, 1, 4, myBezier
    animation = windowsOut, 1, 4, default, popin 80%
    animation = border, 1, 6, default
    animation = borderangle, 1, 6, default
    animation = fade, 1, 4, default
    animation = workspaces, 1, 3, default
}

dwindle {
    pseudotile = true
    preserve_split = true
}

master {
    new_status = master
}

gestures {
    workspace_swipe = true
    workspace_swipe_fingers = 3
}

misc {
    force_default_wallpaper = 0
    disable_hyprland_logo = true
}

# --- Atalhos de Teclado (Keybindings) ---
$mainMod = SUPER

# Atalhos Principais
bind = $mainMod, Return, exec, $terminal
bind = $mainMod, Q, killactive,
bind = $mainMod, M, exit,
bind = $mainMod, E, exec, $fileManager
bind = $mainMod, V, togglefloating,
bind = $mainMod, Space, exec, $menu
bind = $mainMod, D, exec, $menu
bind = $mainMod, F, fullscreen, 0

# Foco de Janelas (Vim Style / Setas)
bind = $mainMod, left, movefocus, l
bind = $mainMod, right, movefocus, r
bind = $mainMod, up, movefocus, u
bind = $mainMod, down, movefocus, d

bind = $mainMod, H, movefocus, l
bind = $mainMod, L, movefocus, r
bind = $mainMod, K, movefocus, u
bind = $mainMod, J, movefocus, d

# Mover Janelas
bind = $mainMod SHIFT, left, movewindow, l
bind = $mainMod SHIFT, right, movewindow, r
bind = $mainMod SHIFT, up, movewindow, u
bind = $mainMod SHIFT, down, movewindow, d

# Workspaces (1 - 6)
bind = $mainMod, 1, workspace, 1
bind = $mainMod, 2, workspace, 2
bind = $mainMod, 3, workspace, 3
bind = $mainMod, 4, workspace, 4
bind = $mainMod, 5, workspace, 5
bind = $mainMod, 6, workspace, 6

bind = $mainMod SHIFT, 1, movetoworkspace, 1
bind = $mainMod SHIFT, 2, movetoworkspace, 2
bind = $mainMod SHIFT, 3, movetoworkspace, 3
bind = $mainMod SHIFT, 4, movetoworkspace, 4
bind = $mainMod SHIFT, 5, movetoworkspace, 5
bind = $mainMod SHIFT, 6, movetoworkspace, 6

# Controle de Brilho e Volume do MacBook
binde = , XF86MonBrightnessUp, exec, brightnessctl set +5%
binde = , XF86MonBrightnessDown, exec, brightnessctl set 5%-
binde = , XF86AudioRaiseVolume, exec, pamixer -i 5
binde = , XF86AudioLowerVolume, exec, pamixer -d 5
binde = , XF86AudioMute, exec, pamixer -t

# Mover/Redimensionar Janelas com o Mouse
bindm = $mainMod, mouse:272, movewindow
bindm = $mainMod, mouse:273, resizewindow
EOF

# --- Estilo do Waybar (~/.config/waybar/config & style.css) ---
log_info "Gerando configuração da barra de status Waybar..."
cat <<'EOF' > "${USER_HOME}/.config/waybar/config"
{
    "layer": "top",
    "position": "top",
    "height": 30,
    "spacing": 4,
    "modules-left": ["hyprland/workspaces", "hyprland/window"],
    "modules-center": ["clock"],
    "modules-right": ["cpu", "memory", "network", "pulseaudio", "battery", "tray"],
    
    "hyprland/workspaces": {
        "disable-scroll": true,
        "all-outputs": true,
        "format": "{name}"
    },
    "clock": {
        "format": "<b>{:%H:%M | %d/%m/%Y}</b>",
        "tooltip-format": "<big>{:%Y %B}</big>\n<tt><small>{calendar}</small></tt>"
    },
    "cpu": {
        "format": " {usage}%",
        "tooltip": true
    },
    "memory": {
        "format": " {used:0.1f}G/{total:0.1f}G"
    },
    "network": {
        "format-wifi": " {essid}",
        "format-ethernet": "🖧 {ipaddr}",
        "format-disconnected": "⚠️ Off"
    },
    "pulseaudio": {
        "format": "🔊 {volume}%",
        "format-muted": "🔇 Mute",
        "on-click": "pavucontrol"
    },
    "battery": {
        "format": "🔋 {capacity}%",
        "format-charging": "⚡ {capacity}%"
    }
}
EOF

cat <<'EOF' > "${USER_HOME}/.config/waybar/style.css"
* {
    border: none;
    border-radius: 0;
    font-family: "Fira Code", "FontAwesome", sans-serif;
    font-size: 13px;
    min-height: 0;
}

window#waybar {
    background: rgba(24, 24, 37, 0.90);
    color: #cdd6f4;
    border-bottom: 2px solid #ff2a4b;
}

#workspaces button {
    padding: 0 8px;
    background: transparent;
    color: #a6adc8;
}

#workspaces button.active {
    background: #ff2a4b;
    color: #ffffff;
    border-radius: 4px;
}

#clock, #cpu, #memory, #network, #pulseaudio, #battery, #tray {
    padding: 0 10px;
    margin: 2px 4px;
    background: #1e1e2e;
    color: #f2f4fc;
    border-radius: 6px;
    border: 1px solid #313248;
}

#clock {
    color: #ff6600;
}
EOF

# --- Estilo do Terminal Foot (~/.config/foot/foot.ini) ---
cat <<'EOF' > "${USER_HOME}/.config/foot/foot.ini"
[main]
font=Fira Code:size=11
pad=8x8

[colors]
background=1e1e2e
foreground=f2f4fc
regular0=181825
regular1=ff2a4b
regular2=40ff7d
regular3=ffe066
regular4=89b4fa
regular5=cba6f7
regular6=94e2d5
regular7=cdd6f4
EOF

# Permissões das configurações do usuário juca
chroot /mnt chown -R juca:juca /home/juca/.config

# ==============================================================================
# --- INSTALAÇÃO E CONFIGURAÇÃO DO GERENCIADOR DE PACOTES NIX ---
# ==============================================================================
log_info "Instalando e configurando o gerenciador de pacotes Nix..."
chroot /mnt apt-get install -y --no-install-recommends nix-bin nix-setup-systemd

mkdir -pv /mnt/etc/nix
cat <<EOF >/mnt/etc/nix/nix.conf
# Configuração do Gerenciador Nix Multi-User
experimental-features = nix-command flakes
trusted-users = root juca
substituters = https://cache.nixos.org/
trusted-substituters = https://cache.nixos.org/
EOF

# Adicionar usuário juca ao grupo do Nix
chroot /mnt groupadd -r nix-users 2>/dev/null || true
chroot /mnt usermod -aG nix-users juca

# Configurar variáveis de ambiente do Nix nos perfis do bash
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
log_info "Instalando pacotes do GRUB (grub-pc e grub-efi-amd64)..."
chroot /mnt apt-get install -y --no-install-recommends \
    grub-pc \
    grub-efi-amd64 \
    efibootmgr

log_info "Instalando o GRUB BIOS (i386-pc) em ${DRIVE} para inicializar a VBIOS da NVIDIA 8600M GT..."
chroot /mnt grub-install --target=i386-pc "${DRIVE}"

log_info "Instalando o GRUB EFI (x86_64-efi) em /boot/efi como fallback..."
chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot/efi --no-nvram --removable --recheck

# --- Configuração do arquivo /etc/default/grub ---
log_info "Configurando parâmetros de boot no GRUB..."
cat <<EOF >/mnt/etc/default/grub
GRUB_DEFAULT=0
GRUB_TIMEOUT=2
GRUB_DISTRIBUTOR="Debian"
GRUB_CMDLINE_LINUX_DEFAULT="quiet splash apparmor=1 security=apparmor i915.modeset=0 nouveau.modeset=1 pcie_aspm=force zswap.enabled=1 zswap.compressor=zstd mitigations=off nowatchdog"
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
log_info "Ativando serviços essenciais no systemd (incluindo o Display Manager SDDM)..."
chroot /mnt systemctl enable NetworkManager.service
chroot /mnt systemctl enable iwd.service
chroot /mnt systemctl enable ssh.service
chroot /mnt systemctl enable sddm.service
chroot /mnt systemctl enable earlyoom.service
chroot /mnt systemctl enable mbpfan.service
chroot /mnt systemctl enable tlp.service
chroot /mnt systemctl enable thermald.service
chroot /mnt systemctl enable irqbalance.service
chroot /mnt systemctl enable zram-tools.service
chroot /mnt systemctl enable nix-daemon.service 2>/dev/null || true
chroot /mnt systemctl enable fstrim.timer

log_ok "=========================================================================="
log_ok " Instalação do Debian com Hyprland, SDDM & Nix concluída com SUCESSO!"
log_ok "=========================================================================="
log_info "Você já pode reiniciar o computador e remover a mídia de instalação."
log_info "Ao reiniciar, a tela gráfica de login do SDDM iniciará automaticamente."
log_info "Selecione o usuário 'juca' (senha: 200291) e a sessão 'Hyprland'."
