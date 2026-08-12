#!/usr/bin/env bash
#
# install-fedora-minimal-kvm.sh
# Instalação ULTRA-ENXUTA: Fedora 44 KDE Mínimo + KVM/VFIO + Nix + Snapshots
#
# Hardware alvo: Acer Nitro 5 AN515-52 (UEFI-only, Intel 8th Gen + NVIDIA GTX)
# SSD: 500 GB NVMe
# RAM: 16 GB
#
# Layout de Partições:
#   p1: EFI System  (1 GB)   — FAT32
#   p2: Boot        (1 GB)   — ext4
#   p3: Btrfs Pool  (300 GB) — Btrfs (@root, @home, @nix, @libvirt, @containers, @log, @cache, @tmp, @spool, @opt, @snapshots, @swap)
#   p4: Shared Data (resto)  — exFAT
#
set -euo pipefail

echo "⚡ Iniciando instalação: Fedora 44 KDE Mínimo + KVM/VFIO + Nix..."

setenforce 0 2>/dev/null || true

# ============================================================
# Instalar ferramentas de disco na ISO Live
# ============================================================
dnf install -y gdisk arch-install-scripts exfatprogs btrfs-progs

# ============================================================
# Variáveis
# ============================================================
DRIVE="/dev/nvme0n1"

EFI_PART="${DRIVE}p1"
SYSTEM_PART="${DRIVE}p2"
BTRFS_PART="${DRIVE}p3"
MISC_PART="${DRIVE}p4"

MOUNTPOINT="/mnt"
BTRFS_LABEL="Fedora"
EFI_LABEL="ESP"
SYSTEM_LABEL="BOOT"
MISC_LABEL="SharedData"

# Opções Btrfs otimizadas para SSD NVMe
BTRFS_OPTS="noatime,ssd,compress=zstd:1,space_cache=v2,commit=120,discard=async"

# ============================================================
# IDs da GPU NVIDIA para VFIO Passthrough
# Execute 'lspci -nn | grep -i nvidia' para descobrir os IDs reais.
# Formato: "VÍDEO_ID,ÁUDIO_ID" (ex: "10de:1c8c,10de:0fb0")
# ============================================================
NVIDIA_GPU_ID="10de:XXXX"
NVIDIA_AUDIO_ID="10de:YYYY"

# ============================================================
# Particionamento (UEFI-only — sem BIOS Boot)
# ============================================================
echo "🧹 Particionando $DRIVE..."
sgdisk --zap-all "$DRIVE"
parted -s -a optimal "$DRIVE" mklabel gpt

# p1: EFI (1GB), p2: Boot (1GB), p3: Btrfs Pool (350GB), p4: exFAT (resto)
sgdisk -n 1:0:+1G      -t 1:EF00 -c 1:"EFI SYSTEM"          "$DRIVE"
sgdisk -n 2:0:+1G      -t 2:8301 -c 2:"SYSTEM RESERVED"     "$DRIVE"
sgdisk -n 3:0:+300G    -t 3:8300 -c 3:"Fedora Btrfs Pool"   "$DRIVE"
sgdisk -n 4:0:0        -t 4:0700 -c 4:"Shared exFAT Data"   "$DRIVE"
sgdisk -p "$DRIVE"

# ============================================================
# Formatação
# ============================================================
echo "🧼 Formatando partições..."
mkfs.fat  -F32 -n "$EFI_LABEL"    "$EFI_PART"
mkfs.ext4 -F   -L "$SYSTEM_LABEL" "$SYSTEM_PART"
mkfs.btrfs -f  -L "$BTRFS_LABEL"  "$BTRFS_PART"
mkfs.exfat     -n "$MISC_LABEL"   "$MISC_PART"

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
mount -o "$BTRFS_OPTS,subvol=@root" "$BTRFS_PART" "$MOUNTPOINT"

# Criar estrutura de diretórios
mkdir -pv "$MOUNTPOINT"/{boot/efi,home,nix,opt,.snapshots,var/{tmp,spool,log,cache,swap,lib/{libvirt,containers}}}

# Montar todos os subvolumes
mount -o "$BTRFS_OPTS,subvol=@home"      "$BTRFS_PART" "$MOUNTPOINT/home"
mount -o "$BTRFS_OPTS,subvol=@nix"       "$BTRFS_PART" "$MOUNTPOINT/nix"
mount -o "$BTRFS_OPTS,subvol=@opt"       "$BTRFS_PART" "$MOUNTPOINT/opt"
mount -o "$BTRFS_OPTS,subvol=@log"       "$BTRFS_PART" "$MOUNTPOINT/var/log"
mount -o "$BTRFS_OPTS,subvol=@spool"     "$BTRFS_PART" "$MOUNTPOINT/var/spool"
mount -o "$BTRFS_OPTS,subvol=@tmp"       "$BTRFS_PART" "$MOUNTPOINT/var/tmp"
mount -o "$BTRFS_OPTS,subvol=@cache"     "$BTRFS_PART" "$MOUNTPOINT/var/cache"
mount -o "$BTRFS_OPTS,subvol=@snapshots" "$BTRFS_PART" "$MOUNTPOINT/.snapshots"
mount -o "$BTRFS_OPTS,subvol=@swap"      "$BTRFS_PART" "$MOUNTPOINT/var/swap"

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

# ============================================================
# Bind-mounts para chroot
# ============================================================
echo "🔧 Montando pseudo-filesystems..."
for dir in dev proc sys run; do
    mkdir -pv "$MOUNTPOINT/$dir"
    mount --bind "/$dir" "$MOUNTPOINT/$dir"
done

# ============================================================
# Instalar sistema base
# ============================================================
source /etc/os-release
VERSION_ID="${VERSION_ID:-44}"
echo "📦 Instalando Fedora $VERSION_ID..."

dnf --installroot="$MOUNTPOINT" --releasever="$VERSION_ID" --forcearch=x86_64 \
    --setopt=fastestmirror=True --setopt=install_weak_deps=False \
    group install "Core" --use-host-config -y --skip-unavailable

dnf --installroot="$MOUNTPOINT" --setopt=install_weak_deps=False install -y \
    glibc-langpack-pt glibc-langpack-en \
    btrfs-progs \
    efi-filesystem efibootmgr \
    grub2-common grub2-efi-x64 grub2-tools grub2-tools-efi \
    kernel shim-x64

# Copiar DNS
cp -L /etc/resolv.conf "$MOUNTPOINT/etc/resolv.conf"

# ============================================================
# Gerar /etc/fstab
# ============================================================
echo "📝 Gerando /etc/fstab..."
cat << EOF > "$MOUNTPOINT/etc/fstab"
# /etc/fstab — Gerado automaticamente pelo script de instalação
# Fedora $VERSION_ID — Acer Nitro 5 AN515-52

# === Btrfs Pool Único (350 GB) ===
LABEL=${BTRFS_LABEL}    /                   btrfs rw,${BTRFS_OPTS},subvol=@root                   0 0
LABEL=${BTRFS_LABEL}    /home               btrfs rw,${BTRFS_OPTS},subvol=@home                   0 0
LABEL=${BTRFS_LABEL}    /nix                btrfs rw,${BTRFS_OPTS},subvol=@nix                    0 0
LABEL=${BTRFS_LABEL}    /.snapshots         btrfs rw,${BTRFS_OPTS},subvol=@snapshots              0 0
LABEL=${BTRFS_LABEL}    /var/log            btrfs rw,${BTRFS_OPTS},subvol=@log                    0 0
LABEL=${BTRFS_LABEL}    /var/tmp            btrfs rw,${BTRFS_OPTS},subvol=@tmp                    0 0
LABEL=${BTRFS_LABEL}    /var/spool          btrfs rw,${BTRFS_OPTS},subvol=@spool                  0 0
LABEL=${BTRFS_LABEL}    /var/cache          btrfs rw,${BTRFS_OPTS},subvol=@cache                  0 0
LABEL=${BTRFS_LABEL}    /var/lib/libvirt    btrfs rw,${BTRFS_OPTS},subvol=@libvirt                0 0
LABEL=${BTRFS_LABEL}    /var/lib/containers btrfs rw,${BTRFS_OPTS},subvol=@containers             0 0
LABEL=${BTRFS_LABEL}    /opt                btrfs rw,${BTRFS_OPTS},subvol=@opt                    0 0

# === Boot e EFI ===
LABEL=${SYSTEM_LABEL}   /boot               ext4  rw,relatime                                     0 1
LABEL=${EFI_LABEL}      /boot/efi           vfat  defaults,noatime,nodiratime                      0 2

# === Swap (Prioridade 10, abaixo do zRAM que opera em 100) ===
/var/swap/swapfile      none                swap  defaults,pri=10                                  0 0

# === Tmpfs ===
tmpfs                   /tmp                tmpfs noatime,mode=1777,nosuid,nodev                  0 0
EOF

# ============================================================
# Pós-instalação dentro do Chroot
# ============================================================
echo "⚙️ Executando pós-instalação no chroot..."

cat << 'EOF_CHROOT' > "$MOUNTPOINT/tmp/post_install.sh"
#!/bin/bash
set -euo pipefail

mount -t efivarfs efivarfs /sys/firmware/efi/efivars 2>/dev/null || true

# ==== GRUB (UEFI-only, sem BIOS) ====
cat << 'GRUB_EOF' > /etc/default/grub
GRUB_TIMEOUT=3
GRUB_DISTRIBUTOR="Fedora"
GRUB_DEFAULT=saved
GRUB_DISABLE_SUBMENU=true
GRUB_TERMINAL_OUTPUT="console"
GRUB_CMDLINE_LINUX="rhgb quiet intel_iommu=on iommu=pt nvidia-drm.modeset=1 i915.modeset=1 nowatchdog split_lock_detect=off"
GRUB_DISABLE_RECOVERY="true"
GRUB_ENABLE_BLSCFG=true
GRUB_EOF

grub2-mkconfig -o /boot/grub2/grub.cfg

# Criar entrada EFI no firmware
efibootmgr -c -d /dev/nvme0n1 -p 1 -L "Fedora" -l "\\EFI\\fedora\\shimx64.efi" 2>/dev/null || true

# ==== Usuários ====
echo "root:200291" | chpasswd
useradd juca -m -c "Reinaldo P JR" -s /bin/bash || true
echo "juca:200291" | chpasswd
usermod -aG wheel,libvirt juca

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

# ==== VFIO: Preparação para GPU Passthrough ====
# IMPORTANTE: Substitua os IDs abaixo pelos valores reais da sua GPU NVIDIA.
# Execute no sistema instalado: lspci -nn | grep -i nvidia
# Exemplo: options vfio-pci ids=10de:1c8c,10de:0fb0
cat << 'VFIO_CONF_EOF' > /etc/modprobe.d/vfio.conf
# Descomente e substitua com os IDs reais da GPU NVIDIA:
# options vfio-pci ids=10de:XXXX,10de:YYYY
VFIO_CONF_EOF

# Blacklist do nouveau (conflita com NVIDIA proprietário e VFIO)
cat << 'BLACKLIST_EOF' > /etc/modprobe.d/blacklist-nouveau.conf
blacklist nouveau
options nouveau modeset=0
BLACKLIST_EOF

# Garantir que os módulos VFIO carreguem no initramfs
mkdir -p /etc/dracut.conf.d
cat << 'DRACUT_VFIO_EOF' > /etc/dracut.conf.d/vfio.conf
add_drivers+=" vfio vfio_iommu_type1 vfio_pci "
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

# ==== KDE Plasma MÍNIMO ====
echo "🖥️ Instalando KDE Plasma mínimo..."
dnf5 install -y --setopt=install_weak_deps=False \
    sddm \
    plasma-desktop \
    konsole \
    dolphin \
    plasma-nm \
    plasma-pa \
    kwin-wayland \
    kscreen \
    NetworkManager \
    intel-undervolt

# ==== Snapper + Btrfs-Assistant (Snapshots) ====
echo "📸 Instalando Snapper e Btrfs-Assistant..."
dnf5 install -y --setopt=install_weak_deps=False \
    snapper \
    btrfs-assistant \
    libdnf5-plugin-actions \
    inotify-tools \
    make git

# ==== KVM / Virt-Manager ====
echo "🎮 Instalando componentes de virtualização..."
dnf5 install -y --setopt=install_weak_deps=False \
    qemu-kvm \
    libvirt \
    virt-manager \
    swtpm \
    edk2-ovmf \
    dnsmasq

# ==== Ativar serviços ====
systemctl enable sddm
systemctl enable libvirtd
systemctl enable NetworkManager

# NÃO ativar intel-undervolt no boot até testar manualmente!
# Após testar: sudo systemctl enable intel-undervolt.service

# ==== RPM Fusion + Drivers NVIDIA ====
echo "🎮 Instalando drivers NVIDIA..."
dnf5 install -y \
    "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
    "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"
dnf5 makecache
dnf5 install -y akmod-nvidia xorg-x11-drv-nvidia-cuda

# ==== SELinux Relabeling no próximo boot ====
fixfiles -F onboot

# ==== Configurar Snapper para snapshots do Root ====
echo "📸 Configurando Snapper..."

# Remover o subvolume .snapshots criado automaticamente pelo snapper
# (já temos o nosso próprio @snapshots montado em /.snapshots)
umount /.snapshots 2>/dev/null || true
snapper -c root create-config / 2>/dev/null || true

# Snapper cria um subvolume em /.snapshots que conflita com o nosso @snapshots
# Deletar o subvolume do snapper e remontar o nosso
btrfs subvolume delete /.snapshots 2>/dev/null || true
mkdir -p /.snapshots
mount -a

# Política de limpeza automática de snapshots
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

# Configurar para o Fedora (caminho do GRUB diferente do Arch/Ubuntu)
sed -i 's|GRUB_BTRFS_GRUB_DIRNAME=.*|GRUB_BTRFS_GRUB_DIRNAME="/boot/grub2"|' config
sed -i 's|GRUB_BTRFS_MKCONFIG=.*|GRUB_BTRFS_MKCONFIG=/sbin/grub2-mkconfig|' config
sed -i 's|GRUB_BTRFS_SCRIPT_CHECK=.*|GRUB_BTRFS_SCRIPT_CHECK=grub2-script-check|' config

make install
cd /tmp && rm -rf grub-btrfs

# Ativar o daemon que detecta novos snapshots e atualiza o GRUB automaticamente
systemctl enable grub-btrfsd

# Gerar GRUB inicial com suporte a snapshots
grub2-mkconfig -o /boot/grub2/grub.cfg

# ==== Limpeza de cache ====
dnf5 clean all

# ==== Regenerar initramfs com VFIO e NVIDIA ====
dracut --force --regenerate-all

EOF_CHROOT

chmod +x "$MOUNTPOINT/tmp/post_install.sh"
chroot "$MOUNTPOINT" /tmp/post_install.sh
rm -f "$MOUNTPOINT/tmp/post_install.sh"

# ============================================================
# Finalização
# ============================================================
echo "✅ Instalação completa! Desmontando..."
umount -R "$MOUNTPOINT" 2>/dev/null || true

cat << 'FINAL_MSG'

🎉 ══════════════════════════════════════════════════════════
   INSTALAÇÃO CONCLUÍDA — Fedora 44 KDE Mínimo + KVM/VFIO + Snapshots
   ══════════════════════════════════════════════════════════

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

   📝 PASSOS PÓS-INSTALAÇÃO (após o primeiro boot):

   1. Descobrir os IDs da GPU NVIDIA:
      $ lspci -nn | grep -i nvidia

   2. Editar /etc/modprobe.d/vfio.conf com os IDs reais:
      $ sudo nano /etc/modprobe.d/vfio.conf
      Descomente e substitua: options vfio-pci ids=10de:XXXX,10de:YYYY

   3. Regenerar o initramfs:
      $ sudo dracut --force --regenerate-all

   4. Reiniciar e verificar que VFIO carregou:
      $ lspci -nnk | grep -A3 nvidia

   5. Instalar o Nix package manager (já nos repos do Fedora 44):
      $ sudo dnf5 install nix
      $ sudo systemctl enable --now nix-daemon

   6. Compilar o Looking Glass client:
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

   7. Configurar o teclado BR/US (Wayland/KDE):
      $ localectl set-x11-keymap us,br pc105 intl,abnt2 grp:alt_shift_toggle

   8. Verificar zRAM + Swapfile:
      $ swapon --show

   9. Testar o Undervolt da CPU (reduz temperatura em ~10-20°C):
      $ sudo intel-undervolt apply
      $ sudo intel-undervolt read
      Se estável após 1h de uso pesado, ativar no boot:
      $ sudo systemctl enable --now intel-undervolt.service

  10. Instalar Podman/Distrobox (containers já tem subvolume pronto):
      $ sudo dnf5 install podman distrobox

══════════════════════════════════════════════════════════════
FINAL_MSG