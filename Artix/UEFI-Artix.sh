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

paru -S grub grub-btrfs efibootmgr reflector networkmanager networkmanager-runit network-manager-applet ntp ntp-runit dialog wpa_supplicant duf bat exa ripgrep fzf rsm wpa_supplicant-runit pacman-contrib avahi avahi-runit xdg-user-dirs xdg-utils gvfs gvfs-smb nfs-utils inetutils dnsutils bluez bluez-runit bluez-utils pulseaudio-bluetooth pulseaudio-alsa pulseaudio-equalizer pulseaudio-jack alsa-utils alsa-utils-runit bash-completion exfat-utils cups cups-runit hplip openssh openssh-runit rsync rsync-runit acpi acpid acpi_call tlp tlp-runit virt-manager libvirt-runit qemu qemu-guest-agent-runit qemu-arch-extra vde2 edk2-ovmf bridge-utils dnsmasq dnsmasq-runit vde2 ebtables openbsd-netcat iptables-nft ipset firewalld firewalld-runit flatpak sof-firmware nss-mdns acpid-runit os-prober ntfs-3g

# pacman -S reflector
# pacman -S nvidia-lts nvidia-utils nvidia-settings
# pacman -S glow ncdu2
### Works on xanmod
# paru -S nvidia-tweaks nvidia-prime xf86-video-intel

paru -S zramen-runit

ln -s /etc/runit/sv/NetworkManager /etc/runit/runsvdir/default/
ln -s /etc/runit/sv/sshd /etc/runit/runsvdir/default/
ln -s /etc/runit/sv/acpid /etc/runit/runsvdir/default/
ln -s /etc/runit/sv/ntpd /etc/runit/runsvdir/default/
ln -s /etc/runit/sv/bluetoothd /etc/runit/runsvdir/default/
ln -s /etc/runit/sv/wpa_supplicant /etc/runit/runsvdir/default/
ln -s /etc/runit/sv/avahi-daemon /etc/runit/runsvdir/default/
ln -s /etc/runit/sv/alsa /etc/runit/runsvdir/default/
ln -s /etc/runit/sv/cupsd /etc/runit/runsvdir/default/
ln -s /etc/runit/sv/tlp /etc/runit/runsvdir/default/
ln -s /etc/runit/sv/libvirtd/ /etc/runit/runsvdir/default/

useradd -m junior
echo junior:200291 | chpasswd
usermod -aG libvirt junior

echo "junior ALL=(ALL) ALL" >>/etc/sudoers.d/junior

pacman -Rs linux acpi_call --noconfirm
pacman -S acpi_call-lts --noconfirm

grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=GRUB
grub-mkconfig -o /boot/grub/grub.cfg

mkinitcpio -P linux-lts

# Add Chaotic repo
pacman-key --recv-key FBA220DFC880C036 --keyserver keyserver.ubuntu.com
pacman-key --lsign-key FBA220DFC880C036
pacman -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'

cat << EOF >> /etc/pacman.conf

[chaotic-aur]
Include = /etc/pacman.d/chaotic-mirrorlist
EOF

# Add Liquorix
pacman-key --keyserver hkps://keyserver.ubuntu.com --recv-keys 9AE4078033F8024D
pacman-key --lsign-key 9AE4078033F8024D

cat << EOF >> /etc/pacman.conf

#[liquorix]
#Server = https://liquorix.net/archlinux/$repo$arch
EOF

paru -Syy

printf "\e[1;32mDone! Type exit, umount -a and reboot.\e[0m"
