#!/usr/bin/env bash
set -euo pipefail
IFS=$'\n\t'

# umount -Rv /mnt
apt update && apt install debootstrap btrfs-progs lsb-release wget -y
# sgdisk -Z /dev/sda


#######################
## Global Variables ##
#######################
# HOSTNAME="nitro"
HOSTNAME="devtest"
USERNAME="juca"
FULLNAME="Reinaldo P JR"
ARCH="amd64"
CODENAME="bookworm"
# DRIVE="/dev/nvme0n1"
DRIVE="/dev/vda"
MNT="/mnt"

# DRIVE="/dev/nvme0n1"
# SYSTEM_PART="${DRIVE}p2"
# EFI_PART="${DRIVE}p3"
# ROOT_PART="${DRIVE}p4"
# # HOME_PART="${DRIVE}p5"
# WINDOWS_PART="${DRIVE}p7"
# MISC_PART="${DRIVE}p8"

SYSTEM_PART="${DRIVE}2"
EFI_PART="${DRIVE}3"
ROOT_PART="${DRIVE}4"
# HOME_PART="${DRIVE}5"
WINDOWS_PART="${DRIVE}7"
MISC_PART="${DRIVE}8"

ROOT_LABEL="Debian"
EFI_LABEL="ESP"
SYSTEM_LABEL="SYSTEM"
WINDOWS_LABEL="Windows 11"
MISC_LABEL="SharedData"
SWAP_LABEL="swap"

BTRFS_OPTS="noatime,ssd,compress-force=zstd:8,space_cache=v2,nodatacow,commit=120,discard=async"
BTRFS_OPTS_HOME="noatime,ssd,compress-force=zstd:15,space_cache=v2,nodatacow,commit=120,discard=async"

##########################
## Partitioning & FS ##
##########################
partition_disk() {
  echo "📐 Partitioning $DRIVE …"

  # ─── Config (all in MiB) ─────────────────────────────────────────
  local bios_size=1
  local system_size=1024      # 1G
  local efi_size=600          # 600M
  local root_size=20480       # 20G
  local msr_size=16           # 16M
  # local win_data_size=10240 # 10G
  local win_data_size=5120    # 15G
  # local swap_size=8192
  # local home_size=40960

  # ─── State ────────────────────────────────────────────────────────
  local start=1
  local end=0
  local PART_IDX=1

  # ─── Initialize GPT & Unit ───────────────────────────────────────
  parted --script "$DRIVE" mklabel gpt
  parted --script "$DRIVE" unit MiB

  # ─── Helper Function ──────────────────────────────────────────────
  create_part() {
    local label=$1 size=$2
    end=$(( start + size ))
    parted --script "$DRIVE" mkpart primary "$start" "$end"
    parted --script "$DRIVE" name      "$PART_IDX" "$label"
    start=$end
    PART_IDX=$(( PART_IDX + 1 ))
  }

  # ─── Build Partitions ──────────────────────────────────────────────
  create_part BIOS_BOOT       $bios_size
  parted --script "$DRIVE" set 1 bios_grub on

  create_part SYSTEM_RESERVED $system_size

  create_part EFI_SYSTEM      $efi_size
  parted --script "$DRIVE" set 3 boot on
  parted --script "$DRIVE" set 3 esp on

  create_part ROOT            $root_size
  create_part MSR             $msr_size
  create_part WINDOWS_DATA    $win_data_size

  # create_part SWAP          $swap_size
  # create_part HOME          $home_size

  # ─── Final Catch-All ───────────────────────────────────────────────
  parted --script "$DRIVE" mkpart primary "$start" 100%
  parted --script "$DRIVE" name      "$PART_IDX" "$MISC_LABEL"

  # ─── Verify ────────────────────────────────────────────────────────
  echo
  parted --script "$DRIVE" print
}



# format_filesystems() {
#   echo "🧼 Formatting partitions..."
#   mkfs.ext4 -L "$SYSTEM_LABEL" "${DRIVE}p2"
#   mkfs.fat -F32 -n "$EFI_LABEL" "${DRIVE}p3"
#   mkfs.btrfs -f -L "$ROOT_LABEL" "${DRIVE}p4"
#   mkfs.ntfs -Q -f -L "$WINDOWS_LABEL" "${DRIVE}p6"
#   mkfs.exfat -n "$MISC_LABEL" "${DRIVE}p7"
# }

format_filesystems() {
  echo "🧼 Formatting partitions..."
  mkfs.ext4 -L "$SYSTEM_LABEL" "${DRIVE}2"
  mkfs.fat -F32 -n "$EFI_LABEL" "${DRIVE}3"
  mkfs.btrfs -f -L "$ROOT_LABEL" "${DRIVE}4"
  mkfs.ntfs -Q -f -L "$WINDOWS_LABEL" "${DRIVE}6"
  mkfs.exfat -n "$MISC_LABEL" "${DRIVE}7"
}

# /dev/nvme0n1
# create_subvolumes() {
#   echo "🗂️ Creating Btrfs subvolumes..."
#   mount "${DRIVE}p4" "$MNT"
#   for sv in @root @home @opt @nix @snapshots @cache @log @tmp @spool @libvirt @gdm; do
#     btrfs subvolume create "$MNT/$sv"
#   done
#   umount -R "$MNT"
# }

# /dev/sda
create_subvolumes() {
  echo "🗂️ Creating Btrfs subvolumes..."
  mount "${DRIVE}4" "$MNT"
  for sv in @root @home @opt @nix @snapshots @cache @log @tmp @spool @libvirt @gdm; do
    btrfs subvolume create "$MNT/$sv"
  done
  umount -R "$MNT"
}

mount_subvolumes() {
  echo "📦 Mounting subvolumes..."
  mount -o $BTRFS_OPTS,subvol=@root LABEL=$ROOT_LABEL $MNT
  mkdir -p $MNT/{boot,home,opt,nix,.snapshots,var/{tmp,spool,log,cache,lib/{libvirt,gdm}}}
  mount -o $BTRFS_OPTS,subvol=@home LABEL=$ROOT_LABEL $MNT/home
  mount -o $BTRFS_OPTS_HOME,subvol=@nix LABEL=$ROOT_LABEL $MNT/nix
  mount -o $BTRFS_OPTS_HOME,subvol=@opt LABEL=$ROOT_LABEL $MNT/opt
  mount -o $BTRFS_OPTS,subvol=@gdm LABEL=$ROOT_LABEL $MNT/var/lib/gdm
  mount -o $BTRFS_OPTS,subvol=@libvirt LABEL=$ROOT_LABEL $MNT/var/lib/libvirt
  mount -o $BTRFS_OPTS,subvol=@log LABEL=$ROOT_LABEL $MNT/var/log
  mount -o $BTRFS_OPTS,subvol=@spool LABEL=$ROOT_LABEL $MNT/var/spool
  mount -o $BTRFS_OPTS,subvol=@tmp LABEL=$ROOT_LABEL $MNT/var/tmp
  mount -o $BTRFS_OPTS,subvol=@cache LABEL=$ROOT_LABEL $MNT/var/cache
  mount -o $BTRFS_OPTS_HOME,subvol=@snapshots LABEL=$ROOT_LABEL $MNT/.snapshots

  mount LABEL=$SYSTEM_LABEL $MNT/boot
  mkdir -pv $MNT/boot/efi
  mount -t vfat -o defaults,noatime,nodiratime LABEL=$EFI_LABEL $MNT/boot/efi
}

##########################
## Bootstrap System ##
##########################
bootstrap_debian() {
  echo "📦 Bootstrapping Debian..."
  debootstrap \
    --variant=minbase \
    --include=apt,bash,btrfs-compsize,btrfs-progs,udisks2-btrfs,duperemove,zsh,nano,extrepo,cpio,net-tools,locales,console-setup,perl-openssl-defaults,apt-utils,dosfstools,debconf-utils,wget,tzdata,keyboard-configuration,zstd,dracut,ca-certificates,debian-archive-keyring,xz-utils,kmod,gdisk,ncurses-base,systemd,udev,ifupdown,init,iproute2,iputils-ping \
    --arch=$ARCH \
    $CODENAME $MNT \
    "http://debian.c3sl.ufpr.br/debian/ $CODENAME contrib non-free non-free-firmware"
}

prepare_chroot() {
  echo "🔗 Binding virtual filesystems..."
  for fs in dev proc sys run; do
    mount --rbind /$fs $MNT/$fs
    mount --make-rslave $MNT/$fs
  done
  mount -t devpts devpts $MNT/dev/pts
}

misc_configurations(){
  cat <<EOF >/mnt/etc/hostname
${HOSTNAME}
EOF

  touch /mnt/etc/hosts
  cat <<EOF >/mnt/etc/hosts
# Loopback entries; do not change.
127.0.0.1   localhost
127.0.1.1   ${HOSTNAME}.localdomain ${HOSTNAME}
# The following lines are desirable for IPv6 capable hosts
::1         localhost ip6-localhost ip6-loopback
ff02::1     ip6-allnodes
ff02::2     ip6-allrouters
# See hosts(5) for proper format and other examples:
# 192.168.1.10 foo.example.org foo
# 192.168.1.13 bar.example.org bar
EOF

  touch /mnt/etc/host.conf
  cat <<EOF >/mnt/etc/host.conf
multi on
EOF

  touch /mnt/etc/nsswitch.conf
  cat <<EOF >/mnt/etc/nsswitch.conf
# Generated by authselect
# Do not modify this file manually, use authselect instead. Any user changes will be overwritten.
# You can stop authselect from managing your configuration by calling 'authselect opt-out'.
# See authselect(8) for more details.

# In order of likelihood of use to accelerate lookup.
passwd:     files systemd
shadow:     files systemd
group:      files [SUCCESS=merge] systemd
hosts:      files myhostname mdns4_minimal [NOTFOUND=return] resolve [!UNAVAIL=return] dns
services:   files
netgroup:   files
automount:  files

aliases:    files
ethers:     files
gshadow:    files systemd
networks:   files dns
protocols:  files
publickey:  files
rpc:        files
EOF

  BOOT_UUID=$(blkid -s UUID -o value $SYSTEM_PART)
  ESP_UUID=$(blkid -s UUID -o value $EFI_PART)
  ROOT_UUID=$(blkid -s UUID -o value $ROOT_PART)
  # HOME_UUID=$(blkid -s UUID -o value $HOME_PART)

  touch /mnt/etc/fstab

### Swap ###
# UUID="${SWAP_UUID}"     none                swap      defaults,noatime                           0     0
# LABEL="${SWAP_LABEL}"   none                swap      defaults,noatime                           0     0

  cat <<EOF >/mnt/etc/fstab
# <file system>           <dir>               <type>    <options>                               <dump> <pass>

### ROOTFS ###
# UUID="${ROOT_UUID}"     /                   btrfs     rw,$BTRFS_OPTS,subvol=@root                0     0
LABEL="${ROOT_LABEL}"     /                   btrfs     rw,$BTRFS_OPTS,subvol=@root                0     0

# UUID="${ROOT_UUID}"     /.snapshots         btrfs     rw,$BTRFS_OPTS,subvol=@snapshots           0     0
LABEL="${ROOT_LABEL}"     /.snapshots         btrfs     rw,$BTRFS_OPTS,subvol=@snapshots           0     0

# UUID="${ROOT_UUID}"     /nix                btrfs     rw,$BTRFS_OPTS_HOME,subvol=@nix            0     0
LABEL="${ROOT_LABEL}"     /nix                btrfs     rw,$BTRFS_OPTS_HOME,subvol=@nix            0     0

# UUID="${ROOT_UUID}"     /var/log            btrfs     rw,$BTRFS_OPTS,subvol=@log                 0     0
LABEL="${ROOT_LABEL}"     /var/log            btrfs     rw,$BTRFS_OPTS,subvol=@log                 0     0

# UUID="${ROOT_UUID}"     /var/tmp            btrfs     rw,$BTRFS_OPTS,subvol=@tmp                 0     0
LABEL="${ROOT_LABEL}"     /var/tmp            btrfs     rw,$BTRFS_OPTS,subvol=@tmp                 0     0

# UUID="${ROOT_UUID}"     /var/spool          btrfs     rw,$BTRFS_OPTS,subvol=@spool               0     0
LABEL="${ROOT_LABEL}"     /var/spool          btrfs     rw,$BTRFS_OPTS,subvol=@spool               0     0

# UUID="${ROOT_UUID}"     /var/cache          btrfs     rw,$BTRFS_OPTS,subvol=@cache               0     0
LABEL="${ROOT_LABEL}"     /var/cache          btrfs     rw,$BTRFS_OPTS,subvol=@cache               0     0

# UUID="${ROOT_UUID}"     /var/lib/libvirt    btrfs     rw,$BTRFS_OPTS,subvol=@libvirt             0     0
LABEL="${ROOT_LABEL}"     /var/lib/libvirt    btrfs     rw,$BTRFS_OPTS,subvol=@libvirt             0     0

# UUID="${ROOT_UUID}"     /var/lib/gdm        btrfs     rw,$BTRFS_OPTS,subvol=@gdm                 0     0
LABEL="${ROOT_LABEL}"     /var/lib/gdm        btrfs     rw,$BTRFS_OPTS,subvol=@gdm                 0     0

# UUID="${ROOT_UUID}"     /opt                btrfs     rw,$BTRFS_OPTS,subvol=@opt                 0     0
LABEL="${ROOT_LABEL}"     /opt                btrfs     rw,$BTRFS_OPTS,subvol=@opt                 0     0

### HOME_FS ###
# UUID="${ROOT_UUID}"     /home               btrfs     rw,$BTRFS_OPTS_HOME,subvol=@home           0     0
LABEL="${ROOT_LABEL}"     /home               btrfs     rw,$BTRFS_OPTS_HOME,subvol=@home           0     0

### BOOT ###
# UUID="${BOOT_UUID}"     /boot               ext4      rw,relatime                                0     1
LABEL="${SYSTEM_LABEL}"   /boot               ext4      rw,relatime                                0     1

### EFI ###
# UUID="${ESP_UUID}"      /boot/efi           vfat      defaults,noatime,nodiratime                0     2
LABEL="${EFI_LABEL}"      /boot/efi           vfat      defaults,noatime,nodiratime                0     2


#Swapfile
# LABEL="${ROOT_UUID}"    none                swap      defaults,noatime
# /swap/swapfile          none                swap      sw                                         0     0

### Tmp ###
# tmpfs                   /tmp                tmpfs     defaults,nosuid,nodev,noatime              0     0
# tmpfs                   /tmp                tmpfs     noatime,mode=1777,nosuid,nodev             0     0
EOF
}

optimize_package_manager() {
  mkdir -pv /mnt/etc/apt/apt.conf.d
  touch /mnt/etc/apt/apt.conf.d/99norecommends
  cat >/mnt/etc/apt/apt.conf.d/99norecommends <<HEREDOC
#Recommends are as of now abused in many packages
APT::Install-Recommends "0";        # Prevents auto-installing recommended packages
APT::Install-Suggests "0";          # Skips suggested packages (often unnecessary)

# // no install recommends/suggests packages
# APT::Install-Recommends "false";
# APT::Install-Suggests "false";

### For install testing packages
#APT::Default-Release "testing";    # Commented out, but useful if you want to prioritize testing selectively
HEREDOC

  touch /mnt/etc/apt/apt.conf.d/99assumeyes
  cat >/mnt/etc/apt/apt.conf.d/99assumeyes <<HEREDOC
# assume yes install packages
// assume yes install packages
APT::Get::Assume-Yes "true";
HEREDOC

# echo 'APT::Default-Release "stable";' | sudo tee /etc/apt/apt.conf.d/99default-release
  echo 'APT::Default-Release "stable";' | tee /mnt/etc/apt/apt.conf.d/99default-release

  mkdir -pv /mnt/etc/apt/preferences.d

  touch /mnt/etc/apt/preferences.d/99stable.pref
  touch /mnt/etc/apt/preferences.d/50testing.pref
  touch /mnt/etc/apt/preferences.d/10unstable.pref
  touch /mnt/etc/apt/preferences.d/1experimental.pref

  cat >/mnt/etc/apt/preferences.d/99stable.pref <<HEREDOC
# 500 <= P < 990: causes a version to be installed unless there is a
# version available belonging to the target release or the installed
# version is more recent

Package: *
Pin: release a=stable
Pin-Priority: 900
HEREDOC

  cat >/mnt/etc/apt/preferences.d/50testing.pref <<HEREDOC
# 100 <= P < 500: causes a version to be installed unless there is a
# version available belonging to some other distribution or the installed
# version is more recent

Package: *
Pin: release a=testing
Pin-Priority: 400
HEREDOC

  cat >/mnt/etc/apt/preferences.d/10unstable.pref <<HEREDOC
# 0 < P < 100: causes a version to be installed only if there is no
# installed version of the package

Package: *
Pin: release a=unstable
Pin-Priority: 50
HEREDOC

  cat >/mnt/etc/apt/preferences.d/1experimental.pref <<HEREDOC
# 0 < P < 100: causes a version to be installed only if there is no
# installed version of the package

Package: *
Pin: release a=experimental
Pin-Priority: 1
HEREDOC
}

add_repositories() {
    echo "Adding repositories to Debian..."
    rm $MNT/etc/apt/sources.list
    touch $MNT/etc/apt/sources.list.d/{debian.list,others.list}
    cat >$MNT/etc/apt/sources.list.d/debian.list <<HEREDOC
####################
### Debian repos ###
####################

deb https://deb.debian.org/debian/ $CODENAME main contrib non-free non-free-firmware
deb-src https://deb.debian.org/debian/ $CODENAME main contrib non-free non-free-firmware

#deb https://security.debian.org/debian-security $CODENAME-security main contrib non-free non-free-firmware
#deb-src https://security.debian.org/debian-security $CODENAME-security main contrib non-free non-free-firmware

deb https://deb.debian.org/debian/ $CODENAME-updates main contrib non-free non-free-firmware
deb-src https://deb.debian.org/debian/ $CODENAME-updates main contrib non-free non-free-firmware

deb https://deb.debian.org/debian/ $CODENAME-backports main contrib non-free non-free-firmware
deb-src https://deb.debian.org/debian/ $CODENAME-backports main contrib non-free non-free-firmware

#######################
### Debian unstable ###
#######################

##Debian Testing
#deb http://deb.debian.org/debian/ testing main contrib non-free non-free-firmware
#deb-src http://deb.debian.org/debian/ testing main contrib non-free non-free-firmware


##Debian Unstable
#deb http://deb.debian.org/debian/ unstable main
##Debian Experimental
#deb http://deb.debian.org/debian/ experimental main

###################
### Tor com apt ###
###################

#deb tor+http://vwakviie2ienjx6t.onion/debian stretch main
#deb-src tor+http://vwakviie2ienjx6t.onion/debian stretch main

#deb tor+http://sgvtcaew4bxjd7ln.onion/debian-security stretch/updates main
#deb-src tor+http://sgvtcaew4bxjd7ln.onion/debian-security stretch/updates main

#deb tor+http://vwakviie2ienjx6t.onion/debian stretch-updates main
#deb-src tor+http://vwakviie2ienjx6t.onion/debian stretch-updates main
HEREDOC

    chroot $MNT apt update
    chroot $MNT apt upgrade --yes
}

configure_locales() {
  chroot /mnt echo "America/Sao_Paulo" >/mnt/etc/timezone
  chroot /mnt dpkg-reconfigure -f noninteractive tzdata
  sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /mnt/etc/locale.gen
  sed -i -e 's/# pt_BR.UTF-8 UTF-8/pt_BR.UTF-8 UTF-8/' /mnt/etc/locale.gen
  chroot /mnt dpkg-reconfigure -f noninteractive locales
  chroot /mnt apt update
  touch /mnt/etc/vconsole.conf
  echo 'KEYMAP="br-abnt2"' >/mnt/etc/vconsole.conf
  echo 'KEYMAP_TOGGLE="us-intl"' >> /mnt/etc/vconsole.conf

  chroot /mnt apt update
}

##########################
## System Configuration ##
##########################
configure_base() {
  echo "⚙️ Configuring system…"

  chroot $MNT apt update
  chroot $MNT apt purge initramfs-tools initramfs-tools-core -y
  chroot $MNT apt install linux-image-amd64 firmware-linux-free firmware-linux-nonfree firmware-iwlwifi firmware-realtek linux-headers-amd64 -y
  chroot $MNT apt install network-manager iwd sudo neovim locales tzdata bash-completion x11-utils xserver-xorg xinit -y
}

setup_dracut() {
  echo "🧪 Configuring Dracut…"

  mkdir -p $MNT/etc/dracut.conf.d
  cat <<EOF > $MNT/etc/dracut.conf.d/10-nitro.conf
hostonly="yes"
hostonly_cmdline="yes"
compress="zstd --ultra -14"
#add_dracutmodules+=" systemd tpm2 crypt resume btrfs "
add_dracutmodules+=" systemd btrfs "
# force_drivers+=" nvme ahci i915 iwlwifi nvidia nvidia_modeset nvidia_uvm nvidia_drm "
force_drivers+=" ahci "
filesystems+=" btrfs ext4 vfat "
# early_microcode="yes"
kernel_cmdline="rootflags=subvol=@root rw quiet splash"
EOF

  chroot $MNT dracut --kver "$(ls $MNT/lib/modules | head -n1)" --force
}

finalize_users() {
  echo "👤 Creating users and setting passwords…"
  chroot $MNT sh -c 'echo "root:200291" | chpasswd -c SHA512'
  chroot $MNT useradd $USERNAME -m -c "$FULLNAME" -s /bin/bash
  chroot $MNT sh -c 'echo "juca:200291" | chpasswd -c SHA512'
  chroot $MNT usermod -aG sudo $USERNAME
}

#install_video_graphics() {
#####################################
#### intel Hardware Acceleration ####
#####################################
# chroot /mnt apt install intel-media-va-driver-non-free libva2 vainfo intel-gpu-tools firmware-misc-nonfree mesa-va-drivers --no-install-recommends --yes

#}

install_grub() {
  echo "🧰 Installing GRUB…"
  chroot $MNT apt install grub-efi-amd64 efibootmgr os-prober -y
  #chroot $MNT grub-install --target=x86_64-efi --bootloader-id="$ROOT_LABEL" --efi-directory=/boot/efi --no-nvram --removable --recheck
  chroot $MNT grub-install --target=x86_64-efi --bootloader-id="$ROOT_LABEL" --efi-directory=/boot/efi --no-nvram --removable --recheck
  chroot $MNT update-grub
}

####################
## MAIN FUNCTION ##
####################
main() {
  partition_disk
  format_filesystems
  create_subvolumes
  mount_subvolumes
  bootstrap_debian
  prepare_chroot
  optimize_package_manager
  configure_locales
  add_repositories
  configure_locales
  misc_configurations
  configure_base
  setup_dracut
  finalize_users
  install_grub

  echo "✅ Installation complete. Ready to reboot!"
}

main "$@"
