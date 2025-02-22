gdisk 

# bios partition
o - delete all partition
n - new partition
default 
first sector - ok
last sector - +10M
hex code - ef02 (bios boot)

# efi partition
n - new partition
default 
first sector - ok
last sector - +250M
hex code - ef00 (efi partition)
mkfs.fat -F32 

# root partition 
n
default 
default
default
hex code - 8300 
mkfs.ext4 -O "^has_journal" /dev # disable journaling

xf86-video-intel xf86-video-amdgpu xf86-video-nouveau xf86-video-ati xf86-video-vesa
xorg xf86-input-libinput libinput 


# Normal Install
#Grub for legacy
grub-install --target=i386-pc --boot-directory=/boot /dev/sdd

#Grub for efi
grub-install --target=x86_64-efi --efi-directory=/boot --boot-directory=/boot --removable --recheck


/etc/systemd/journald.conf
#Storage=auto
Storage=volatile
# RuntimeMaxUse=
RuntimeMaxUse=30M

#!/bin/sh

#### Update and install needed packages ####
apt update && apt install debootstrap btrfs-progs lsb-release wget -y

#### Umount drive, if it's mounted ####
umount -R /dev/sdb

#### Add faster repo's ####
CODENAME=$(lsb_release --codename --short) # or CODENAME=bullseye
cat >/etc/apt/sources.list <<HEREDOC
deb https://deb.debian.org/debian/ $CODENAME main contrib non-free
deb-src https://deb.debian.org/debian/ $CODENAME main contrib non-free

#deb https://security.debian.org/debian-security $CODENAME-security main contrib non-free
#deb-src https://security.debian.org/debian-security $CODENAME-security main contrib non-free

deb https://deb.debian.org/debian/ $CODENAME-updates main contrib non-free
deb-src https://deb.debian.org/debian/ $CODENAME-updates main contrib non-free

deb https://deb.debian.org/debian/ $CODENAME-backports main contrib non-free
deb-src https://deb.debian.org/debian/ $CODENAME-backports main contrib non-free

#######################
### Debian unstable ###
#######################

##Debian Testing
#deb http://deb.debian.org/debian/ testing main
#deb-src http://deb.debian.org/debian/ testing main


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

#### update fastest repo's
apt update

#####################################
####Gptfdisk Partitioning example####
#####################################

#######################
#### real hardware ####
#######################

sgdisk -Z /dev/sdb
parted -s -a optimal /dev/sdb mklabel gpt
sgdisk -n 0:0:10M /dev/sdb
sgdisk -n 0:0:250M /dev/sdb
sgdisk -n 0:0:0 /dev/sdb
sgdisk -c 1:BIOS /dev/sdb
sgdisk -c 2:EFI /dev/sdb
sgdisk -c 3:LINUX /dev/sdb
sgdisk -t 1:ef02 /dev/sdb
sgdisk -t 2:ef00 /dev/sdb
sgdisk -t 3:8300 /dev/sdb
sgdisk -p /dev/sdb



#####################################
##########  FileSystem  #############
#####################################

#######################
#### real hardware ####
#######################

mkfs.vfat -F32 /dev/sdb2 -n "EFI"
mkfs.ext4 -O "^has_journal" /dev/sdb3 -f -L "Linux"

###############################
#### Enviroments variables ####
###############################

mount -t ext4 /dev/sdb3 /mnt
mkdir -pv /mnt/boot
mount -t vfat /dev/sdb2 /mnt/boot

####################################################
#### Install tarball debootstrap to the mount / ####
####################################################

debootstrap --variant=minbase --include=apt,apt-utils,extrepo,cpio,arch-install-scripts,cron,zstd,ca-certificates,perl-openssl-defaults,sudo,neovim,initramfs-tools,console-setup,dosfstools,console-setup-linux,keyboard-configuration,debian-archive-keyring,locales,busybox,btrfs-progs,dmidecode,kmod,less,gdisk,gpgv,neovim,ncurses-base,netbase,procps,systemd,systemd-sysv,udev,ifupdown,init,iproute2,iputils-ping,bash,whiptail --arch amd64 bullseye /mnt "http://debian.c3sl.ufpr.br/debian/ bullseye contrib non-free"
# deb http://debian.c3sl.ufpr.br/debian/ main contrib non-free
# mmdebstrap --variant=minbase --include=apt,apt-utils,extrepo,cpio,cron,zstd,ca-certificates,perl-openssl-defaults,sudo,neovim,initramfs-tools,initramfs-tools-core,dracut,console-setup,dosfstools,console-setup-linux,keyboard-configuration,debian-archive-keyring,locales,locales-all,btrfs-progs,dmidecode,kmod,less,gdisk,gpgv,neovim,ncurses-base,netbase,procps,systemd,systemd-sysv,udev,ifupdown,init,iproute2,iputils-ping,bash,whiptail --arch=amd64 bullseye /mnt "http://debian.c3sl.ufpr.br/debian/ bullseye contrib non-free"

########################
#### Fastest Repo's ####
########################

rm /mnt/etc/apt/sources.list
touch /mnt/etc/apt/sources.list.d/{debian.list,various.list}

CODENAME=$(lsb_release --codename --short) # or CODENAME=bullseye
cat >/mnt/etc/apt/sources.list.d/debian.list <<HEREDOC
####################
### Debian repos ###
####################

deb https://deb.debian.org/debian/ $CODENAME main contrib non-free
deb-src https://deb.debian.org/debian/ $CODENAME main contrib non-free

#deb https://security.debian.org/debian-security $CODENAME-security main contrib non-free
#deb-src https://security.debian.org/debian-security $CODENAME-security main contrib non-free

deb https://deb.debian.org/debian/ $CODENAME-updates main contrib non-free
deb-src https://deb.debian.org/debian/ $CODENAME-updates main contrib non-free

deb https://deb.debian.org/debian/ $CODENAME-backports main contrib non-free
deb-src https://deb.debian.org/debian/ $CODENAME-backports main contrib non-free

#######################
### Debian unstable ###
#######################

##Debian Testing
#deb http://deb.debian.org/debian/ testing main
#deb-src http://deb.debian.org/debian/ testing main


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

## Disable verification ##
# touch /mnt/etc/apt/apt.conf.d/99verify-peer.conf \
# && echo >> /mnt/etc/apt/apt.conf.d/99verify-peer.conf "Acquire { https::Verify-Peer false }"

######################################################## 
#### Mount points for chroot, just like arch-chroot ####
########################################################

for dir in dev proc sys run; do
        mount --rbind /$dir /mnt/$dir
        mount --make-rslave /mnt/$dir
done

##################################################
#### Disable some features for optimal system ####
##################################################
########################################
#### real hardware modprobe modules ####
########################################

mkdir -pv /mnt/etc/modprobe.d
cat <<EOF >/mnt/etc/modprobe.d/iwlwifi.conf
options iwlwifi enable_ini=N
EOF

touch /mnt/etc/modprobe.d/i915.conf
cat <<EOF >/mnt/etc/modprobe.d/i915.conf
## Boot Faster with intel ##
options i915 enable_guc=2 enable_fbc=1 enable_dc=4 enable_hangcheck=0 error_capture=0 enable_dp_mst=0 fastboot=1 #parameters may differ
EOF

#######################################
#### Kernel params for tune system ####
#######################################
#######################
#### real hardware ####
#######################

mkdir -pv /mnt/etc/sysctl.d
cat <<EOF >/mnt/etc/sysctl.d/00-swap.conf
vm.vfs_cache_pressure=500
vm.swappiness=100
vm.dirty_background_ratio=1
vm.dirty_ratio=50
EOF

cat <<EOF >/mnt/etc/sysctl.d/10-conf.conf
net.ipv4.ping_group_range=0 $MAX_GID
EOF

cat <<EOF >/mnt/etc/sysctl.d/10-intel.conf
# Intel Graphics
dev.i915.perf_stream_paranoid=0
EOF

######################################
#### Update initramfs load system ####
######################################

chroot /mnt update-initramfs -c -k all

############################
#### Set default editor ####
############################

chroot /mnt update-alternatives --install /usr/bin/editor editor /usr/bin/nvim 100

######################################
#### Optimize apt package manager ####
######################################

touch /mnt/etc/apt/apt.conf
cat >/mnt/etc/apt/apt.conf <<HEREDOC
#Recommends are as of now abused in many packages
APT::Install-Recommends "0";
APT::Install-Suggests "0";

### For install testing packages
#APT::Default-Release "testing";
HEREDOC

mkdir -pv /mnt/etc/apt/preferences.d
touch /mnt/etc/apt/preferences.d/stable.pref
touch /mnt/etc/apt/preferences.d/testing.pref
touch /mnt/etc/apt/preferences.d/unstable.pref
touch /mnt/etc/apt/preferences.d/experimental.pref
cat >/mnt/etc/apt/preferences.d/stable.pref <<HEREDOC
# 500 <= P < 990: causes a version to be installed unless there is a
# version available belonging to the target release or the installed
# version is more recent

Package: *
Pin: release a=stable
Pin-Priority: 900
HEREDOC

cat >/mnt/etc/apt/preferences.d/testing.pref <<HEREDOC
# 100 <= P < 500: causes a version to be installed unless there is a
# version available belonging to some other distribution or the installed
# version is more recent

Package: *
Pin: release a=testing
Pin-Priority: 400
HEREDOC

cat >/mnt/etc/apt/preferences.d/unstable.pref <<HEREDOC
# 0 < P < 100: causes a version to be installed only if there is no
# installed version of the package

Package: *
Pin: release a=unstable
Pin-Priority: 50
HEREDOC

cat >/mnt/etc/apt/preferences.d/experimental.pref <<HEREDOC
# 0 < P < 100: causes a version to be installed only if there is no
# installed version of the package

Package: *
Pin: release a=experimental
Pin-Priority: 1
HEREDOC

################################
#### Update package manager ####
################################

chroot /mnt apt update
chroot /mnt apt upgrade -y

######################
#### Set Hostname ####
######################
# real=nitro

cat <<EOF >/mnt/etc/hostname
debianusb
EOF

# Hosts
touch /mnt/etc/hosts
cat <<\EOF >/mnt/etc/hosts
127.0.0.1   localhost
127.0.1.1   debianusb.localdomain debianusb

### The following lines are desirable for IPv6 capable hosts
::1         localhost ip6-localhost ip6-loopback
ff02::1     ip6-allnodes
ff02::2     ip6-allrouters
EOF


#########################
#### Setting Locales ####
#########################

chroot /mnt echo "America/Sao_Paulo" >/mnt/etc/timezone && \
        dpkg-reconfigure -f noninteractive tzdata && \
        sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
        sed -i -e 's/# pt_BR.UTF-8 UTF-8/pt_BR.UTF-8 UTF-8/' /etc/locale.gen && \
        dpkg-reconfigure -f noninteractive locales && \
        echo 'KEYMAP="br-abnt2"' >/etc/vconsole.conf

chroot /mnt apt update

#####################################
#### Install additional packages ####
#####################################

#############
## Network ##
#############

chroot /mnt apt install nftables net-tools arp-scan gvfs gvfs-backends samba nfs-common smbclient cifs-utils avahi-daemon \
firmware-realtek firmware-linux-nonfree firmware-linux-free firmware-iwlwifi network-manager iwd rfkill --no-install-recommends -y

# ssh
chroot /mnt apt install openssh-client openssh-server --no-install-recommends -y

########################################################
#### Config iwd as backend instead of wpasupplicant ####
########################################################

cat <<EOF >/mnt/etc/NetworkManager/conf.d/iwd.conf
[device]
wifi.backend=iwd
wifi.iwd.autoconnect=yes
EOF

mkdir -pv /mnt/etc/iwd
touch /mnt/etc/iwd/main.conf
cat <<EOF >/mnt/etc/iwd/main.conf
[General]
EnableNetworkConfiguration=true

[Network]
NameResolvingService=systemd
RouterPriorityOffset=30
EOF

###############
#### Audio ####
###############

## Pulseaudio
chroot /mnt apt install alsa-utils bluetooth rfkill bluez bluez-tools pulseaudio pulseaudio-module-bluetooth pavucontrol --no-install-recommends -y

###############
#### Utils ####
###############

chroot /mnt apt install fwupdate fwupd duperemove libvshadow-utils aptitude apt-show-versions rsyslog manpages acpid hwinfo lshw dkms pciutils linux-image-amd64 linux-headers-amd64 fonts-firacode \
debian-keyring make libssl-dev libreadline-dev libffi-dev liblzma-dev xz-utils llvm git gnupg lolcat libncursesw5-dev libsqlite3-dev libxml2-dev libxmlsec1-dev zlib1g-dev libbz2-dev build-essential htop \
efibootmgr grub-pc os-prober wget unzip curl sysfsutils chrony bluez-firmware firmware-linux firmware-b43legacy-installer firmware-b43-installer --no-install-recommends -y
# apt install linux-headers-$(uname -r|sed 's/[^-]*-[^-]*-//')

cat << EOF > /mnt/etc/initramfs-tools/modules
crc32c-intel
ahci
lz4hc
lz4hc_compress
zstd
zram
z3fold
EOF

###############
#### Tools ####
###############

chroot /mnt apt install colord bash-completion bzip2 man-db gdisk mtools p7zip neofetch fzf duf bat unattended-upgrades --no-install-recommends -y

#############################
#### Optimizations Tools ####
#############################

chroot /mnt apt install earlyoom tlp thermald irqbalance --no-install-recommends -y

###################
#### Microcode ####
###################

chroot /mnt apt install intel-microcode amd64-microcode --no-install-recommends -y

#####################################
#### intel Hardware Acceleration ####
#####################################

chroot /mnt apt install xorg xinput intel-media-va-driver-non-free vainfo intel-gpu-tools gstreamer1.0-vaapi -y

##################################
#### Nvidia Drivers with Cuda ####
##################################

# chroot /mnt apt build-dep -t bullseye-backports nvidia-driver firmware-misc-nonfree nvidia-settings libvulkan-dev nvidia-vulkan-icd vulkan-validationlayers vulkan-validationlayers-dev fizmo-sdl2 libsdl2-2.0-0 libsdl2-dev libsdl2-gfx-1.0-0 libsdl2-gfx-dev libsdl2-image-2.0-0 libsdl2-mixer-2.0-0 libsdl2-net-2.0-0 mesa-utils nvidia-kernel-source inxi nvidia-driver nvidia-smi nvidia-settings nvidia-xconfig nvidia-persistenced libnvcuvid1 libnvidia-encode1 firmware-misc-nonfree --no-install-recommends -y
chroot /mnt apt install -t bullseye-backports nvidia-driver firmware-misc-nonfree nvidia-settings vulkan-tools libvulkan-dev nvidia-vulkan-icd \
vulkan-validationlayers vulkan-validationlayers-dev fizmo-sdl2 libsdl2-2.0-0 libsdl2-dev libsdl2-gfx-1.0-0 libsdl2-gfx-dev libsdl2-image-2.0-0 \
libsdl2-mixer-2.0-0 libsdl2-net-2.0-0 mesa-utils nvidia-kernel-source inxi nvidia-driver nvidia-smi nvidia-settings nvidia-xconfig nvidia-persistenced \
libnvcuvid1 libnvidia-encode1 firmware-misc-nonfree --no-install-recommends -y
# chroot /mnt apt install nvidia-driver firmware-misc-nonfree libnvidia-fbc1 nvidia-settings vulkan-tools libvulkan-dev nvidia-vulkan-icd vulkan-validationlayers vulkan-validationlayers-dev fizmo-sdl2 libsdl2-2.0-0 libsdl2-dev libsdl2-gfx-1.0-0 libsdl2-gfx-dev libsdl2-image-2.0-0 libsdl2-mixer-2.0-0 libsdl2-net-2.0-0 mesa-utils nvidia-kernel-source inxi nvidia-driver nvidia-smi nvidia-settings nvidia-xconfig nvidia-persistenced libnvcuvid1 libnvidia-encode1 firmware-misc-nonfree --no-install-recommends -y


###########################
#### Some XORG configs ####
###########################

# Touchpad tap to click
mkdir -pv /mnt/etc/X11/xorg.conf.d/
touch /mnt/etc/X11/xorg.conf.d/30-touchpad.conf
cat <<EOF >/mnt/etc/X11/xorg.conf.d/30-touchpad.conf
Section "InputClass"
        # Identifier "SynPS/2 Synaptics TouchPad"
        # Identifier "SynPS/2 Synaptics TouchPad"
        # MatchIsTouchpad "on"
        # Driver "libinput"
        # Option "Tapping" "on"

        Identifier      "touchpad"
        Driver          "libinput"
        MatchIsTouchpad "on"
        Option          "Tapping"       "on"
EndSection
EOF

mkdir -pv /mnt/etc/X11/xorg.conf.d
touch /mnt/etc/X11/xorg.conf.d/30-nvidia.conf
cat << EOF > /mnt/etc/X11/xorg.conf.d/30-nvidia.conf
#Section "Device"
#    Identifier "Nvidia GTX 1050"
#    Driver "nvidia"
#    BusID "PCI:1:0:0"
#    Option "DPI" "96 x 96"
#    Option "AllowEmptyInitialConfiguration" "Yes"
#    #  Option "UseDisplayDevice" "none"
#EndSection
EOF

# Fix tearing with intel
touch /mnt/etc/X11/xorg.conf.d/20-modesetting.conf
cat <<EOF >/mnt/etc/X11/xorg.conf.d/20-modesetting.conf
#Section "Device"
##   Identifier "Intel Graphics 630"
##   Driver "intel"
##   Option "AccelMethod" "sna"
##   Option "TearFree" "True"
##   Option "Tiling" "True"
##   Option "SwapbuffersWait" "True"
##   Option "DRI" "3"
#
#    Identifier  "Intel Graphics"
#    Driver      "modesetting"
#    Option      "TearFree"       "True"
#    Option      "AccelMethod"    "glamor"
#    Option      "DRI"            "3"
#EndSection
EOF

#########################
#### Config Powertop ####
#########################

touch /mnt/etc/rc.local
cat <<EOF >/mnt/etc/rc.local
#PowerTop
#powertop --auto-tune
EOF

#################################
#### Infrastructure packages ####
#################################

# chroot /mnt apt install python3 python3-pip snapd slirp4netns flatpak spice-vdagent gir1.2-spiceclientgtk-3.0 ovmf ovmf-ia32 \
# dnsmasq ipset ansible libguestfs0 virt-viewer qemu qemu-system qemu-utils qemu-system-gui vde2 uml-utilities virtinst virt-manager \
# bridge-utils libvirt-daemon-system uidmap podman fuse-overlayfs zsync --no-install-recommends -y


###########################
#### Setup resolv.conf ####
###########################

cat <<EOF >/mnt/etc/resolv.conf
nameserver 8.8.8.8
nameserver 8.8.4.4
nameserver 1.1.1.1
EOF

################################
#### Setup default keyboard ####
################################

mkdir -pv /mnt/etc/default/
touch /mnt/etc/default/keyboard
cat << EOF > /mnt/etc/default/keyboard
# KEYBOARD CONFIGURATION FILE

# Consult the keyboard(5) manual page.

XKBMODEL="pc105"
XKBLAYOUT="br"
XKBVARIANT=""
XKBOPTIONS="terminate:ctrl_alt_bksp"
EOF

#################
#### Locales ####
#################

chroot /mnt echo "America/Sao_Paulo" >/mnt/etc/timezone && \
        dpkg-reconfigure -f noninteractive tzdata && \
        sed -i -e 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
        sed -i -e 's/# pt_BR.UTF-8 UTF-8/pt_BR.UTF-8 UTF-8/' /etc/locale.gen && \
        echo 'LANGUAGE="en_US.UTF-8"' >/etc/default/locale && \
        dpkg-reconfigure -f noninteractive locales && \
        echo 'KEYMAP="br-abnt2"' >/etc/vconsole.conf

chroot /mnt update

#############################
#### Set bash as default ####
#############################

chroot /mnt chsh -s /usr/bin/bash root

#################################
#### Plymouth animation boot ####
#################################

chroot /mnt apt install plymouth plymouth-themes --no-install-recommends -y
chroot /mnt plymouth-set-default-theme -R solar

mkdir -pv /mnt/etc/plymouth
touch /mnt/etc/plymouth/plymouth.conf
cat <<EOF >/mnt/etc/plymouth/plymouth.conf
# Administrator customizations go in this file
[Daemon]
Theme=solar
ShowDelay=5
EOF

##############
#### sudo ####
##############

chroot /mnt apt install sudo -y

##############################
#### User's and passwords ####
##############################

chroot /mnt sh -c 'echo "root:200291" | chpasswd -c SHA512'
chroot /mnt useradd juca -m -c "Reinaldo P JR" -s /bin/bash
chroot /mnt sh -c 'echo "juca:200291" | chpasswd -c SHA512'
chroot /mnt usermod -aG floppy,audio,sudo,video,systemd-journal,kvm,lp,cdrom,netdev,input,libvirt,kvm juca
chroot /mnt usermod -aG sudo juca

############################################################
#### NetworkManager config as default instead of dhcpd5 ####
############################################################

cat << EOF > /mnt/etc/NetworkManager/NetworkManager.conf
[main]
plugins=ifupdown,keyfile

[ifupdown]
managed=true
EOF

#########################
#### Enable Services ####
#########################

## Network
chroot /mnt systemctl enable NetworkManager.service
chroot /mnt systemctl enable iwd.service
chroot /mnt systemctl enable ssh.service
# chroot /mnt systemctl enable --user pulseaudio.service
chroot /mnt systemctl enable rtkit-daemon.service
chroot /mnt systemctl enable chrony.service
chroot /mnt systemctl enable fstrim.timer

##Pulseaudio
chroot /mnt systemctl --user enable pulseaudio.{socket,service}
chroot /mnt systemctl --user --now mask pipewire{,-pulse}.{socket,service}

## Pulseaudio
# chroot /mnt systemctl --user enable pulseaudio

## Optimizations ##
chroot /mnt systemctl enable earlyoom.service
chroot /mnt systemctl enable thermald.service
chroot /mnt systemctl enable irqbalance.service

## Update initramfs
chroot /mnt update-initramfs -c -k all

######################
#### Install grub ####
######################

# Bios
chroot /mnt grub-install --target=i386-pc --recheck --boot-directory=/mnt/boot /dev/sdb
# EFI
chroot /mnt grub-install --target=x86_64-efi --efi-directory=/mnt/boot --boot-directory=/mnt/boot --no-nvram --removable --recheck

#####################
#### Config Grub ####
#####################

cat <<EOF >/mnt/etc/default/grub
#
# Configuration file for GRUB.
#
GRUB_DEFAULT=0
#GRUB_HIDDEN_TIMEOUT=0
#GRUB_HIDDEN_TIMEOUT_QUIET=false
GRUB_TIMEOUT=2
GRUB_DISTRIBUTOR="Debian"
GRUB_CMDLINE_LINUX_DEFAULT="quiet kernel.unprivileged_userns_clone vt.global_cursor_default=0 loglevel=0 gpt init_on_alloc=0 udev.log_level=0 intel_iommu=igfx_off nvidia-drm.modeset=1 i915.enable_psr=0 i915.modeset=1 zswap.enabled=1 zswap.compressor=lz4hc zswap.max_pool_percent=10 zswap.zpool=z3fold mitigations=off nowatchdog msr.allow_writes=on pcie_aspm=force module.sig_unenforce intel_idle.max_cstate=1 cryptomgr.notests initcall_debug net.ifnames=0 no_timer_check noreplace-smp page_alloc.shuffle=1 rcupdate.rcu_expedited=1 tsc=reliable"

# Uncomment to use basic console
#GRUB_TERMINAL_INPUT="console"
# Uncomment to disable graphical terminal
#GRUB_TERMINAL_OUTPUT=console
#GRUB_BACKGROUND=/usr/share/void-artwork/splash.png
GRUB_GFXMODE=auto
#GRUB_DISABLE_LINUX_UUID=true
#GRUB_DISABLE_RECOVERY=true
# Uncomment and set to the desired menu colors.  Used by normal and wallpaper
# modes only.  Entries specified as foreground/background.
GRUB_COLOR_NORMAL="light-blue/black"
GRUB_COLOR_HIGHLIGHT="light-cyan/blue"
# GRUB_DISABLE_OS_PROBER=false
EOF

chroot /mnt update-grub

chroot /mnt update-initramfs -c -k all

rm -rf /mnt/vmlinuz.old
rm -rf /mnt/vmlinuz
rm -rf /mnt/initrd.img
rm -rf /mnt/initrd.img.old

###########################
#### Fix Dual provider ####
###########################

touch /mnt/home/juca/.xsessionrc
cat << EOF > /mnt/home/juca/.xsessionrc
xrandr --setprovideroutputsource 1 0
EOF

chroot /mnt chmod +x /home/juca/.xsessionrc
chroot /mnt chown -R juca:juca /home/juca/.xsessionrc

