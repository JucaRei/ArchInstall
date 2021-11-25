# Void Linux installation (btrfs without luks or lvm)

loadkeys br-abnt2

### Connecting with Wifi

```cp
cp /etc/wpa_supplicant/wpa_supplicant.conf /etc/wpa_supplicant/wpa_supplicant-<interface>.conf
wpa_passphrase <SSID> <password> >> /etc/wpa_supplicant/wpa_supplicant-<interface>.conf
wpa_supplicant -B -i <interface> -c /etc/wpa_supplicant/wpa_supplicant-<interface>.conf
```

### Update the repo
```update
  xbps-install -Su xbps
```

make 3 partitions for boot, root and home.

```format
mkfs.fat -F32 /dev/sdX
mkfs.btrfs /dev/sdX
mkfs.btrfs /dev/sdX
```
REPO=https://alpha.de.repo.voidlinux.org/current
ARCH=x86_64

XBPS_ARCH=$ARCH xbps-install -S -r /mnt -R "$REPO" base-system vim git wget efibootmgr btrfs-progs nano ntfs-3g mtools dosfstools grub-x86_64-efi elogind polkit dbus chrony neofetch

mount --rbind /sys /mnt/sys && mount --make-rslave /mnt/sys

mount --rbind /dev /mnt/dev && mount --make-rslave /mnt/dev

mount --rbind /proc /mnt/proc && mount --make-rslave /mnt/proc

cp /etc/resolv.conf /mnt/etc

chroot /mnt /bin/bash

ln -sf /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime

(locales)
vim /etc/default/libc-locales 
xbps-reconfigure -f glibc-locales

echo "juca" > /etc/hostname

vim /etc/hosts

passwd for root 

useradd juca -m -c "Juca" -s /bin/bash
passwd juca
usermod -aG wheel,audio,video,optical,storage juca

visudo(uncomment %wheel ALL=(ALL) ALL )

cat /proc/mounts >> /etc/fstab
remove proc mounts (efi  must be 2 at the end)

grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=VOID

update-grub

xbps-reconfigure -fa

=========================================================

### Mounting partitions

- mount /dev/sdaX /mnt

```subvol
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@snapshots
btrfs subvolume create /mnt/@var_log
```
- umount /mnt

- mount -o noatime,compress-force=zstd:8,space_cache=v2,commit=60,discard=async,subvol=@ /dev/sdaX /mnt
- mkdir -p /mnt/{boot,home,.snapshots,var/log}
- mount -o noatime,compress-force=zstd:8,space_cache=v2,commit=60,discard=async,subvol=@home /dev/sdaX /mnt/home
- mount -o noatime,compress-force=zstd:8,space_cache=v2,commit=60,discard=async,subvol=@snapshots /dev/sdaX /mnt/.snapshots
- mount -o noatime,compress-force=zstd:8,space_cache=v2,commit=60,discard=async,subvol=@var_log /dev/sdaX /mnt/var/log
- mount /dev/sdX /mnt/boot/efibt
### Create variables for Install your system type:

- export XBPS_ARCH=x86_64
  <br> **OR**
- export XBPS_ARCH=x86_64-musl
- export REPO=https://alpha.de.repo.voidlinux.org/current

### Install base

xbps-install -Suy -r /mnt -R "REPO" base-system btrfs-progs grub nano vim

### Chroot
- mount -t proc proc /mnt/proc/
- mount -t sysfs sys /mnt/sys/
- mount -o bind /dev /mnt/dev
- mount -t devpts pts /mnt/dev/pts
- cp -L /etc/resolv.conf /mnt/etc/
- cp -L /etc/wpa_supplicant/- wpa_supplicant-<interface>.conf /mnt/etc/wpa_supplicant/
- chroot /mnt /bin/bash

### Post Chroot


- ln -sf /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime
- hwclock --systohc
- vim /etc/default/libc-locales
- xbps-reconfigure -f glibc-locales