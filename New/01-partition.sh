#!/usr/bin/env bash
#
# 01-partition.sh
# PASSO 1 — Particionar e formatar o SSD 500 GB
# Acer Nitro 5 AN515-52 | Dual Boot: Windows 11 + Fedora 44
#
# Layout de Partições:
#   p1: EFI System   (1 GB)    — FAT32  (compartilhada entre Windows e Fedora)
#   p2: Boot Fedora  (1 GB)    — ext4
#   p3: Windows 11   (150 GB)  — NTFS   (o instalador Win11 sobrescreve)
#   p4: Fedora Btrfs (100 GB)  — Btrfs  (@root @home @nix @libvirt ...)
#   p5: Shared Data  (~248 GB) — exFAT  (compartilhado entre os dois SOs)
#
# ORDEM DE USO:
#   1. Execute este script  →  partições criadas
#   2. Instale o Windows 11 na p3 (150 GB)
#   3. Rode 02-mount.sh  →  monta o Fedora para chroot
#   4. Rode 03-fedora.sh →  instala o Fedora
#
set -euo pipefail

# ============================================================
# Verificar root
# ============================================================
if [ "$(id -u)" -ne 0 ]; then
    echo "❌ Este script precisa ser executado como root."
    exit 1
fi

echo "⚡ PASSO 1 — Particionando SSD para dual-boot Windows 11 + Fedora..."
setenforce 0 2>/dev/null || true

# ============================================================
# Instalar ferramentas de disco na ISO Live
# ============================================================
echo "📦 Instalando ferramentas de disco..."
dnf install -y gdisk parted exfatprogs btrfs-progs ntfsprogs ntfs-3g

# ============================================================
# Variáveis
# ============================================================
DRIVE="/dev/nvme0n1"

EFI_PART="${DRIVE}p1"
SYSTEM_PART="${DRIVE}p2"
WIN_PART="${DRIVE}p3"
BTRFS_PART="${DRIVE}p4"
MISC_PART="${DRIVE}p5"

EFI_LABEL="ESP"
SYSTEM_LABEL="BOOT"
WIN_LABEL="Windows11"
BTRFS_LABEL="Fedora"
MISC_LABEL="SharedData"

# ============================================================
# Limpeza
# ============================================================
echo "🧹 Limpando montagens e tabela de partições..."
swapoff -a 2>/dev/null || true
umount -R /mnt 2>/dev/null || true
udevadm settle 2>/dev/null || true

# ============================================================
# Particionamento GPT
# ============================================================
echo "🧱 Criando tabela GPT e partições..."
sgdisk --zap-all "$DRIVE"
sleep 2
partprobe "$DRIVE" 2>/dev/null || true
udevadm settle
parted -s -a optimal "$DRIVE" mklabel gpt

# p1: EFI (1GB), p2: Boot Fedora (1GB), p3: Windows (150GB), p4: Fedora Btrfs (100GB), p5: exFAT (resto)
sgdisk -n 1:0:+1G      -t 1:EF00 -c 1:"EFI SYSTEM"          "$DRIVE"
sgdisk -n 2:0:+1G      -t 2:8301 -c 2:"SYSTEM RESERVED"     "$DRIVE"
sgdisk -n 3:0:+150G    -t 3:0700 -c 3:"Windows 11"          "$DRIVE"
sgdisk -n 4:0:+100G    -t 4:8300 -c 4:"Fedora Btrfs Pool"   "$DRIVE"
sgdisk -n 5:0:0        -t 5:0700 -c 5:"Shared exFAT Data"   "$DRIVE"

partprobe "$DRIVE" 2>/dev/null || true
udevadm settle
sgdisk -p "$DRIVE"

# ============================================================
# Formatação
# ============================================================
echo "🧼 Formatando partições..."

# p1: EFI — compartilhada com Windows
mkfs.fat -F32 -n "$EFI_LABEL" "$EFI_PART"

# p2: /boot do Fedora
mkfs.ext4 -F -L "$SYSTEM_LABEL" "$SYSTEM_PART"

# p3: Windows — NTFS placeholder. O instalador do Win11 reformata.
# NÃO instale o Fedora antes do Windows (Win11 sobrescreve o bootloader).
echo "🪟 Formatando p3 como NTFS placeholder para Windows 11..."
mkntfs -f -L "$WIN_LABEL" "$WIN_PART"

# p4: Fedora Btrfs pool
mkfs.btrfs -f -L "$BTRFS_LABEL" "$BTRFS_PART"

# p5: exFAT compartilhado (-b 1M otimizado para arquivos grandes: VMs, vídeos)
mkfs.exfat -b 1M -c 32K -n "$MISC_LABEL" "$MISC_PART"

# ============================================================
# Criar subvolumes Btrfs
# ============================================================
echo "📂 Criando subvolumes Btrfs..."
mount "$BTRFS_PART" /mnt
for sv in @root @home @nix @cache @opt @libvirt @containers @spool @log @tmp @snapshots @swap; do
    btrfs subvolume create "/mnt/$sv"
done
umount -Rv /mnt

# ============================================================
# Resultado final
# ============================================================
echo ""
echo "✅ Particionamento concluído!"
echo ""
echo "   Layout do SSD $DRIVE:"
sgdisk -p "$DRIVE"
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "   PRÓXIMOS PASSOS:"
echo ""
echo "   1. Reinicie e instale o Windows 11 na partição de 150 GB (p3)"
echo "      ➜  Na tela de instalação, selecione a partição 'Windows11'"
echo "      ➜  O instalador vai reformatá-la e criar partições auxiliares"
echo "      ➜  NÃO toque nas outras partições durante a instalação do Windows"
echo ""
echo "   2. Após instalar o Windows, inicialize o live do Fedora novamente"
echo "      e execute: bash 02-mount.sh && bash 03-fedora.sh"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
