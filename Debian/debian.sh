#!/bin/sh


apt update && apt install btrfs-progs wget -y

# wget -c http://deb.devuan.org/devuan/pool/main/d/debootstrap/debootstrap_1.0.126+nmu1devuan1.tar.gz

#####################################
####Gptfdisk Partitioning example####
#####################################

# -s script call | -a optimal
sgdisk -Z /dev/sda
parted -s -a optimal /dev/sda mklabel gpt

# Create new partition
sgdisk -n 0:0:100MiB /dev/sda
sgdisk -n 0:0:0 /dev/sda

# Change the name of partition
sgdisk -c 1:Devuan /dev/sda
sgdisk -c 2:Devroot /dev/sda

# Change Types
sgdisk -t 1:ef00 /dev/sda
sgdisk -t 2:8300 /dev/sda

sgdisk -p /dev/sda

#####################################
##########  FileSystem  #############
#####################################

mkfs.vfat -F32 /dev/sda1 -n "Grub"
mkfs.btrfs /dev/sda2 -f -L "Devuan"

## Volumes Vda apenas para testes em vm
set -e
DEVUAN_ARCH="amd64"
BTRFS_OPTS="noatime,ssd,compress-force=zstd:19,space_cache=v2,commit=120,autodefrag,discard=async"
# Mude de acordo com sua partição
# mount -o $BTRFS_OPTS /dev/vda5 /mnt
mount -o $BTRFS_OPTS /dev/sda2 /mnt

#Cria os subvolumes
btrfs su cr /mnt/@
btrfs su cr /mnt/@home
btrfs su cr /mnt/@snapshots
btrfs su cr /mnt/@var_log
# btrfs su cr /mnt/@swap
btrfs su cr /mnt/@var_cache_apt
umount -v /mnt

# Monta com os valores selecionados
# Lembre-se de mudar os valores de sdX

mount -o $BTRFS_OPTS,subvol=@ /dev/sda2 /mnt
mkdir -pv /mnt/boot/efi
mkdir -pv /mnt/home
mkdir -pv /mnt/.snapshots
mkdir -pv /mnt/var/log
mkdir -pv /mnt/var/swap
mkdir -pv /mnt/var/cache/apt

mount -o $BTRFS_OPTS,subvol=@home /dev/sda2 /mnt/home
mount -o $BTRFS_OPTS,subvol=@snapshots /dev/sda2 /mnt/.snapshots
mount -o $BTRFS_OPTS,subvol=@var_log /dev/sda2 /mnt/var/log
# mount -o $BTRFS_OPTS,subvol=@swap /dev/sda2 /mnt/var/swap
mount -o $BTRFS_OPTS,subvol=@var_cache_apt /dev/sda2 /mnt/var/cache/apt
mount -t vfat -o noatime,nodiratime /dev/sda1 /mnt/boot/efi 



# debootstrap --include "bash,zsh,wpasupplicant,locales,grub2,wget,curl,ntp,network-manager,dhcpcd5,linux-image-amd64,firmware-linux-free" --arch amd64 chimaera /mnt http://devuan.c3sl.ufpr.br/merged/ chimaera
# debootstrap --include "bash,zsh,iwd,locales,grub2,wget,curl,ntp,network-manager,dhcpcd5,linux-image-amd64,firmware-linux-free" --arch amd64 chimaera /mnt http://devuan.c3sl.ufpr.br/merged/ chimaera
# debootstrap --arch amd64 chimaera /mnt http://devuan.c3sl.ufpr.br/merged/ chimaera
debootstrap --variant=minbase --arch amd64 chimaera /mnt http://devuan.c3sl.ufpr.br/merged/ chimaera
# deb http://devuan.c3sl.ufpr.br/merged/ main contrib non-free


# Mount points
for dir in dev proc sys run; do
        mount --rbind /$dir /mnt/$dir
        mount --make-rslave /mnt/$dir
done

# Desabilita instalar recomendados
touch /mnt/etc/apt/apt.conf
cat <<EOF > /mnt/etc/apt/apt.conf
#Recommends are as of now still abused in many packages
APT::Install-Recommends "0";
APT::Install-Suggests "0";
EOF

# Repositorios mais rapidos
rm /mnt/etc/apt/sources.list
# mkdir -pv /mnt/etc/apt/sources.d/
touch /mnt/etc/apt/sources.list.d/{debian.list,various.list}

apt install lsb-release
CODENAME=$(lsb_release --codename --short)
cat > /etc/apt/sources.list << HEREDOC
deb https://deb.debian.org/debian/ $CODENAME main contrib non-free
deb-src https://deb.debian.org/debian/ $CODENAME main contrib non-free

deb https://security.debian.org/debian-security $CODENAME-security main contrib non-free
deb-src https://security.debian.org/debian-security $CODENAME-security main contrib non-free

deb https://deb.debian.org/debian/ $CODENAME-updates main contrib non-free
deb-src https://deb.debian.org/debian/ $CODENAME-updates main contrib non-free
HEREDOC
# Hostname
HOSTNAME=devuan
cat <<EOF >/mnt/etc/hostname
$HOSTNAME
EOF

# Hosts
touch /mnt/etc/hosts
cat > /etc/hosts << HEREDOC
127.0.0.1 localhost
127.0.1.1 nitro

# The following lines are desirable for IPv6 capable hosts
::1     localhost ip6-localhost ip6-loopback
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
HEREDOC

# fstab
UEFI_UUID=$(blkid -s UUID -o value /dev/sda1)
ROOT_UUID=$(blkid -s UUID -o value /dev/sda2)

echo $UEFI_UUID
echo $ROOT_UUID
# echo $SWAP_UUID
# echo $HOME_UUID

touch /mnt/etc/fstab
cat <<EOF >/mnt/etc/fstab
# <file system> <dir> <type> <options> <dump> <pass>

### ROOTFS ###
UUID=$ROOT_UUID   /               btrfs rw,$BTRFS_OPTS,subvol=@                         0 0
UUID=$ROOT_UUID   /.snapshots     btrfs rw,$BTRFS_OPTS,subvol=@snapshots                0 0
UUID=$ROOT_UUID   /var/log        btrfs rw,$BTRFS_OPTS,subvol=@var_log                  0 0
UUID=$ROOT_UUID   /var/cache/apt  btrfs rw,$BTRFS_OPTS,subvol=@var_cache_xbps           0 0

### HOME_FS ###
# UUID=$HOME_UUID /home           btrfs rw,$BTRFS_OPTS,subvol=@home                     0 0
UUID=$ROOT_UUID   /home           btrfs rw,$BTRFS_OPTS,subvol=@home                     0 0

### EFI ###
# UUID=$UEFI_UUID /boot/efi       vfat rw,noatime,nodiratime,umask=0077,fmask=0022,dmask=0022,codepage=437,iocharset=iso8859-1,shortname=mixed,utf8,errors=remount-ro  0 2
UUID=$UEFI_UUID   /boot/efi       vfat rw,defaults,noatime,nodiratime,umask=0077        0 2

### Swap ###
#UUID=$SWAP_UUID  none            swap defaults,noatime                                 0 0

### Tmp ###
# tmpfs         /tmp              tmpfs defaults,nosuid,nodev,noatime                   0 0
tmpfs           /tmp              tmpfs noatime,mode=1777,nosuid                        0 0
EOF

# antix-archive-keyring
# devuan-keyring

# Some base packages
chroot /mnt apt install dracut manpages dbus devuan-keyring bash zstd locales btrfs-progs build-essential grub-efi-amd64 wget curl sysfsutils chrony network-manager iwd linux-image-amd64 linux-headers-amd64 firmware-linux multipath-tools --no-install-recommends -y

chroot /mnt apt update runit --no-install-recommends -y

# Init System
chroot /mnt apt install

# Utils
chroot /mnt apt install bash-completion bzip2 man-db gptfdisk dosfstools mtools p7zip neofetch fzf bat duf --no-install-recommends -y

# Optimizations
chroot /mnt apt install earlyoom powertop thermald irqbalance --yes


zsh stterm rxvt-unicode-256color

# Microcode
chroot /mnt apt install intel-microcode --no-install-recommends -y

# Audio, Bluetooth and wifi
chroot /mnt apt install iwd rfkill --no-install-recommends -y
 
# Umount
# for dir in dev proc sys run; do
#         umount --rbind /$dir /mnt/$dir
#         umount --make-rslave /mnt/$dir
# done

# copia o arquivo de resolv para o /mnt
# cp -v /etc/resolv.conf /mnt/etc/

cat <<EOF > /mnt/etc/resolv.conf 
nameserver 8.8.8.8
nameserver 8.8.4.4
nameserver 1.1.1.1
EOF

# Locales
chroot /mnt echo "America/Sao_Paulo" > /mnt/etc/timezone && \
                dpkg-reconfigure -f noninteractive tzdata && \
                sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
                sed -i -e 's/# pt_BR.UTF-8 UTF-8/pt_BR.UTF-8 UTF-8/' /etc/locale.gen && \
                echo 'LANG="en_US.UTF-8"'>/etc/default/locale && \
                dpkg-reconfigure --frontend=noninteractive locales && \
                update-locale LANG=en_US.UTF-8 && \
                localedef -i en_US -f UTF-8 en_US.UTF-8


# Set bash as default
chroot /mnt chsh -s /usr/bin/bash root

# Define user and root password
chroot /mnt sh -c 'echo "root:200291" | chpasswd -c SHA512'
chroot /mnt useradd juca -m -c "Reinaldo P JR" -s /bin/bash
chroot /mnt sh -c 'echo "juca:200291" | chpasswd -c SHA512'
chroot /mnt usermod -aG wheel,floppy,audio,video,optical,kvm,lp,storage,cdrom,xbuilder,input juca
chroot /mnt sed -i 's/^#\s*\(%wheel\s*ALL=(ALL)\)/\1/' /etc/sudoers
chroot /mnt sed -i 's/^#\s*\(%wheel\s*ALL=(ALL)\s*NOPASSWD:\s*ALL\)/\1/' /etc/sudoers
chroot /mnt usermod -a -G socklog juca


# install sudo
chroot /mnt apt install sudo -y
chroot /mnt usermod -aG sudo juca
