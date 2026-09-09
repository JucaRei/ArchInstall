#!/usr/bin/env bash
#
# 02-mount.sh
# PASSO 2 — Montar partições Btrfs do Fedora para chroot / instalação
# Acer Nitro 5 AN515-52 | Fedora 44
#
# Use este script:
#   - Antes de rodar 03-fedora.sh (para preparar o ambiente)
#   - Para entrar em chroot e corrigir problemas no sistema instalado
#
# Para entrar em chroot manualmente depois de rodar este script:
#   chroot /mnt /bin/bash
#
set -euo pipefail

# ============================================================
# Verificar root
# ============================================================
if [ "$(id -u)" -ne 0 ]; then
    echo "❌ Este script precisa ser executado como root."
    exit 1
fi

# ============================================================
# Variáveis
# ============================================================
DRIVE="/dev/nvme0n1"

SYSTEM_PART="${DRIVE}p2"
BTRFS_PART="${DRIVE}p4"
EFI_PART="${DRIVE}p1"

MOUNTPOINT="/mnt"
BTRFS_LABEL="Fedora"

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
# Desmontar qualquer montagem prévia
# ============================================================
echo "🧹 Desmontando montagens anteriores..."
# swapoff "$MOUNTPOINT/var/swap/swapfile" 2>/dev/null || true  # swap desativado (usando zRAM)
umount -R "$MOUNTPOINT" 2>/dev/null || true
udevadm settle 2>/dev/null || true

# ============================================================
# Montagem dos subvolumes Btrfs
# ============================================================
echo "🔗 Montando subvolumes Btrfs ($BTRFS_LABEL → $MOUNTPOINT)..."

# Root
mount -o "$BTRFS_SYS,subvol=@root" "$BTRFS_PART" "$MOUNTPOINT"

# Criar estrutura de diretórios
mkdir -pv "$MOUNTPOINT"/{boot/efi,home,nix,opt,.snapshots,var/{tmp,spool,log,cache,swap,lib/{libvirt,containers}}}

# Subvolumes de dados do usuário e programas
mount -o "$BTRFS_OPTS_HOME,subvol=@home"     "$BTRFS_PART" "$MOUNTPOINT/home"
mount -o "$BTRFS_OPTS_MAX,subvol=@nix"       "$BTRFS_PART" "$MOUNTPOINT/nix"
mount -o "$BTRFS_OPTS_MAX,subvol=@opt"       "$BTRFS_PART" "$MOUNTPOINT/opt"
mount -o "$BTRFS_OPTS_MAX,subvol=@snapshots" "$BTRFS_PART" "$MOUNTPOINT/.snapshots"

# Subvolumes de log/cache/tmp (I/O intensivo — commit curto)
mount -o "$BTRFS_OPTS,subvol=@log"           "$BTRFS_PART" "$MOUNTPOINT/var/log"
mount -o "$BTRFS_OPTS,subvol=@spool"         "$BTRFS_PART" "$MOUNTPOINT/var/spool"
mount -o "$BTRFS_OPTS,subvol=@tmp"           "$BTRFS_PART" "$MOUNTPOINT/var/tmp"
mount -o "$BTRFS_OPTS,subvol=@cache"         "$BTRFS_PART" "$MOUNTPOINT/var/cache"

# Subvolumes de virtualização (nocow via chattr +C já aplicado na criação)
mount -o "$BTRFS_OPTS,subvol=@libvirt"       "$BTRFS_PART" "$MOUNTPOINT/var/lib/libvirt"
mount -o "$BTRFS_OPTS,subvol=@containers"    "$BTRFS_PART" "$MOUNTPOINT/var/lib/containers"

# Swap (nodatacow — obrigatório para swapfile Btrfs)
mount -o "$BTRFS_OPTS_SWAP,subvol=@swap"     "$BTRFS_PART" "$MOUNTPOINT/var/swap"

# ============================================================
# Montagem de /boot e /boot/efi
# ============================================================
echo "⏏️  Montando /boot e /boot/efi..."
mount "$SYSTEM_PART" "$MOUNTPOINT/boot"
mkdir -pv "$MOUNTPOINT/boot/efi"
mount -t vfat -o defaults,noatime,nodiratime "$EFI_PART" "$MOUNTPOINT/boot/efi"

# Swap em disco desativado — usando apenas zRAM (1,5× RAM)
# if [ -f "$MOUNTPOINT/var/swap/swapfile" ]; then
#     echo "💾 Ativando swapfile..."
#     swapon "$MOUNTPOINT/var/swap/swapfile" 2>/dev/null || true
# fi

# ============================================================
# Bind-mounts para chroot
# ============================================================
echo "🔧 Montando pseudo-filesystems para chroot..."
for dir in dev proc sys run; do
    mkdir -pv "$MOUNTPOINT/$dir"
    mount --rbind "/$dir" "$MOUNTPOINT/$dir"   # --rbind inclui /dev/pts
    mount --make-rslave "$MOUNTPOINT/$dir" 2>/dev/null || true
done
udevadm trigger 2>/dev/null || true

# Montar efivarfs (necessário para efibootmgr funcionar no chroot)
mount -t efivarfs efivarfs "$MOUNTPOINT/sys/firmware/efi/efivars" 2>/dev/null || true

# ============================================================
# Copiar resolv.conf para o chroot ter acesso à rede
# ============================================================
umount "$MOUNTPOINT/etc/resolv.conf" 2>/dev/null || true
rm -f "$MOUNTPOINT/etc/resolv.conf"
cp -L /etc/resolv.conf "$MOUNTPOINT/etc/resolv.conf"

# ============================================================
# Resultado
# ============================================================
echo ""
echo "✅ Partições montadas em $MOUNTPOINT"
echo ""
echo "   Para entrar em chroot e corrigir/inspecionar o sistema:"
echo "   $ chroot /mnt /bin/bash"
echo ""
echo "   Para instalar o Fedora agora:"
echo "   $ bash 03-fedora.sh"
echo ""
echo "   Para desmontar tudo depois:"
echo "   $ umount -R /mnt"
