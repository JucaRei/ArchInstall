#!/usr/bin/env bash
#
# 03-fedora.sh
# PASSO 3 — Instalar Fedora 44 KDE Mínimo + KVM/VFIO + Nix + Snapshots
# Acer Nitro 5 AN515-52
#
# PRÉ-REQUISITO: execute 02-mount.sh antes deste script.
#
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "❌ Este script precisa ser executado como root."
    exit 1
fi

MOUNTPOINT="/mnt"

# Verificar se as partições estão montadas
if ! mountpoint -q "$MOUNTPOINT"; then
    echo "❌ $MOUNTPOINT não está montado. Execute 02-mount.sh primeiro."
    exit 1
fi

echo "⚡ PASSO 3 — Instalando Fedora 44 KDE Mínimo + KVM/VFIO + Nix..."
setenforce 0 2>/dev/null || true

# ============================================================
# Instalar ferramentas na ISO Live
# ============================================================
dnf install -y arch-install-scripts btrfs-progs

# ============================================================
# Detecção da GPU NVIDIA para VFIO Passthrough
# ============================================================
NVIDIA_GPU_ID="$(lspci -nn | grep -i 'nvidia' | grep -Ei 'vga|3d controller' | grep -oE '\[10de:[0-9a-fA-F]{4}\]' | tr -d '[]' | head -n1)"
NVIDIA_AUDIO_ID="$(lspci -nn | grep -i 'nvidia' | grep -i 'audio' | grep -oE '\[10de:[0-9a-fA-F]{4}\]' | tr -d '[]' | head -n1)"

[ -z "$NVIDIA_GPU_ID" ]   && { echo "⚠️  GPU NVIDIA não detectada. Usando fallback."; NVIDIA_GPU_ID="10de:1c8d"; }
[ -z "$NVIDIA_AUDIO_ID" ] && { echo "⚠️  Áudio NVIDIA não detectado. Usando fallback."; NVIDIA_AUDIO_ID="10de:0fb9"; }
echo "🎮 GPU NVIDIA: ${NVIDIA_GPU_ID} | Áudio: ${NVIDIA_AUDIO_ID}"

# ============================================================
# Variáveis Btrfs (devem bater com 02-mount.sh)
# ============================================================
BTRFS_LABEL="Fedora"
EFI_LABEL="ESP"
SYSTEM_LABEL="BOOT"
MISC_LABEL="SharedData"
BTRFS_SYS="noatime,ssd,compress=zstd:3,space_cache=v2,commit=120,discard=async"
BTRFS_OPTS_HOME="noatime,ssd,compress=zstd:9,space_cache=v2,commit=120,discard=async"
BTRFS_OPTS_MAX="noatime,ssd,compress-force=zstd:15,space_cache=v2,commit=120,discard=async"
BTRFS_OPTS="noatime,ssd,compress=zstd:3,space_cache=v2,commit=60,discard=async"
BTRFS_OPTS_SWAP="noatime,ssd,nodatacow,space_cache=v2,commit=120,discard=async"

# ============================================================
# Swapfile — DESATIVADO (usando apenas zRAM 1,5× RAM)
# Descomente o bloco abaixo se quiser swap em disco também:
# ============================================================
# if [ ! -f "$MOUNTPOINT/var/swap/swapfile" ]; then
#     echo "💾 Criando Swapfile de 16 GB..."
#     btrfs filesystem mkswapfile --size 16g "$MOUNTPOINT/var/swap/swapfile"
#     chmod 600 "$MOUNTPOINT/var/swap/swapfile"
# fi

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

# Garantir resolv.conf independente do host
umount "$MOUNTPOINT/etc/resolv.conf" 2>/dev/null || true
rm -f "$MOUNTPOINT/etc/resolv.conf"
cp -L /etc/resolv.conf "$MOUNTPOINT/etc/resolv.conf"

# ============================================================
# Gerar /etc/fstab
# ============================================================
echo "📝 Gerando /etc/fstab..."
cat << EOF > "$MOUNTPOINT/etc/fstab"
# /etc/fstab — Fedora $VERSION_ID | Nitro 5 AN515-52 | Dual Boot Win11+Fedora

# === Btrfs Pool (100 GB — p4) ===
LABEL=${BTRFS_LABEL}    /                   btrfs rw,${BTRFS_SYS},subvol=@root                    0 0
LABEL=${BTRFS_LABEL}    /home               btrfs rw,${BTRFS_OPTS_HOME},subvol=@home              0 0
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
LABEL=${EFI_LABEL}      /boot/efi           vfat  defaults,noatime,nodiratime,umask=0077          0 2

# === Swap em disco — desativado; usando apenas zRAM (1,5× RAM) ===
# /var/swap/swapfile    none                swap  defaults,pri=10                                 0 0

# === Tmpfs ===
tmpfs                   /tmp                tmpfs noatime,mode=1777,nosuid,nodev                  0 0

# === Dados Compartilhados exFAT — p5 (~248 GB) ===
# Descomente para montar automaticamente no boot:
# LABEL=${MISC_LABEL}   /mnt/shared         exfat defaults,uid=1000,gid=1000,fmask=0022,dmask=0022 0 0
EOF

# ============================================================
# Script de pós-instalação no chroot
# ============================================================
echo "⚙️ Preparando pós-instalação no chroot..."

cat << 'EOF_CHROOT' > "$MOUNTPOINT/tmp/post_install.sh"
#!/bin/bash
set -euo pipefail
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:$PATH"

mount -t efivarfs efivarfs /sys/firmware/efi/efivars 2>/dev/null || true

# ==== GRUB ====
mkdir -p /etc/default /etc/grub.d

cat << 'GRUB_EOF' > /etc/default/grub
GRUB_TIMEOUT=5
GRUB_DISTRIBUTOR="Fedora"
GRUB_DEFAULT=saved
GRUB_DISABLE_SUBMENU=true
GRUB_TERMINAL_OUTPUT="console"
# Aplica apenas ao boot normal (não ao recovery)
GRUB_CMDLINE_LINUX_DEFAULT="rhgb quiet intel_iommu=on iommu=pt i915.enable_psr=0 i915.enable_fbc=1 i915.enable_guc=3 nvidia-drm.modeset=1 nvidia-drm.fbdev=1 msr.allow_writes=on nowatchdog split_lock_detect=off psi=1 i8042.nopnp usbcore.autosuspend=-1 page_alloc.shuffle=1 rcupdate.rcu_expedited=1"
GRUB_DISABLE_RECOVERY="true"
GRUB_ENABLE_BLSCFG=true
# Detectar Windows no menu GRUB (dual-boot)
GRUB_DISABLE_OS_PROBER=false
# Cores do menu
GRUB_COLOR_NORMAL="light-blue/black"
GRUB_COLOR_HIGHLIGHT="light-cyan/blue"
GRUB_EOF

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

# Limpar entradas antigas do Fedora no NVRAM
for bootnum in $(efibootmgr | grep -i "Fedora" | awk '{print $1}' | sed 's/Boot//;s/\*//'); do
    efibootmgr -b "$bootnum" -B 2>/dev/null || true
done

efibootmgr -c -d /dev/nvme0n1 -p 1 -L "Fedora" -l "\\EFI\\fedora\\shimx64.efi" 2>/dev/null || true

# ==== Usuários ====
echo "root:200291" | chpasswd
useradd juca -m -c "Reinaldo P JR" -s /bin/bash || true
echo "juca:200291" | chpasswd
usermod -aG wheel,libvirt,kvm juca

# ==== Timezone, Hostname e Teclado ====
ln -sf /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime
echo "nitro5" > /etc/hostname
cat << 'HOSTS_EOF' > /etc/hosts
127.0.0.1   localhost
::1         localhost
127.0.1.1   nitro5.localdomain nitro5
HOSTS_EOF

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

# ==== zRAM (1,5× RAM = 24 GB para 16 GB de RAM, prioridade 100) ====
# 1,5× garante headroom para workloads de VM/compilação sem swap em disco
mkdir -p /etc/systemd
cat << 'ZRAM_EOF' > /etc/systemd/zram-generator.conf
[zram0]
zram-size = ram * 1.5
compression-algorithm = zstd
swap-priority = 100
ZRAM_EOF

# ==== KVM: Nested Virtualization ====
mkdir -p /etc/modprobe.d
cat << 'KVM_EOF' > /etc/modprobe.d/kvm.conf
options kvm_intel nested=1
KVM_EOF

# ==== VFIO: GPU Passthrough Dinâmico ====
cat << VFIO_CONF_EOF > /etc/modprobe.d/vfio.conf
# IDs: ${NVIDIA_GPU_ID},${NVIDIA_AUDIO_ID}
# Descomente SOMENTE para prender a GPU no vfio-pci desde o boot (não recomendado):
# options vfio-pci ids=${NVIDIA_GPU_ID},${NVIDIA_AUDIO_ID}
VFIO_CONF_EOF

cat << 'VFIO_MODULES_EOF' > /etc/modules-load.d/vfio.conf
vfio
vfio_iommu_type1
vfio_pci
vfio_virqfd
VFIO_MODULES_EOF

# ==== Looking Glass: IVSHMEM ====
mkdir -p /etc/tmpfiles.d
cat << 'LG_TMPFILES_EOF' > /etc/tmpfiles.d/10-looking-glass.conf
f /dev/shm/looking-glass 0660 juca libvirt-qemu - 32M
LG_TMPFILES_EOF

# ==== Blacklist nouveau ====
cat << 'BLACKLIST_EOF' > /etc/modprobe.d/blacklist-nouveau.conf
blacklist nouveau
options nouveau modeset=0
BLACKLIST_EOF

# ==== Dracut: initramfs enxuto + i915 + VFIO ====
mkdir -p /etc/dracut.conf.d
cat << 'DRACUT_EOF' > /etc/dracut.conf.d/nitro.conf
# hostonly=yes: initramfs enxuto (~40 MB vs ~100 MB)
hostonly="yes"
hostonly_cmdline="yes"
# i915 cedo (Wayland/KMS) + módulos VFIO disponíveis no boot
force_drivers+=" i915 vfio vfio_iommu_type1 vfio_pci "
omit_dracutmodules+=" brltty "
DRACUT_EOF

# ==== I/O Scheduler ====
mkdir -p /etc/udev/rules.d
cat << 'IOSCHED_EOF' > /etc/udev/rules.d/60-iosched.rules
ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/scheduler}="none"
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/scheduler}="bfq"
IOSCHED_EOF

# ==== Intel Undervolt ====
cat << 'UNDERVOLT_EOF' > /etc/intel-undervolt.conf
undervolt 0 'CPU' -80
undervolt 1 'GPU' -50
undervolt 2 'CPU Cache' -80
undervolt 3 'System Agent' 0
undervolt 4 'Analog I/O' 0
power package 45 28 60 0.00244
UNDERVOLT_EOF

# ==== SDDM: forçar Intel para Wayland/Optimus ====
mkdir -p /etc/systemd/system/sddm.service.d
cat << 'SDDM_GPU_EOF' > /etc/systemd/system/sddm.service.d/10-intel-gpu.conf
[Service]
Environment=KWIN_DRM_DEVICES=/dev/dri/by-path/pci-0000:00:02.0-card
SDDM_GPU_EOF

# ==== KDE Plasma mínimo + Wi-Fi + Bluetooth + Firewall + TLP ====
echo "🖥️ Instalando KDE Plasma mínimo..."
dnf5 install -y \
    zram-generator \
    sddm \
    plasma-desktop plasma-workspace \
    kwin-wayland xorg-x11-server-Xwayland \
    konsole dolphin \
    plasma-nm plasma-pa kscreen \
    NetworkManager NetworkManager-wifi \
    wpa_supplicant iwlwifi-mvm-firmware iw wireless-regdb \
    bluez \
    intel-undervolt \
    firewalld fail2ban tlp \
    nix

# ==== Configuração do Nix ====
echo "❄️ Configurando Nix..."
usermod -aG nixbld juca
mkdir -p /etc/nix
cat << 'NIX_CONF_EOF' > /etc/nix/nix.conf
build-users-group = nixbld
trusted-users = root juca @nixbld
allowed-users = *
experimental-features = nix-command flakes
NIX_CONF_EOF

cat << 'NIX_PROFILE_EOF' > /etc/profile.d/nix-env.sh
export NIX_REMOTE=daemon
export NIX_PATH=$HOME/.nix-defexpr/channels:nixpkgs=$HOME/.nix-defexpr/channels/nixpkgs
NIX_PROFILE_EOF
chmod +x /etc/profile.d/nix-env.sh

# ==== Snapper + Btrfs-Assistant ====
echo "📸 Instalando Snapper..."
dnf5 install -y snapper btrfs-assistant libdnf5-plugin-actions inotify-tools make git

# ==== KVM / Virt-Manager ====
echo "🎮 Instalando KVM/Virt-Manager..."
dnf5 install -y qemu-kvm libvirt virt-manager swtpm edk2-ovmf dnsmasq
usermod -aG libvirt juca || true

# ==== Ativar serviços ====
systemctl enable sddm
systemctl enable libvirtd
systemctl enable NetworkManager
systemctl enable bluetooth
systemctl enable firewalld
systemctl enable fail2ban
systemctl enable tlp
systemctl enable nix-daemon.service

# ==== RPM Fusion + NVIDIA 580xx ====
echo "🎮 Instalando RPM Fusion e drivers NVIDIA..."
dnf5 install -y \
    "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
    "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"
dnf5 config-manager setopt fedora-cisco-openh264.enabled=1 2>/dev/null || true
dnf5 makecache

RUNNING_KERNEL="$(rpm -q kernel --qf '%{VERSION}-%{RELEASE}.%{ARCH}\n' | sort -V | tail -n1)"
echo "🔎 Kernel: ${RUNNING_KERNEL}"

dnf5 install -y akmod-nvidia-580xx xorg-x11-drv-nvidia-580xx-cuda akmods mokutil \
    "kernel-devel-${RUNNING_KERNEL}"

echo "🔨 Compilando módulo NVIDIA 580xx..."
akmods --force --kernels "${RUNNING_KERNEL}"

if ! modinfo -k "${RUNNING_KERNEL}" nvidia >/dev/null 2>&1; then
    echo "❌ ERRO: módulo NVIDIA não compilou. Verifique kernel-devel-${RUNNING_KERNEL}."
    exit 1
fi
echo "✅ Módulo NVIDIA compilado com sucesso para ${RUNNING_KERNEL}."
systemctl enable akmods.service 2>/dev/null || true

# Secure Boot
SECURE_BOOT_STATE="$(mokutil --sb-state 2>/dev/null || echo 'desconhecido')"
echo "🔐 Secure Boot: ${SECURE_BOOT_STATE}"
if echo "$SECURE_BOOT_STATE" | grep -qi "enabled"; then
    echo "⚠️  Secure Boot ativo — gerando chave MOK..."
    akmods-keygen 2>/dev/null || true
fi

# ==== SELinux: Looking Glass ====
mkdir -p /etc/tmpfiles.d
systemd-tmpfiles --create /etc/tmpfiles.d/10-looking-glass.conf 2>/dev/null || true
semanage fcontext -a -t svirt_tmpfs_t /dev/shm/looking-glass 2>/dev/null || true
restorecon -v /dev/shm/looking-glass 2>/dev/null || true
fixfiles -F onboot

# ==== Snapper: config do root ====
echo "📸 Configurando Snapper..."
mkdir -p /etc/snapper/configs
umount /.snapshots 2>/dev/null || true
btrfs subvolume delete /.snapshots 2>/dev/null || true
snapper --no-dbus -c root create-config / 2>/dev/null || true
if [ ! -f /etc/snapper/configs/root ] && [ -f /etc/snapper/config-templates/default ]; then
    cp /etc/snapper/config-templates/default /etc/snapper/configs/root
fi
btrfs subvolume delete /.snapshots 2>/dev/null || true
mkdir -p /.snapshots
mount -a 2>/dev/null || true
[ -f /etc/sysconfig/snapper ] && sed -i 's/^SNAPPER_CONFIGS=.*/SNAPPER_CONFIGS="root"/' /etc/sysconfig/snapper

if [ -f /etc/snapper/configs/root ]; then
    sed -i \
        -e 's/^TIMELINE_CREATE=.*/TIMELINE_CREATE="yes"/' \
        -e 's/^TIMELINE_CLEANUP=.*/TIMELINE_CLEANUP="yes"/' \
        -e 's/^TIMELINE_LIMIT_HOURLY=.*/TIMELINE_LIMIT_HOURLY="5"/' \
        -e 's/^TIMELINE_LIMIT_DAILY=.*/TIMELINE_LIMIT_DAILY="7"/' \
        -e 's/^TIMELINE_LIMIT_WEEKLY=.*/TIMELINE_LIMIT_WEEKLY="2"/' \
        -e 's/^TIMELINE_LIMIT_MONTHLY=.*/TIMELINE_LIMIT_MONTHLY="1"/' \
        -e 's/^TIMELINE_LIMIT_YEARLY=.*/TIMELINE_LIMIT_YEARLY="0"/' \
        -e 's/^NUMBER_CLEANUP=.*/NUMBER_CLEANUP="yes"/' \
        -e 's/^NUMBER_LIMIT=.*/NUMBER_LIMIT="5"/' \
        /etc/snapper/configs/root
fi

systemctl enable snapper-timeline.timer
systemctl enable snapper-cleanup.timer

# ==== Snapshots automáticos DNF5 ====
mkdir -p /etc/dnf/libdnf5-plugins/actions.d
cat << 'DNF5_SNAP_EOF' > /etc/dnf/libdnf5-plugins/actions.d/snapper.actions
pre_transaction::::/usr/bin/sh -c echo "tmp.cmd=$(ps -o command --no-headers -p '${pid}')"
pre_transaction::::/usr/bin/sh -c echo "tmp.snapper_pre_number=$(snapper create -t pre -p -d '${tmp.cmd}')"
post_transaction::::/usr/bin/sh -c [ -n "${tmp.snapper_pre_number}" ] && snapper create -t post -p --pre-number "${tmp.snapper_pre_number}" -d "${tmp.cmd}"
DNF5_SNAP_EOF

# ==== grub-btrfs (snapshots no menu GRUB) ====
echo "🔧 Instalando grub-btrfs..."
cd /tmp
git clone https://github.com/Antynea/grub-btrfs.git
cd grub-btrfs
ln -sf /boot/grub2 /boot/grub 2>/dev/null || true
sed -i \
    -e 's|GRUB_BTRFS_GRUB_DIRNAME=.*|GRUB_BTRFS_GRUB_DIRNAME="/boot/grub2"|' \
    -e 's|GRUB_BTRFS_MKCONFIG=.*|GRUB_BTRFS_MKCONFIG=/sbin/grub2-mkconfig|' \
    -e 's|GRUB_BTRFS_SCRIPT_CHECK=.*|GRUB_BTRFS_SCRIPT_CHECK=grub2-script-check|' \
    config
make install
[ -f grub-btrfsd.service ] && cp -fv grub-btrfsd.service /etc/systemd/system/ \
    || { [ -f services/grub-btrfsd.service ] && cp -fv services/grub-btrfsd.service /etc/systemd/system/; }
cd /tmp && rm -rf grub-btrfs
systemctl enable grub-btrfsd 2>/dev/null || true

# ==== Gerar GRUB final ====
grub2-mkconfig -o /boot/grub2/grub.cfg
[ -f /boot/efi/EFI/fedora/grub.cfg ] && \
    grub2-mkconfig -o /boot/efi/EFI/fedora/grub.cfg 2>/dev/null || true

# ==== Limpeza e initramfs ====
dnf5 clean all
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
   FEDORA 44 INSTALADO — KDE Mínimo + KVM/VFIO + Snapshots
   Dual Boot: Windows 11 (150 GB) + Fedora (100 GB) + exFAT (~248 GB)
   ══════════════════════════════════════════════════════════

   💾 LAYOUT FINAL DO SSD:
      p1  EFI  (  1 GB)  FAT32  — compartilhada Windows + Fedora
      p2  Boot (  1 GB)  ext4   — /boot do Fedora
      p3  Win  (150 GB)  NTFS   — Windows 11
      p4  Fed  (100 GB)  Btrfs  — Fedora 44
      p5  Shr  (~248 GB) exFAT  — dados compartilhados

   🔐 SE O SECURE BOOT ESTIVER ATIVO:
      No primeiro boot aparecerá a tela azul "MOK Management".
      Escolha "Enroll MOK" → "Continue" → "Yes" e digite a senha.
      Sem isso o nvidia.ko NÃO carrega. Alternativa: desativar Secure Boot.

   📝 PÓS-INSTALAÇÃO (primeiro boot):
      $ lspci -nnk | grep -A3 nvidia   # confirmar NVIDIA
      $ nvidia-smi
      $ swapon --show                  # confirmar zRAM (deve mostrar /dev/zram0)
      $ sudo intel-undervolt apply     # testar undervolt
      # Se estável: sudo systemctl enable --now intel-undervolt.service

FINAL_MSG
