# Void Linux installation (btrfs without luks or lvm)

loadkeys br-abnt2

### Connecting with Wifi


### Connecting to the internet
```console
# cp /etc/wpa_supplicant/wpa_supplicant.conf /etc/wpa_supplicant/wpa_supplicant-<wlan-interface>.conf
# wpa_passphrase <ssid> <passphrase> >> /etc/wpa_supplicant/wpa_supplicant-<wlan-interface>.conf
# sv restart dhcpcd
# ip link set up <interface>
```

### Update the repo
```update
  xbps-install -Su xbps
```

### Make 3 partitions for boot, root and home.

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

```mount
  - mount -o noatime,ssd,compress-force=zstd:20,space_cache=v2,commit=120,discard=async,subvol=@ /dev/sdaX /mnt

  - mkdir -p /mnt/{boot/efi,home,.snapshots,var/log}

  - mount -o noatime,ssd,compress-force=zstd:20,space_cache=v2,commit=120,discard=async,subvol=@ /dev/sdaX /mnt/home

  - mount -o noatime,ssd,compress-force=zstd:20,space_cache=v2,commit=120,discard=async,subvol=@ /dev/sdaX /mnt/.snapshots

  - mount -o noatime,ssd,compress-force=zstd:20,space_cache=v2,commit=120,discard=async,subvol=@ /dev/sdaX /mnt/var/log

  - mount /dev/sdX /mnt/boot/efi
```

### Add REPO

```config
REPO=https://alpha.de.repo.voidlinux.org/current
ARCH=x86_64
```
### Install base system

```base
XBPS_ARCH=$ARCH xbps-install -S -r /mnt -R "$REPO" base-system vim git wget efibootmgr btrfs-progs nano ntfs-3g mtools dosfstools grub-x86_64-efi void-repo-nonfree elogind polkit dbus chrony neofetch glow bluez bluz-alsa xdg-user-dirs xdg-utils
```

### Bind before chroot

```bind
- mount --rbind /sys /mnt/sys && mount --make-rslave /mnt/sys

- mount --rbind /dev /mnt/dev && mount --make-rslave /mnt/dev

- mount --rbind /proc /mnt/proc && mount --make-rslave /mnt/proc
```

### Copy network config to mnt

```net
cp /etc/resolv.conf /mnt/etc
```
### Chroot

 - chroot /mnt /bin/bash

###  Set your zone

- ln -sf /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime

### add locales (US, pt-BR)

- vim /etc/default/libc-locales 

 - xbps-reconfigure -f glibc-locales

### Add hostname and edit hosts
- **echo "desiredname" > /etc/hostname**

### Configuring hosts file 
**Place below content in the file /etc/hosts**

```hosts
127.0.0.1 localhost
::1 localhost
127.0.1.1 desiredname.localdomain desiredname
```
### Change Root password
```pass
  passwd
```
### Add user
```user
useradd juca -m -c "Full User Name" -s /bin/bash
passwd juca
usermod -aG wheel,audio,video,optical,bluetooth,storage juca

  - visudo
  (uncomment %wheel ALL=(ALL) ALL)
```
### Generate fstab and fix
```fstab
cat /proc/mounts >> /etc/fstab
  - remove proc mounts (efi  must be 2 at the end)
```
### Install Bootloader


```grub
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=VOID

update-grub
```
### Installing network-related packages 
```internet
xbps-install -Sy NetworkManager pavucontrol
```

### Check if everything is ok
```check
xbps-reconfigure -fa

hwclock --systohc
```

  REBOOT
=========================================================

### Post Installation

#### Enabling RTC service 
```conf
ln -s /etc/sv/chronyd /var/service/
```
#### Enabling network-related services 
```conf
ln -s /etc/sv/{dhcpcd,NetworkManager} /var/service/
```
#### Enabling services for seat 
```conf
ln -srf /etc/sv/{dbus,polkitd,elogind} /var/service
```
#### Install some packages
```packages
sudo xbps-install -S intel-ucode pulseaudio pavucontrol alsa-plugins-pulseaudio
```

#### Video

```video
#Intel
sudo xbps-install -S xf86-video-intel

# Open Source
sudo xbps-install -S xf86-video-nouveau

#Nvidia
sudo xbps-install -S nvidia
```

#### Virtual Machines

```vm
sudo xbps-install virt-manager qemu bridge-utils
```
#### **Load Services**

```sv
sudo ln -s /etc/sv/libvirtd /var/service
sudo ln -s /etc/sv/virtlockd /var/service
sudo ln -s /etc/sv/virtlogd /var/service

# Check services

sudo sv status libvirtd 
sudo sv status virtlogd 
sudo sv status virtlockd
``` 

Install your Desktop Enviroment or Window Manager
================================================================
