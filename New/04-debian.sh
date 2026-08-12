#!/usr/bin/env bash
#
# 04-debian.sh
# PASSO 3 (alternativo) — Instalar Debian Trixie KDE Mínimo + KVM/VFIO + Snapshots
# Acer Nitro 5 AN515-52
#
# PRÉ-REQUISITO: execute 02-mount.sh antes deste script.
# As partições devem estar montadas em /mnt.
#
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
    echo "❌ Este script precisa ser executado como root."
    exit 1
fi

MOUNTPOINT="/mnt"

if ! mountpoint -q "$MOUNTPOINT"; then
    echo "❌ $MOUNTPOINT não está montado. Execute 02-mount.sh primeiro."
    exit 1
fi

echo "⚡ PASSO 3 — Instalando Debian Trixie KDE Mínimo + KVM/VFIO..."
setenforce 0 2>/dev/null || true

# ============================================================
# Variáveis
# ============================================================
DRIVE="/dev/nvme0n1"
CODENAME="trixie"
ARCH="amd64"
HOSTNAME="nitro5"
USERNAME="juca"
MIRROR="http://debian.c3sl.ufpr.br/debian"

BTRFS_LABEL="Fedora"   # label criada pelo 01-partition.sh — não muda
EFI_LABEL="ESP"
SYSTEM_LABEL="BOOT"
MISC_LABEL="SharedData"
BTRFS_SYS="noatime,ssd,compress=zstd:3,space_cache=v2,commit=120,discard=async"
BTRFS_OPTS_HOME="noatime,ssd,compress=zstd:9,space_cache=v2,commit=120,discard=async"
BTRFS_OPTS_MAX="noatime,ssd,compress-force=zstd:15,space_cache=v2,commit=120,discard=async"
BTRFS_OPTS="noatime,ssd,compress=zstd:3,space_cache=v2,commit=60,discard=async"
BTRFS_OPTS_SWAP="noatime,ssd,nodatacow,space_cache=v2,commit=120,discard=async"

# Detecção NVIDIA
NVIDIA_GPU_ID="$(lspci -nn | grep -i 'nvidia' | grep -Ei 'vga|3d controller' | grep -oE '\[10de:[0-9a-fA-F]{4}\]' | tr -d '[]' | head -n1)"
NVIDIA_AUDIO_ID="$(lspci -nn | grep -i 'nvidia' | grep -i 'audio' | grep -oE '\[10de:[0-9a-fA-F]{4}\]' | tr -d '[]' | head -n1)"
[ -z "$NVIDIA_GPU_ID" ]   && { echo "⚠️  GPU NVIDIA não detectada. Usando fallback."; NVIDIA_GPU_ID="10de:1c8d"; }
[ -z "$NVIDIA_AUDIO_ID" ] && { echo "⚠️  Áudio NVIDIA não detectado. Usando fallback."; NVIDIA_AUDIO_ID="10de:0fb9"; }
echo "🎮 GPU NVIDIA: ${NVIDIA_GPU_ID} | Áudio: ${NVIDIA_AUDIO_ID}"

# ============================================================
# Ferramentas na ISO live (Debian live ou outro)
# ============================================================
echo "📦 Instalando ferramentas..."
apt-get update -qq
apt-get install -y debootstrap btrfs-progs gdisk arch-install-scripts

# ============================================================
# Swapfile — DESATIVADO (usando apenas zRAM 1,5× RAM)
# Descomente o bloco abaixo se quiser swap em disco também:
# ============================================================
# if [ ! -f "$MOUNTPOINT/var/swap/swapfile" ]; then
#     echo "💾 Criando swapfile de 16 GB..."
#     btrfs filesystem mkswapfile --size 16g "$MOUNTPOINT/var/swap/swapfile"
#     chmod 600 "$MOUNTPOINT/var/swap/swapfile"
# fi

# ============================================================
# debootstrap — sistema base Debian Trixie
# ============================================================
echo "📦 Instalando sistema base Debian $CODENAME via debootstrap..."
debootstrap \
    --arch="${ARCH}" \
    --variant=minbase \
    --include=apt,bash,zsh,neovim,wpasupplicant,firmware-iwlwifi,zstd,apt-utils,\
btrfs-progs,iputils-ping,dbus-broker,dbus-user-session,libpam-systemd,\
wget,curl,tzdata,ca-certificates,systemd-sysv,grub-efi-amd64,\
grub2-common,os-prober,efibootmgr,shim-signed,\
login,passwd,procps,e2fsprogs,network-manager,sudo,\
locales,console-setup,keyboard-configuration \
    "${CODENAME}" "${MOUNTPOINT}" "${MIRROR}"

# ============================================================
# /etc/fstab
# ============================================================
echo "📝 Gerando /etc/fstab..."
cat << EOF > "$MOUNTPOINT/etc/fstab"
# /etc/fstab — Debian $CODENAME | Nitro 5 AN515-52 | Dual Boot Win11+Debian

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
# Descomente para montar automaticamente:
# LABEL=${MISC_LABEL}   /mnt/shared         exfat defaults,uid=1000,gid=1000,fmask=0022,dmask=0022 0 0
EOF

# ============================================================
# Pós-instalação no chroot
# ============================================================
echo "⚙️ Executando pós-instalação no chroot..."

cat << EOF > "$MOUNTPOINT/tmp/post_debian.sh"
#!/bin/bash
set -euo pipefail
export DEBIAN_FRONTEND=noninteractive
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin:\$PATH"

mount -t efivarfs efivarfs /sys/firmware/efi/efivars 2>/dev/null || true

# ==== Repositórios APT ====
rm -f /etc/apt/sources.list
cat > /etc/apt/sources.list.d/debian.sources << 'SOURCES_EOF'
Types: deb deb-src
URIs: http://debian.c3sl.ufpr.br/debian/
Suites: trixie trixie-updates trixie-backports
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

Types: deb deb-src
URIs: http://debian.c3sl.ufpr.br/debian/
Suites: unstable
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
SOURCES_EOF

# ==== APT: sem recommends/suggests, prioridade trixie ====
mkdir -p /etc/apt/apt.conf.d /etc/apt/preferences.d

cat > /etc/apt/apt.conf.d/00local << 'APT_EOF'
APT::Install-Recommends "false";
APT::Install-Suggests "0";
APT::Get::Assume-Yes "true";
APT::Default-Release "trixie";
APT_EOF

cat > /etc/apt/preferences.d/99trixie.pref << 'PREF_EOF'
Package: *
Pin: release a=trixie
Pin-Priority: 900

Package: *
Pin: release a=unstable
Pin-Priority: 50
PREF_EOF

# Bloquear initramfs-tools (usamos dracut)
cat > /etc/apt/preferences.d/no-initramfs-tools << 'PREF_EOF'
Package: initramfs-tools initramfs-tools-core
Pin: release *
Pin-Priority: -1
PREF_EOF

apt-get update
apt-get upgrade -y

# ==== Locale e Timezone ====
echo "America/Sao_Paulo" > /etc/timezone
ln -sf /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime
dpkg-reconfigure -f noninteractive tzdata
sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen
sed -i -e 's/# pt_BR.UTF-8 UTF-8/pt_BR.UTF-8 UTF-8/' /etc/locale.gen
dpkg-reconfigure -f noninteractive locales
echo "LANG=en_US.UTF-8" > /etc/default/locale

# Teclado
cat > /etc/vconsole.conf << 'KBD_EOF'
KEYMAP="br-abnt2"
KEYMAP_TOGGLE="us-intl"
KBD_EOF

cat > /etc/X11/xorg.conf.d/00-keyboard.conf << 'XKBD_EOF'
Section "InputClass"
    Identifier "keyboard"
    MatchIsKeyboard "on"
    Option "XkbLayout" "us,br"
    Option "XkbVariant" "intl,abnt2"
    Option "XkbModel" "pc105"
    Option "XkbOptions" "grp:alt_shift_toggle"
EndSection
XKBD_EOF

# ==== Hostname ====
echo "${HOSTNAME}" > /etc/hostname
cat > /etc/hosts << 'HOSTS_EOF'
127.0.0.1   localhost
127.0.1.1   ${HOSTNAME}.localdomain ${HOSTNAME}
::1         localhost ip6-localhost ip6-loopback
HOSTS_EOF

# ==== Usuários ====
echo "root:200291" | chpasswd -c SHA512
useradd ${USERNAME} -m -c "Reinaldo P Jr" -s /bin/bash || true
echo "${USERNAME}:200291" | chpasswd -c SHA512
usermod -aG sudo,audio,video,cdrom,netdev,lp,floppy,systemd-journal,kvm,libvirt ${USERNAME}

# ==== dbus-broker (mais eficiente que dbus-daemon) ====
systemctl disable dbus-daemon.service 2>/dev/null || true
systemctl enable dbus-broker.service

# ==== Rede: remover ifupdown, usar NetworkManager ====
apt-get purge -y ifupdown 2>/dev/null || true
mkdir -p /etc/network
echo -e "auto lo\niface lo inet loopback" > /etc/network/interfaces
update-alternatives --install /usr/bin/editor editor /usr/bin/nvim 100

# ==== Pacotes de sistema ====
apt-get install -y \
    linux-image-amd64 \
    linux-headers-amd64 \
    firmware-linux \
    firmware-linux-nonfree \
    firmware-iwlwifi \
    intel-microcode \
    iucode-tool \
    btrfs-progs \
    exfatprogs \
    snapper \
    snapper-gui \
    iw wireless-regdb \
    bluez \
    ufw \
    fail2ban \
    tlp tlp-rdw \
    network-manager-gnome \
    zram-tools

# ==== zRAM (1,5× RAM = 24 GB para 16 GB de RAM, prioridade 100) ====
# PERCENT=150 = 1,5× a RAM física; headroom para VMs sem swap em disco
cat > /etc/default/zramswap << 'ZRAM_EOF'
ALGO=zstd
PERCENT=150
PRIORITY=100
ZRAM_EOF
systemctl enable zramswap 2>/dev/null || true

# ==== sysctl: tuning ====
mkdir -p /etc/sysctl.d
cat > /etc/sysctl.d/99-nitro.conf << 'SYSCTL_EOF'
vm.swappiness=10
vm.vfs_cache_pressure=50
vm.dirty_background_ratio=5
vm.dirty_ratio=20
net.ipv4.ping_group_range=0 2147483647
net.ipv4.conf.default.rp_filter=2
net.ipv4.conf.all.rp_filter=2
net.ipv6.conf.all.use_tempaddr=2
net.ipv6.conf.default.use_tempaddr=2
kernel.kptr_restrict=1
kernel.printk=4 4 1 7
vm.mmap_min_addr=65536
SYSCTL_EOF

# ==== modprobe: iwlwifi + blacklist nouveau ====
mkdir -p /etc/modprobe.d
cat > /etc/modprobe.d/iwlwifi.conf << 'IWLWIFI_EOF'
options iwlwifi enable_ini=0
options iwlwifi disable_11ac=0
options iwlwifi disable_11ax=0
IWLWIFI_EOF

cat > /etc/modprobe.d/blacklist-nouveau.conf << 'BLACKLIST_EOF'
blacklist nouveau
options nouveau modeset=0
BLACKLIST_EOF

cat > /etc/modprobe.d/kvm.conf << 'KVM_EOF'
options kvm_intel nested=1
KVM_EOF

# ==== VFIO ====
cat > /etc/modprobe.d/vfio.conf << VFIO_EOF
# IDs: ${NVIDIA_GPU_ID},${NVIDIA_AUDIO_ID}
# options vfio-pci ids=${NVIDIA_GPU_ID},${NVIDIA_AUDIO_ID}
VFIO_EOF

cat > /etc/modules-load.d/vfio.conf << 'VFIO_MODULES_EOF'
vfio
vfio_iommu_type1
vfio_pci
vfio_virqfd
VFIO_MODULES_EOF

# ==== I/O Scheduler ====
mkdir -p /etc/udev/rules.d
cat > /etc/udev/rules.d/60-iosched.rules << 'IOSCHED_EOF'
ACTION=="add|change", KERNEL=="nvme[0-9]*", ATTR{queue/scheduler}="none"
ACTION=="add|change", KERNEL=="sd[a-z]", ATTR{queue/scheduler}="bfq"
IOSCHED_EOF

# ==== Looking Glass IVSHMEM ====
mkdir -p /etc/tmpfiles.d
cat > /etc/tmpfiles.d/looking-glass.conf << 'LG_EOF'
f /dev/shm/looking-glass 0660 ${USERNAME} kvm - 32M
LG_EOF

# ==== Dracut (initramfs enxuto, substituindo initramfs-tools) ====
apt-get install -y dracut dracut-core

mkdir -p /etc/dracut.conf.d
cat > /etc/dracut.conf.d/nitro.conf << 'DRACUT_EOF'
hostonly="yes"
hostonly_cmdline="yes"
compress="zstd"
compressargs="-15"
uefi="no"
early_microcode="yes"
add_dracutmodules+=" btrfs systemd "
force_drivers+=" i915 nvme iwlwifi vfio vfio_iommu_type1 vfio_pci "
add_drivers+=" psmouse "
omit_dracutmodules+=" amdgpu brltty 90crypt "
DRACUT_EOF

# ==== GRUB ====
mkdir -p /etc/default
cat > /etc/default/grub << 'GRUB_EOF'
GRUB_TIMEOUT=5
GRUB_DEFAULT=saved
GRUB_DISTRIBUTOR="Debian"
GRUB_DISABLE_SUBMENU=true
GRUB_TERMINAL_OUTPUT="console"
GRUB_CMDLINE_LINUX_DEFAULT="quiet intel_iommu=on iommu=pt i915.enable_psr=0 i915.enable_fbc=1 i915.enable_guc=3 nvidia-drm.modeset=1 nvidia-drm.fbdev=1 nowatchdog split_lock_detect=off psi=1 i8042.nopnp usbcore.autosuspend=-1 page_alloc.shuffle=1 rcupdate.rcu_expedited=1"
GRUB_DISABLE_RECOVERY="true"
GRUB_DISABLE_OS_PROBER=false
GRUB_COLOR_NORMAL="light-blue/black"
GRUB_COLOR_HIGHLIGHT="light-cyan/blue"
GRUB_EOF

grub-install --target=x86_64-efi \
    --efi-directory=/boot/efi \
    --bootloader-id=debian \
    --recheck

update-grub

# ==== KDE Plasma mínimo ====
echo "🖥️ Instalando KDE Plasma mínimo..."
apt-get install -y \
    sddm \
    plasma-desktop \
    plasma-workspace \
    kwin-wayland \
    xwayland \
    konsole \
    dolphin \
    plasma-nm \
    plasma-pa \
    kscreen \
    bluedevil \
    kde-config-sddm \
    breeze \
    breeze-gtk-theme \
    powerdevil

# ==== KVM / Virt-Manager ====
echo "🎮 Instalando KVM/Virt-Manager..."
apt-get install -y \
    qemu-system-x86 \
    qemu-utils \
    libvirt-daemon-system \
    libvirt-clients \
    virt-manager \
    swtpm \
    ovmf \
    dnsmasq-base \
    bridge-utils

usermod -aG libvirt,kvm ${USERNAME} || true

# ==== NVIDIA driver proprietário (legacy 470/535/545 — GTX 1050 Ti) ====
echo "🎮 Instalando driver NVIDIA..."
# GTX 1050 é Pascal (GP107) — suportado pelo nvidia-driver (branch atual no Debian trixie)
apt-get install -y nvidia-driver nvidia-smi nvidia-cuda-toolkit 2>/dev/null || \
    apt-get install -y nvidia-legacy-470xx-driver 2>/dev/null || \
    echo "⚠️  Driver NVIDIA não instalado automaticamente. Instale manualmente após o boot."

# ==== Snapper ====
echo "📸 Configurando Snapper..."
mkdir -p /etc/snapper/configs
umount /.snapshots 2>/dev/null || true
btrfs subvolume delete /.snapshots 2>/dev/null || true
snapper --no-dbus -c root create-config / 2>/dev/null || true
[ ! -f /etc/snapper/configs/root ] && [ -f /etc/snapper/config-templates/default ] && \
    cp /etc/snapper/config-templates/default /etc/snapper/configs/root
btrfs subvolume delete /.snapshots 2>/dev/null || true
mkdir -p /.snapshots
mount -a 2>/dev/null || true

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
systemctl enable snapper-timeline.timer snapper-cleanup.timer

# ==== apt-btrfs-snapshot (snapshots automáticos no apt) ====
apt-get install -y apt-btrfs-snapshot 2>/dev/null || true

# ==== Ativar serviços ====
systemctl enable sddm
systemctl enable libvirtd
systemctl enable NetworkManager
systemctl enable bluetooth
systemctl enable ufw
systemctl enable fail2ban
systemctl enable tlp

# ==== Regenerar initramfs com dracut ====
dracut --force --regenerate-all

# ==== GRUB final (detecta Windows) ====
update-grub

# ==== Limpeza ====
apt-get autoremove -y
apt-get autoclean -y

EOF

chmod +x "$MOUNTPOINT/tmp/post_debian.sh"

# Substituir variáveis antes de enviar ao chroot
sed -i \
    -e "s|\${HOSTNAME}|${HOSTNAME}|g" \
    -e "s|\${USERNAME}|${USERNAME}|g" \
    -e "s|\${NVIDIA_GPU_ID}|${NVIDIA_GPU_ID}|g" \
    -e "s|\${NVIDIA_AUDIO_ID}|${NVIDIA_AUDIO_ID}|g" \
    "$MOUNTPOINT/tmp/post_debian.sh"

chroot "$MOUNTPOINT" /bin/bash /tmp/post_debian.sh
rm -f "$MOUNTPOINT/tmp/post_debian.sh"

# ============================================================
# Finalização
# ============================================================
echo "✅ Debian instalado! Desmontando..."
umount -R "$MOUNTPOINT" 2>/dev/null || true

cat << 'FINAL_MSG'

🎉 ══════════════════════════════════════════════════════════
   DEBIAN TRIXIE INSTALADO — KDE Mínimo + KVM/VFIO + Snapper
   Dual Boot: Windows 11 (150 GB) + Debian (100 GB) + exFAT (~248 GB)
   ══════════════════════════════════════════════════════════

   💾 LAYOUT DO SSD:
      p1  EFI  (  1 GB)  FAT32  — compartilhada Windows + Debian
      p2  Boot (  1 GB)  ext4   — /boot do Debian
      p3  Win  (150 GB)  NTFS   — Windows 11
      p4  Deb  (100 GB)  Btrfs  — Debian Trixie
      p5  Shr  (~248 GB) exFAT  — dados compartilhados

   📝 PÓS-INSTALAÇÃO (primeiro boot):
      $ lspci -nnk | grep -A3 nvidia   # confirmar NVIDIA
      $ nvidia-smi
      $ swapon --show                  # confirmar zRAM (deve mostrar /dev/zram0)
      $ sudo ufw enable                # ativar firewall
      # Configurar Looking Glass:
      $ systemd-tmpfiles --create /etc/tmpfiles.d/looking-glass.conf

FINAL_MSG
