#!/usr/bin/env bash
# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║           INSTALADOR DEBIAN TRIXIE — MacBook Pro 4,1 (Late 2008)           ║
# ║                                                                            ║
# ║   🖥️  CPU:    Intel Core 2 Duo (Penryn, 64-bit)                           ║
# ║   🎮  GPU:    NVIDIA GeForce 8600M GT (Nouveau)                           ║
# ║   💾  RAM:    6GB DDR2 (2GB + 4GB Canal Assimétrico)                       ║
# ║   📶  Wi-Fi:  Broadcom BCM43xx (broadcom-sta + nm-applet)                 ║
# ║   💿  FS:     Btrfs com subvolumes e compressão ZSTD                      ║
# ║   🎨  Desktop: XFCE4 (Arc-Dark / Catppuccin Mocha) + LightDM + Firefox    ║
# ║   📦  Extras:  Plymouth, Nix Multi-User, Ferramentas CLI Modernas         ║
# ║                                                                            ║
# ║   Hostname: rocinante                                                      ║
# ║   Usuário:  juca (Reinaldo P JR)                                          ║
# ╚══════════════════════════════════════════════════════════════════════════════╝
#
# USO:
#   sudo bash install-debian-macbookpro41.sh /dev/sda
#
# O QUE ESTE SCRIPT FAZ (resumo para leigos):
#   1.  Apaga TUDO do disco que você escolher (cuidado!)
#   2.  Cria 3 partições: Boot BIOS (2MB), EFI (512MB) e Sistema Btrfs
#   3.  Instala o Debian Trixie (versão mais recente do Debian)
#   4.  Configura teclado Apple US Mac (igual ao macOS)
#   5.  Instala drivers de vídeo, Wi-Fi, som e controle térmico
#   6.  Instala o desktop XFCE4 com tema escuro bonito
#   7.  Instala Firefox, ferramentas de terminal e Nix package manager
#   8.  Configura boot com animação Plymouth
#   9.  Cria usuário "juca" e deixa tudo pronto para usar
#
# REQUISITOS:
#   - Estar rodando um Live USB de Debian/Ubuntu com acesso à internet
#   - Ter acesso root (sudo)
#   - Cabo ethernet OU Wi-Fi já conectado no Live USB
#

set -euo pipefail

# ┌────────────────────────────────────────────────────────────────────────────┐
# │                        CONFIGURAÇÕES E VARIÁVEIS                         │
# └────────────────────────────────────────────────────────────────────────────┘

DRIVE="${1:-/dev/sda}"           # Disco alvo (padrão: /dev/sda)
HOSTNAME="rocinante"            # Nome da máquina na rede
USERNAME="juca"                 # Usuário principal
FULLNAME="Reinaldo P JR"       # Nome completo do usuário
PASSWORD="200291"               # Senha do usuário e do root
CODENAME="trixie"               # Versão do Debian (Trixie = Testing)
MIRROR="http://deb.debian.org/debian"
TIMEZONE="America/Sao_Paulo"
LOCALE_MAIN="en_US.UTF-8"
LOCALE_EXTRA="pt_BR.UTF-8"
SWAP_SIZE_MB=6144               # Tamanho do swap em MB (6GB)
BTRFS_OPTS="noatime,ssd,compress-force=zstd:2,space_cache=v2,commit=120,discard=async"

# Cores e formatação para o terminal
RED='\033[0;31m'    ; GREEN='\033[0;32m'  ; BLUE='\033[0;34m'
YELLOW='\033[1;33m' ; CYAN='\033[0;36m'   ; MAGENTA='\033[0;35m'
BOLD='\033[1m'      ; DIM='\033[2m'       ; NC='\033[0m'

TOTAL_STEPS=15
CURRENT_STEP=0

# ┌────────────────────────────────────────────────────────────────────────────┐
# │                        FUNÇÕES DE INTERFACE                              │
# └────────────────────────────────────────────────────────────────────────────┘

# Mostra uma mensagem informativa (texto azul)
log_info() { echo -e "  ${CYAN}ℹ${NC}  $1"; }

# Mostra que algo deu certo (texto verde)
log_ok()   { echo -e "  ${GREEN}✔${NC}  $1"; }

# Mostra um aviso importante (texto amarelo)
log_warn() { echo -e "  ${YELLOW}⚠${NC}  $1"; }

# Mostra um erro crítico (texto vermelho)
log_err()  { echo -e "  ${RED}✖${NC}  $1"; }

# Mostra o cabeçalho de cada etapa com o número e nome
# Uso: step "Nome da Etapa"
step() {
    CURRENT_STEP=$((CURRENT_STEP + 1))
    local bar=""
    local filled=$((CURRENT_STEP * 30 / TOTAL_STEPS))
    local empty=$((30 - filled))
    for ((i=0; i<filled; i++)); do bar+="█"; done
    for ((i=0; i<empty; i++)); do bar+="░"; done
    echo ""
    echo -e "${BOLD}${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}${MAGENTA}  ETAPA ${CURRENT_STEP}/${TOTAL_STEPS}${NC}  ${BOLD}$1${NC}"
    echo -e "${DIM}  [${GREEN}${bar}${NC}${DIM}] ${CURRENT_STEP}/${TOTAL_STEPS}${NC}"
    echo -e "${BOLD}${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Executa um comando no chroot (dentro do sistema que está sendo instalado)
in_chroot() { chroot /mnt "$@"; }

# Instala pacotes no sistema que está sendo instalado, sem pacotes extras
in_chroot_install() { in_chroot apt-get install -y --no-install-recommends "$@"; }

# ┌────────────────────────────────────────────────────────────────────────────┐
# │                        VERIFICAÇÕES INICIAIS                             │
# └────────────────────────────────────────────────────────────────────────────┘

# Precisa ser root para instalar um sistema operacional
if [ "$(id -u)" -ne 0 ]; then
    log_err "Este script deve ser executado como ROOT (ou via sudo)!"
    exit 1
fi

# Banner de boas-vindas
clear 2>/dev/null || true
echo ""
echo -e "${BOLD}${CYAN}"
cat << 'BANNER'
    ____             _                   __
   / __ \____  _____(_)___  ____ _____  / /____
  / /_/ / __ \/ ___/ / __ \/ __ `/ __ \/ __/ _ \
 / _, _/ /_/ / /__/ / / / / /_/ / / / / /_/  __/
/_/ |_|\____/\___/_/_/ /_/\__,_/_/ /_/\__/\___/

BANNER
echo -e "${NC}"
echo -e "${BOLD}  Instalador Debian Trixie para MacBook Pro 4,1${NC}"
echo -e "${DIM}  XFCE4 · Arc-Dark · Firefox · Plymouth · Nix${NC}"
echo ""
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${RED}${BOLD}"
echo -e "  ⚠  ATENÇÃO: O disco ${DRIVE} será COMPLETAMENTE APAGADO!"
echo -e "     Todos os dados nele serão PERDIDOS PARA SEMPRE."
echo -e "${NC}"
echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -n "  Deseja continuar? (s/N): "
read -r CONFIRM
if [[ ! "$CONFIRM" =~ ^[sS]$ ]]; then
    log_info "Operação cancelada pelo usuário. Nenhuma alteração foi feita."
    exit 0
fi

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                         INÍCIO DA INSTALAÇÃO                              ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

# ──────────────────────────────────────────────────────────────────────────────
# ETAPA 1: Preparar o ambiente do Live USB
#   → Sincroniza o relógio e instala ferramentas necessárias
# ──────────────────────────────────────────────────────────────────────────────
step "Preparando o ambiente do Live USB"

log_info "Sincronizando o relógio do sistema pela internet..."
HTTP_DATE=$(curl -sI http://deb.debian.org | grep -i '^Date:' | cut -d' ' -f2- || true)
if [ -n "$HTTP_DATE" ]; then
    date -s "$HTTP_DATE" 2>/dev/null || true
    log_ok "Relógio sincronizado: $(date)"
fi

# Opções do APT para evitar erros de data em Live USBs antigos
APT_OPT=("-o" "Acquire::Check-Valid-Until=false" "-o" "Acquire::Check-Date=false" "-o" "Acquire::AllowInsecureRepositories=true")

log_info "Verificando se as ferramentas necessárias estão instaladas..."

# Lista de ferramentas que precisamos e seus pacotes no Debian
# Formato: "comando:pacote"
TOOL_MAP=(
    "debootstrap:debootstrap"
    "mkfs.btrfs:btrfs-progs"
    "sgdisk:gdisk"
    "parted:parted"
    "mkfs.vfat:dosfstools"
    "wipefs:util-linux"
    "wget:wget"
    "curl:curl"
)

PKGS_MISSING=()
for entry in "${TOOL_MAP[@]}"; do
    cmd="${entry%%:*}"
    pkg="${entry##*:}"
    if ! command -v "$cmd" &>/dev/null; then
        PKGS_MISSING+=("$pkg")
    fi
done

if [ ${#PKGS_MISSING[@]} -ne 0 ]; then
    log_info "Instalando ferramentas ausentes: ${PKGS_MISSING[*]}"
    apt-get update "${APT_OPT[@]}" -qq 2>/dev/null || true
    for pkg in "${PKGS_MISSING[@]}"; do
        apt-get install "${APT_OPT[@]}" -y "$pkg" 2>/dev/null || true
    done
fi

if ! command -v debootstrap &>/dev/null; then
    log_err "Falha crítica: não foi possível instalar o 'debootstrap'!"
    log_err "Verifique sua conexão com a internet e tente novamente."
    exit 1
fi
log_ok "Todas as ferramentas necessárias estão disponíveis."

# ──────────────────────────────────────────────────────────────────────────────
# ETAPA 2: Limpar e preparar o disco
#   → Desmonta partições, remove assinaturas antigas, zera o disco
# ──────────────────────────────────────────────────────────────────────────────
step "Limpando e preparando o disco ${DRIVE}"

log_info "Parando serviços que podem estar usando o disco..."
systemctl stop udisks2 udisks tracker 2>/dev/null || true

log_info "Desmontando todas as partições do disco..."
for mnt in $(grep "${DRIVE}" /proc/mounts 2>/dev/null | awk '{print $2}' | sort -r); do
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

log_info "Apagando assinaturas e tabela de partições antiga..."
wipefs --all --force "${DRIVE}" 2>/dev/null || true
dd if=/dev/zero of="${DRIVE}" bs=1M count=10 status=none 2>/dev/null || true
sync

# Limpa também o backup da GPT no final do disco
DISK_SECTORS=$(blockdev --getsz "${DRIVE}" 2>/dev/null || echo 0)
if [ "$DISK_SECTORS" -gt 2048 ]; then
    BACKUP_START=$((DISK_SECTORS - 2048))
    dd if=/dev/zero of="${DRIVE}" seek="${BACKUP_START}" bs=512 count=2048 status=none 2>/dev/null || true
    sync
fi

blockdev --rereadpt "${DRIVE}" 2>/dev/null || partprobe "${DRIVE}" 2>/dev/null || true
udevadm settle 2>/dev/null || true
sleep 2
log_ok "Disco ${DRIVE} limpo e pronto para particionamento."

# ──────────────────────────────────────────────────────────────────────────────
# ETAPA 3: Criar as partições no disco
#   → Partição 1: BIOS Boot (2MB)  — para inicializar a VBIOS da NVIDIA
#   → Partição 2: EFI (512MB)      — fallback para boot UEFI
#   → Partição 3: Sistema (resto)  — Btrfs com todo o sistema
# ──────────────────────────────────────────────────────────────────────────────
step "Criando partições no disco ${DRIVE}"

set +e
parted -s -a optimal "${DRIVE}" -- \
    mklabel gpt \
    mkpart primary 2048s 6143s \
    set 1 bios_grub on \
    mkpart primary fat32 6144s 1054719s \
    set 2 esp on \
    mkpart primary btrfs 1054720s 100% 2>/dev/null

if [ $? -ne 0 ]; then
    log_warn "Parted falhou, tentando com sgdisk..."
    sgdisk -Z "${DRIVE}" 2>/dev/null || true
    sgdisk -n 1:2048:+2M -t 1:ef02 -c 1:"BIOS Boot" "${DRIVE}" 2>/dev/null || true
    sgdisk -n 2:0:+512M -t 2:ef00 -c 2:"EFI System" "${DRIVE}" 2>/dev/null || true
    sgdisk -n 3:0:0 -t 3:8300 -c 3:"Debian Btrfs" "${DRIVE}" 2>/dev/null || true
fi
set -e

# Identifica os nomes das partições (diferente para NVMe e SATA)
if [[ "${DRIVE}" =~ "nvme" ]] || [[ "${DRIVE}" =~ "mmcblk" ]]; then
    PART_BIOS="${DRIVE}p1"; PART_EFI="${DRIVE}p2"; PART_ROOT="${DRIVE}p3"
else
    PART_BIOS="${DRIVE}1"; PART_EFI="${DRIVE}2"; PART_ROOT="${DRIVE}3"
fi

blockdev --rereadpt "${DRIVE}" 2>/dev/null || partprobe "${DRIVE}" 2>/dev/null || true
udevadm settle 2>/dev/null || true
sleep 3

# Aguarda o Linux criar os arquivos de dispositivo (/dev/sdaX)
for i in {1..10}; do
    [ -b "${PART_EFI}" ] && [ -b "${PART_ROOT}" ] && break
    sleep 1
done

log_ok "Partições criadas:"
lsblk "${DRIVE}" 2>/dev/null || true

# ──────────────────────────────────────────────────────────────────────────────
# ETAPA 4: Formatar e montar o sistema de arquivos
#   → EFI em FAT32, Sistema em Btrfs com 6 subvolumes
# ──────────────────────────────────────────────────────────────────────────────
step "Formatando e montando o sistema de arquivos"

log_info "Formatando partição EFI (FAT32)..."
mkfs.vfat -F32 "${PART_EFI}" -n "EFI"

log_info "Formatando partição do sistema (Btrfs com compressão ZSTD)..."
btrfs device scan --forget 2>/dev/null || true
wipefs -a -f "${PART_ROOT}" 2>/dev/null || true
udevadm settle 2>/dev/null || true
sleep 2

if ! mkfs.btrfs -f -L "Debian" "${PART_ROOT}"; then
    log_warn "Erro na formatação, tentando liberar trava do disco..."
    btrfs device scan --forget 2>/dev/null || true
    fuser -k -9 "${PART_ROOT}" 2>/dev/null || true
    sleep 3
    mkfs.btrfs -f -L "Debian" "${PART_ROOT}"
fi

# Subvolumes Btrfs — cada um tem uma função:
#   @             → Raiz do sistema (/)
#   @home         → Pasta dos usuários (/home) — fácil de fazer backup
#   @snapshots    → Snapshots do sistema (/.snapshots) — para restauração
#   @var_log      → Logs do sistema (/var/log) — evita encher o snapshot
#   @var_cache_apt → Cache de pacotes (/var/cache/apt) — fácil de limpar
#   @swap         → Arquivo de swap (/swap) — precisa de CoW desabilitado
log_info "Criando subvolumes Btrfs..."
mount -o "${BTRFS_OPTS}" "${PART_ROOT}" /mnt
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@snapshots
btrfs subvolume create /mnt/@var_log
btrfs subvolume create /mnt/@var_cache_apt
btrfs subvolume create /mnt/@swap
umount -v /mnt

log_info "Montando subvolumes na estrutura de diretórios..."
mount -o "${BTRFS_OPTS},subvol=@" "${PART_ROOT}" /mnt
mkdir -pv /mnt/{boot/efi,home,.snapshots,var/log,var/cache/apt,swap}
mount -o "${BTRFS_OPTS},subvol=@home" "${PART_ROOT}" /mnt/home
mount -o "${BTRFS_OPTS},subvol=@snapshots" "${PART_ROOT}" /mnt/.snapshots
mount -o "${BTRFS_OPTS},subvol=@var_log" "${PART_ROOT}" /mnt/var/log
mount -o "${BTRFS_OPTS},subvol=@var_cache_apt" "${PART_ROOT}" /mnt/var/cache/apt
mount -o "${BTRFS_OPTS},subvol=@swap" "${PART_ROOT}" /mnt/swap
mount -t vfat -o noatime,nodiratime "${PART_EFI}" /mnt/boot/efi
log_ok "Sistema de arquivos montado com sucesso."

# ──────────────────────────────────────────────────────────────────────────────
# ETAPA 5: Instalar o sistema base do Debian Trixie
#   → Debootstrap baixa e instala os pacotes mínimos do Debian
# ──────────────────────────────────────────────────────────────────────────────
step "Instalando o sistema base Debian Trixie"

log_info "Baixando e instalando pacotes essenciais (isso demora uns minutos)..."
debootstrap --variant=minbase \
    --include=apt,apt-utils,ca-certificates,sudo,neovim,locales,e2fsprogs,initramfs-tools,console-setup,dosfstools,btrfs-progs,kmod,less,gdisk,ncurses-base,netbase,procps,systemd,systemd-sysv,udev,iproute2,iputils-ping,bash,whiptail \
    --arch=amd64 "${CODENAME}" /mnt "${MIRROR}"
log_ok "Sistema base instalado."

# ──────────────────────────────────────────────────────────────────────────────
# ETAPA 6: Configurar repositórios, idioma e fuso horário
#   → Repositórios APT, locales, timezone, hostname
# ──────────────────────────────────────────────────────────────────────────────
step "Configurando idioma, fuso horário e repositórios"

log_info "Configurando repositórios Debian Trixie (main, contrib, non-free)..."
mkdir -pv /mnt/etc/apt/apt.conf.d /mnt/etc/apt/sources.list.d
rm -f /mnt/etc/apt/sources.list

# Configurar APT para não instalar pacotes sugeridos (economia de espaço)
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

# Montar pseudo-sistemas de arquivos (necessário para o chroot funcionar)
log_info "Preparando ambiente chroot..."
for dir in dev proc sys run; do
    mount --rbind "/$dir" "/mnt/$dir"
    mount --make-rslave "/mnt/$dir"
done

# FSTAB — Tabela que diz ao Linux o que montar na inicialização
log_info "Gerando tabela de montagem (fstab)..."
ROOT_UUID=$(blkid -s UUID -o value "${PART_ROOT}")
EFI_UUID=$(blkid -s UUID -o value "${PART_EFI}")

cat <<EOF >/mnt/etc/fstab
# Tabela de Montagem do Sistema — gerada pelo instalador
# Disco: ${DRIVE} | Hostname: ${HOSTNAME}
UUID=${ROOT_UUID}  /               btrfs  rw,${BTRFS_OPTS},subvol=@              0  0
UUID=${ROOT_UUID}  /home           btrfs  rw,${BTRFS_OPTS},subvol=@home          0  0
UUID=${ROOT_UUID}  /.snapshots     btrfs  rw,${BTRFS_OPTS},subvol=@snapshots     0  0
UUID=${ROOT_UUID}  /var/log        btrfs  rw,${BTRFS_OPTS},subvol=@var_log       0  0
UUID=${ROOT_UUID}  /var/cache/apt  btrfs  rw,${BTRFS_OPTS},subvol=@var_cache_apt 0  0
UUID=${ROOT_UUID}  /swap           btrfs  rw,${BTRFS_OPTS},subvol=@swap          0  0
UUID=${EFI_UUID}   /boot/efi       vfat   rw,noatime,umask=0077                  0  2
/swap/swapfile     none            swap   defaults,pri=100                       0  0
tmpfs              /tmp            tmpfs  noatime,mode=1777,nosuid,nodev         0  0
EOF

# Hostname e rede local
log_info "Configurando hostname '${HOSTNAME}'..."
echo "${HOSTNAME}" > /mnt/etc/hostname
cat <<EOF >/mnt/etc/hosts
127.0.0.1   localhost
127.0.1.1   ${HOSTNAME}
::1         localhost ip6-localhost ip6-loopback
ff02::1     ip6-allnodes
ff02::2     ip6-allrouters
EOF

# Fuso horário e idioma
in_chroot ln -sf /usr/share/zoneinfo/${TIMEZONE} /etc/localtime

cat <<EOF >/mnt/etc/locale.gen
${LOCALE_MAIN} UTF-8
${LOCALE_EXTRA} UTF-8
EOF

log_info "Atualizando pacotes e gerando locales..."
in_chroot apt-get update -qq
in_chroot apt-get install -y locales || true
in_chroot locale-gen

cat <<EOF >/mnt/etc/default/locale
LANG=${LOCALE_MAIN}
LC_ALL=${LOCALE_MAIN}
EOF
log_ok "Idioma, fuso horário e hostname configurados."

# ──────────────────────────────────────────────────────────────────────────────
# ETAPA 7: Configurar o teclado Apple US Mac
#   → Layout US Mac, teclas de função como no macOS, Command/Option corretos
# ──────────────────────────────────────────────────────────────────────────────
step "Configurando teclado Apple (idêntico ao macOS)"

log_info "Definindo layout do teclado: US Mac..."
cat <<EOF >/mnt/etc/default/keyboard
XKBMODEL="pc105"
XKBLAYOUT="us"
XKBVARIANT="mac"
XKBOPTIONS="terminate:ctrl_alt_bksp"
BACKSPACE="guess"
EOF

# Módulo do kernel para teclado Apple
# fnmode=1: Teclas de brilho/volume funcionam direto (sem segurar Fn) — igual macOS
# swap_opt_cmd=1: Mantém Command e Option nas posições corretas do Mac
log_info "Configurando módulo hid_apple (comportamento Mac nativo)..."
mkdir -pv /mnt/etc/modprobe.d
cat <<EOF >/mnt/etc/modprobe.d/hid_apple.conf
options hid_apple fnmode=1 swap_opt_cmd=1
EOF

# Módulo applesmc — controla os sensores de temperatura e LEDs do teclado
echo "applesmc" >> /mnt/etc/modules

# Permissões para controlar brilho da tela e teclado sem precisar de sudo
log_info "Configurando permissões de brilho (tela e teclado)..."
mkdir -pv /mnt/etc/udev/rules.d
cat <<EOF >/mnt/etc/udev/rules.d/90-macbook-backlight.rules
ACTION=="add", SUBSYSTEM=="backlight", RUN+="/bin/chmod a+w /sys/class/backlight/%k/brightness"
ACTION=="add", SUBSYSTEM=="leds", RUN+="/bin/chmod a+w /sys/class/leds/%k/brightness"
EOF
log_ok "Teclado Apple configurado."

# ──────────────────────────────────────────────────────────────────────────────
# ETAPA 8: Instalar kernel, drivers de vídeo e Wi-Fi
#   → Kernel Linux, Intel Microcode, Nouveau (GPU), Broadcom (Wi-Fi)
# ──────────────────────────────────────────────────────────────────────────────
step "Instalando kernel, drivers de vídeo e Wi-Fi"

log_info "Instalando kernel Linux e firmware Intel..."
in_chroot_install \
    linux-image-amd64 \
    linux-headers-amd64 \
    intel-microcode \
    firmware-linux-free \
    firmware-linux-nonfree \
    firmware-misc-nonfree

log_info "Instalando drivers Wi-Fi Broadcom (BCM43xx)..."
in_chroot_install \
    broadcom-sta-dkms \
    wireless-regdb

# Resolver conflitos de drivers Wi-Fi:
# O broadcom-sta (módulo "wl") conflita com os módulos open-source b43/bcma.
# Se ambos carregarem ao mesmo tempo, o Wi-Fi não funciona — especialmente
# em repetidores/extenders que são mais sensíveis a handshakes instáveis.
log_info "Configurando blacklist de módulos Wi-Fi conflitantes..."
cat <<EOF >/mnt/etc/modprobe.d/broadcom-wifi.conf
# Blacklist dos módulos open-source que conflitam com o driver broadcom-sta (wl)
# Sem isso, o Wi-Fi pode falhar em repetidores e redes com sinal fraco
blacklist b43
blacklist b43legacy
blacklist bcma
blacklist brcmsmac
blacklist brcmfmac
blacklist ssb
EOF

log_info "Instalando drivers de vídeo Nouveau para NVIDIA 8600M GT..."
in_chroot_install \
    xserver-xorg-video-nouveau \
    mesa-va-drivers \
    mesa-vdpau-drivers \
    vdpau-driver-all \
    va-driver-all \
    libgl1-mesa-dri \
    libvdpau1 \
    vdpauinfo \
    vainfo
log_ok "Kernel e drivers instalados."

# ──────────────────────────────────────────────────────────────────────────────
# ETAPA 9: Configurar rede e Wi-Fi (com fix para repetidores)
#   → NetworkManager, nm-applet, domínio regulatório BR, power save off
# ──────────────────────────────────────────────────────────────────────────────
step "Configurando rede e Wi-Fi (com fix para repetidores)"

log_info "Instalando NetworkManager e applet de Wi-Fi para a barra de tarefas..."
in_chroot_install \
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

# Configuração do NetworkManager otimizada para Broadcom + repetidores:
# - wifi.scan-rand-mac-address=no → Desabilita MAC aleatório durante scan
#   (repetidores rejeitam dispositivos que mudam de MAC a cada scan)
# - wifi.powersave=2 → Desabilita power save do Wi-Fi
#   (o driver Broadcom desconecta quando entra em modo economia)
log_info "Aplicando configurações anti-repetidor no NetworkManager..."
mkdir -pv /mnt/etc/NetworkManager/conf.d
cat <<EOF >/mnt/etc/NetworkManager/NetworkManager.conf
[main]
plugins=ifupdown,keyfile

[ifupdown]
managed=true

[connection]
wifi.powersave=2

[device]
wifi.scan-rand-mac-address=no
EOF

# Domínio regulatório do Brasil — libera canais 12 e 13 usados por repetidores
log_info "Configurando domínio regulatório Wi-Fi para Brasil (BR)..."
mkdir -pv /mnt/etc/default
echo 'REGDOMAIN=BR' > /mnt/etc/default/crda

# Configuração do wpa_supplicant com país BR
mkdir -pv /mnt/etc/wpa_supplicant
cat <<EOF >/mnt/etc/wpa_supplicant/wpa_supplicant.conf
country=BR
ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
update_config=1
EOF

# Script de NetworkManager para desabilitar power save sempre que conectar
log_info "Criando script para manter Wi-Fi estável em repetidores..."
mkdir -pv /mnt/etc/NetworkManager/dispatcher.d
cat <<'EOF' >/mnt/etc/NetworkManager/dispatcher.d/99-wifi-powersave-off
#!/bin/bash
# Desabilita power save do Wi-Fi ao conectar — evita desconexões em repetidores
if [ "$2" = "up" ] && [ -n "$(iw dev 2>/dev/null | grep Interface | awk '{print $2}')" ]; then
    for iface in $(iw dev 2>/dev/null | grep Interface | awk '{print $2}'); do
        iw dev "$iface" set power_save off 2>/dev/null || true
    done
fi
EOF
chmod +x /mnt/etc/NetworkManager/dispatcher.d/99-wifi-powersave-off
log_ok "Rede e Wi-Fi configurados com proteções anti-repetidor."

# ──────────────────────────────────────────────────────────────────────────────
# ETAPA 10: Instalar ferramentas de sistema
#   → Controle térmico, utilitários CLI, Firefox, Plymouth
# ──────────────────────────────────────────────────────────────────────────────
step "Instalando ferramentas de sistema e navegador"

log_info "Instalando Plymouth (animação de boot)..."
in_chroot_install plymouth plymouth-themes
in_chroot plymouth-set-default-theme -R spinner 2>/dev/null || \
    in_chroot plymouth-set-default-theme -R bgrt 2>/dev/null || true

log_info "Instalando controle térmico do MacBook (mbpfan, TLP, earlyoom)..."
in_chroot_install \
    mbpfan \
    tlp \
    powertop \
    thermald \
    irqbalance \
    earlyoom \
    zram-tools \
    chrony \
    rsyslog

# Configuração dos ventiladores do MacBook Pro
cat <<EOF >/mnt/etc/mbpfan.conf
[general]
min_fan1_speed = 2000
max_fan1_speed = 6000
low_temp = 55
high_temp = 72
max_temp = 86
polling_interval = 2
EOF

log_info "Instalando Firefox ESR (em português) e utilitários modernos..."
in_chroot_install \
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

# Tuning de memória para 6GB RAM assimétrica
log_info "Otimizando uso de memória para 6GB RAM..."
mkdir -pv /mnt/etc/sysctl.d
cat <<EOF >/mnt/etc/sysctl.d/99-macbook-memory.conf
vm.swappiness=60
vm.vfs_cache_pressure=50
vm.dirty_background_ratio=5
vm.dirty_ratio=15
vm.dirty_writeback_centisecs=1500
EOF

cat <<EOF >/mnt/etc/default/zram-tools
ALGO=zstd
PERCENT=50
PRIORITY=100
EOF

# Criar arquivo de swap de 6GB no subvolume Btrfs
log_info "Criando arquivo de swap de ${SWAP_SIZE_MB}MB (isso demora um pouco)..."
truncate -s 0 /mnt/swap/swapfile
chmod 600 /mnt/swap/swapfile
in_chroot chattr +C /swap/swapfile 2>/dev/null || true
in_chroot btrfs property set /swap/swapfile compression none 2>/dev/null || true
dd if=/dev/zero of=/mnt/swap/swapfile bs=1M count=${SWAP_SIZE_MB} status=progress
mkswap /mnt/swap/swapfile
log_ok "Ferramentas de sistema instaladas."

# ──────────────────────────────────────────────────────────────────────────────
# ETAPA 11: Criar usuário e configurar senhas
#   → Cria o usuário "juca" com permissões de administrador
# ──────────────────────────────────────────────────────────────────────────────
step "Criando usuário '${USERNAME}'"

log_info "Definindo senha do root..."
echo "root:${PASSWORD}" | in_chroot chpasswd -c SHA512

log_info "Criando usuário '${USERNAME}' (${FULLNAME})..."
in_chroot useradd "${USERNAME}" -m -c "${FULLNAME}" -s /bin/bash
echo "${USERNAME}:${PASSWORD}" | in_chroot chpasswd -c SHA512
in_chroot usermod -aG sudo,audio,video,systemd-journal,input,netdev,render "${USERNAME}"
log_ok "Usuário '${USERNAME}' criado com permissões de administrador."

# ──────────────────────────────────────────────────────────────────────────────
# ETAPA 12: Instalar e configurar desktop XFCE4
#   → XFCE4 com tema Arc-Dark, Whisker Menu, LightDM, Pipewire
# ──────────────────────────────────────────────────────────────────────────────
step "Instalando desktop XFCE4 com tema escuro elegante"

log_info "Instalando XFCE4, Pipewire, LightDM e componentes..."
in_chroot_install \
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

# PolicyKit — necessário para ações administrativas no desktop
in_chroot_install polkit-1-auth-agent 2>/dev/null || \
    in_chroot_install lxpolkit 2>/dev/null || \
    in_chroot_install policykit-1-gnome 2>/dev/null || true

# Configuração do LightDM (tela de login)
log_info "Configurando tela de login LightDM..."
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
log_ok "Desktop XFCE4 instalado."

# ──────────────────────────────────────────────────────────────────────────────
# ETAPA 13: Personalizar aparência e atalhos
#   → Tema Catppuccin Mocha, nm-applet, atalhos de brilho/volume
# ──────────────────────────────────────────────────────────────────────────────
step "Personalizando aparência e atalhos de teclado"

USER_HOME="/mnt/home/${USERNAME}"
mkdir -pv "${USER_HOME}/.config/"{xfce4/terminal,xfce4/xfconf/xfce-perchannel-xml,autostart}

# nm-applet inicia automaticamente para mostrar o ícone de Wi-Fi na barra
log_info "Configurando autostart do applet de Wi-Fi..."
cat <<'EOF' > "${USER_HOME}/.config/autostart/nm-applet.desktop"
[Desktop Entry]
Type=Application
Name=Network Manager Applet
Comment=Ícone de Wi-Fi na barra de tarefas
Icon=nm-device-wireless
Exec=nm-applet
Terminal=false
StartupNotify=false
EOF

# Cores do terminal — Catppuccin Mocha com acentos vermelhos
log_info "Aplicando tema Catppuccin Mocha no terminal..."
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

# Tema escuro Arc-Dark + fontes Inter + ícones Papirus-Dark
log_info "Aplicando tema Arc-Dark e fontes Inter no XFCE4..."
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

# Layout de teclado US Mac no XFCE
cat <<'EOF' > "${USER_HOME}/.config/xfce4/xfconf/xfce-perchannel-xml/keyboard-layout.xml"
<?xml version="1.0" encoding="UTF-8"?>
<channel name="keyboard-layout" version="1.0">
  <property name="Default" type="empty">
    <property name="XkbDisable" type="bool" value="false"/>
    <property name="XkbLayout" type="string" value="us"/>
    <property name="XkbVariant" type="string" value="mac"/>
    <property name="XkbModel" type="string" value="pc105"/>
  </property>
</channel>
EOF

# Atalhos de teclado para brilho da tela, luz do teclado e volume
log_info "Configurando atalhos de brilho e volume..."
cat <<'EOF' > "${USER_HOME}/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-keyboard-shortcuts.xml"
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-keyboard-shortcuts" version="1.0">
  <property name="commands" type="empty">
    <property name="custom" type="empty">
      <property name="XF86MonBrightnessDown" type="string" value="brightnessctl set 5%-"/>
      <property name="XF86MonBrightnessUp" type="string" value="brightnessctl set +5%"/>
      <property name="XF86KbdBrightnessDown" type="string" value="brightnessctl --device='smc::kbd_backlight' set 10%-"/>
      <property name="XF86KbdBrightnessUp" type="string" value="brightnessctl --device='smc::kbd_backlight' set 10%+"/>
      <property name="XF86AudioMute" type="string" value="wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"/>
      <property name="XF86AudioLowerVolume" type="string" value="wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"/>
      <property name="XF86AudioRaiseVolume" type="string" value="wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"/>
    </property>
  </property>
</channel>
EOF

in_chroot chown -R "${USERNAME}:${USERNAME}" "/home/${USERNAME}/.config"
log_ok "Aparência e atalhos configurados."

# ──────────────────────────────────────────────────────────────────────────────
# ETAPA 14: Instalar Nix e bootloader GRUB
#   → Nix package manager, GRUB BIOS + EFI, configuração de boot
# ──────────────────────────────────────────────────────────────────────────────
step "Instalando Nix e bootloader GRUB"

log_info "Instalando gerenciador de pacotes Nix..."
in_chroot_install nix-bin nix-setup-systemd 2>/dev/null || true

mkdir -pv /mnt/etc/nix
cat <<EOF >/mnt/etc/nix/nix.conf
experimental-features = nix-command flakes
trusted-users = root ${USERNAME}
substituters = https://cache.nixos.org/
trusted-substituters = https://cache.nixos.org/
EOF

in_chroot groupadd -r nix-users 2>/dev/null || true
in_chroot usermod -aG nix-users "${USERNAME}" 2>/dev/null || true

# Ativar Nix no login do usuário e do root
for bashrc in "/mnt/home/${USERNAME}/.bashrc" "/mnt/root/.bashrc"; do
    cat <<'NIXEOF' >> "$bashrc"

# Nix Package Manager
if [ -e /etc/profile.d/nix.sh ]; then . /etc/profile.d/nix.sh; fi
NIXEOF
done
in_chroot chown "${USERNAME}:${USERNAME}" "/home/${USERNAME}/.bashrc"

# GRUB — Bootloader duplo (BIOS + EFI)
# BIOS (i386-pc): Necessário para a VBIOS da NVIDIA inicializar a GPU
# EFI (x86_64-efi): Fallback para boot UEFI
log_info "Instalando GRUB (BIOS + EFI)..."
in_chroot_install \
    grub-pc \
    grub-pc-bin \
    grub-efi-amd64-bin \
    efibootmgr

log_info "Instalando GRUB BIOS em ${DRIVE}..."
in_chroot grub-install --target=i386-pc "${DRIVE}"

log_info "Instalando GRUB EFI como fallback..."
in_chroot grub-install --target=x86_64-efi --efi-directory=/boot/efi --no-nvram --removable --recheck

# Parâmetros de boot
log_info "Configurando parâmetros de boot com Plymouth..."
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

# Hibernação — detecta o offset do swapfile para o GRUB
if command -v filefrag &>/dev/null; then
    OFFSET=$(filefrag -v /mnt/swap/swapfile | awk '$1=="0:" {print substr($4, 1, length($4)-2)}' | head -n1 || true)
    if [ -n "$OFFSET" ]; then
        log_info "Configurando hibernação (resume_offset=${OFFSET})..."
        sed -i "s/GRUB_CMDLINE_LINUX=\"\"/GRUB_CMDLINE_LINUX=\"resume=UUID=${ROOT_UUID} resume_offset=${OFFSET}\"/g" /mnt/etc/default/grub
    fi
fi

in_chroot update-grub
in_chroot update-initramfs -u -k all
log_ok "GRUB e Nix configurados."

# ──────────────────────────────────────────────────────────────────────────────
# ETAPA 15: Ativar serviços e finalizar instalação
#   → Systemd services, desmontagem limpa
# ──────────────────────────────────────────────────────────────────────────────
step "Ativando serviços e finalizando"

log_info "Ativando serviços do sistema..."
SERVICES=(
    "NetworkManager.service"    # Gerenciador de rede e Wi-Fi
    "ssh.service"               # Acesso remoto SSH
    "lightdm.service"           # Tela de login gráfica
    "earlyoom.service"          # Mata processos antes de travar por falta de RAM
    "mbpfan.service"            # Controle dos ventiladores do MacBook
    "tlp.service"               # Economia de energia da bateria
    "thermald.service"          # Proteção contra superaquecimento
    "irqbalance.service"        # Balanceia interrupções entre os 2 cores da CPU
)

for svc in "${SERVICES[@]}"; do
    in_chroot systemctl enable "$svc" 2>/dev/null || true
done

# Serviços opcionais (podem não existir dependendo da versão)
in_chroot systemctl enable zramswap.service 2>/dev/null || \
    in_chroot systemctl enable zram-tools.service 2>/dev/null || true
in_chroot systemctl enable nix-daemon.service 2>/dev/null || true
log_ok "Serviços ativados."

# Desmontagem limpa
log_info "Desmontando sistema de arquivos..."
swapoff -a 2>/dev/null || true
umount -R -f /mnt 2>/dev/null || true

# ╔══════════════════════════════════════════════════════════════════════════════╗
# ║                      INSTALAÇÃO CONCLUÍDA! 🎉                             ║
# ╚══════════════════════════════════════════════════════════════════════════════╝

echo ""
echo -e "${BOLD}${GREEN}"
cat << 'DONE'
    ____                   __          __
   / __ \_________  ____  / /_____    / /
  / /_/ / ___/ __ \/ __ \/ __/ __ \  / /
 / ____/ /  / /_/ / / / / /_/ /_/ / /_/
/_/   /_/   \____/_/ /_/\__/\____/ (_)

DONE
echo -e "${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}  ✔ Instalação do Debian Trixie concluída com sucesso!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo -e "  ${BOLD}Próximos passos:${NC}"
echo -e "  ${CYAN}1.${NC} Remova o USB de instalação"
echo -e "  ${CYAN}2.${NC} Reinicie o computador: ${BOLD}sudo reboot${NC}"
echo -e "  ${CYAN}3.${NC} A animação do Plymouth aparecerá durante o boot"
echo -e "  ${CYAN}4.${NC} Na tela de login do LightDM, entre com:"
echo -e "     ${BOLD}Usuário:${NC} ${USERNAME}"
echo -e "     ${BOLD}Senha:${NC}   ${PASSWORD}"
echo ""
echo -e "  ${BOLD}O que você encontrará:${NC}"
echo -e "  ${GREEN}•${NC} Desktop XFCE4 com tema escuro Arc-Dark"
echo -e "  ${GREEN}•${NC} Firefox ESR (em português) pronto para navegar"
echo -e "  ${GREEN}•${NC} Ícone de Wi-Fi na barra de tarefas (nm-applet)"
echo -e "  ${GREEN}•${NC} Teclado Apple funcionando igual ao macOS"
echo -e "  ${GREEN}•${NC} Teclas de brilho e volume funcionando"
echo -e "  ${GREEN}•${NC} Nix package manager pronto para usar"
echo ""
echo -e "  ${DIM}Hostname: ${HOSTNAME} | Disco: ${DRIVE} | Debian ${CODENAME}${NC}"
echo ""
