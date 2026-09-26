#!/usr/bin/env bash
# ==============================================================================
# Script de Correção e Finalização Pós-Instalação para Debian 13 (Trixie)
# Máquina Virtual (KVM / QEMU / virt-manager) — virtualvm — Btrfs Pool Único
#
# NÃO REINSTALA O SISTEMA NEM FORMATA PARTIÇÕES.
# Executa as correções pontuais para ambiente virtual:
#   1. Corrige hostname (virtualvm) e sincroniza relógio no chroot/live
#   2. Monta os subvolumes Btrfs existentes se executado a partir do Live ISO
#   3. Valida e garante fstab resiliente por UUIDs e labels corretas
#   4. Instala chaveiro oficial MX Linux (2279 bytes embutido, permissão 0644)
#   5. Configura repositórios oficiais Debian Trixie e MX Linux com pinning seguro
#   6. Instala drivers de vídeo VirtIO/QXL, Mesa, áudio PipeWire e agentes QEMU/SPICE
#   7. Configura Nix Daemon multi-usuário, permissões do socket (0666) e canal nixpkgs-unstable
#   8. Configura LightDM com Greeter GTK, sessão DWM do Home Manager e privilégios PAM
#   9. Regenera initramfs via Dracut com drivers VirtIO/QXL e suporte a Btrfs
#  10. Atualiza e reinstala o GRUB EFI nativo (sem Secure Boot/MOK)
#  11. Executa script de diagnóstico da VM (check-vm-setup.sh)
# ==============================================================================
set -e

# Configuração de Cores
C_RESET='\033[0m'
C_RED='\033[0;31m'
C_GREEN='\033[0;32m'
C_YELLOW='\033[1;33m'
C_BLUE='\033[0;34m'
C_CYAN='\033[0;36m'
C_BOLD='\033[1m'

info()  { echo -e "${C_BLUE}ℹ${C_RESET} $*"; }
ok()    { echo -e "${C_GREEN}✓${C_RESET} $*"; }
warn()  { echo -e "${C_YELLOW}⚠${C_RESET} $*"; }
err()   { echo -e "${C_RED}✗${C_RESET} $*"; }
step()  { echo -e "\n${C_CYAN}==>${C_RESET} ${C_BOLD}${C_YELLOW}$*${C_RESET}"; }

if [ "$EUID" -ne 0 ]; then
    err "Este script precisa ser executado como root. Use: sudo bash $0"
    exit 1
fi

echo -e "${C_BOLD}${C_CYAN}"
echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║      REPARO E FINALIZAÇÃO DO DEBIAN 13 (MÁQUINA VIRTUAL virtualvm)   ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo -e "${C_RESET}"

# ==============================================================================
# Passo 0: Hostname e Sincronização de Relógio
# ==============================================================================
step "Passo 0: Sincronizando Data, Hora e Hostname..."

# Resolver host virtualvm no /etc/hosts local para eliminar aviso do sudo
if ! grep -q "127.0.1.1 virtualvm" /etc/hosts 2>/dev/null; then
    echo "127.0.1.1 virtualvm" >> /etc/hosts 2>/dev/null || true
fi

timedatectl set-ntp true 2>/dev/null || true
HTTP_DATE=$(curl -sI --max-time 5 https://deb.debian.org 2>/dev/null | sed -n 's/^[dD]ate: //p' | tr -d '\r\n')
if [ -z "$HTTP_DATE" ]; then
    HTTP_DATE=$(curl -sI --max-time 5 http://deb.debian.org 2>/dev/null | sed -n 's/^[dD]ate: //p' | tr -d '\r\n')
fi
if [ -z "$HTTP_DATE" ]; then
    HTTP_DATE=$(curl -sI --max-time 5 https://www.google.com 2>/dev/null | sed -n 's/^[dD]ate: //p' | tr -d '\r\n')
fi

if [ -n "$HTTP_DATE" ]; then
    date -u -s "$HTTP_DATE" 2>/dev/null || true
    hwclock --systohc 2>/dev/null || true
    ok "Relógio sincronizado via HTTP Date: $(date)"
else
    info "Data do sistema mantida: $(date)"
fi

# ==============================================================================
# Passo 1: Detecção de Ambiente (Live USB vs Sistema Instalado) e Montagem
# ==============================================================================
step "Passo 1: Detectando Ambiente de Execução..."

DRIVE="/dev/vda"
ROOT_PART="${DRIVE}3"
BOOT_PART="${DRIVE}2"
EFI_PART="${DRIVE}1"

# Otimizações Btrfs balanceadas para NVMe (zstd:3 para sistema, zstd:1 para throughput)
BTRFS_SYS="noatime,ssd,compress=zstd:3,space_cache=v2,commit=120,discard=async"
BTRFS_OPTS="noatime,ssd,compress=zstd:1,space_cache=v2,commit=120,discard=async"
BTRFS_OPTS_MAX="noatime,ssd,compress=zstd:6,space_cache=v2,commit=120,discard=async"
BTRFS_OPTS_SWAP="noatime,ssd,space_cache=v2,commit=120,discard=async"

LIVE_MODE=false
TARGET="/mnt"
RUN_CHROOT="chroot /mnt"

# Verificar se estamos rodando nativamente dentro do Debian já instalado
if [ -f "/etc/debian_version" ] && [ ! -d "/lib/live/mount" ] && [ ! -d "/run/live" ]; then
    if [ -f "/etc/fstab" ] && grep -q "@root" /etc/fstab 2>/dev/null; then
        info "Executando diretamente no Debian instalado (Modo Nativo)."
        TARGET=""
        RUN_CHROOT=""
    fi
fi

if [ -n "$TARGET" ]; then
    LIVE_MODE=true
    info "Executando em ambiente Live USB. Montando subvolumes Btrfs em /mnt..."

    mkdir -p /mnt

    # 1. Montar @root em /mnt se não estiver montado
    if ! mountpoint -q /mnt; then
        info "Montando subvolume @root em /mnt..."
        mount -o "$BTRFS_SYS,subvol=@root" "$ROOT_PART" /mnt
    fi

    # 2. Criar estrutura de diretórios
    mkdir -p /mnt/{boot/efi,home,nix,opt,.snapshots,var/{tmp,spool,log,cache,swap,lib/{libvirt,containers,gdm}}}

    # Função auxiliar para montagem idempotente
    mount_subvol_if_needed() {
        local opts="$1"
        local subvol="$2"
        local mp="$3"
        mkdir -p "$mp"
        if ! mountpoint -q "$mp"; then
            mount -o "$opts,subvol=$subvol" "$ROOT_PART" "$mp"
        fi
    }

    mount_subvol_if_needed "$BTRFS_OPTS"      "@home"          /mnt/home
    mount_subvol_if_needed "$BTRFS_OPTS"      "@nix"           /mnt/nix
    mount_subvol_if_needed "$BTRFS_OPTS_MAX"  "@opt"           /mnt/opt
    mount_subvol_if_needed "$BTRFS_OPTS"      "@gdm"           /mnt/var/lib/gdm
    mount_subvol_if_needed "$BTRFS_OPTS"      "@log"           /mnt/var/log
    mount_subvol_if_needed "$BTRFS_OPTS"      "@spool"         /mnt/var/spool
    mount_subvol_if_needed "$BTRFS_OPTS"      "@tmp"           /mnt/var/tmp
    mount_subvol_if_needed "$BTRFS_OPTS"      "@cache"         /mnt/var/cache
    mount_subvol_if_needed "$BTRFS_OPTS"      "@apt"           /mnt/var/cache/apt
    mount_subvol_if_needed "$BTRFS_OPTS_MAX"  "@snapshots"     /mnt/.snapshots
    mount_subvol_if_needed "$BTRFS_OPTS_SWAP" "@swap"          /mnt/var/swap
    mount_subvol_if_needed "$BTRFS_OPTS"      "@libvirt"       /mnt/var/lib/libvirt
    mount_subvol_if_needed "$BTRFS_OPTS"      "@containers"    /mnt/var/lib/containers

    # 3. Montar /boot e /boot/efi
    if ! mountpoint -q /mnt/boot; then
        mount "$BOOT_PART" /mnt/boot
    fi
    mkdir -p /mnt/boot/efi
    if ! mountpoint -q /mnt/boot/efi; then
        mount -t vfat -o defaults,noatime,nodiratime "$EFI_PART" /mnt/boot/efi
    fi

    # 4. Bind mount dos diretórios de sistema virtual
    for dir in dev proc sys run; do
        if ! mountpoint -q "/mnt/$dir"; then
            mount --rbind "/$dir" "/mnt/$dir"
            mount --make-rslave "/mnt/$dir"
        fi
    done
    if ! mountpoint -q /mnt/dev/pts; then
        mount -t devpts devpts /mnt/dev/pts
    fi

    # 5. Configurar resolução DNS e hostname no chroot
    rm -f /mnt/etc/resolv.conf 2>/dev/null || true
    cp -L /etc/resolv.conf /mnt/etc/resolv.conf 2>/dev/null || true
    if ! grep -q "127.0.1.1 virtualvm" /mnt/etc/hosts 2>/dev/null; then
        echo "127.0.1.1 virtualvm" >> /mnt/etc/hosts 2>/dev/null || true
    fi

    ok "Todos os subvolumes Btrfs e diretórios virtuais estão montados em /mnt."
fi

# ==============================================================================
# Passo 2: Verificação e Ajuste Resiliente de /etc/fstab
# ==============================================================================
step "Passo 2: Verificando e Atualizando /etc/fstab..."

ROOT_UUID=$(blkid -s UUID -o value "$ROOT_PART" 2>/dev/null || true)
BOOT_UUID=$(blkid -s UUID -o value "$BOOT_PART" 2>/dev/null || true)
EFI_UUID=$(blkid -s UUID -o value "$EFI_PART" 2>/dev/null || true)

# Garantir identificadores seguros: se houver UUID, utilizar UUID= para boot e efi
BOOT_ID="LABEL=BOOT"
[ -n "$BOOT_UUID" ] && BOOT_ID="UUID=${BOOT_UUID}"

EFI_ID="LABEL=ESP"
[ -n "$EFI_UUID" ] && EFI_ID="UUID=${EFI_UUID}"

ROOT_ID="LABEL=Debian"
[ -n "$ROOT_UUID" ] && ROOT_ID="UUID=${ROOT_UUID}"

cat << FSTAB_EOF > "${TARGET}/etc/fstab"
# /etc/fstab — Gerado automaticamente pelo fix-debian_vm.sh
# Debian 13 (Trixie) — Máquina Virtual (virtualvm)

# === Btrfs Pool Único ===
${ROOT_ID}    /                   btrfs rw,${BTRFS_SYS},subvol=@root                    0 0
${ROOT_ID}    /home               btrfs rw,${BTRFS_OPTS},subvol=@home                   0 0
${ROOT_ID}    /nix                btrfs rw,${BTRFS_OPTS},subvol=@nix                    0 0
${ROOT_ID}    /.snapshots         btrfs rw,${BTRFS_OPTS_MAX},subvol=@snapshots          0 0
${ROOT_ID}    /var/log            btrfs rw,${BTRFS_OPTS},subvol=@log                    0 0
${ROOT_ID}    /var/tmp            btrfs rw,${BTRFS_OPTS},subvol=@tmp                    0 0
${ROOT_ID}    /var/spool          btrfs rw,${BTRFS_OPTS},subvol=@spool                  0 0
${ROOT_ID}    /var/cache          btrfs rw,${BTRFS_OPTS},subvol=@cache                  0 0
${ROOT_ID}    /var/cache/apt      btrfs rw,${BTRFS_OPTS},subvol=@apt                    0 0
${ROOT_ID}    /var/lib/libvirt    btrfs rw,${BTRFS_OPTS},subvol=@libvirt                0 0
${ROOT_ID}    /var/lib/containers btrfs rw,${BTRFS_OPTS},subvol=@containers             0 0
${ROOT_ID}    /var/lib/gdm        btrfs rw,${BTRFS_OPTS},subvol=@gdm                    0 0
${ROOT_ID}    /opt                btrfs rw,${BTRFS_OPTS_MAX},subvol=@opt                0 0
${ROOT_ID}    /var/swap           btrfs rw,${BTRFS_OPTS_SWAP},subvol=@swap              0 0

# === Boot e EFI ===
${BOOT_ID}    /boot               ext4  rw,relatime                                     0 1
${EFI_ID}     /boot/efi           vfat  defaults,noatime,nodiratime                     0 2

# === Swap (Prioridade 10) ===
/var/swap/swapfile     none                swap  defaults,pri=10                                 0 0

# === Partição de Dados Compartilhados (exFAT) ===
# UUID=FBF7-F8A5         /media/juca/SharedData  exfat  defaults,nofail,uid=1000,gid=1000,dmask=0022,fmask=0133  0 0

# === Tmpfs ===
tmpfs                  /tmp                tmpfs noatime,mode=1777,nosuid,nodev                  0 0
FSTAB_EOF

ok "/etc/fstab atualizado com identificadores UUID resilientes."

# ==============================================================================
# Passo 3: Configuração do Chaveiro e Repositórios MX Linux (Chaveiro Embutido)
# ==============================================================================
step "Passo 3: Configurando Chaveiro e Repositório MX Linux..."

mkdir -p "${TARGET}/usr/share/keyrings" "${TARGET}/etc/apt/trusted.gpg.d" "${TARGET}/etc/apt/sources.list.d" "${TARGET}/etc/apt/preferences.d"

# Escrever diretamente a chave oficial MX-25 em formato binário OpenPGP (2279 bytes)
# Elimina qualquer dependência de curl/wget ou falhas de keyserver
info "Instalando chaveiro oficial MX-25 Repository (0FC0E9FB5B3806B71651351259C16711EFA6FD38)..."
base64 -d << 'MX_KEY_BASE64' > "${TARGET}/usr/share/keyrings/mx-25-archive-keyring.gpg"
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
MX_KEY_BASE64

# Copiar também para trusted.gpg.d para retrocompatibilidade
cp -f "${TARGET}/usr/share/keyrings/mx-25-archive-keyring.gpg" "${TARGET}/etc/apt/trusted.gpg.d/mx-25-archive-keyring.gpg" 2>/dev/null || true

# CRÍTICO: Definir permissão de leitura universal (0644) nos arquivos e 0755 nos diretórios
chmod 755 "${TARGET}/usr/share/keyrings" "${TARGET}/etc/apt/trusted.gpg.d" 2>/dev/null || true
chmod 644 "${TARGET}/usr/share/keyrings"/*.gpg 2>/dev/null || true
chmod 644 "${TARGET}/etc/apt/trusted.gpg.d"/* 2>/dev/null || true
chmod -R a+rX "${TARGET}/usr/share/keyrings" "${TARGET}/etc/apt/trusted.gpg.d" 2>/dev/null || true
ok "Chaveiro oficial MX-25 instalado com sucesso (2279 bytes, permissões 0644)."

# Repositório MX Linux em formato deb822
cat << 'MX_SOURCES_EOF' > "${TARGET}/etc/apt/sources.list.d/mxlinux.sources"
Types: deb
URIs: http://mxrepo.com/mx/repo/
Suites: trixie
Components: main non-free ahs
Signed-By: /usr/share/keyrings/mx-25-archive-keyring.gpg
MX_SOURCES_EOF

# Pinning do MX Linux (Prioridade 100 para evitar conflitos com Debian base)
cat << 'MX_PREF_EOF' > "${TARGET}/etc/apt/preferences.d/20mxlinux.pref"
Package: *
Pin: origin mxrepo.com
Pin-Priority: 100
MX_PREF_EOF

ok "Repositório e Pinning do MX Linux configurados com sucesso."

# ==============================================================================
# Passo 4: Repositórios Oficiais Debian 13 (Trixie)
# ==============================================================================
step "Passo 4: Validando Repositórios Debian 13 (Trixie)..."

cat << 'DEB_SOURCES_EOF' > "${TARGET}/etc/apt/sources.list.d/debian.sources"
Types: deb deb-src
URIs: http://deb.debian.org/debian/
Suites: trixie trixie-updates
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

Types: deb deb-src
URIs: http://security.debian.org/debian-security
Suites: trixie-security
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
DEB_SOURCES_EOF

ok "Repositórios Debian Trixie configurados em deb822 com firmware não-livre habilitado."

# ==============================================================================
# Passo 5: Silenciar PackageKit D-Bus durante execução do APT
# ==============================================================================
step "Passo 5: Configurando ambiente apt para execução limpa..."
mkdir -p "${TARGET}/etc/apt/apt.conf.d"
echo 'APT::PackageKit::Enable "false";' > "${TARGET}/etc/apt/apt.conf.d/99no-packagekit"
if [ -f "${TARGET}/etc/apt/apt.conf.d/20packagekit" ]; then
    mv "${TARGET}/etc/apt/apt.conf.d/20packagekit" "${TARGET}/etc/apt/apt.conf.d/20packagekit.disabled" 2>/dev/null || true
fi
export DEBIAN_FRONTEND=noninteractive

# ==============================================================================
# Passo 6: Atualização de Pacotes e Instalação do que está faltando
# ==============================================================================
step "Passo 6: Executando apt update e instalando dependências pendentes..."

info "Atualizando índices de pacotes..."
$RUN_CHROOT apt update || true

info "Corrigindo possíveis dependências quebradas..."
$RUN_CHROOT apt --fix-broken install -y

info "Instalando Kernel e Headers..."
$RUN_CHROOT apt install -y \
    linux-image-amd64 \
    linux-headers-amd64

info "Removendo pacotes de aceleração física VA-API incompatíveis com a VM..."
$RUN_CHROOT apt purge -y mesa-va-drivers vainfo 2>/dev/null || true

info "Instalando drivers de vídeo VirtIO/QXL, Mesa, Vulkan e MPV..."
$RUN_CHROOT apt install -y \
    xserver-xorg-video-qxl \
    xserver-xorg-video-all \
    libgl1-mesa-dri \
    mesa-vulkan-drivers \
    mpv

info "Instalando ferramentas de áudio PipeWire, agentes VM, Nix e utilitários..."
$RUN_CHROOT apt install -y \
    pipewire-audio \
    wireplumber \
    pipewire-pulse \
    pipewire-alsa \
    libspa-0.2-jack \
    rtkit \
    network-manager \
    systemd-zram-generator \
    earlyoom \
    irqbalance \
    qemu-guest-agent \
    spice-vdagent \
    polkitd \
    pkexec \
    udisks2 \
    udisks2-btrfs \
    dconf-cli \
    dconf-gsettings-backend \
    acl \
    xdg-user-dirs \
    chrony \
    sudo \
    btrfs-progs \
    zstd \
    curl \
    wget \
    ca-certificates \
    nix-bin \
    nix-setup-systemd

info "Instalando servidor gráfico Xorg, Display Manager LightDM e Greeter GTK..."
$RUN_CHROOT apt install -y \
    xserver-xorg \
    xserver-xorg-input-libinput \
    x11-xserver-utils \
    xinit \
    xauth \
    xterm \
    lightdm \
    lightdm-gtk-greeter \
    lightdm-gtk-greeter-settings \
    libpam-gnome-keyring \
    xwayland || true

info "Configurando zRAM (Swap comprimido em RAM de 4 GB via zstd)..."
mkdir -p "${TARGET}/etc/systemd" "${TARGET}/etc/sysctl.d"
cat << 'ZRAM_CONF_EOF' > "${TARGET}/etc/systemd/zram-generator.conf"
# /etc/systemd/zram-generator.conf — Configuração do zRAM (virtualvm)
[zram0]
zram-size = min(ram / 2, 4096)
compression-algorithm = zstd
swap-priority = 100
ZRAM_CONF_EOF

cat << 'ZRAM_SYSCTL_EOF' > "${TARGET}/etc/sysctl.d/99-zram.conf"
# Otimizações de kernel para zRAM de alta performance
vm.swappiness = 100
vm.page-cluster = 0
ZRAM_SYSCTL_EOF

# Desativar systemd-networkd para evitar conflito com NetworkManager
$RUN_CHROOT systemctl disable --now systemd-networkd.service 2>/dev/null || true
$RUN_CHROOT systemctl mask systemd-networkd.socket 2>/dev/null || true
$RUN_CHROOT systemctl mask systemd-networkd-wait-online.service 2>/dev/null || true

# Ativar serviços essenciais na VM
$RUN_CHROOT systemctl enable lightdm.service 2>/dev/null || true
$RUN_CHROOT systemctl enable NetworkManager.service 2>/dev/null || true
$RUN_CHROOT systemctl enable qemu-guest-agent.service 2>/dev/null || true
$RUN_CHROOT systemctl enable spice-vdagent.service 2>/dev/null || true
$RUN_CHROOT systemctl enable earlyoom 2>/dev/null || true
$RUN_CHROOT systemctl enable irqbalance 2>/dev/null || true
$RUN_CHROOT systemctl enable fstrim.timer 2>/dev/null || true

info "Garantindo pacotes essenciais de Bootloader assinado e Kernel..."
$RUN_CHROOT apt install -y \
    linux-image-amd64 \
    linux-headers-amd64 \
    dracut \
    dracut-core \
    shim-signed \
    grub-efi-amd64-signed \
    efibootmgr \
    os-prober

ok "Pacotes essenciais da VM instalados e serviços ativados."

# ==============================================================================
# Passo 7: Configuração do Nix Daemon (Multi-Usuário), Socket e Canal Unstable
# ==============================================================================
step "Passo 7: Configurando Nix Daemon, Permissões do Socket e Canal Unstable..."

info "Garantindo existência do usuário juca e grupos do Nix..."
if ! $RUN_CHROOT id -u juca >/dev/null 2>&1; then
    info "Criando usuário 'juca' no sistema..."
    $RUN_CHROOT useradd -m -c "Reinaldo P Jr" -s /bin/bash juca
    $RUN_CHROOT sh -c 'echo "juca:200291" | chpasswd -c SHA512'
    $RUN_CHROOT usermod -aG floppy,audio,sudo,video,systemd-journal,lp,cdrom,netdev,input,plugdev juca 2>/dev/null || true
fi

$RUN_CHROOT groupadd -r nixbld 2>/dev/null || true
$RUN_CHROOT groupadd -r nix-users 2>/dev/null || true
$RUN_CHROOT usermod -aG nixbld,nix-users juca 2>/dev/null || true

info "Garantindo propriedade e permissões seguras do Nix (evita falhas de tmpfiles)..."
chown root:root "${TARGET}/nix" "${TARGET}/nix/var" "${TARGET}/nix/var/nix" "${TARGET}/nix/var/nix/profiles" "${TARGET}/nix/var/nix/gcroots" 2>/dev/null || true
chmod 755 "${TARGET}/nix" "${TARGET}/nix/var" "${TARGET}/nix/var/nix" "${TARGET}/nix/var/nix/profiles" "${TARGET}/nix/var/nix/gcroots" 2>/dev/null || true

info "Restaurando permissões corretas da árvore /nix para multi-usuário..."
chmod 755 "${TARGET}/nix" 2>/dev/null || true
mkdir -p "${TARGET}/nix/store" \
         "${TARGET}/nix/var/nix/daemon-socket" \
         "${TARGET}/nix/var/nix/profiles/per-user" \
         "${TARGET}/nix/var/nix/gcroots/per-user" \
         "${TARGET}/etc/nix"

# Permissões do /nix/store: gerenciado pelo daemon (root:nixbld com sticky bit 1775)
chown root:nixbld "${TARGET}/nix/store" 2>/dev/null || true
chmod 1775 "${TARGET}/nix/store" 2>/dev/null || true

# Permissões do daemon-socket: universalmente acessível (0777) para eliminar 'Permission denied'
chown root:nix-users "${TARGET}/nix/var/nix/daemon-socket" 2>/dev/null || true
chmod 0777 "${TARGET}/nix/var/nix/daemon-socket" 2>/dev/null || true
chmod 1777 "${TARGET}/nix/var/nix/profiles/per-user" "${TARGET}/nix/var/nix/gcroots/per-user" 2>/dev/null || true

# Configurar SocketMode=0666 no nix-daemon.socket para permitir conexão irrestrita de usuários locais
mkdir -p "${TARGET}/etc/systemd/system/nix-daemon.socket.d"
cat << 'NIX_SOCK_OVERRIDE_EOF' > "${TARGET}/etc/systemd/system/nix-daemon.socket.d/override.conf"
[Socket]
SocketMode=0666
SocketUser=root
SocketGroup=nix-users
NIX_SOCK_OVERRIDE_EOF

# Regra de tmpfiles.d persistente para garantir permissões do socket a cada boot
cat << 'NIX_SOCK_TMPFILES_EOF' > "${TARGET}/etc/tmpfiles.d/nix-daemon-socket.conf"
d /nix/var/nix/daemon-socket 0777 root nix-users -
d /nix/var/nix/profiles/per-user 1777 root root -
d /nix/var/nix/gcroots/per-user 1777 root root -
NIX_SOCK_TMPFILES_EOF
$RUN_CHROOT systemd-tmpfiles --create /etc/tmpfiles.d/nix-daemon-socket.conf 2>/dev/null || true

# /etc/nix/nix.conf otimizado com trusted-users e flakes
cat << 'NIX_CONF_EOF' > "${TARGET}/etc/nix/nix.conf"
build-users-group = nixbld
trusted-users = root juca @nixbld @nix-users
allowed-users = *
experimental-features = nix-command flakes
max-jobs = auto
cores = 0
NIX_CONF_EOF

# Ativar serviços do Nix daemon no boot
$RUN_CHROOT systemctl enable nix-daemon.socket nix-daemon.service 2>/dev/null || true

# Configurar canal nixpkgs-unstable para juca e root
info "Configurando o canal nixpkgs-unstable para o usuário juca e root..."
mkdir -p "${TARGET}/home/juca/.nix-defexpr/channels" "${TARGET}/root/.nix-defexpr/channels"
echo "https://nixos.org/channels/nixpkgs-unstable nixpkgs" > "${TARGET}/home/juca/.nix-channels"
echo "https://nixos.org/channels/nixpkgs-unstable nixpkgs" > "${TARGET}/root/.nix-channels"
$RUN_CHROOT chown -R juca:juca /home/juca/.nix-channels /home/juca/.nix-defexpr 2>/dev/null || chown -R 1000:1000 "${TARGET}/home/juca/.nix-channels" "${TARGET}/home/juca/.nix-defexpr" 2>/dev/null || true

# Variáveis globais em /etc/profile.d/nix-env.sh apontando para nixpkgs-unstable
cat << 'NIX_PROFILE_EOF' > "${TARGET}/etc/profile.d/nix-env.sh"
# Carregar o ambiente do Nix Daemon
if [ -e /etc/profile.d/nix.sh ]; then
    . /etc/profile.d/nix.sh
elif [ -e /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh ]; then
    . /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh
fi

export NIX_REMOTE=daemon
export NIX_PATH="nixpkgs=https://nixos.org/channels/nixpkgs-unstable:$HOME/.nix-defexpr/channels"
export PATH="$HOME/.nix-profile/bin:/etc/profiles/per-user/$USER/bin:$PATH"
export XDG_DATA_DIRS="$HOME/.nix-profile/share:/etc/profiles/per-user/$USER/share:${XDG_DATA_DIRS:-/usr/local/share:/usr/share}"
NIX_PROFILE_EOF
chmod 755 "${TARGET}/etc/profile.d/nix-env.sh"

ok "Nix multi-usuário configurado com socket mode 0666, canal unstable e usuário juca autorizado."

# ==============================================================================
# Passo 8: Configuração do LightDM, Sessão DWM do Home Manager e PAM
# ==============================================================================
step "Passo 8: Configurando LightDM, Sessão DWM do Home Manager e Privilégios PAM..."

mkdir -p "${TARGET}/etc/tmpfiles.d" "${TARGET}/etc/pam.d" "${TARGET}/etc/lightdm" "${TARGET}/etc/lightdm/lightdm.conf.d"
mkdir -p "${TARGET}/usr/share/wayland-sessions" "${TARGET}/usr/share/xsessions" "${TARGET}/usr/local/bin"

# 1. Configuração do LightDM: Greeter padrão, sessão padrão DWM e logind
cat << 'LIGHTDM_CONF_EOF' > "${TARGET}/etc/lightdm/lightdm.conf"
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
cat << 'LIGHTDM_USERS_EOF' > "${TARGET}/etc/lightdm/users.conf"
[UserList]
minimum-uid=1000
hidden-users=nobody nobody4 noaccess nixbld1 nixbld2 nixbld3 nixbld4 nixbld5 nixbld6 nixbld7 nixbld8 nixbld9 nixbld10 nixbld11 nixbld12 nixbld13 nixbld14 nixbld15 nixbld16 nixbld17 nixbld18 nixbld19 nixbld20 nixbld21 nixbld22 nixbld23 nixbld24 nixbld25 nixbld26 nixbld27 nixbld28 nixbld29 nixbld30 nixbld31 nixbld32
hidden-shells=/bin/false /usr/sbin/nologin /sbin/nologin
LIGHTDM_USERS_EOF

# 3. Configuração visual e amigável do Greeter GTK
cat << 'LIGHTDM_GREETER_EOF' > "${TARGET}/etc/lightdm/lightdm-gtk-greeter.conf"
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
cat << 'DWM_WRAPPER_EOF' > "${TARGET}/usr/local/bin/start-dwm-session"
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
chmod 755 "${TARGET}/usr/local/bin/start-dwm-session"

# 5. Entrada da Sessão X11 em /usr/share/xsessions/dwm.desktop
cat << 'DWM_DESKTOP_EOF' > "${TARGET}/usr/share/xsessions/dwm.desktop"
[Desktop Entry]
Name=DWM
Comment=Dynamic Window Manager (Home Manager)
Exec=/usr/local/bin/start-dwm-session
Type=Application
DesktopNames=dwm
DWM_DESKTOP_EOF

# 6. Sessão padrão do usuário juca no ~/.dmrc
mkdir -p "${TARGET}/home/juca"
cat << 'DMRC_EOF' > "${TARGET}/home/juca/.dmrc"
[Desktop]
Session=dwm
DMRC_EOF
$RUN_CHROOT chown juca:juca /home/juca/.dmrc 2>/dev/null || chown 1000:1000 "${TARGET}/home/juca/.dmrc" 2>/dev/null || true
$RUN_CHROOT chmod 644 /home/juca/.dmrc 2>/dev/null || chmod 644 "${TARGET}/home/juca/.dmrc" 2>/dev/null || true

# 7. Helpers setuid em /run/wrappers/bin para Home Manager standalone
cat << 'NIX_WRAPPERS_EOF' > "${TARGET}/etc/tmpfiles.d/nix-wrappers.conf"
d /run/wrappers 0755 root root -
d /run/wrappers/bin 0755 root root -
L+ /run/wrappers/bin/unix_chkpwd - - - - /usr/sbin/unix_chkpwd
L+ /run/wrappers/bin/polkit-agent-helper-1 - - - - /usr/lib/polkit-1/polkit-agent-helper-1
NIX_WRAPPERS_EOF

# 8. Arquivos PAM dedicados para screen lockers
cat << 'PAM_LOCK_EOF' > "${TARGET}/etc/pam.d/hyprlock"
#%PAM-1.0
@include common-auth
@include common-account
@include common-password
@include common-session
PAM_LOCK_EOF

cp -f "${TARGET}/etc/pam.d/hyprlock" "${TARGET}/etc/pam.d/swaylock"
cp -f "${TARGET}/etc/pam.d/hyprlock" "${TARGET}/etc/pam.d/noctalia"
cp -f "${TARGET}/etc/pam.d/hyprlock" "${TARGET}/etc/pam.d/i3lock"

# 9. Links para sessões Wayland e X11 disponíveis no Home Manager
cat << 'DM_SESSIONS_TMPFILES_EOF' > "${TARGET}/etc/tmpfiles.d/nix-desktop-sessions.conf"
L+ /usr/share/wayland-sessions/hyprland.desktop - - - - /home/juca/.local/share/wayland-sessions/hyprland.desktop
L+ /usr/share/wayland-sessions/mango.desktop    - - - - /home/juca/.local/share/wayland-sessions/mango.desktop
L+ /usr/share/xsessions/dwm.desktop            - - - - /home/juca/.local/share/xsessions/dwm.desktop
L+ /usr/share/xsessions/bspwm.desktop          - - - - /home/juca/.local/share/xsessions/bspwm.desktop
DM_SESSIONS_TMPFILES_EOF

# Garantir permissão de leitura e propriedade na home para que o LightDM acesse arquivos de sessão
$RUN_CHROOT chown -R juca:juca /home/juca 2>/dev/null || chown -R 1000:1000 "${TARGET}/home/juca" 2>/dev/null || true
chmod 755 "${TARGET}/home/juca" 2>/dev/null || true

ok "LightDM, sessão DWM resiliente e privilégios PAM configurados com sucesso."

# ==============================================================================
# Passo 9: Configuração do Dracut e Geração de Initramfs
# ==============================================================================
step "Passo 9: Configurando e Regenerando Initramfs via Dracut..."

mkdir -p "${TARGET}/etc/dracut.conf.d"

cat << 'DRACUT_DEB_EOF' > "${TARGET}/etc/dracut.conf.d/10-debian.conf"
do_prelink="no"
hostonly="yes"
add_dracutmodules+=" systemd btrfs "
DRACUT_DEB_EOF

cat << 'DRACUT_CUSTOM_EOF' > "${TARGET}/etc/dracut.conf.d/10-custom.conf"
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
DRACUT_CUSTOM_EOF

cat << 'DRACUT_INPUT_EOF' > "${TARGET}/etc/dracut.conf.d/input.conf"
add_drivers+=" psmouse "
DRACUT_INPUT_EOF

# Regenerar initramfs para cada kernel instalado
for kpath in "${TARGET}"/lib/modules/*; do
    [ -d "$kpath" ] || continue
    kver=$(basename "$kpath")
    info "Gerando Dracut initramfs para kernel $kver..."
    $RUN_CHROOT dracut --kver "$kver" --force
done

ok "Initramfs gerado com suporte nativo a Btrfs e compressão Zstandard."

cat << 'GRUB_CFG_EOF' > "${TARGET}/etc/default/grub"
# Configuration file for GRUB — Virtual Machine (virt-manager)
GRUB_DEFAULT=saved
GRUB_TIMEOUT=3
GRUB_DISABLE_SUBMENU=false
GRUB_DISTRIBUTOR=$(lsb_release -i -s 2>/dev/null || echo Debian)
GRUB_DISABLE_OS_PROBER=false
GRUB_CMDLINE_LINUX_DEFAULT="quiet rhgb apparmor=1 security=apparmor"
GRUB_DISABLE_RECOVERY="true"
GRUB_GFXMODE=1920x1080x32,auto
GRUB_COLOR_NORMAL="light-blue/black"
GRUB_COLOR_HIGHLIGHT="light-cyan/blue"
GRUB_CFG_EOF

info "Executando grub-install para arquitetura x86_64-efi (com suporte a Secure Boot)..."
$RUN_CHROOT grub-install \
  --target=x86_64-efi \
  --efi-directory=/boot/efi \
  --bootloader-id=debian \
  --recheck

# Garantir cópia de fallback padrão em EFI/BOOT/BOOTX64.EFI (resolve Access Denied no OVMF)
mkdir -p "${TARGET}/boot/efi/EFI/BOOT"
if [ -f "${TARGET}/boot/efi/EFI/debian/shimx64.efi" ]; then
    cp -f "${TARGET}/boot/efi/EFI/debian/shimx64.efi" "${TARGET}/boot/efi/EFI/BOOT/BOOTX64.EFI" 2>/dev/null || true
    cp -f "${TARGET}/boot/efi/EFI/debian/grubx64.efi" "${TARGET}/boot/efi/EFI/BOOT/grubx64.efi" 2>/dev/null || true
    cp -f "${TARGET}/boot/efi/EFI/debian/mmx64.efi" "${TARGET}/boot/efi/EFI/BOOT/mmx64.efi" 2>/dev/null || true
    cp -f "${TARGET}/boot/efi/EFI/debian/fbx64.efi" "${TARGET}/boot/efi/EFI/BOOT/fbx64.efi" 2>/dev/null || true
fi

info "Executando update-grub..."
$RUN_CHROOT update-grub

info "Verificando entradas de inicialização UEFI (efibootmgr)..."
$RUN_CHROOT efibootmgr 2>/dev/null || true

ok "GRUB EFI assinado instalado e atualizado com sucesso."

# ==============================================================================
# Passo 11: Script de Diagnóstico e Verificação da VM
# ==============================================================================
step "Passo 11: Criando Script de Diagnóstico e Verificando Status da VM..."

cat << 'CHECK_VM_EOF' > "${TARGET}/usr/local/bin/check-vm-setup.sh"
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
echo "   Faça login como 'juca' e execute:"
echo "   home-manager switch --flake .#juca@virtualvm"
echo "=========================================="
CHECK_VM_EOF
chmod +x "${TARGET}/usr/local/bin/check-vm-setup.sh"

$RUN_CHROOT /usr/local/bin/check-vm-setup.sh || true

# ==============================================================================
# Passo 12: Limpeza e Finalização
# ==============================================================================
step "Passo 12: Finalizando e Limpando Configurações Temporárias..."

rm -f "${TARGET}/etc/apt/apt.conf.d/99no-packagekit" 2>/dev/null || true
if [ -f "${TARGET}/etc/apt/apt.conf.d/20packagekit.disabled" ]; then
    mv "${TARGET}/etc/apt/apt.conf.d/20packagekit.disabled" "${TARGET}/etc/apt/apt.conf.d/20packagekit" 2>/dev/null || true
fi

echo -e "\n${C_BOLD}${C_GREEN}"
echo "╔══════════════════════════════════════════════════════════════════════╗"
echo "║             REPARO DA VM CONCLUÍDO COM SUCESSO!                      ║"
echo "╚══════════════════════════════════════════════════════════════════════╝"
echo -e "${C_RESET}"

info "Instruções para reinicialização:"
if [ "$LIVE_MODE" = true ]; then
    echo -e "  1. Desmonte as partições antes de reiniciar:"
    echo -e "     ${C_CYAN}sudo umount -R /mnt${C_RESET}"
    echo -e "  2. Reinicie a VM:"
    echo -e "     ${C_CYAN}sudo reboot${C_RESET}"
else
    echo -e "  1. O sistema está reparado. Pode reiniciar quando desejar:"
    echo -e "     ${C_CYAN}sudo reboot${C_RESET}"
fi
echo -e "  3. No menu GRUB, selecione '${C_BOLD}Debian GNU/Linux${C_RESET}' para iniciar seu sistema."
echo -e "  4. No primeiro login, execute no terminal:"
echo -e "     ${C_CYAN}home-manager switch --flake .#juca@virtualvm${C_RESET}"
echo ""
