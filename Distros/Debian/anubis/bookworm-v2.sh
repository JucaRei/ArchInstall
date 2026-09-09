#!/usr/bin/env bash
set -euo pipefail

# Atualiza pacotes e instala dependências mínimas para o script rodar
apt update
apt install -y gdisk debootstrap btrfs-progs lsb-release wget curl gpg ca-certificates arch-install-scripts

# Define caminhos do drive e partições (ajuste se necessário para o seu hardware)
DRIVE="/dev/sda"
SYSTEM_PART="${DRIVE}2"  # Partição /boot (ext4)
EFI_PART="${DRIVE}3"     # Partição EFI (FAT32)
ROOT_PART="${DRIVE}4"    # Partição root (Btrfs com subvolumes)

# Rótulos para as partições (usados no fstab para montagem por label)
ROOT_LABEL="Linux"
SYSTEM_LABEL="BOOT"
EFI_LABEL="ESP"

# Opções otimizadas para Btrfs (compressão, noatime para performance em SSD antigo)
BTRFS_OPTS="noatime,ssd,compress=zstd:3,space_cache=v2,commit=120,discard=async"
NIX_OPTS="noatime,ssd,compress=zstd:3,space_cache=v2,commit=20,discard=async"
BTRFS_OPTS2="noatime,ssd,compress=zstd:3,space_cache=v2,commit=120,discard=async"

# Ponto de montagem temporário para a instalação
MOUNTPOINT="/mnt"

# Particionamento: Apaga tudo e cria partições novas (DESTRUTIVO! Confirme o drive)
echo "🧱 Wiping and creating partitions on ${DRIVE} (DESTRUCTIVE!)"
sgdisk --zap-all "${DRIVE}"
sleep 1
parted -s -a optimal "${DRIVE}" mklabel gpt
sgdisk -n 1:0:+1M -t 1:EF02 -c 1:"BIOS BOOT" "${DRIVE}"      # Partição BIOS boot (1M, para compatibilidade GRUB)
sgdisk -n 2:0:+1G -t 2:8301 -c 2:"SYSTEM RESERVED" "${DRIVE}" # Partição /boot (1G, ext4)
sgdisk -n 3:0:+600M -t 3:EF00 -c 3:"EFI SYSTEM" "${DRIVE}"    # Partição EFI (600M, FAT32)
sgdisk -n 4:0:0 -t 4:8300 -c 4:"Linux Root" "${DRIVE}"        # Partição root (restante, Btrfs)
sgdisk -p "${DRIVE}"

# Formatação das partições
echo "🧼 Formatting partitions..."
mkfs.ext4 -F -L "${SYSTEM_LABEL}" "${SYSTEM_PART}"  # Formata /boot como ext4
mkfs.fat -F32 -n "${EFI_LABEL}" "${EFI_PART}"       # Formata EFI como FAT32
mkfs.btrfs -f -L "${ROOT_LABEL}" "${ROOT_PART}"     # Formata root como Btrfs

# Cria subvolumes Btrfs no root (estrutura separada para snapshots, home, etc.)
echo "🎯 Creating btrfs subvolumes..."
mkdir -p "${MOUNTPOINT}"
mount "${ROOT_PART}" "${MOUNTPOINT}"
for sv in @ @home @opt @nix @gdm @libvirt @spool @log @tmp @apt @snapshots @swap; do
    btrfs subvolume create "${MOUNTPOINT}/${sv}"  # @ é o subvolume root padrão
done
umount -Rv "${MOUNTPOINT}"

# Monta subvolumes com opções otimizadas
echo "📦 Mounting subvolumes..."
mount -o "${BTRFS_OPTS2},subvol=@" "/dev/disk/by-label/${ROOT_LABEL}" "${MOUNTPOINT}"
mkdir -pv "${MOUNTPOINT}/"{boot,home,opt,nix,.snapshots,var/{tmp,spool,log,cache/apt,lib/{gdm,libvirt}},swap}
mount -o "${BTRFS_OPTS},subvol=@home" "/dev/disk/by-label/${ROOT_LABEL}" "${MOUNTPOINT}/home"
mount -o "${BTRFS_OPTS},subvol=@opt" "/dev/disk/by-label/${ROOT_LABEL}" "${MOUNTPOINT}/opt"
mount -o "${BTRFS_OPTS},subvol=@gdm" "/dev/disk/by-label/${ROOT_LABEL}" "${MOUNTPOINT}/var/lib/gdm"
mount -o "${BTRFS_OPTS},subvol=@libvirt" "/dev/disk/by-label/${ROOT_LABEL}" "${MOUNTPOINT}/var/lib/libvirt"
mount -o "${BTRFS_OPTS2},subvol=@log" "/dev/disk/by-label/${ROOT_LABEL}" "${MOUNTPOINT}/var/log"
mount -o "${NIX_OPTS},subvol=@nix" "/dev/disk/by-label/${ROOT_LABEL}" "${MOUNTPOINT}/nix"
mount -o "${BTRFS_OPTS},subvol=@spool" "/dev/disk/by-label/${ROOT_LABEL}" "${MOUNTPOINT}/var/spool"
mount -o "${BTRFS_OPTS2},subvol=@tmp" "/dev/disk/by-label/${ROOT_LABEL}" "${MOUNTPOINT}/var/tmp"
mount -o "${BTRFS_OPTS},subvol=@apt" "/dev/disk/by-label/${ROOT_LABEL}" "${MOUNTPOINT}/var/cache/apt"
mount -o "${BTRFS_OPTS},subvol=@snapshots" "/dev/disk/by-label/${ROOT_LABEL}" "${MOUNTPOINT}/.snapshots"
mount -o "${BTRFS_OPTS2},subvol=@swap" "/dev/disk/by-label/${ROOT_LABEL}" "${MOUNTPOINT}/swap"

# Monta /boot e EFI
echo "⏏️ Mounting boot and EFI..."
mount "/dev/disk/by-label/${SYSTEM_LABEL}" "${MOUNTPOINT}/boot"
mkdir -pv "${MOUNTPOINT}/boot/efi"
mount -t vfat -o defaults,noatime,nodiratime "/dev/disk/by-label/${EFI_LABEL}" "${MOUNTPOINT}/boot/efi"

# Gera UUIDs e cria fstab (usa labels para montagem; inclui entrada para swapfile)
BOOT_UUID=$(blkid -s UUID -o value $SYSTEM_PART)
ESP_UUID=$(blkid -s UUID -o value $EFI_PART)
ROOT_UUID=$(blkid -s UUID -o value $ROOT_PART)
echo "📝 Generating /etc/fstab..."
mkdir -p "${MOUNTPOINT}/etc"
cat > "${MOUNTPOINT}/etc/fstab" <<EOF
LABEL=${SYSTEM_LABEL}   /boot            ext4    defaults,noatime 0 2
LABEL=${EFI_LABEL}      /boot/efi        vfat    defaults,noatime,nodiratime 0 1
LABEL=${ROOT_LABEL}     /                btrfs   ${BTRFS_OPTS2},subvol=@ 0 1
LABEL=${ROOT_LABEL}     /home            btrfs   ${BTRFS_OPTS},subvol=@home 0 2
LABEL=${ROOT_LABEL}     /opt             btrfs   ${BTRFS_OPTS},subvol=@opt 0 2
LABEL=${ROOT_LABEL}     /var/lib/gdm     btrfs   ${BTRFS_OPTS},subvol=@gdm 0 2
LABEL=${ROOT_LABEL}     /var/lib/libvirt btrfs   ${BTRFS_OPTS},subvol=@libvirt 0 2
LABEL=${ROOT_LABEL}     /var/log         btrfs   ${BTRFS_OPTS2},subvol=@log 0 2
LABEL=${ROOT_LABEL}     /nix             btrfs   ${NIX_OPTS},subvol=@nix 0 2
LABEL=${ROOT_LABEL}     /var/spool       btrfs   ${BTRFS_OPTS},subvol=@spool 0 2
LABEL=${ROOT_LABEL}     /var/tmp         btrfs   ${BTRFS_OPTS2},subvol=@tmp 0 2
LABEL=${ROOT_LABEL}     /var/cache/apt   btrfs   ${BTRFS_OPTS},subvol=@apt 0 2
LABEL=${ROOT_LABEL}     /.snapshots      btrfs   ${BTRFS_OPTS},subvol=@snapshots 0 2
LABEL=${ROOT_LABEL}     /swap            btrfs   ${BTRFS_OPTS2},subvol=@swap 0 2
/swap/swapfile          none             swap    sw 0 0  # Entrada para swapfile de 8G
EOF

echo "✅ Partitions ready. Proceeding to debootstrap..."

# Variáveis para Debian (arquitetura, codename, usuário e hostname)
Architecture="amd64"
CODENAME="trixie"
username="juca"
hostname="anubis"

# Debootstrap: Instala base mínima do Debian com pacotes essenciais
debootstrap \
  --arch=${Architecture} \
  --variant=minbase \
  --no-check-gpg \
  --include=apt,bash,cpio,kmod,initramfs-tools,dkms,neovim,ssh,curl,locales,zstd,apt-utils,btrfs-progs,iputils-ping,dbus-broker,dbus-user-session,libpam-systemd,wget,curl,tzdata,ca-certificates,systemd-sysv,grub-efi-amd64,login,passwd,procps,e2fsprogs,network-manager,sudo \
  ${CODENAME} /mnt \
  http://debian.c3sl.ufpr.br/debian

# Monta filesystems do sistema para chroot
echo "🔧 Mounting system filesystems..."
udevadm trigger
mkdir -p $MOUNTPOINT/{proc,sys,dev/pts}
mount -t proc proc $MOUNTPOINT/proc
mount -t sysfs sysfs $MOUNTPOINT/sys
mount --rbind /dev $MOUNTPOINT/dev
mount -t devpts devpts $MOUNTPOINT/dev/pts
mount -t efivarfs efivarfs $MOUNTPOINT/sys/firmware/efi/efivars

# Atualiza certificados e remove ifupdown (usa NetworkManager)
chroot /mnt update-ca-certificates
chroot /mnt apt install --reinstall ca-certificates -y
chroot /mnt update-ca-certificates
chroot /mnt apt purge ifupdown --yes
mkdir -pv /mnt/etc/network/
cat <<EOF > /mnt/etc/network/interfaces
auto lo
iface lo inet loopback
EOF

# Configura editor padrão (nvim) e corrige pacotes quebrados
chroot /mnt update-alternatives --install /usr/bin/editor editor /usr/bin/nvim 100
chroot /mnt apt --fix-broken install --yes

# Configura environment (sem locale aqui, configurado depois)
touch /mnt/etc/environment
cat <<EOF >/mnt/etc/environment
EOF

# Configura sources.list para Trixie com atualizações e security
rm /mnt/etc/apt/sources.list
mkdir -pv /mnt/etc/apt/sources.list.d
cat >/mnt/etc/apt/sources.list.d/debian.sources <<HEREDOC
Types: deb deb-src
URIs: http://debian.c3sl.ufpr.br/debian/
Suites: trixie
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

Types: deb deb-src
URIs: http://debian.c3sl.ufpr.br/debian/
Suites: trixie-updates
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

Types: deb deb-src
URIs: http://security.debian.org/debian-security/
Suites: trixie-security
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg

Types: deb deb-src
URIs: http://deb.debian.org/debian
Suites: bookworm-backports
Components: main contrib non-free non-free-firmware
Signed-By: /usr/share/keyrings/debian-archive-keyring.gpg
HEREDOC

# Configurações APT (sem recommends, autoremove kernels, etc.)
mkdir -pv /mnt/etc/apt/apt.conf.d
cat >/mnt/etc/apt/apt.conf.d/00recommends <<HEREDOC
APT::Install-Recommends "false";
HEREDOC

cat >/mnt/etc/apt/apt.conf.d/70debconf <<HEREDOC
// Pre-configure all packages with debconf before they are installed.
// DPkg::Pre-Install-Pkgs {"/usr/sbin/dpkg-preconfigure --apt || true";};
HEREDOC

cat >/mnt/etc/apt/apt.conf.d/99suggests <<HEREDOC
APT::Install-Suggests "0";
HEREDOC

cat >/mnt/etc/apt/apt.conf.d/99snapshot <<HEREDOC
Acquire::Check-Valid-Until "false";
HEREDOC

cat >/mnt/etc/apt/apt.conf.d/01autoremove <<HEREDOC
APT
{
  NeverAutoRemove
  {
        "^firmware-linux.*";
        "^linux-firmware$";
  };

  VersionedKernelPackages
  {
        "linux-image";
        "linux-headers";
        "linux-image-extra";
        "linux-modules";
        "linux-modules-extra";
        "linux-signed-image";
        "linux-.*";
        "kfreebsd-.*";
        "kfreebsd-image";
        "kfreebsd-headers";
        "gnumach-image";
        "gnumach-.*";
        ".*-modules";
        ".*-kernel";
        "linux-backports-modules-.*";
        "linux-modules-.*";
        "linux-tools";
  };

  Never-MarkAuto-Sections
  {
        "metapackages";
        "tasks";
  };

  Move-Autobit-Sections
  {
        "oldlibs";
  };
}
HEREDOC

echo 'APT::Default-Release "trixie";' | tee /mnt/etc/apt/apt.conf.d/99default-release

# Preferências APT para pins em releases (Trixie prioritário)
mkdir -pv /mnt/etc/apt/preferences.d
cat >/mnt/etc/apt/preferences.d/99trixie.pref <<HEREDOC
Package: *
Pin: release a=trixie
Pin-Priority: 900
HEREDOC

cat >/mnt/etc/apt/preferences.d/50testing.pref <<HEREDOC
Package: *
Pin: release a=testing
Pin-Priority: 400
HEREDOC

cat >/mnt/etc/apt/preferences.d/10unstable.pref <<HEREDOC
Package: *
Pin: release a=unstable
Pin-Priority: 50
HEREDOC

cat >/mnt/etc/apt/preferences.d/1experimental.pref <<HEREDOC
Package: *
Pin: release a=experimental
Pin-Priority: 1
HEREDOC

cat >/mnt/etc/apt/preferences.d/bookworm-backports <<HEREDOC
# Package: *
# Pin: release n=bookworm-backports
# Pin-Priority: 100
HEREDOC

cat >/mnt/etc/apt/preferences.d/bullseye-kernel <<HEREDOC
# Package: *
# Pin: release n=bullseye
# Pin-Priority: 50

# Package: linux-image-amd64
# Pin: release n=bullseye
# Pin-Priority: 990

# Package: linux-headers-amd64
# Pin: release n=bullseye
# Pin-Priority: 990

# Package: linux-image-5.10*
# Pin: release n=bullseye
# Pin-Priority: 1001
HEREDOC

cat >/mnt/etc/apt/preferences.d/buster-kernel <<HEREDOC
# Package: *
# Pin: release n=buster-backports
# Pin-Priority: 1

# Package: linux-image-5.4*
# Pin: release n=buster-backports
# Pin-Priority: 1001

# Package: linux-headers-5.4*
# Pin: release n=buster-backports
# Pin-Priority: 1001
HEREDOC

# Atualiza e instala pacotes recomendados (firmware Intel, TLP para bateria, etc.)
chroot /mnt apt update
chroot /mnt apt upgrade --yes
chroot /mnt apt install -y intel-microcode firmware-linux-nonfree tlp macfanctld zram-tools
chroot /mnt apt install -y locales

# Configura timezone, locales e teclado console
chroot /mnt echo "America/Sao_Paulo" > /etc/timezone
chroot /mnt dpkg-reconfigure -f noninteractive tzdata
sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /mnt/etc/locale.gen
sed -i -e 's/# pt_BR.UTF-8 UTF-8/pt_BR.UTF-8 UTF-8/' /mnt/etc/locale.gen
chroot /mnt dpkg-reconfigure -f noninteractive locales
echo 'KEYMAP="us"' > /mnt/etc/vconsole.conf
echo 'KEYMAP_TOGGLE="br-abnt2"' >> /mnt/etc/vconsole.conf

# Atualiza e limpa sistema
chroot /mnt apt update
chroot /mnt apt upgrade
chroot /mnt apt autoremove
chroot /mnt apt autoclean

# Cria usuário e define senhas (root e usuário)
chroot /mnt sh -c 'echo "root:200291" | chpasswd -c SHA512'
chroot /mnt useradd $username -m -c "Reinaldo P Jr" -s /bin/bash
chroot /mnt sh -c 'echo "juca:200291" | chpasswd -c SHA512'
chroot /mnt usermod -aG floppy,audio,sudo,video,systemd-journal,lp,cdrom,netdev $username
chroot /mnt usermod -aG sudo $username

# Configura dbus-broker (melhor performance que dbus-daemon)
chroot /mnt systemctl disable dbus-daemon.service
chroot /mnt systemctl enable dbus-broker.service

# Blacklist módulos desnecessários ou problemáticos (watchdog, drivers legados)
mkdir -pv /mnt/etc/modprobe.d
cat <<EOF >/mnt/etc/modprobe.d/blacklist.conf
install iTCO_wdt /bin/true
install iTCO_vendor_support /bin/true

blacklist evbug
blacklist usbmouse
blacklist usbkbd
blacklist eepro100
blacklist de4x5
blacklist eth1394

blacklist garmin_gps

# Blacklist Broadcom WiFi (descomente se precisar de drivers alternativos)
# blacklist bcm43xx
# blacklist brcmsmac
# blacklist wl
# blacklist bcma
# blacklist b43
# blacklist ssb
EOF

# Opções para i915 (graphics Intel) e hid_apple (teclado Mac)
cat <<EOF > /mnt/etc/modprobe.d/i915.conf
options i915 enable_rc6=1 enable_fbc=1 enable_psr=0 fastboot=1
EOF

cat <<EOF > /mnt/etc/modprobe.d/hid_apple.conf
options hid_apple fnmode=2
EOF

# Carrega módulos essenciais no boot (iptables, brcmsmac para WiFi Mac)
mkdir -pv /mnt/etc/modules-load.d
cat <<EOF > /mnt/etc/modules-load.d/iptables.conf
ip6_tables
ip6table_nat
ip_tables
iptable_nat
EOF

cat <<EOF > /mnt/etc/modules-load.d/brcm.conf
brcmsmac
EOF

# Otimizações sysctl (swap agressivo para 2GB RAM, economia de bateria, rede, kernel hardening)
mkdir -pv /mnt/etc/sysctl.d
cat <<EOF >/mnt/etc/sysctl.d/00-swap.conf
vm.vfs_cache_pressure=50
vm.swappiness=60  # Aumentado para usar swap mais cedo (otimiza baixa RAM)
vm.dirty_background_ratio=1  # Reduz dirty pages para economia de bateria
vm.dirty_ratio=3
vm.dirty_expire_centisecs=1500
vm.dirty_writeback_centisecs=1500
vm.overcommit_memory=1
vm.min_free_kbytes=32768  # Reduzido para baixa RAM
vm.laptop_mode=5  # Modo laptop para economia de disco/bateria
EOF

cat <<EOF >/mnt/etc/sysctl.d/99-allow-ping.conf
net.ipv4.ping_group_range=0 2147483647
EOF

cat <<EOF >/mnt/etc/sysctl.d/10-console-messages.conf
kernel.printk=4 4 1 7
EOF

cat <<EOF >/mnt/etc/sysctl.d/99-dmesg.conf
kernel.dmesg_restrict=0
EOF

cat <<EOF >/mnt/etc/sysctl.d/10-ipv6-privacy.conf
net.ipv6.conf.all.use_tempaddr = 2
net.ipv6.conf.default.use_tempaddr = 2
EOF

cat <<EOF >/mnt/etc/sysctl.d/10-kernel-hardening.conf
kernel.kptr_restrict = 1
EOF

cat <<EOF >/mnt/etc/sysctl.d/10-network-security.conf
net.ipv4.conf.default.rp_filter=2
net.ipv4.conf.all.rp_filter=2
EOF

cat <<EOF >/mnt/etc/sysctl.d/10-zeropage.conf
vm.mmap_min_addr = 65536
EOF

# Configura hostname, hosts, host.conf e nsswitch.conf
cat <<EOF >/mnt/etc/hostname
${hostname}
EOF

cat <<EOF >/mnt/etc/hosts
127.0.0.1   localhost
127.0.1.1   ${hostname}.localdomain ${hostname}
::1         localhost ip6-localhost ip6-loopback
EOF

cat <<EOF >/mnt/etc/host.conf
multi on
EOF

cat <<EOF >/mnt/etc/nsswitch.conf
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

# Cria swapfile de 8G no subvolume @swap e calcula offset para resume (hibernação)
chroot /mnt btrfs filesystem mkswapfile --size 8g /swap/swapfile  # Swapfile de 8G como solicitado, otimizado para 2GB RAM
RESUME_OFFSET=$(chroot /mnt btrfs inspect-internal map-swapfile -r /swap/swapfile)
chroot /mnt mkswap /swap/swapfile  # Formata como swap
chroot /mnt swapon /swap/swapfile

# Instala AppArmor e auditd para segurança
chroot /mnt apt install -y apparmor apparmor-utils auditd
mkdir -pv /mnt/var/log/audit
chown root:root /mnt/var/log/audit
chmod 0700 /mnt/var/log/audit

# Instala pacotes para compartilhamento e rede (GVFS, Samba, Avahi)
chroot /mnt apt install -y gvfs gvfs-backends smbclient cifs-utils avahi-daemon

# Adiciona sysctl para ping group
echo "net.ipv4.ping_group_range = 0 2147483647" >> /mnt/usr/lib/sysctl.d/50-default.conf

# Instala e configura áudio (PipeWire em vez de PulseAudio, otimizado para baixa RAM)
chroot /mnt apt install -y pulseaudio-utils pipewire-audio wireplumber pipewire-pulse pipewire-alsa libspa-0.2-bluetooth libspa-0.2-jack
chroot /mnt systemctl --user enable wireplumber.service
chroot /mnt systemctl --user disable pulseaudio.service pulseaudio.socket
chroot /mnt systemctl --user mask pulseaudio
chroot /mnt systemctl --user enable pipewire pipewire-pulse

# Instala rtkit para gerenciamento de prioridade real-time
chroot /mnt apt install -y rtkit

# Instala utilitários básicos (gdisk, bash-completion, etc.)
chroot /mnt apt install -y gdisk bash-completion pciutils xz-utils curl unzip

# Configura Polkit para permissões (udisks, logs, commands)
mkdir -pv /mnt/run/polkit-1/rules.d
chmod 755 /mnt/run/polkit-1/rules.d

mkdir -pv /mnt/etc/polkit-1/localauthority/50-local.d
cat <<EOF >/mnt/etc/polkit-1/localauthority/50-local.d/50-udisks.pkla
[udisks]
Identity=unix-group:sudo
Action=org.freedesktop.udisks2.filesystem-mount-system
ResultAny=yes
ResultInactive=no
ResultActive=yes
EOF

mkdir -pv /mnt/etc/polkit-1/rules.d
cat >/mnt/etc/polkit-1/rules.d/10-udisks2.rules <<HEREDOC
polkit.addRule(function(action, subject) {
    if ((action.id == "org.freedesktop.udisks2.filesystem-mount" ||
        action.id == "org.freedesktop.udisks2.filesystem-mount-system") &&
        subject.isInGroup("sudo")) {
        return polkit.Result.YES;
    }
});
HEREDOC

cat >/mnt/etc/polkit-1/rules.d/10-logs.rules <<HEREDOC
polkit.addRule(function(action, subject) {
  polkit.log("user " +  subject.user + " is attempting action " + action.id + " from PID " + subject.pid);
});
HEREDOC

cat >/mnt/etc/polkit-1/rules.d/10-commands.rules <<HEREDOC
polkit.addRule(function(action, subject) {
  if (
    subject.isInGroup("sudo")
      && (
        action.id == "org.freedesktop.login1.reboot" ||
        action.id == "org.freedesktop.login1.reboot-multiple-sessions" ||
        action.id == "org.freedesktop.login1.power-off" ||
        action.id == "org.freedesktop.login1.power-off-multiple-sessions" ||
        action.id == "org.freedesktop.login1.suspend" ||
        action.id == "org.freedesktop.login1.suspend-multiple-sessions"
      )
    )
  {
    return polkit.Result.YES;
  }
})
HEREDOC

chmod 644 /mnt/etc/polkit-1/rules.d/*.rules
chown root:root /mnt/etc/polkit-1/rules.d/*.rules

# Instala GRUB EFI e os-prober
chroot /mnt apt install -y efibootmgr grub-efi-amd64 os-prober

# Instala chrony para NTP
chroot /mnt apt install -y chrony

# Instala e habilita ferramentas de otimização (earlyoom para OOM em baixa RAM, powertop/thermald para bateria/CPU)
chroot /mnt apt install -y earlyoom powertop tlp thermald irqbalance
chroot /mnt systemctl enable earlyoom powertop tlp thermald irqbalance

# Configura TLP para economia máxima de bateria no MacBook Air 4,1 (agressivo para baixa RAM/CPU antiga)
chroot /mnt apt install -y tlp-rdw
cat <<EOF > /mnt/etc/tlp.conf
CPU_SCALING_GOVERNOR_ON_BAT="powersave"
CPU_SCALING_GOVERNOR_ON_AC="powersave"  # Powersave em AC para máxima economia
CPU_ENERGY_PERF_POLICY_ON_BAT="power"
CPU_ENERGY_PERF_POLICY_ON_AC="power"  # Power em AC para baixa performance/energia
CPU_MIN_PERF_ON_BAT=0
CPU_MAX_PERF_ON_BAT=50  # Limita CPU para evitar aquecimento/dreno (hardware antigo)
CPU_BOOST_ON_BAT=0
PLATFORM_PROFILE_ON_BAT="low-power"
WIFI_PWR_ON_BAT="on"  # Economia WiFi máxima
USB_AUTOSUSPEND=1
USB_EXCLUDE_BTUSB=1  # Exclui BT se não usado
RUNTIME_PM_ON_BAT="auto"
SATA_LINKPWR_ON_BAT="min_power"
DEVICES_TO_DISABLE_ON_STARTUP="bluetooth wwan"  # Desliga BT/WWAN para bateria
SOUND_POWER_SAVE_ON_BAT=1
SOUND_POWER_SAVE_CONTROLLER=Y  # Desliga controlador áudio quando idle
WIFI_RADIO_SWITCH_ON_BAT=1
EOF

# Configura Xorg para touchpad e teclado (libinput, modelo Apple)
mkdir -pv /mnt/etc/X11/xorg.conf.d/
cat <<EOF >/mnt/etc/X11/xorg.conf.d/30-touchpad.conf
Section "InputClass"
  Identifier "libinput touchpad catchall"
  Driver "libinput"
  MatchIsTouchpad "on"
  MatchDevicePath "/dev/input/event*"
  Option "Tapping" "on"
  Option "NaturalScrolling" "true"
EndSection
EOF

cat <<EOF >/mnt/etc/X11/xorg.conf.d/40-keyboard.conf
Section "InputClass"
  Identifier "system-keyboard"
  MatchIsKeyboard "on"
  Option "XkbModel" "apple"
  Option "XkbLayout" "us"
  Option "XkbVariant" "mac"
EndSection
EOF

# Instala e habilita Bluetooth (mas desabilitado no TLP para bateria)
chroot /mnt apt install -y bluez bluez-tools
chroot /mnt systemctl enable bluetooth

# Instala e configura console-setup/keyboard (modelo Apple, layout US com variante Mac)
chroot /mnt apt install -y console-setup keyboard-configuration
chroot /mnt /bin/bash -c 'cat <<EOF | debconf-set-selections
console-setup console-setup/charmap47 select UTF-8
console-setup console-setup/codeset47 select # Latin1 and Latin5 - western Europe and Brazil
console-setup console-setup/fontface47 select Terminus
console-setup console-setup/fontsize-text47 select 16x32 (framebuffer only)
console-setup console-setup/modelcode select apple
console-setup console-setup/layoutcode select us
console-setup console-setup/variantcode select mac
console-setup console-setup/optionscode select
EOF
dpkg-reconfigure -f noninteractive keyboard-configuration
dpkg-reconfigure -f noninteractive console-setup
setupcon --force
'

# Define shell padrão para root como bash
chroot /mnt chsh -s /usr/bin/bash root

# Desabilita/mascara systemd-networkd (usa NetworkManager)
chroot /mnt systemctl disable systemd-networkd.service systemd-networkd.socket systemd-networkd-wait-online.service
chroot /mnt systemctl mask systemd-networkd.service systemd-networkd.socket systemd-networkd-wait-online.service

# Habilita serviços essenciais (NetworkManager, SSH, etc.)
chroot /mnt systemctl enable NetworkManager.service ssh.service rtkit-daemon.service chrony.service fstrim.timer

# Instala kernel padrão AMD64 (usa kernel leve para baixa RAM)
chroot /mnt apt install -y linux-image-amd64 linux-headers-amd64

# Instala initramfs-tools e atualiza initramfs
chroot /mnt apt install -y initramfs-tools
chroot /mnt update-initramfs -u -k all

# Força inclusão de módulos no initramfs (essenciais para Mac: graphics, WiFi, storage)
mkdir -pv /mnt/etc/initramfs-tools
cat <<EOF >> /mnt/etc/initramfs-tools/modules
i915
hid_apple
brcmsmac
snd_hda_intel
ahci
btrfs
EOF

# Configura hibernação com swapfile (resume UUID + offset para MacBook baixa RAM)
mkdir -pv /mnt/etc/initramfs-tools/conf.d
cat <<EOF >/mnt/etc/initramfs-tools/conf.d/resume
RESUME=UUID=${ROOT_UUID} resume_offset=${RESUME_OFFSET}
EOF
chroot /mnt update-initramfs -u -k all  # Regenera initramfs com resume

# Instala pm-utils para comandos legacy de hibernação (pm-hibernate, etc.)
chroot /mnt apt install -y pm-utils

# Configura hibernação com swapfile (resume UUID + offset para MacBook baixa RAM)
mkdir -pv /mnt/etc/initramfs-tools/conf.d
cat <<EOF >/mnt/etc/initramfs-tools/conf.d/resume
RESUME=UUID=${ROOT_UUID} resume_offset=${RESUME_OFFSET}
EOF

chroot /mnt update-initramfs -u -k all  # Regenera initramfs com resume

# Habilita serviços de hibernação (systemd gerencia resume automaticamente; habilita hibernate se quiser)
chroot /mnt systemctl enable systemd-hibernate.service  # Habilita hibernação (opcional, mas útil)

# Instala GRUB EFI
chroot /mnt grub-install --target=x86_64-efi --bootloader-id="Debian" --efi-directory=/boot/efi --recheck --force

# Configura GRUB (cmdline com nomodeset para evitar hangs no Mac; inclui resume para hibernação)
cat <<EOF >/mnt/etc/default/grub
GRUB_DEFAULT=saved
GRUB_TIMEOUT=5
GRUB_DISABLE_SUBMENU=false
GRUB_DISTRIBUTOR="Debian"
GRUB_CMDLINE_LINUX_DEFAULT="root=UUID=${ROOT_UUID} rootflags=subvol=@ quiet splash nomodeset apparmor=1 security=apparmor resume=UUID=${ROOT_UUID} resume_offset=${RESUME_OFFSET}"
GRUB_DISABLE_OS_PROBER=false
GRUB_ENABLE_BLSCFG=true
EOF

chroot /mnt update-grub

# Verifica EFI boot entries
chroot /mnt efibootmgr

# Limpa arquivos temporários
rm -rf /mnt/{vmlinuz.old,vmlinuz,initrd.img,initrd.img.old,debootstrap}

# Configura zram para swap comprimido (alta prioridade para baixa RAM, complemento ao swapfile)
cat <<EOF > /mnt/etc/default/zramswap
ALLOCATION=50  # 50% da RAM como zram (1GB para 2GB RAM)
PRIORITY=100   # Prioridade alta para usar zram antes de swap disco
COMPRESSION_ALGORITHM=lz4
SWAPPINESS=150  # Agressivo para baixa RAM
EOF
chroot /mnt systemctl enable zramswap.service

echo "Instalação concluída! Reinicie e teste hibernação com 'systemctl hibernate'. Otimizações para bateria e baixa RAM aplicadas (TLP agressivo, sysctl swap, zram)."