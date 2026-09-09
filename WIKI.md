# 📖 Linux Installers & System Reference Wiki

Este documento é a **base de conhecimento definitiva** com todos os comandos, parâmetros, flags, técnicas e alternativas utilizadas em todos os scripts deste repositório (`ArchInstall`).

> 💡 **Objetivo:** Permitir que você limpe ou enxugue os scripts de instalação de cada máquina específica no futuro, mantendo aqui uma consulta rápida e completa de **o que cada comando faz**, **por que cada flag foi escolhida** e **quais são as formas alternativas de fazer**.

---

## 📑 Índice Geral

1. [Visão Geral e Fluxo de Instalação](#1-visão-geral-e-fluxo-de-instalação)
2. [Preparação do Ambiente e Limpeza Prévia](#2-preparação-do-ambiente-e-limpeza-prévia)
3. [Particionamento de Disco (sgdisk, parted, cfdisk)](#3-particionamento-de-disco-sgdisk-parted-cfdisk)
4. [Formatação de Sistemas de Arquivos (mkfs e Variantes)](#4-formatação-de-sistemas-de-arquivos-mkfs-e-variantes)
5. [Btrfs: Subvolumes, Opções de Montagem e CoW](#5-btrfs-subvolumes-opções-de-montagem-e-cow)
6. [Gerenciamento de Swap e Memória (zRAM vs Swapfile vs Partição)](#6-gerenciamento-de-swap-e-memória-zram-vs-swapfile-vs-partição)
7. [Criptografia de Disco (LUKS2 + Argon2id)](#7-criptografia-de-disco-luks2--argon2id)
8. [Bootstrap do Sistema Base por Distribuição](#8-bootstrap-do-sistema-base-por-distribuição)
9. [Chroot e Configurações Essenciais do Sistema](#9-chroot-e-configurações-essenciais-do-sistema)
10. [Bootloaders (GRUB, systemd-boot e Casos Especiais de Hardware)](#10-bootloaders-grub-systemd-boot-e-casos-especiais-de-hardware)
11. [Drivers de Vídeo, Gráficos Híbridos e VFIO/KVM Passthrough](#11-drivers-de-vídeo-gráficos-híbridos-e-vfiokvm-passthrough)
12. [Ecosistema Nix, Serviços e Pós-Instalação](#12-ecosistema-nix-serviços-e-pós-instalação)
13. [Tabela Prática de Equivalência entre Distros](#13-tabela-prática-de-equivalência-entre-distros)

---

## 1. Visão Geral e Fluxo de Instalação

Qualquer instalação manual ou scriptada de Linux moderno segue este ciclo canônico:

```mermaid
flowchart LR
    A[1. Preparação & Rede] --> B[2. Particionamento]
    B --> C[3. Criptografia / Formatação]
    C --> D[4. Subvolumes & Montagem]
    D --> E[5. Bootstrap / De-bootstrap]
    E --> F[6. Chroot & Configuração]
    F --> G[7. Bootloader & Kernel]
    G --> H[8. Drivers & Pós-Instalação]
```

### Perfis de Máquinas Presentes no Repositório
* **Acer Nitro 5 (AN515-52 / AN515-54):** UEFI pura, SSD NVMe/SATA, GPU híbrida Intel UHD 630 + NVIDIA GTX 1050/1650, Dual-boot com Windows 11, VM KVM com VFIO dinâmico e Looking Glass.
* **Apple MacBooks (MacBook Air / MacBook Pro 4,1):** Firmwares híbridos (EFI de 32-bit em CPUs Core 2 Duo de 64-bit, teclados ABNT2 vs Mac layout, placas Broadcom Wi-Fi BCM43xx).
* **Máquinas Virtuais (QEMU/KVM/Proxmox):** Partições enxutas em `/dev/vda`, drivers VirtIO, Btrfs comprimido para economia de disco físico.
* **SBCs / Servidores Leves (DietPi, La Frite):** Armazenamento em eMMC/SD, Podman/Docker, Jellyfin com aceleração v4l2, compartilhamento Samba.

---

## 2. Preparação do Ambiente e Limpeza Prévia

Antes de tocar nas partições, é fundamental desmontar qualquer sistema ativo e sincronizar os serviços de disco do kernel.

### Comandos de Limpeza Pré-Instalação

```bash
# 1. Desativa qualquer swap ativa no sistema Live
swapoff -a 2>/dev/null || true

# 2. Desmonta recursivamente tudo o que estiver sob o ponto de montagem
umount -R "$MOUNTPOINT" 2>/dev/null || true
# Alternativa forçada (caso algum processo prenda o ponto):
umount -Rvf "$MOUNTPOINT" 2>/dev/null || true

# 3. Espera o subsistema udev processar todos os eventos pendentes de blocos
udevadm settle 2>/dev/null || true
```

* **`swapoff -a`:** O instalador Live frequentemente monta automaticamente partições de swap existentes no disco. Se a swap estiver ligada, o particionador (`sgdisk`/`parted`) falha com erro de "device or resource busy".
* **`umount -R` (Recursive):** Desmonta `/mnt`, `/mnt/boot`, `/mnt/home` e todos os subvolumes de uma só vez, de baixo para cima na árvore.
* **`udevadm settle`:** Bloqueia a execução do script até que o kernel e o `udev` terminem de registrar ou remover os nós de dispositivo (`/dev/sdX`, `/dev/nvmeX`). Evita erros onde o particionamento roda antes do disco ter sido totalmente liberado.

### Rede e Relógio na ISO Live

```bash
# Sincroniza o relógio da placa-mãe via NTP (evita falhas de certificados SSL em downloads de repositórios)
timedatectl set-ntp true

# Arch: Atualiza repositórios e seleciona os mirrors mais rápidos do Brasil
reflector -c Brazil -a 6 --sort rate --save /etc/pacman.d/mirrorlist

# Void Linux: Conexão Wi-Fi manual via wpa_supplicant
wpa_passphrase "MinhaRede" "Senha123" >> /etc/wpa_supplicant/wpa_supplicant-wlan0.conf
ip link set up dev wlan0
sv restart dhcpcd
```

---

## 3. Particionamento de Disco (sgdisk, parted, cfdisk)

O repositório utiliza primordialmente **GPT (GUID Partition Table)** por suportar discos maiores que 2 TB, até 128 partições primárias e identificação robusta por UUID e rótulo.

### 3.1 `sgdisk` (Linha de Comando Não-Interativa)

O `sgdisk` é a versão de linha de comando do `gdisk`. Ideal para scripts automatizados.

```bash
# Destrói totalmente as tabelas GPT e MBR existentes no disco
sgdisk --zap-all "$DRIVE"
# Alternativa:
sgdisk -Z "$DRIVE"

# Criação de Partições: Sintaxe: -n <número>:<início>:<fim>
# 0 = próximo setor livre alinhado; +1G = tamanho relativo; 0 no fim = até o final do disco
sgdisk -n 1:0:+1G   -t 1:EF00 -c 1:"EFI SYSTEM"        "$DRIVE"
sgdisk -n 2:0:+1G   -t 2:8301 -c 2:"SYSTEM RESERVED"   "$DRIVE"
sgdisk -n 3:0:+300G -t 3:8300 -c 3:"Fedora Btrfs Pool" "$DRIVE"
sgdisk -n 4:0:0     -t 4:0700 -c 4:"Shared exFAT Data" "$DRIVE"

# Imprime a tabela resultante para conferência
sgdisk -p "$DRIVE"
```

#### Explicação Detalhada dos Parâmetros do `sgdisk`:
* **`--zap-all` / `-Z`:** Apaga os dados do GPT primário, GPT secundário (backup no fim do disco) e do MBR protetor.
* **`-n <partnum>:<start>:<end>`:**
  * `1:0:+1G`: Cria partição número `1`. Começa no primeiro setor alinhado livre (`0`) e termina após `1 GiB` (`+1G`).
  * `4:0:0`: Cria a partição número `4`, começando onde a 3 parou e preenchendo **todo o restante do disco** até o último setor (`:0`).
  * `-4G`: Também aceito em sintaxe relativa (ex: reservar 4 GB no final do disco para swap).
* **`-t <partnum>:<hex_code>`:** Atribui o GUID do tipo de partição:
  * `EF00`: **EFI System Partition (ESP)** — obrigatória para boot UEFI.
  * `8300`: **Linux Filesystem** (dados gerais, ext4, btrfs, xfs).
  * `8301`: **Linux Reserved** (usado para partição `/boot` dedicada).
  * `8200`: **Linux Swap** (partição de paginação de memória).
  * `EF02`: **BIOS Boot Partition** (obrigatória caso use tabela GPT em computadores antigos sem UEFI / Legacy BIOS para o GRUB gravar o `core.img`).
  * `0700`: **Microsoft Basic Data** (partições NTFS ou exFAT compartilhadas).
* **`-c <partnum>:"Nome"`:** Define o **PARTLABEL** (nome da partição no GPT). Isso difere do filesystem label, sendo lido pela UEFI e por `/dev/disk/by-partlabel/`.

---

### 3.2 `parted` (Abordagem Alternativa / Complementar)

```bash
# Cria o rótulo da tabela como GPT com alinhamento ótimo de blocos
parted -s -a optimal "$DRIVE" mklabel gpt

# Criação de partições primárias com parted
parted -s -a optimal "$DRIVE" mkpart primary fat32 1MiB 1024MiB
parted -s "$DRIVE" -- set 1 boot on
parted -s -a optimal "$DRIVE" mkpart primary ext4 1024MiB 2048MiB
parted -s -a optimal "$DRIVE" mkpart primary btrfs 2048MiB 100%
```

* **`-s` (`--script`):** Modo silencioso/não-interativo (nunca trava esperando confirmação).
* **`-a optimal` (`--align optimal`):** Alinha os setores a múltiplos de 1 MiB (2048 setores de 512 bytes ou páginas 4K de SSDs modernos), garantindo máxima vida útil e velocidade de leitura/escrita.
* **`set 1 boot on` / `set 1 esp on`:** Marca a flag de boot/ESP no GPT.

---

### 3.3 Esquemas de Particionamento Recomendados

#### Perfil A: UEFI Moderno + Dual Boot (ex: Acer Nitro 5)
| Partição | Tamanho | Tipo GPT | Filesystem | Rótulo / Ponto de Montagem | Função |
|---|---|---|---|---|---|
| `p1` | 1024 MB (1 GB) | `EF00` | FAT32 | `ESP` (`/boot/efi`) | Armazena binários `.efi` (Windows, Fedora, GRUB) |
| `p2` | 1024 MB (1 GB) | `8301` | ext4 | `SYSTEM` (`/boot`) | Kernels e initramfs isolados (segurança para GRUB) |
| `p3` | 200–400 GB | `8300` | Btrfs | `Fedora` (`/`) | Pool Btrfs com subvolumes `@root`, `@home`, `@nix` |
| `p4` | Resto do disco | `0700` | exFAT | `SHARED` (`/mnt/shared`) | Leitura/Escrita nativa no Windows 11 e Linux |

#### Perfil B: BIOS/Legacy ou Apple Mac antigo (MBR ou GPT Híbrido)
* Para GPT em BIOS clássico: Criar partição de **1 MB a 2 MB** com código `EF02` (BIOS Boot Partition, sem formatação). O GRUB usa esse espaço para embedar seu código de segundo estágio.
* Para Apple Mac antigo: Partição EFI inicial de 200MB a 512MB em FAT32, mantendo compatibilidade com o firmware Apple.

---

## 4. Formatação de Sistemas de Arquivos (mkfs e Variantes)

Aqui detalhamos a linha de comando citada (`nitro-dual.sh:L93`) e todas as alternativas do repositório.

### 4.1 O Comando Btrfs: `mkfs.btrfs -f -L "$BTRFS_LABEL" "$BTRFS_PART"`

```bash
mkfs.btrfs -f -L "$BTRFS_LABEL" "$BTRFS_PART"
```

#### O que cada flag faz:
* **`mkfs.btrfs`:** Utilitário do pacote `btrfs-progs` que inicializa uma estrutura de árvore B-Tree de sistema de arquivos Btrfs na partição ou disco.
* **`-f` (`--force`):** **Força a sobrescrita**. Se a partição já tiver qualquer assinatura anterior de sistema de arquivos (ex: um ext4 antigo, NTFS, ou outro Btrfs), o comando normal aborta pedindo confirmação manual. O `-f` remove a assinatura antiga e formata diretamente sem travar o script.
* **`-L "$BTRFS_LABEL"` (`--label`):** Define o rótulo de volume do sistema de arquivos (ex: `Fedora`, `VOID`, `Archsys`).
  * **Vantagem crítica:** Permite que o `/etc/fstab` e os comandos de montagem utilizem `/dev/disk/by-label/Fedora` ou `LABEL=Fedora`. Isso garante que mesmo se você trocar o SSD de slot M.2 ou plugar um pendrive que mude a ordem de `/dev/sda` para `/dev/sdb`, o sistema **continua inicializando perfeitamente**.
* **`"$BTRFS_PART"`:** O caminho do bloco (ex: `/dev/nvme0n1p3` ou `/dev/sda3`).

#### Parâmetros Avançados Opcionais do `mkfs.btrfs`:
```bash
# Para SSDs com suporte a blocos maiores e metadados duplicados em disco único:
mkfs.btrfs -f -L "Fedora" -m dup -d single --nodesize 16k "$BTRFS_PART"

# Para pools com múltiplos discos (RAID0 de velocidade ou RAID1 de espelhamento):
mkfs.btrfs -f -L "DataPool" -m raid1 -d raid1 /dev/sda /dev/sdb
```
* `-m dup`: Grava duas cópias de todos os metadados (árvores de alocação), prevenindo corrupção mesmo se houver setores ruins no SSD.
* `--nodesize 16k` (ou 64k): Tamanho dos nós de metadados. Padrão 16k é excelente para a maioria dos sistemas; 64k pode beneficiar bancos de dados pesados.

---

### 4.2 Formatação de Boot EFI: `mkfs.fat -F32` / `mkfs.vfat`

```bash
mkfs.fat -F32 -n "$EFI_LABEL" "$EFI_PART"
# Ou:
mkfs.vfat -F32 -n "ESP" /dev/sda1
```

* **`-F32`:** Força tabela FAT de 32 bits. A especificação UEFI exige formalmente partições ESP em FAT32 (ou FAT16 para partições menores que 32MB em certos firmwares antigos).
* **`-n "$EFI_LABEL"`:** Define o rótulo de volume FAT (limite máximo de **11 caracteres** em maiúsculas).

---

### 4.3 Formatação de Partição `/boot` dedicada: `mkfs.ext4`

```bash
mkfs.ext4 -F -L "$SYSTEM_LABEL" "$SYSTEM_PART"
```

* **`-F`:** Força a criação do filesystem mesmo se a partição já tiver conteúdo prévio.
* **`-L "$SYSTEM_LABEL"`:** Atribui o rótulo do volume (ex: `SYSTEM` ou `BOOT`).
* **Por que usar ext4 para `/boot` em vez de deixar tudo no Btrfs?**
  1. O GRUB tradicional possui limitações ao ler partições Btrfs com algoritmos de compressão modernos (`zstd` com certos níveis) ou configurações avançadas de metadados.
  2. Isola os binários do kernel (`vmlinuz`) e imagens de inicialização (`initramfs`) de eventuais rollbacks de snapshots do Btrfs, evitando inconsistência entre o kernel inicializado e os módulos em `/lib/modules`.

---

### 4.4 Formatação de Partições Compartilhadas (Windows + Linux)

```bash
# 1. exFAT (Recomendado para dados compartilhados rápidos)
mkfs.exfat -n "$MISC_LABEL" "$MISC_PART"

# 2. NTFS (Caso precise formatar ou reinstalar partição do Windows)
mkfs.ntfs -Q -f -L "Windows" /dev/sda4
```

* `mkfs.exfat -n`: Cria partição compatível nativamente sem permissões complexas de POSIX no Windows 11, Linux e macOS.
* `mkfs.ntfs -Q -f`: `-Q` executa formatação rápida (Quick Format), sem verificar setores vazios um por um; `-f` força a execução.

---

### 4.5 Formatação de Swap Clássica

```bash
mkswap -L "$SWAP_LABEL" "$SWAP_PART"
swapon "$SWAP_PART"
```

* Transforma a partição em área de paginação de memória e ativa imediatamente no live environment.

---

## 5. Btrfs: Subvolumes, Opções de Montagem e CoW

O repositório adota o padrão de **Layout Plano (Flat Layout)** com prefixo `@`.

### 5.1 Criação dos Subvolumes

```bash
# Monta o volume raiz puro do Btrfs temporariamente
mount "$BTRFS_PART" "$MOUNTPOINT"

# Criação em laço de todos os subvolumes do ecossistema
for sv in @root @home @nix @cache @opt @libvirt @containers @spool @log @tmp @snapshots @swap; do
  btrfs subvolume create "$MOUNTPOINT/$sv"
  # Forma abreviada equivalente:
  # btrfs su cr "$MOUNTPOINT/$sv"
done

# Desmonta a raiz para remontar a árvore correta organizada
umount -Rv "$MOUNTPOINT"
```

#### Finalidade de Cada Subvolume no Layout:
| Subvolume | Ponto de Montagem | Justificativa Arquitetural |
|---|---|---|
| `@root` | `/` | Sistema operacional raiz. Suporta snapshot e rollback completo do SO sem perder dados de usuários. |
| `@home` | `/home` | Arquivos pessoais. **Nunca** é restaurado em rollback do sistema, preservando downloads, configs e códigos. |
| `@nix` | `/nix` | Diretório do Nix Package Manager. Contém a `/nix/store` determinística; fica imune a snapshots do sistema base. |
| `@opt` | `/opt` | Softwares comerciais ou de terceiros (Google Chrome, DaVinci Resolve, drivers externos). |
| `@snapshots` | `/.snapshots` | Armazena os snapshots criados pelo Snapper ou scripts manuais. |
| `@cache` | `/var/cache` | Caches do DNF, pacman, flatpak. Economiza espaço não incluindo lixo descartável em snapshots. |
| `@log` | `/var/log` | Logs do `systemd-journald` e do sistema. Preserva histórico de diagnósticos mesmo se você fizer rollback de um boot quebrado. |
| `@tmp` | `/var/tmp` | Arquivos temporários grandes persistentes entre reboots. |
| `@spool` | `/var/spool` | Filas de impressão (CUPS) e tarefas cron. |
| `@libvirt` | `/var/lib/libvirt` | Imagens de máquinas virtuais (KVM/QEMU). Requer **No-CoW**. |
| `@containers` | `/var/lib/containers` | Storage do Podman/Docker. Evita duplicação de CoW sobre o driver de overlay. |
| `@swap` | `/var/swap` | Diretório dedicado ao swapfile com CoW desligado. |

---

### 5.2 Opções de Montagem do Btrfs Explicadas

Nos scripts encontramos as seguintes combinações:

```bash
# Opções padrão para sistema (alta performance e compressão balanceada)
BTRFS_OPTS="noatime,compress=zstd:1,space_cache=v2,commit=60,discard=async"

# Opções para subvolumes estáticos ou store (máxima compressão de dados)
BTRFS_OPTS_MAX="noatime,compress=zstd:3,space_cache=v2,commit=60,discard=async"

# Opções para swapfile (sem compressão)
BTRFS_OPTS_SWAP="noatime,space_cache=v2"
```

#### Guia de Flags do `mount -o`:
* **`noatime`:** Desativa a atualização do carimbo de data/hora de **último acesso** de leitura do arquivo. Por padrão (`atime`), toda vez que o SO lê um arquivo, ele faz uma escrita no disco para atualizar a data de acesso. Com `noatime`, economiza-se até 30% de I/O desnecessário e preserva-se o SSD.
* **`compress=zstd:1`:** Comprime blocos em tempo real com algoritmo Zstandard no nível 1.
  * **Por que ZSTD nível 1?** A descompressão é tão rápida que, em SSDs NVMe e SATA, o gargalo é a velocidade da CPU. O nível 1 é praticamente imperceptível para o processador e economiza entre 20% e 40% de espaço em disco.
  * **`compress=zstd:3`:** Nível padrão do ZSTD. Ótimo para `@nix`, `@snapshots` e `/` onde o espaço livre importa mais.
  * **`compress-force=zstd:8`:** Força a tentativa de compressão mesmo em arquivos que o Btrfs inicialmente julgue como incompressíveis.
* **`space_cache=v2`:** Gerenciador de blocos livres da árvore Btrfs versão 2. O v1 original ficava lento em sistemas com muitos gigabytes livres ou partições muito fragmentadas. O v2 é o padrão estável e recomendado hoje.
* **`discard=async`:** Habilita o TRIM assíncrono para SSDs NVMe/SATA no kernel Linux 5.6+.
  * O `discard` síncrono antigo travava o I/O da máquina toda vez que um arquivo grande era deletado porque o SSD parava para zerar as células. Com `discard=async`, o kernel enfileira os comandos TRIM e os envia ao SSD em momentos de ociosidade, sem qualquer travamento.
* **`commit=60`:** Força o flush de transações da memória RAM para o disco a cada 60 segundos (o padrão do kernel é 30s). Aumenta o throughput de escrita agrupando mais blocos, com uma janela aceitável de tolerância a quedas de energia.

---

### 5.3 Montagem Prática da Árvore Completa

```bash
# 1. Monta a raiz primeiro
mount -o "$BTRFS_OPTS_MAX,subvol=@root" "$BTRFS_PART" "$MOUNTPOINT"

# 2. Cria todos os pontos de montagem necessários dentro da nova raiz
mkdir -pv "$MOUNTPOINT"/{boot/efi,home,nix,opt,.snapshots,var/{tmp,spool,log,cache,swap,lib/{libvirt,containers}}}

# 3. Monta cada subvolume em seu respectivo diretório
mount -o "$BTRFS_OPTS,subvol=@home"          "$BTRFS_PART" "$MOUNTPOINT/home"
mount -o "$BTRFS_OPTS_MAX,subvol=@nix"       "$BTRFS_PART" "$MOUNTPOINT/nix"
mount -o "$BTRFS_OPTS_MAX,subvol=@opt"       "$BTRFS_PART" "$MOUNTPOINT/opt"
mount -o "$BTRFS_OPTS,subvol=@log"           "$BTRFS_PART" "$MOUNTPOINT/var/log"
mount -o "$BTRFS_OPTS,subvol=@spool"         "$BTRFS_PART" "$MOUNTPOINT/var/spool"
mount -o "$BTRFS_OPTS,subvol=@tmp"           "$BTRFS_PART" "$MOUNTPOINT/var/tmp"
mount -o "$BTRFS_OPTS,subvol=@cache"         "$BTRFS_PART" "$MOUNTPOINT/var/cache"
mount -o "$BTRFS_OPTS_MAX,subvol=@snapshots" "$BTRFS_PART" "$MOUNTPOINT/.snapshots"
mount -o "$BTRFS_OPTS_SWAP,subvol=@swap"     "$BTRFS_PART" "$MOUNTPOINT/var/swap"
mount -o "$BTRFS_OPTS,subvol=@libvirt"       "$BTRFS_PART" "$MOUNTPOINT/var/lib/libvirt"
mount -o "$BTRFS_OPTS,subvol=@containers"    "$BTRFS_PART" "$MOUNTPOINT/var/lib/containers"

# 4. Monta boot e EFI
mount "$SYSTEM_PART" "$MOUNTPOINT/boot"
mount -t vfat -o defaults,noatime,nodiratime "$EFI_PART" "$MOUNTPOINT/boot/efi"
```

---

### 5.4 Desativação de Copy-on-Write: `chattr +C` (No-CoW)

```bash
chattr +C "$MOUNTPOINT/var/lib/libvirt"
chattr +C "$MOUNTPOINT/var/lib/containers"
chattr +C "$MOUNTPOINT/var/swap"
```

#### O que faz:
* Aplica o atributo de arquivo `+C` (NOCOW - No Copy-on-Write) no diretório especificado.
* **Por que isso é essencial?**
  O Btrfs é um sistema CoW: toda vez que um byte dentro de um arquivo de 100 GB (ex: `windows11.qcow2`) é alterado, o Btrfs não sobrescreve aquele setor; ele aloca um bloco novo e atualiza a árvore. Em discos virtuais de máquinas virtuais ou bancos de dados, isso gera **fragmentação catastrófica**, reduzindo a velocidade do disco para menos de 10% do original.
* ⚠️ **Atenção:** O `chattr +C` só tem efeito em arquivos novos criados após o comando, ou se executado no diretório **quando ele ainda estiver completamente vazio**!

---

## 6. Gerenciamento de Swap e Memória (zRAM vs Swapfile vs Partição)

A melhor arquitetura de memória para notebooks modernos (como o Acer Nitro 5) é o **modelo em duas camadas**:
1. **zRAM de alta prioridade (prioridade 100):** Comprime páginas na RAM sem encostar no disco.
2. **Swapfile em SSD de baixa prioridade (prioridade 10):** Apenas como válvula de escape caso a RAM e a zRAM esgotem juntas.

### 6.1 Criação do Swapfile em Btrfs

#### Método A: Moderno (Kernel 6.1+ e btrfs-progs atualizados)
```bash
# Cria o arquivo já com No-CoW e sem compressão de forma atômica
btrfs filesystem mkswapfile --size 16G --uuid clear "$MOUNTPOINT/var/swap/swapfile"
```

#### Método B: Canônico Manual (compatível com qualquer versão do Linux)
```bash
SWAPFILE="$MOUNTPOINT/var/swap/swapfile"

# 1. Cria um arquivo vazio de tamanho 0
truncate -s 0 "$SWAPFILE"

# 2. Desativa CoW obrigatoriamente
chattr +C "$SWAPFILE"

# 3. Garante que o Btrfs nunca tente comprimir o swap
btrfs property set "$SWAPFILE" compression none

# 4. Aloca os 16 GB contíguos no disco
fallocate -l 16G "$SWAPFILE"
# Se fallocate falhar em Btrfs antigo, use dd:
# dd if=/dev/zero of="$SWAPFILE" bs=1M count=16384 status=progress

# 5. Permissão estrita de root
chmod 600 "$SWAPFILE"

# 6. Formata a estrutura de swap
mkswap -L "SWAPFILE" "$SWAPFILE"
```

### 6.2 Offset de Swap para Hibernação (Resume Offset)

Caso você queira que o Linux hiberne (salve a memória no swap e desligue totalmente a máquina), o kernel precisa saber exatamente em qual setor do disco o arquivo de swap começa:

```bash
# Obter o offset exato do arquivo no Btrfs:
btrfs inspect-internal map-swapfile -r /var/swap/swapfile

# Parâmetros adicionados na linha de comando do kernel (GRUB_CMDLINE_LINUX):
# resume=UUID=<uuid_da_particao_btrfs> resume_offset=<numero_obtido_acima>
```

### 6.3 Configuração de zRAM

No Fedora, Debian e Arch, use o `zram-generator`:

```ini
# Arquivo: /etc/systemd/zram-generator.conf
[zram0]
zram-size = min(ram / 2, 8192)
compression-algorithm = zstd
```

---

## 7. Criptografia de Disco (LUKS2 + Argon2id)

Utilizado nos scripts de segurança e servidores Proxmox (`proxmox-luks-tmp2.sh`).

```bash
# 1. Formata a partição com LUKS versão 2 usando função de derivação Argon2id
echo -n "minhasenha" | cryptsetup luksFormat \
  --type luks2 \
  --pbkdf argon2id \
  --cipher aes-xts-plain64 \
  --key-size 512 \
  --hash sha512 \
  --batch-mode \
  --key-file=- "$DRIVE"3

# 2. Abre o contêiner criptografado mapeando-o em /dev/mapper/luks_root
echo -n "minhasenha" | cryptsetup open "$DRIVE"3 luks_root --key-file=-

# 3. Formata o Btrfs diretamente DENTRO do contêiner aberto
mkfs.btrfs -f -L Fedora /dev/mapper/luks_root

# 4. Ao finalizar manutenções ou montagens:
cryptsetup luksClose /dev/mapper/luks_root
```

* **`--type luks2`:** Cabeçalho moderno com suporte a múltiplos perfis de chaves e resiliência a corrupção.
* **`--pbkdf argon2id`:** Protege a senha contra ataques de força bruta realizados por GPUs modernas (mais seguro que o PBKDF2 antigo).

---

## 8. Bootstrap do Sistema Base por Distribuição

Cada família de distribuição possui uma ferramenta para instalar o sistema básico dentro de `/mnt`.

### 8.1 Fedora / RHEL (`dnf` ou `dnf5 --installroot`)

```bash
# Instala os pacotes fundamentais na partição montada
dnf5 --installroot="$MOUNTPOINT" \
  --releasever=44 \
  --setopt=install_weak_deps=False \
  -y install \
  @core \
  @base-x \
  kernel \
  kernel-core \
  kernel-modules \
  kernel-modules-extra \
  btrfs-progs \
  dracut \
  grub2-efi-x64 \
  shim-x64 \
  efibootmgr \
  NetworkManager \
  sudo \
  git \
  neovim
```

* `--installroot=/mnt`: Trata `/mnt` como a raiz do novo sistema, baixando e descompactando os RPMs lá dentro.
* `--setopt=install_weak_deps=False`: Não instala pacotes "recomendados" ou opcionais, resultando em um sistema ultraleve e minimalista.

---

### 8.2 Debian / Ubuntu (`debootstrap`)

```bash
# Bootstrap minimalista via espelho oficial ou mirror da UFPR
debootstrap --variant=minbase \
  --arch amd64 \
  --include=apt,apt-utils,systemd,systemd-sysv,udev,btrfs-progs,locales,sudo,linux-image-amd64,grub-efi-amd64,network-manager \
  bookworm "$MOUNTPOINT" "http://deb.debian.org/debian/"
```

* `--variant=minbase`: Cria a menor instalação possível do Debian (~150 MB de arquivos puros).
* `--include=...`: Já inclui o kernel, gerenciador de rede, suporte Btrfs e GRUB diretamente na extração inicial.

---

### 8.3 Arch Linux (`pacstrap`)

```bash
# Inicializa o keyring e instala o pacote base
pacstrap -K "$MOUNTPOINT" \
  base \
  base-devel \
  linux \
  linux-firmware \
  btrfs-progs \
  grub \
  efibootmgr \
  networkmanager \
  sudo \
  neovim
```

* `-K`: Inicializa um chaveiro de chaves pacman vazio dentro do novo sistema com as chaves do ambiente live importadas.

---

### 8.4 Artix Linux (Arch sem systemd: `basestrap`)

```bash
# Para init RUNIT:
basestrap "$MOUNTPOINT" base base-devel runit elogind-runit linux linux-firmware btrfs-progs

# Para init S6:
basestrap "$MOUNTPOINT" base base-devel s6-base elogind-s6 linux linux-firmware btrfs-progs

# Para init DINIT:
basestrap "$MOUNTPOINT" base base-devel dinit elogind-dinit linux linux-firmware btrfs-progs
```

---

### 8.5 Void Linux (`xbps` ou Rootfs Tarball)

```bash
# Método 1: Extração do tarball oficial RootFS
wget -c https://repo-default.voidlinux.org/live/current/void-x86_64-ROOTFS-*.tar.xz
tar xf void-x86_64-ROOTFS-*.tar.xz -C "$MOUNTPOINT"

# Método 2: Via xbps-install do live
XBPS_ARCH="x86_64" xbps-install -Sy -R https://repo-default.voidlinux.org/current -r "$MOUNTPOINT" \
  base-system btrfs-progs grub-x86_64-efi
```

---

## 9. Chroot e Configurações Essenciais do Sistema

### 9.1 Geração de `/etc/fstab`

```bash
# Arch Linux:
genfstab -U "$MOUNTPOINT" >> "$MOUNTPOINT/etc/fstab"

# Artix Linux:
fstabgen -U "$MOUNTPOINT" >> "$MOUNTPOINT/etc/fstab"

# No Debian / Fedora (Geração manual por UUID):
ROOT_UUID=$(blkid -s UUID -o value "$BTRFS_PART")
cat <<EOF >> "$MOUNTPOINT/etc/fstab"
UUID=$ROOT_UUID  /               btrfs  subvol=@root,noatime,compress=zstd:1,space_cache=v2  0 0
UUID=$ROOT_UUID  /home           btrfs  subvol=@home,noatime,compress=zstd:1,space_cache=v2  0 0
UUID=$ROOT_UUID  /nix            btrfs  subvol=@nix,noatime,compress=zstd:3,space_cache=v2   0 0
UUID=$ROOT_UUID  /var/swap       btrfs  subvol=@swap,noatime,space_cache=v2                  0 0
/var/swap/swapfile none          swap   defaults,pri=10                                      0 0
EOF
```

---

### 9.2 Entrada no Chroot

```bash
# Se estiver no Arch:
arch-chroot "$MOUNTPOINT" /bin/bash

# Se estiver no Artix:
artix-chroot "$MOUNTPOINT" /bin/bash

# Se estiver no Void:
xchroot "$MOUNTPOINT" /bin/bash

# Chroot Genérico Manual (Obrigatório para Debian/Fedora a partir de ISO genérica):
mount --bind /dev "$MOUNTPOINT/dev"
mount --bind /dev/pts "$MOUNTPOINT/dev/pts"
mount -t proc proc "$MOUNTPOINT/proc"
mount -t sysfs sysfs "$MOUNTPOINT/sys"
mount -t efivarfs efivarfs "$MOUNTPOINT/sys/firmware/efi/efivars" 2>/dev/null || true
chroot "$MOUNTPOINT" /bin/bash
```

---

### 9.3 Comandos Canônicos Executados Dentro do Chroot

```bash
# 1. Fuso horário e Sincronização de Hardware
ln -sf /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime
hwclock --systohc --utc

# 2. Localidades e Idioma
echo "en_US.UTF-8 UTF-8" >> /etc/locale.gen
echo "pt_BR.UTF-8 UTF-8" >> /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" > /etc/locale.conf
echo "KEYMAP=br-abnt2" > /etc/vconsole.conf

# 3. Hostname e Hosts
echo "nitro-fedora" > /etc/hostname
cat <<EOF > /etc/hosts
127.0.0.1   localhost
::1         localhost
127.0.1.1   nitro-fedora.localdomain nitro-fedora
EOF

# 4. Criação do Usuário Principal com Grupos de Hardware/Virtualização
useradd -m -g users -G wheel,video,audio,input,kvm,libvirt,storage,render -s /bin/bash juca
echo "juca:minhasenha" | chpasswd
echo "root:senharoot" | chpasswd

# 5. Habilitar sudo sem senha para o grupo wheel (opcional para scripts):
echo "%wheel ALL=(ALL:ALL) NOPASSWD: ALL" > /etc/sudoers.d/10-wheel-nopasswd
```

---

## 10. Bootloaders (GRUB, systemd-boot e Casos Especiais de Hardware)

### 10.1 Instalação Padrão do GRUB UEFI (x86_64)

```bash
grub-install --target=x86_64-efi \
  --efi-directory=/boot/efi \
  --bootloader-id=GRUB \
  --recheck

# Habilita detecção automática de outros SOs (Windows 11):
echo "GRUB_DISABLE_OS_PROBER=false" >> /etc/default/grub

# Gera o arquivo final de configuração:
grub-mkconfig -o /boot/grub/grub.cfg
# No Fedora antigo:
# grub2-mkconfig -o /boot/efi/EFI/fedora/grub.cfg
```

---

### 10.2 O Quirk Crítico do Acer Nitro 5 (InsydeH2O UEFI Reset)

> ⚠️ **Problema:** A BIOS InsydeH2O de notebooks Acer Nitro 5 frequentemente perde ou "esquece" as variáveis de boot NVRAM geradas pelo `efibootmgr` ao atualizar o Windows ou trocar opções na BIOS. O notebook passa a dar boot direto no Windows ou cair em tela preta.

#### Solução Definitiva (Fallback EFI):
Copie o binário do bootloader para a pasta `/EFI/BOOT/BOOTX64.EFI`, que é o caminho que toda placa-mãe UEFI tenta por padrão se a NVRAM falhar:

```bash
mkdir -p /boot/efi/EFI/BOOT
# No Fedora:
cp /boot/efi/EFI/fedora/shimx64.efi /boot/efi/EFI/BOOT/BOOTX64.EFI
cp /boot/efi/EFI/fedora/grubx64.efi /boot/efi/EFI/BOOT/grubx64.efi

# No Arch / Debian:
cp /boot/efi/EFI/GRUB/grubx64.efi /boot/efi/EFI/BOOT/BOOTX64.EFI
```

---

### 10.3 Caso Apple Mac Antigo (EFI 32-bit em Processador 64-bit)

Modelos como MacBook Pro 4,1 e primeiros MacBook Air utilizam processadores Intel Core 2 Duo de 64 bits, mas a firmware Apple EFI é estritamente de **32 bits**:

```bash
# O instalador do GRUB precisa ser compilado para o target i386-efi:
grub-install --target=i386-efi \
  --efi-directory=/boot/efi \
  --bootloader-id=mac-grub \
  --recheck
```

---

### 10.4 Alternativa: `systemd-boot` (Mais Rápido e Limpo que GRUB)

```bash
# Instala os binários do systemd-boot na partição ESP
bootctl install --esp-path=/boot/efi

# Configuração global: /boot/efi/loader/loader.conf
cat <<EOF > /boot/efi/loader/loader.conf
default  fedora.conf
timeout  3
console-mode max
editor   no
EOF

# Entrada do Sistema: /boot/efi/loader/entries/fedora.conf
cat <<EOF > /boot/efi/loader/entries/fedora.conf
title   Fedora Linux
linux   /vmlinuz-linux
initrd  /initramfs-linux.img
options root=UUID=$ROOT_UUID rootflags=subvol=@root rw quiet splash
EOF
```

---

## 11. Drivers de Vídeo, Gráficos Híbridos e VFIO/KVM Passthrough

No Acer Nitro 5 temos gráficos híbridos: **Intel UHD 630 (integrada)** + **NVIDIA GTX 1050/1650 (dedicada)**.

### 11.1 Drivers e Decodificação de Hardware (VA-API / NVENC)

```bash
# 1. Driver Intel VA-API (decodificação de vídeo no YouTube/Navegador pela iGPU):
# Fedora:
dnf5 install -y intel-media-driver libva-utils vulkan-intel
# Debian:
apt-get install -y intel-media-va-driver-non-free vainfo

# 2. Driver Proprietário NVIDIA:
# Fedora (RPM Fusion):
dnf5 install -y akmod-nvidia xorg-x11-drv-nvidia-cuda
# Debian:
apt-get install -y nvidia-driver nvidia-smi
```

---

### 11.2 VFIO e GPU Passthrough Dinâmico para Máquinas Virtuais Windows

Em vez de isolar a GPU permanentemente para a VM (o que deixaria o Linux sem GPU dedicada), utilizamos o **VFIO Dinâmico**:
* No Fedora / Linux diário: A GPU NVIDIA fica associada ao driver oficial da NVIDIA para você usar CUDA, Blender, jogos nativos ou compilação.
* No momento em que você liga uma VM Windows no `virt-manager`: O `libvirt` desconecta o driver da NVIDIA e anexa a placa no módulo `vfio-pci`. Ao desligar a VM, ele devolve a GPU para o Linux.

#### Parâmetros de Linha de Comando do Kernel (em `/etc/default/grub`):
```bash
GRUB_CMDLINE_LINUX="... intel_iommu=on iommu=pt kvm.ignore_msrs=1"
```
* `intel_iommu=on`: Habilita a separação de grupos IOMMU do processador Intel.
* `iommu=pt`: Pass-through mode para dispositivos não passados à VM (evita perda de performance de rede e barramento no host).
* `kvm.ignore_msrs=1`: Previne travamentos do Windows dentro da VM ao tentar ler registradores MSR não suportados pelo QEMU.

#### Memória Compartilhada para o Looking Glass (Zero Latency Display):
```bash
# Arquivo: /etc/tmpfiles.d/10-looking-glass.conf
f /dev/shm/looking-glass 0660 juca kvm -
```
Cria automaticamente no boot um buffer de memória compartilhada em RAM com permissões para o usuário `juca` e grupo `kvm`, permitindo que o cliente do Looking Glass leia os frames renderizados pela placa da VM a 120 FPS sem precisar de um monitor físico plugado na saída HDMI.

---

## 12. Ecosistema Nix, Serviços e Pós-Instalação

### 12.1 Gerenciador de Pacotes Nix

O repositório inclui a instalação do Nix no subvolume dedicado `@nix`.

```bash
# Instalação do Nix em modo multi-user ou nativo
dnf5 install -y nix
systemctl enable --now nix-daemon
```

#### Ocultar Usuários de Build do Nix (`nixbld1..32`) na Tela de Login:
Por padrão, o Nix cria diversos usuários de compilação locais. Se não configurado, o GDM ou SDDM lista todos eles na tela de login!
O script `Distros/Fedora/nixusers_hide.sh` resolve isso definindo a propriedade `SystemAccount=true`:

```bash
for u in $(cut -d: -f1 /etc/passwd | grep -E '^nixbld'); do
  mkdir -p /var/lib/AccountsService/users
  cat <<EOF > /var/lib/AccountsService/users/$u
[User]
SystemAccount=true
EOF
done
```

---

### 12.2 Undervolt de CPU Intel (Controle Térmico Nitro 5)

Notebooks gamers sofrem com *thermal throttling*. O utilitário `intel-undervolt` reduz a voltagem de pico da CPU em -100mV a -140mV sem perder estabilidade, reduzindo as temperaturas em até 15°C:

```bash
# /etc/intel-undervolt.conf
undervolt 0 'CPU' -125
undervolt 1 'GPU' -50
undervolt 2 'CPU Cache' -125
undervolt 3 'System Agent' 0
undervolt 4 'Analog I/O' 0

# Testar e aplicar:
intel-undervolt apply
systemctl enable --now intel-undervolt.service
```

---

## 13. Tabela Prática de Equivalência entre Distros

Guia de tradução imediata ao converter scripts de uma distribuição para outra:

| Recurso / Tarefa | Fedora | Arch Linux | Artix Linux | Debian | Void Linux |
|---|---|---|---|---|---|
| **Gerenciador de Pacotes** | `dnf5 install <pkg>` | `pacman -S <pkg>` | `pacman -S <pkg>` | `apt install <pkg>` | `xbps-install -S <pkg>` |
| **Atualização Geral** | `dnf5 upgrade --refresh` | `pacman -Syu` | `pacman -Syu` | `apt update && apt upgrade` | `xbps-install -Su` |
| **Ferramenta Bootstrap** | `dnf5 --installroot` | `pacstrap -K` | `basestrap` | `debootstrap` | `tar xf rootfs` / `xbps -r` |
| **Geração de Initramfs** | `dracut --force` | `mkinitcpio -P` | `mkinitcpio -P` | `update-initramfs -u` | `dracut --force` |
| **Gerenciador de Serviços** | `systemctl enable --now` | `systemctl enable --now` | Runit: `ln -s /etc/runit/sv/...` | `systemctl enable --now` | Runit: `ln -s /etc/sv/... /var/service/` |
| **Entrada no Chroot** | `chroot` (após bind mounts) | `arch-chroot` | `artix-chroot` | `chroot` (após bind mounts) | `xchroot` |
| **Configuração de Teclado** | `localectl set-x11-keymap` | `/etc/vconsole.conf` | `/etc/vconsole.conf` | `dpkg-reconfigure keyboard-configuration` | `/etc/rc.conf` (`KEYMAP=...`) |

---

> 📌 **Como consultar:** Use a pesquisa deste arquivo (`Ctrl + F`) para buscar qualquer comando (ex: `mkfs.btrfs`, `chattr`, `sgdisk`, `dracut`, `subvol=@root`) e conferir o que ele faz e quais flags utilizar em seus novos instaladores minimalistas.
