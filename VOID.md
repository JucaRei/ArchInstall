# Void Linux installation (btrfs without luks or lvm)

loadkeys br-abnt2

### Connecting with Wifi

```cp
cp /etc/wpa_supplicant/wpa_supplicant.conf /etc/wpa_supplicant/wpa_supplicant-<interface>.conf
wpa_passphrase <SSID> <password> >> /etc/wpa_supplicant/wpa_supplicant-<interface>.conf
wpa_supplicant -B -i <interface> -c /etc/wpa_supplicant/wpa_supplicant-<interface>.conf
```

make 3 partitions for boot, root and home.

```format
mkfs.fat -F32 /dev/sdX
mkfs.btrfs /dev/sdX
mkfs.btrfs /dev/sdX
```

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