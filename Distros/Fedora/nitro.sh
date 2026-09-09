#!/usr/bin/env bash
#
# install-fedora-minimal-kvm.sh (nitro-full.sh)
# Instalação ULTRA-ENXUTA & OTIMIZADA: Fedora 44 KDE Mínimo + KVM/VFIO + Nix + Snapshots
# Dual-Boot: Windows 11 + Fedora 44
#
# Hardware alvo: Acer Nitro 5 AN515-52 (UEFI-only, Intel 8th Gen + NVIDIA GTX)
# SSD: 500 GB NVMe
# RAM: 16 GB
#
# Layout de Partições:
#   p1: EFI System   (1 GB)   — FAT32  (compartilhada entre Windows e Fedora)
#   p2: Boot Fedora  (1 GB)   — ext4
#   p3: Windows 11   (150 GB) — NTFS   (partição reservada; o instalador Win11 sobrescreve)
#   p4: Fedora Btrfs (100 GB) — Btrfs  (@root, @home, @nix, @libvirt, @containers, @log, @cache, @tmp, @spool, @opt, @snapshots, @swap)
#   p5: Shared Data  (resto)  — exFAT  (~248 GB compartilhados)
#
set -euo pipefail

# ============================================================
# Verificar root
# ============================================================
if [ "$(id -u)" -ne 0 ]; then
    echo "❌ Este script precisa ser executado como root."
    exit 1
fi

echo "⚡ Iniciando instalação: Fedora 44 KDE Mínimo + KVM/VFIO + Nix..."

setenforce 0 2>/dev/null || true

# ============================================================
# Instalar ferramentas de disco na ISO Live
# ============================================================
dnf install -y gdisk arch-install-scripts exfatprogs btrfs-progs ntfsprogs ntfs-3g

# ============================================================
# Variáveis
# ============================================================
DRIVE="/dev/nvme0n1"

EFI_PART="${DRIVE}p1"
SYSTEM_PART="${DRIVE}p2"
WIN_PART="${DRIVE}p3"
BTRFS_PART="${DRIVE}p4"
MISC_PART="${DRIVE}p5"

MOUNTPOINT="/mnt"
BTRFS_LABEL="Fedora"
EFI_LABEL="ESP"
SYSTEM_LABEL="BOOT"
WIN_LABEL="Windows11"
MISC_LABEL="SharedData"

# Opções Btrfs calibradas por subvolume (SSD NVMe)
# @root — sistema, mix de binários e texto
BTRFS_SYS="noatime,ssd,compress=zstd:3,space_cache=v2,commit=120,discard=async"
# @home — arquivos do usuário, boa compressão
BTRFS_OPTS_HOME="noatime,ssd,compress=zstd:9,space_cache=v2,commit=120,discard=async"
# @nix / @opt / @snapshots — muito compressíveis, forçar
BTRFS_OPTS_MAX="noatime,ssd,compress-force=zstd:15,space_cache=v2,commit=120,discard=async"
# @log / @spool / @cache / @tmp — I/O intensivo, overhead mínimo
BTRFS_OPTS="noatime,ssd,compress=zstd:3,space_cache=v2,commit=60,discard=async"
# @swap — sem compressão (swapfile não pode ser comprimido)
BTRFS_OPTS_SWAP="noatime,ssd,nodatacow,space_cache=v2,commit=120,discard=async"

# ============================================================
# IDs da GPU NVIDIA para VFIO Passthrough
# Detectados automaticamente via lspci. Se a detecção falhar
# (ex: rodando fora do hardware alvo), os valores de fallback
# abaixo são usados, mas SEMPRE confira com:
#   lspci -nn | grep -i nvidia
# ============================================================
NVIDIA_GPU_ID="$(lspci -nn | grep -i 'nvidia' | grep -Ei 'vga|3d controller' | grep -oE '\[10de:[0-9a-fA-F]{4}\]' | tr -d '[]' | head -n1)"
NVIDIA_AUDIO_ID="$(lspci -nn | grep -i 'nvidia' | grep -i 'audio' | grep -oE '\[10de:[0-9a-fA-F]{4}\]' | tr -d '[]' | head -n1)"

if [ -z "$NVIDIA_GPU_ID" ]; then
    echo "⚠️  Não foi possível detectar a GPU NVIDIA via lspci. Usando fallback (CONFIRA depois com 'lspci -nn | grep -i nvidia')."
    NVIDIA_GPU_ID="10de:1c8d"
fi
if [ -z "$NVIDIA_AUDIO_ID" ]; then
    echo "⚠️  Não foi possível detectar o áudio HDMI da NVIDIA via lspci. Usando fallback."
    NVIDIA_AUDIO_ID="10de:0fb9"
fi
echo "🎮 GPU NVIDIA detectada: ${NVIDIA_GPU_ID} | Áudio: ${NVIDIA_AUDIO_ID}"

# ============================================================
# Particionamento (UEFI-only — sem BIOS Boot)
# ============================================================
echo "🧹 Limpando montagens e particionando $DRIVE..."
swapoff -a 2>/dev/null || true
umount -R "$MOUNTPOINT" 2>/dev/null || true
udevadm settle 2>/dev/null || true

sgdisk --zap-all "$DRIVE"
sleep 2
partprobe "$DRIVE" 2>/dev/null || true
udevadm settle
parted -s -a optimal "$DRIVE" mklabel gpt

# p1: EFI (1GB), p2: Boot Fedora (1GB), p3: Windows 11 (150GB), p4: Fedora Btrfs (100GB), p5: exFAT (resto)
sgdisk -n 1:0:+1G      -t 1:EF00 -c 1:"EFI SYSTEM"          "$DRIVE"
sgdisk -n 2:0:+1G      -t 2:8301 -c 2:"SYSTEM RESERVED"     "$DRIVE"
sgdisk -n 3:0:+150G    -t 3:0700 -c 3:"Windows 11"          "$DRIVE"
sgdisk -n 4:0:+100G    -t 4:8300 -c 4:"Fedora Btrfs Pool"   "$DRIVE"
sgdisk -n 5:0:0        -t 5:0700 -c 5:"Shared exFAT Data"   "$DRIVE"
sgdisk -p "$DRIVE"

# ============================================================
# Formatação
# ============================================================
echo "🧼 Formatando partições..."
mkfs.fat  -F32 -n "$EFI_LABEL"    "$EFI_PART"
mkfs.ext4 -F   -L "$SYSTEM_LABEL" "$SYSTEM_PART"
# Partição Windows (p3): NTFS placeholder.
# O instalador do Win11 irá reformatá-la. NÃO instale o Fedora antes do Windows.
mkntfs -f -L "$WIN_LABEL" "$WIN_PART"
mkfs.btrfs -f  -L "$BTRFS_LABEL"  "$BTRFS_PART"
# -b 1M: tamanho de cluster otimizado para arquivos grandes (VMs, vídeos)
mkfs.exfat -b 1M -c 32K -n "$MISC_LABEL" "$MISC_PART"

# ============================================================
# Subvolumes Btrfs — Sistema
# ============================================================
echo "📂 Criando subvolumes Btrfs (pool único de 300 GB)..."
mount "$BTRFS_PART" "$MOUNTPOINT"
for sv in @root @home @nix @cache @opt @libvirt @containers @spool @log @tmp @snapshots @swap; do
  btrfs subvolume create "$MOUNTPOINT/$sv"
done
umount -Rv "$MOUNTPOINT"

# ============================================================
# Montagem de todos os subvolumes
# ============================================================
echo "🔗 Montando subvolumes..."
mount -o "$BTRFS_SYS,subvol=@root" "$BTRFS_PART" "$MOUNTPOINT"

# Criar estrutura de diretórios
mkdir -pv "$MOUNTPOINT"/{boot/efi,home,nix,opt,.snapshots,var/{tmp,spool,log,cache,swap,lib/{libvirt,containers}}}

# Montar todos os subvolumes (opções calibradas por tipo de dado)
mount -o "$BTRFS_OPTS_HOME,subvol=@home"     "$BTRFS_PART" "$MOUNTPOINT/home"
mount -o "$BTRFS_OPTS_MAX,subvol=@nix"      "$BTRFS_PART" "$MOUNTPOINT/nix"
mount -o "$BTRFS_OPTS_MAX,subvol=@opt"      "$BTRFS_PART" "$MOUNTPOINT/opt"
mount -o "$BTRFS_OPTS,subvol=@log"          "$BTRFS_PART" "$MOUNTPOINT/var/log"
mount -o "$BTRFS_OPTS,subvol=@spool"        "$BTRFS_PART" "$MOUNTPOINT/var/spool"
mount -o "$BTRFS_OPTS,subvol=@tmp"          "$BTRFS_PART" "$MOUNTPOINT/var/tmp"
mount -o "$BTRFS_OPTS,subvol=@cache"        "$BTRFS_PART" "$MOUNTPOINT/var/cache"
mount -o "$BTRFS_OPTS_MAX,subvol=@snapshots" "$BTRFS_PART" "$MOUNTPOINT/.snapshots"
mount -o "$BTRFS_OPTS_SWAP,subvol=@swap"    "$BTRFS_PART" "$MOUNTPOINT/var/swap"

# Libvirt e Containers: desativar CoW para performance de I/O de VMs e containers
mount -o "$BTRFS_OPTS,subvol=@libvirt" "$BTRFS_PART" "$MOUNTPOINT/var/lib/libvirt"
mount -o "$BTRFS_OPTS,subvol=@containers" "$BTRFS_PART" "$MOUNTPOINT/var/lib/containers"
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
btrfs filesystem mkswapfile --size 16g "$MOUNTPOINT/var/swap/swapfile"
chmod 600 "$MOUNTPOINT/var/swap/swapfile"

# ============================================================
# Bind-mounts para chroot
# ============================================================
echo "🔧 Montando pseudo-filesystems..."
for dir in dev proc sys run; do
    mkdir -pv "$MOUNTPOINT/$dir"
    mount --rbind "/$dir" "$MOUNTPOINT/$dir"   # --rbind inclui /dev/pts
    mount --make-rslave "$MOUNTPOINT/$dir" 2>/dev/null || true
done
udevadm trigger 2>/dev/null || true

# ============================================================
# Instalar sistema base
# ============================================================
source /etc/os-release
VERSION_ID="${VERSION_ID:-44}"
echo "📦 Instalando Fedora $VERSION_ID..."

dnf --installroot="$MOUNTPOINT" --releasever="$VERSION_ID" --forcearch=x86_64 \
    --setopt=fastestmirror=True \
    --setopt=install_weak_deps=False \
    --use-host-config \
    group install "Core" -y --skip-unavailable

dnf --installroot="$MOUNTPOINT" --releasever="$VERSION_ID" --forcearch=x86_64 \
    --setopt=fastestmirror=True \
    --setopt=install_weak_deps=False \
    --use-host-config \
    install -y \
    glibc-langpack-pt glibc-langpack-en \
    btrfs-progs \
    efi-filesystem efibootmgr \
    grub2-common grub2-efi-x64 grub2-tools grub2-tools-efi grub2-tools-extra \
    os-prober \
    kernel kernel-devel kernel-headers shim-x64 \
    linux-firmware \
    systemd-pam \
    shadow-utils sudo passwd \
    gawk grep sed findutils procps-ng neovim \
    firewalld fail2ban tlp \
    dnf5 dnf5-plugins

# Copiar DNS
# O 'dnf --installroot' às vezes faz bind-mount automático do resolv.conf
# do host pra dentro do installroot (pra scriptlets de pacote com rede
# funcionarem). Se isso não for desfeito, o arquivo de destino é
# literalmente o mesmo do host — daí um simples 'cp' por cima falha com
# "are the same file". Desmontamos primeiro (se for o caso) e só então
# recriamos como um arquivo independente.
umount "$MOUNTPOINT/etc/resolv.conf" 2>/dev/null || true
rm -f "$MOUNTPOINT/etc/resolv.conf"
cp -L /etc/resolv.conf "$MOUNTPOINT/etc/resolv.conf"

# ============================================================
# Gerar /etc/fstab
# ============================================================
echo "📝 Gerando /etc/fstab..."
cat << EOF > "$MOUNTPOINT/etc/fstab"
# /etc/fstab — Gerado automaticamente pelo script de instalação
# Fedora $VERSION_ID — Acer Nitro 5 AN515-52 — Dual Boot Windows 11 + Fedora

# === Btrfs Pool Único (100 GB — p4) ===
LABEL=${BTRFS_LABEL}    /                   btrfs rw,${BTRFS_SYS},subvol=@root                    0 0
LABEL=${BTRFS_LABEL}    /home               btrfs rw,${BTRFS_OPTS},subvol=@home                   0 0
LABEL=${BTRFS_LABEL}    /nix                btrfs rw,${BTRFS_OPTS_MAX},subvol=@nix                0 0
LABEL=${BTRFS_LABEL}    /.snapshots         btrfs rw,${BTRFS_OPTS_MAX},subvol=@snapshots          0 0
LABEL=${BTRFS_LABEL}    /var/log            btrfs rw,${BTRFS_OPTS},subvol=@log                    0 0
LABEL=${BTRFS_LABEL}    /var/tmp            btrfs rw,${BTRFS_OPTS},subvol=@tmp                    0 0
LABEL=${BTRFS_LABEL}    /var/spool          btrfs rw,${BTRFS_OPTS},subvol=@spool                  0 0
LABEL=${BTRFS_LABEL}    /var/cache          btrfs rw,${BTRFS_OPTS},subvol=@cache                  0 0
LABEL=${BTRFS_LABEL}    /var/lib/libvirt    btrfs rw,${BTRFS_OPTS},subvol=@libvirt                0 0
LABEL=${BTRFS_LABEL}    /var/lib/containers btrfs rw,${BTRFS_OPTS},subvol=@containers             0 0
LABEL=${BTRFS_LABEL}    /opt                btrfs rw,${BTRFS_OPTS_MAX},subvol=@opt                0 0
LABEL=${BTRFS_LABEL}    /var/swap           btrfs rw,${BTRFS_OPTS_SWAP},subvol=@swap              0 0

# === Boot e EFI ===
LABEL=${SYSTEM_LABEL}   /boot               ext4  rw,relatime                                     0 1
LABEL=${EFI_LABEL}      /boot/efi           vfat  defaults,noatime,nodiratime                     0 2

# === Swap (Prioridade 10, abaixo do zRAM que opera em 100) ===
/var/swap/swapfile      none                swap  defaults,pri=10                                 0 0

# === Tmpfs ===
tmpfs                   /tmp                tmpfs noatime,mode=1777,nosuid,nodev                  0 0

# === Dados Compartilhados exFAT — p5 (~248 GB) ===
# Monte manualmente ou descomente para montar no boot:
# LABEL=${MISC_LABEL}   /mnt/shared         exfat defaults,uid=1000,gid=1000,fmask=0022,dmask=0022 0 0
EOF

# ============================================================
# Pós-instalação dentro do Chroot
# ============================================================
echo "⚙️ Executando pós-instalação no chroot..."

cat << 'EOF_CHROOT' > "$MOUNTPOINT/tmp/post_install.sh"
#!/bin/bash
set -euo pipefail
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"

mount -t efivarfs efivarfs /sys/firmware/efi/efivars 2>/dev/null || true

# ==== GRUB (UEFI-only, Nitro 5 Hardware Tuning + VFIO) ====
mkdir -p /etc/default /etc/grub.d

cat << 'GRUB_EOF' > /etc/default/grub
GRUB_TIMEOUT=5
GRUB_DISTRIBUTOR="Fedora"
GRUB_DEFAULT=saved
GRUB_DISABLE_SUBMENU=true
GRUB_TERMINAL_OUTPUT="console"
# GRUB_CMDLINE_LINUX_DEFAULT: aplica apenas ao boot normal (não ao recovery)
GRUB_CMDLINE_LINUX_DEFAULT="rhgb quiet intel_iommu=on iommu=pt i915.enable_psr=0 i915.enable_fbc=1 i915.enable_guc=3 nvidia-drm.modeset=1 nvidia-drm.fbdev=1 msr.allow_writes=on nowatchdog split_lock_detect=off psi=1 i8042.nopnp usbcore.autosuspend=-1 page_alloc.shuffle=1 rcupdate.rcu_expedited=1"
GRUB_DISABLE_RECOVERY="true"
GRUB_ENABLE_BLSCFG=true
# Detectar Windows no GRUB (dual-boot)
GRUB_DISABLE_OS_PROBER=false
# Cores do menu GRUB
GRUB_COLOR_NORMAL="light-blue/black"
GRUB_COLOR_HIGHLIGHT="light-cyan/blue"
GRUB_EOF

# GRUB 40_custom - Entradas rápidas de Reboot e Shutdown
cat << 'GRUB_CUSTOM_EOF' > /etc/grub.d/40_custom
#!/bin/sh
exec tail -n +3 $0

menuentry "Reboot" {
    reboot
}

menuentry "Shutdown" {
    halt
}
GRUB_CUSTOM_EOF
chmod +x /etc/grub.d/40_custom

grub2-mkconfig -o /boot/grub2/grub.cfg

# Limpar entradas antigas do "Fedora" no NVRAM EFI antes de criar uma nova
for bootnum in $(efibootmgr | grep -i "Fedora" | awk '{print $1}' | sed 's/Boot//;s/\*//'); do
    efibootmgr -b "$bootnum" -B 2>/dev/null || true
done

# Criar entrada EFI no firmware
efibootmgr -c -d /dev/nvme0n1 -p 1 -L "Fedora" -l "\\EFI\\fedora\\shimx64.efi" 2>/dev/null || true

# ==== Usuários ====
echo "root:200291" | chpasswd
useradd juca -m -c "Reinaldo P JR" -s /bin/bash || true
echo "juca:200291" | chpasswd
# usermod -aG wheel juca
usermod -aG wheel,libvirt,kvm juca

# ==== Timezone, Hostname e Teclado ====
ln -sf /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime
echo "nitro5" > /etc/hostname
cat << 'HOSTS_EOF' > /etc/hosts
127.0.0.1   localhost
::1         localhost
127.0.1.1   nitro5.localdomain nitro5
HOSTS_EOF

# Teclado BR/US com Alt+Shift para alternar
mkdir -p /etc/X11/xorg.conf.d
cat << 'KBD_EOF' > /etc/X11/xorg.conf.d/00-keyboard.conf
Section "InputClass"
    Identifier "keyboard-layout"
    MatchIsKeyboard "on"
    Option "XkbLayout" "us,br"
    Option "XkbVariant" "intl,abnt2"
    Option "XkbModel" "pc105"
    Option "XkbOptions" "grp:alt_shift_toggle"
EndSection
KBD_EOF

# ==== zRAM explícita (16 GB = 100% da RAM) ====
mkdir -p /etc/systemd
cat << 'ZRAM_EOF' > /etc/systemd/zram-generator.conf
[zram0]
zram-size = ram
compression-algorithm = zstd
ZRAM_EOF

# ==== KVM: Nested Virtualization para emuladores Android ====
mkdir -p /etc/modprobe.d
cat << 'KVM_EOF' > /etc/modprobe.d/kvm.conf
options kvm_intel nested=1
KVM_EOF

# ==== VFIO: Preparação para GPU Passthrough DINÂMICO ====
# Em vez de prender a GPU no vfio-pci desde o boot (o que tira a NVIDIA
# do host o tempo todo), os módulos VFIO só ficam disponíveis, e o
# libvirt faz o unbind/rebind automático quando a VM liga/desliga
# (hostdev com managed='yes', padrão do virt-manager). Assim dá pra usar
# a NVIDIA no Fedora (codar, etc.) quando a VM Windows estiver desligada.
cat << VFIO_CONF_EOF > /etc/modprobe.d/vfio.conf
# IDs detectados automaticamente na instalação: ${NVIDIA_GPU_ID},${NVIDIA_AUDIO_ID}
# Descomente a linha abaixo SOMENTE se quiser prender a GPU no vfio-pci
# desde o boot (perde acesso à NVIDIA no host o tempo todo, mesmo com a
# VM desligada). Não recomendado para o seu caso de uso (codar + VM
# em segundo plano com Looking Glass).
# options vfio-pci ids=${NVIDIA_GPU_ID},${NVIDIA_AUDIO_ID}
VFIO_CONF_EOF

# Garantir que os módulos VFIO carreguem no boot (disponíveis, mas sem bind fixo)
cat << 'VFIO_MODULES_EOF' > /etc/modules-load.d/vfio.conf
vfio
vfio_iommu_type1
vfio_pci
vfio_virqfd
VFIO_MODULES_EOF

# ==== IVSHMEM: memória compartilhada para o Looking Glass ====
# Cria /dev/shm/looking-glass com permissões corretas a cada boot,
# antes do libvirt subir a VM. Ajuste o tamanho no XML da VM conforme
# a resolução (32M para 1080p, 64M para 1440p/4K).
mkdir -p /etc/tmpfiles.d
cat << 'LG_TMPFILES_EOF' > /etc/tmpfiles.d/10-looking-glass.conf
f /dev/shm/looking-glass 0660 juca libvirt-qemu -
LG_TMPFILES_EOF

# Blacklist do nouveau (conflita com NVIDIA proprietário e VFIO)
cat << 'BLACKLIST_EOF' > /etc/modprobe.d/blacklist-nouveau.conf
blacklist nouveau
options nouveau modeset=0
BLACKLIST_EOF

# Garantir que os módulos i915 carreguem no initramfs
mkdir -p /etc/dracut.conf.d
cat << 'DRACUT_VFIO_EOF' > /etc/dracut.conf.d/vfio.conf
# hostonly=yes: initramfs enxuto (~40 MB vs ~100 MB com no)
hostonly="yes"
hostonly_cmdline="yes"
# Carregar i915 cedo (Wayland/KMS) e módulos VFIO disponíveis no boot
force_drivers+=" i915 vfio vfio_iommu_type1 vfio_pci "
omit_dracutmodules+=" brltty "
DRACUT_VFIO_EOF

# ==== I/O Scheduler otimizado para NVMe + SATA ====
mkdir -p /etc/udev/rules.d
cat << 'IOSCHED_EOF' > /etc/udev/rules.d/60-iosched.rules
# NVMe: sem scheduler (o SSD tem scheduler interno)
ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/scheduler}="none"
# SATA: BFQ para I/O interativo (se instalar segundo SSD no slot 2.5")
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/scheduler}="bfq"
IOSCHED_EOF

# ==== Intel Undervolt (reduz temperatura, aumenta performance sustentada) ====
cat << 'UNDERVOLT_EOF' > /etc/intel-undervolt.conf
# Valores conservadores. Teste e aumente gradualmente.
# Formato: undervolt INDICE 'NOME' OFFSET_MV
undervolt 0 'CPU' -80
undervolt 1 'GPU' -50
undervolt 2 'CPU Cache' -80
undervolt 3 'System Agent' 0
undervolt 4 'Analog I/O' 0

# Limites de potência: PL1 45W/28s, PL2 60W/2.44ms
power package 45 28 60 0.00244
UNDERVOLT_EOF

# ==== KDE Plasma MÍNIMO + Wi-Fi + Bluetooth + Segurança + Energia ====
echo "🖥️ Instalando KDE Plasma mínimo, Drivers de Wi-Fi, Bluetooth, Firewall e TLP..."
dnf5 install -y \
    zram-generator \
    sddm \
    plasma-desktop \
    plasma-workspace \
    kwin-wayland \
    xorg-x11-server-Xwayland \
    konsole \
    dolphin \
    plasma-nm \
    plasma-pa \
    kscreen \
    NetworkManager \
    NetworkManager-wifi \
    wpa_supplicant \
    iwlwifi-mvm-firmware \
    iw \
    wireless-regdb \
    bluez \
    intel-undervolt \
    firewalld \
    fail2ban \
    tlp \
    nix

# ==== Configuração Automatizada do Nix ====
echo "❄️ Configurando Nix Daemon e permissões de usuário..."

# 1. Adicionar o usuário 'juca' ao grupo de compilação do Nix no Fedora
usermod -aG nixbld juca

# 2. Configurar o /etc/nix/nix.conf para permitir o uso do daemon por usuários comuns
mkdir -p /etc/nix
cat << 'NIX_CONF_EOF' > /etc/nix/nix.conf
build-users-group = nixbld
trusted-users = root juca @nixbld
allowed-users = *
experimental-features = nix-command flakes
NIX_CONF_EOF

# 3. Exportar variáveis globais no perfil do sistema (/etc/profile.d/nix-env.sh)
cat << 'NIX_PROFILE_EOF' > /etc/profile.d/nix-env.sh
export NIX_REMOTE=daemon
export NIX_PATH=$HOME/.nix-defexpr/channels:nixpkgs=$HOME/.nix-defexpr/channels/nixpkgs
NIX_PROFILE_EOF
chmod +x /etc/profile.d/nix-env.sh

# 4. Ativar o serviço do Nix Daemon no boot
systemctl enable nix-daemon.service

# ==== Snapper + Btrfs-Assistant (Snapshots) ====
echo "📸 Instalando Snapper e Btrfs-Assistant..."
dnf5 install -y \
    snapper \
    btrfs-assistant \
    libdnf5-plugin-actions \
    inotify-tools \
    make git

# ==== KVM / Virt-Manager ====
echo "🎮 Instalando componentes de virtualização..."
dnf5 install -y \
    qemu-kvm \
    libvirt \
    virt-manager \
    swtpm \
    edk2-ovmf \
    dnsmasq

usermod -aG libvirt juca || true

# ==== SDDM/KWin: notebook Optimus (tela interna só na Intel) ====
# Com nvidia-drm.modeset=0 a NVIDIA não tem capacidade de desenhar tela
# nenhuma. Sem isso, o KWin pode tentar abrir a sessão nela por padrão
# (geralmente é o card de menor número) e falhar com tela preta.
# Fixamos explicitamente via caminho PCI da Intel (00:02.0), que não muda
# entre boots (diferente do número do /dev/dri/cardN, que pode variar).
mkdir -p /etc/systemd/system/sddm.service.d
cat << 'SDDM_GPU_EOF' > /etc/systemd/system/sddm.service.d/10-intel-gpu.conf
[Service]
Environment=KWIN_DRM_DEVICES=/dev/dri/by-path/pci-0000:00:02.0-card
SDDM_GPU_EOF

# ==== Ativar serviços ====
systemctl enable sddm
systemctl enable libvirtd
systemctl enable NetworkManager
systemctl enable bluetooth
systemctl enable firewalld
systemctl enable fail2ban
systemctl enable tlp

# NÃO ativar intel-undervolt no boot até testar manualmente!
# Após testar: sudo systemctl enable intel-undervolt.service

# ==== RPM Fusion + Drivers NVIDIA + OpenH264 ====
echo "🎮 Instalando repositórios RPM Fusion, OpenH264 e drivers NVIDIA..."
dnf5 install -y \
    "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
    "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"
dnf5 config-manager setopt fedora-cisco-openh264.enabled=1 2>/dev/null || true
dnf5 makecache
# IMPORTANTE: 'kernel-devel'/'kernel-headers' genéricos podem instalar uma
# versão diferente do kernel que ficou instalado, se o mirror sincronizar
# em momentos distintos (ou se houver update de kernel entre os passos
# do script). O akmod compila contra o kernel ATUAL, então travamos a
# versão explicitamente pra garantir que bate certinho.
RUNNING_KERNEL="$(rpm -q kernel --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' | sort -V | tail -n1)"
echo "🔎 Kernel instalado detectado: ${RUNNING_KERNEL}"

# IMPORTANTE: a branch "padrão" do akmod-nvidia (590.xx+) só suporta GPUs
# com GSP físico (Turing/RTX 20xx em diante). Placas Maxwell/Pascal/Volta
# (como a GTX 1050 deste notebook) precisam da branch legada 580xx, senão
# o módulo compila mas o kernel recusa carregar ("does not include the
# required GPU System Processor (GSP)").
dnf5 install -y akmod-nvidia-580xx xorg-x11-drv-nvidia-580xx-cuda akmods mokutil \
    "kernel-devel-${RUNNING_KERNEL}"

echo "🔨 Compilando o módulo NVIDIA 580xx (akmods)..."
akmods --force --kernels "${RUNNING_KERNEL}"

if ! modinfo -k "${RUNNING_KERNEL}" nvidia >/dev/null 2>&1; then
    echo "❌ ERRO: o módulo NVIDIA não compilou corretamente."
    echo "   Verifique se 'kernel-devel-${RUNNING_KERNEL}' está mesmo instalado"
    echo "   e bate com o kernel ativo ('rpm -q kernel')."
    exit 1
fi
echo "✅ Módulo NVIDIA compilado com sucesso para ${RUNNING_KERNEL}."

# Garante que, em futuras atualizações de kernel, o akmods recompile
# automaticamente no boot seguinte (evita esse mesmo problema de novo).
systemctl enable akmods.service 2>/dev/null || true

# ==== Secure Boot: módulos akmods/DKMS não são assinados por padrão ====
# Se o Secure Boot estiver ativo, o kernel vai RECUSAR carregar o nvidia.ko
# no boot (tela trava/congela sem erro visível se 'rhgb quiet' estiver ativo).
SECURE_BOOT_STATE="desconhecido"
if command -v mokutil >/dev/null 2>&1; then
    SECURE_BOOT_STATE="$(mokutil --sb-state 2>/dev/null || echo 'desconhecido')"
fi
echo "🔐 Estado do Secure Boot: ${SECURE_BOOT_STATE}"

if echo "$SECURE_BOOT_STATE" | grep -qi "enabled"; then
    echo "⚠️  SECURE BOOT ATIVO — gerando chave MOK para assinar o módulo NVIDIA (akmods-keygen)..."
    akmods-keygen 2>/dev/null || true
    cat << 'SB_WARN_EOF'
   ══════════════════════════════════════════════════════════
   ⚠️  AÇÃO NECESSÁRIA NO PRIMEIRO BOOT (Secure Boot ativo):
   1. Ao reiniciar, a tela azul "MOK Management" vai aparecer.
   2. Selecione "Enroll MOK" -> "Continue" -> "Yes" e digite a
      senha que o akmods-keygen pediu durante a instalação.
   3. Sem isso, o módulo nvidia.ko NÃO vai carregar e o boot
      pode travar/congelar na tela do kernel.
   Alternativa mais simples: desative o Secure Boot na UEFI.
   ══════════════════════════════════════════════════════════
SB_WARN_EOF
fi

# ==============================================================================
# Configuração de Memória Compartilhada do Looking Glass + SELinux
# ==============================================================================
echo "🖥️ Configurando tmpfiles.d e SELinux para o Looking Glass..."

# 1. Regra de tmpfiles.d para criar o arquivo em RAM no boot
mkdir -p /etc/tmpfiles.d
cat << 'LOOKING_GLASS_EOF' > /etc/tmpfiles.d/looking-glass.conf
# Type Path                  Mode User Group Age Size
f      /dev/shm/looking-glass 0660 juca kvm   -   32M
LOOKING_GLASS_EOF

# 2. Criar o arquivo no ambiente de instalação
systemd-tmpfiles --create /etc/tmpfiles.d/looking-glass.conf

# 3. Permitir acesso do QEMU/KVM via SELinux
semanage fcontext -a -t svirt_tmpfs_t /dev/shm/looking-glass
restorecon -v /dev/shm/looking-glass


# ==== SELinux Relabeling no próximo boot ====
fixfiles -F onboot

# ==== Configurar Snapper para snapshots do Root ====
echo "📸 Configurando Snapper..."

mkdir -p /etc/snapper/configs

# Remover montagem temporária para o snapper criar a config
umount /.snapshots 2>/dev/null || true
btrfs subvolume delete /.snapshots 2>/dev/null || true

# Criar configuração sem depender do serviço D-Bus
snapper --no-dbus -c root create-config / 2>/dev/null || true

# Se o template não foi copiado automaticamente, copiar manualmente
if [ ! -f /etc/snapper/configs/root ] && [ -f /etc/snapper/config-templates/default ]; then
    cp /etc/snapper/config-templates/default /etc/snapper/configs/root
fi

# Remontar o subvolume @snapshots em /.snapshots
btrfs subvolume delete /.snapshots 2>/dev/null || true
mkdir -p /.snapshots
mount -a 2>/dev/null || true

if [ -f /etc/sysconfig/snapper ]; then
    sed -i 's/^SNAPPER_CONFIGS=.*/SNAPPER_CONFIGS="root"/' /etc/sysconfig/snapper
fi

# Política de limpeza automática de snapshots
if [ -f /etc/snapper/configs/root ]; then
    sed -i 's/^TIMELINE_CREATE=.*/TIMELINE_CREATE="yes"/' /etc/snapper/configs/root
    sed -i 's/^TIMELINE_CLEANUP=.*/TIMELINE_CLEANUP="yes"/' /etc/snapper/configs/root
    sed -i 's/^TIMELINE_MIN_AGE=.*/TIMELINE_MIN_AGE="1800"/' /etc/snapper/configs/root
    sed -i 's/^TIMELINE_LIMIT_HOURLY=.*/TIMELINE_LIMIT_HOURLY="5"/' /etc/snapper/configs/root
    sed -i 's/^TIMELINE_LIMIT_DAILY=.*/TIMELINE_LIMIT_DAILY="7"/' /etc/snapper/configs/root
    sed -i 's/^TIMELINE_LIMIT_WEEKLY=.*/TIMELINE_LIMIT_WEEKLY="2"/' /etc/snapper/configs/root
    sed -i 's/^TIMELINE_LIMIT_MONTHLY=.*/TIMELINE_LIMIT_MONTHLY="1"/' /etc/snapper/configs/root
    sed -i 's/^TIMELINE_LIMIT_YEARLY=.*/TIMELINE_LIMIT_YEARLY="0"/' /etc/snapper/configs/root
    sed -i 's/^NUMBER_CLEANUP=.*/NUMBER_CLEANUP="yes"/' /etc/snapper/configs/root
    sed -i 's/^NUMBER_LIMIT=.*/NUMBER_LIMIT="5"/' /etc/snapper/configs/root
fi

# Ativar timers do Snapper (snapshots por horário + limpeza)
systemctl enable snapper-timeline.timer
systemctl enable snapper-cleanup.timer

# ==== Snapshots automáticos no DNF5 (pré/pós update) ====
echo "🔄 Configurando snapshots automáticos no DNF5..."
mkdir -p /etc/dnf/libdnf5-plugins/actions.d
cat << 'DNF5_SNAP_EOF' > /etc/dnf/libdnf5-plugins/actions.d/snapper.actions
# Capturar o comando DNF que disparou a transação
pre_transaction::::/usr/bin/sh -c echo "tmp.cmd=$(ps -o command --no-headers -p '${pid}')"

# Criar snapshot PRE antes de qualquer instalação/atualização/remoção
pre_transaction::::/usr/bin/sh -c echo "tmp.snapper_pre_number=$(snapper create -t pre -p -d '${tmp.cmd}')"

# Criar snapshot POST após transação bem-sucedida
post_transaction::::/usr/bin/sh -c [ -n "${tmp.snapper_pre_number}" ] && snapper create -t post -p --pre-number "${tmp.snapper_pre_number}" -d "${tmp.cmd}"
DNF5_SNAP_EOF

# ==== grub-btrfs (Snapshots no menu GRUB) ====
echo "🔧 Instalando grub-btrfs..."
cd /tmp
git clone https://github.com/Antynea/grub-btrfs.git
cd grub-btrfs

# Symlink para compatibilidade do Fedora (/boot/grub2 -> /boot/grub)
ln -sf /boot/grub2 /boot/grub 2>/dev/null || true

# Configurar para o Fedora (caminho do GRUB diferente do Arch/Ubuntu)
sed -i 's|GRUB_BTRFS_GRUB_DIRNAME=.*|GRUB_BTRFS_GRUB_DIRNAME="/boot/grub2"|' config
sed -i 's|GRUB_BTRFS_MKCONFIG=.*|GRUB_BTRFS_MKCONFIG=/sbin/grub2-mkconfig|' config
sed -i 's|GRUB_BTRFS_SCRIPT_CHECK=.*|GRUB_BTRFS_SCRIPT_CHECK=grub2-script-check|' config

make install

# Garantir que o serviço systemd do grub-btrfs seja copiado no ambiente chroot
if [ -f grub-btrfsd.service ]; then
    cp -fv grub-btrfsd.service /etc/systemd/system/
elif [ -f services/grub-btrfsd.service ]; then
    cp -fv services/grub-btrfsd.service /etc/systemd/system/
fi

cd /tmp && rm -rf grub-btrfs

# Ativar o daemon que detecta novos snapshots e atualiza o GRUB automaticamente
systemctl enable grub-btrfsd 2>/dev/null || true

# Gerar GRUB inicial com suporte a snapshots
grub2-mkconfig -o /boot/grub2/grub.cfg
if [ -f /boot/efi/EFI/fedora/grub.cfg ]; then
    grub2-mkconfig -o /boot/efi/EFI/fedora/grub.cfg 2>/dev/null || true
fi

# ==== Limpeza de cache ====
dnf5 clean all

# ==== Regenerar initramfs com i915, VFIO e NVIDIA ====
dracut --force --regenerate-all

EOF_CHROOT

chmod +x "$MOUNTPOINT/tmp/post_install.sh"
chroot "$MOUNTPOINT" /usr/bin/env \
    NVIDIA_GPU_ID="$NVIDIA_GPU_ID" \
    NVIDIA_AUDIO_ID="$NVIDIA_AUDIO_ID" \
    /tmp/post_install.sh
rm -f "$MOUNTPOINT/tmp/post_install.sh"

# ============================================================
# Finalização
# ============================================================
echo "✅ Instalação completa! Desmontando..."
umount -R "$MOUNTPOINT" 2>/dev/null || true

cat << 'FINAL_MSG'

🎉 ══════════════════════════════════════════════════════════
   INSTALAÇÃO CONCLUÍDA — Fedora 44 KDE Mínimo + KVM/VFIO + Snapshots
   Dual Boot: Windows 11 (150 GB) + Fedora (100 GB) + exFAT (~248 GB)
   ══════════════════════════════════════════════════════════

   ⚠️  ORDEM DE INSTALAÇÃO DUAL BOOT (IMPORTANTE):
   1. Execute este script para preparar as partições.
   2. Instale o Windows 11 PRIMEIRO (usará p3 de 150 GB).
      → O instalador Win11 sobrescreverá a EFI mas o GRUB
        do Fedora ainda estará em p4/boot. Após o Win11,
        use o live do Fedora para reinstalar o GRUB.
   3. Com o Windows instalado, rode este script novamente
      (ou apenas a partir da seção de montagem/chroot) para
      instalar o Fedora em p4.
   4. O GRUB do Fedora detecta automaticamente o Windows via
      os-prober. Instale o pacote: dnf5 install os-prober
      e adicione GRUB_DISABLE_OS_PROBER=false no /etc/default/grub,
      depois rode: grub2-mkconfig -o /boot/grub2/grub.cfg

   💾 LAYOUT FINAL DO SSD (500 GB):
      p1  EFI  (  1 GB)  FAT32   — compartilhada Windows + Fedora
      p2  Boot (  1 GB)  ext4    — /boot do Fedora
      p3  Win  (150 GB)  NTFS    — Windows 11
      p4  Fed  (100 GB)  Btrfs   — Fedora 44
      p5  Shr  (~248 GB) exFAT   — dados compartilhados

   📸 SNAPSHOTS (já funcionando!):

   - Snapshots automáticos a cada hora (timeline)
   - Snapshots automáticos antes/depois de cada dnf5 install/update
   - Snapshots visíveis no menu GRUB para rollback
   - Limpeza automática: 5 horários, 7 diários, 2 semanais, 1 mensal

   Comandos úteis:
      $ sudo snapper list                          # Ver todos os snapshots
      $ sudo snapper create -d "antes de mexer"    # Criar snapshot manual
      $ sudo snapper undochange 1..2               # Reverter mudanças entre 2 snapshots
      $ sudo btrfs-assistant                       # Interface gráfica

   🔐 SE O SECURE BOOT ESTIVER ATIVO:
   No primeiro boot vai aparecer a tela azul "MOK Management".
   Escolha "Enroll MOK" -> "Continue" -> "Yes" e digite a senha
   pedida durante a instalação. Sem isso o módulo nvidia.ko NÃO
   carrega e o boot pode travar. Alternativa: desativar Secure
   Boot na UEFI (mais simples, comum em setups de VFIO/gaming).

   📝 PASSOS PÓS-INSTALAÇÃO (após o primeiro boot):

   1. Confirmar que a NVIDIA carregou normalmente no host:
      $ lspci -nnk | grep -A3 nvidia
      $ nvidia-smi

   2. Passthrough é DINÂMICO (não fica preso no vfio-pci o tempo
      todo) — no virt-manager, ao adicionar a GPU como PCI Host
      Device na VM Windows, deixe "managed" marcado (padrão). O
      libvirt desconecta a nvidia do host e conecta no vfio-pci
      só quando a VM liga, e devolve pro host quando ela desliga.
      Assim você usa a GPU no Fedora normalmente pra codar.

   3. Instalar o Nix package manager (já nos repos do Fedora 44):
      $ sudo dnf5 install nix
      $ sudo systemctl enable --now nix-daemon

   4. Compilar o Looking Glass client:
      $ sudo dnf5 install cmake gcc gcc-c++ SDL2-devel \
        fontconfig-devel spice-protocol libX11-devel \
        nettle-devel wayland-protocols-devel libXi-devel \
        libXScrnSaver-devel libXinerama-devel \
        libXcursor-devel libXpresent-devel libxkbcommon-x11-devel \
        wayland-devel libdecor-devel pipewire-devel
      $ git clone --recursive https://github.com/gnif/LookingGlass.git
      $ cd LookingGlass && mkdir client/build && cd client/build
      $ cmake ../ && make -j$(nproc)
      $ sudo make install

   5. Na VM Windows, adicionar um dispositivo ivshmem-plain
      apontando pra /dev/shm/looking-glass (já criado no boot com
      permissões certas) e instalar o looking-glass-host.exe +
      driver IVSHMEM como serviço. Rode 'looking-glass-client' no
      Fedora pra abrir a janela com o vídeo da VM.

   6. Configurar o teclado BR/US (Wayland/KDE):
      $ localectl set-x11-keymap us,br pc105 intl,abnt2 grp:alt_shift_toggle

   7. Verificar zRAM + Swapfile:
      $ swapon --show

   8. Testar o Undervolt da CPU (reduz temperatura em ~10-20°C):
      $ sudo intel-undervolt apply
      $ sudo intel-undervolt read
      Se estável após 1h de uso pesado, ativar no boot:
      $ sudo systemctl enable --now intel-undervolt.service

   9. Instalar Podman/Distrobox (containers já tem subvolume pronto):
      $ sudo dnf5 install podman distrobox

══════════════════════════════════════════════════════════════
FINAL_MSG
