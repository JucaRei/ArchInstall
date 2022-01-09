#!/bin/bash



ln -sf /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime
hwclock --systohc
sed -i '177s/.//' /etc/locale.gen
locale-gen
echo "LANG=en_US.UTF-8" >>/etc/locale.conf
# echo "KEYMAP=br-abnt2" >>/etc/vconsole.conf
# echo "KEYMAP=us-intl" >>/etc/vconsole.conf
# echo "KEYMAP=mac-us" >>/etc/vconsole.conf
echo "oldmac" >>/etc/hostname
echo "127.0.0.1 localhost" >>/etc/hosts
echo "::1       localhost" >>/etc/hosts
echo "127.0.1.1 oldmac.localdomain oldmac" >>/etc/hosts
echo root:200291 | chpasswd

pacman -S artix-archlinux-support
pacman-key --populate archlinux

pacman -Syyy

# ADD Repos
cat << EOF >> /etc/pacman.conf
[extra]
Include = /etc/pacman.d/mirrorlist-arch

[community]
Include = /etc/pacman.d/mirrorlist-arch

[multilib]
Include = /etc/pacman.d/mirrorlist-arch
EOF

pacman -S archlinux-keyring
pacman -Syyy

# cat << EOF >> /etc/pacman.conf
# [universe]
# Server = https://universe.artixlinux.org/$arch
# Server = https://mirror1.artixlinux.org/universe/$arch
# Server = https://mirror.pascalpuffke.de/artix-universe/$arch
# Server = https://artixlinux.qontinuum.space:4443/universe/os/$arch
# Server = https://mirror.alphvino.com/artix-universe/$arch

# [omniverse]
# Server = http://omniverse.artixlinux.org/$arch
# EOF

pacman-key --populate archlinux

pacman -Syy

cd ArchInstall/Arch/Arch_pkgs
pacman -U paru-1.9.2-1-x86_64.pkg.tar.zst

cd

paru -S efibootmgr intel-ucode networkmanager networkmanager-runit network-manager-applet chrony chrony-runit dialog wpa_supplicant duf bat dust fzf ripgrep rsm wireless_tools wpa_supplicant-runit avahi avahi-runit xdg-user-dirs xdg-utils gvfs gvfs-smb nfs-utils nfs-utils-runit inetutils dnsutils bluez bluez-runit bluez-utils pulseaudio-bluetooth pulseaudio-alsa pulseaudio-equalizer pulseaudio-jack alsa-utils alsa-utils-runit bash-completion exfat-utils cups cups-runit hplip openssh openssh-runit rsync rsync-runit acpi acpid acpi_call tlp tlp-runit virt-manager libvirt-runit qemu qemu-guest-agent qemu-guest-agent-runit qemu-arch-extra vde2 edk2-ovmf bridge-utils dnsmasq dnsmasq-runit vde2 openbsd-netcat iptables iptables-nft iptables-runit  ipset firewalld firewalld-runit flatpak sof-firmware nss-mdns acpid-runit ntfs-3g 

pari -S xf86-video-intel xf86-video-nouveau --noconfirm 
#xorg --ignore xorg-server-xdmx

# pacman -S reflector
# pacman -S nvidia-lts nvidia-utils nvidia-settings

paru -S zramen-runit

ln -s /etc/runit/sv/NetworkManager /run/runit/service
ln -s /etc/runit/sv/sshd /run/runit/service
ln -s /etc/runit/sv/acpid /run/runit/service
ln -s /etc/runit/sv/ntpd /run/runit/service
ln -s /etc/runit/sv/bluetoothd /run/runit/service
ln -s /etc/runit/sv/wpa_supplicant /run/runit/service
ln -s /etc/runit/sv/avahi-daemon /run/runit/service
ln -s /etc/runit/sv/alsa /run/runit/service
ln -s /etc/runit/sv/cupsd /run/runit/service
ln -s /etc/runit/sv/tlp /run/runit/service
ln -s /etc/runit/sv/libvirtd/ /run/runit/service

useradd -m juca
echo juca:200291 | chpasswd
usermod -aG libvirt juca

echo "juca ALL=(ALL) ALL" >>/etc/sudoers.d/juca

# GummiBoot
paru -S nosystemd-boot

# mount --bind /sys/firmware/efi/efivars /mnt/sys/firmware/efi/efivars
mount -t efivarfs efivarfs /sys/firmware/efi/efivars
#gummiboot install

printf "\e[1;32mDone! Type exit, umount -a and reboot.\e[0m"
