# Arch Basic Install Commands-Script

Remember that the first part of the Arch Linux install is manual, that is you will have to partition, format and mount the disk yourself. Install the base packages and make sure to include git so that you can clone the repository in chroot.

#### A small summary:

```sh
  ip a (see ip address to ssh installsudo)
```

- If needed, load your keymap
    - `loadkeys br-abnt2`

2.  Refresh the servers with pacman -Syy and fix sync time
    - `sudo pacman -Syy`
    - `timedatectl set-ntp true`

- Select best servers for your location
    - `reflector -c Brazil -a 6 --sort rate --save /etc/pacman.d/mirrorlist`

4.  Partition your disk:

- **cfdisk** /dev/sd**X** (write)
- **gdisk** /dev/sd**X** (write)
    - `(boot, swap, linuxFileSystem, etc)`

5.  Now, Format the partitions:
    - mkfs.btrfs /dev/sd**X**  (can be **any** filesystem you like not only ext4)
    - mkfs.fat -F32 /dev/sda**X**  (boot **MUST** be fat32)
    - mkswap /dev/sda**X** - (swap if you already want to make a swap partition)
6.  Activate the swap:
    
- swapon /dev/sda**X** (swapNumber)

7.  Mount the partitions

	- 	mount /dev/sda**X**   /mnt
	- 	(mount efi windows) mkdir /mnt/boot
	- 	mount /dev/sd**X**(efi windows number) /mnt/boot
	- 	(windows partition acessible on linux) /mnt/windows10
	-	 mount /dev/sd**X** /mnt/windows10

8.  Mount Btrfs subvolumes

- Root subvolume:
    - `btrfs su cr /mnt/@`
- Home subvolume:
    - `btrfs su cr /mnt/@home`
- Snapshots subvolume:
    - `btrfs su cr /mnt/@snapshots`
- Var_log subvolume:
    - `btrfs su cr /mnt/@var_log`

9.  Umount to fix their own respective directories:

	- `umount /mnt`

```Remember
    On oldpc use the EFI from default OS (mac) to boot, which is on /dev/sda1 
```
```ex
    mount /dev/sda1 /mnt/boot
```

10. Mount the subvolumes:

```compress
  choose lzo or zstd for compression  (compress-force=ztsd:5  | compress-force=lzo:4)
```

- `mount -o noatime,ssd,compress-force=zstd:18,space_cache=v2,commit=120,discard=async,subvol=@ /dev/sdaX /mnt`
- `mkdir -p /mnt/{boot/{efi,grub},Windows,home,.snapshots,var/log}`
- `mount -o noatime,ssd,compress-force=zstd:18,space_cache=v2,commit=120,discard=async,subvol=@home /dev/sdaX /mnt/home`
- `mount -o noatime,ssd,compress-force=zstd:18,space_cache=v2,commit=120,discard=async,subvol=@snapshots /dev/sdaX /mnt/.snapshots`
- `mount -o noatime,ssd,compress-force=zstd:18,space_cache=v2,commit=120,discard=async,subvol=@var_log /dev/sdaX /mnt/var/log`
    - Dont forget to mount boot and Windows:
        - mount /dev/sd**X** *(boot)* /mnt/
        - mount /dev/sd**X** *(Windows)* /mnt/Windows
    

11. Check if everything is ok:

- `lsblk -f`

### Now install the base packages for the System

12. Install the base packages into /mnt 
### **Arch**

	- (intel-ucode or amd-ucode)
- `pacstrap /mnt base linux-lts linux-lts-headers linux-firmware git nano vim intel-ucode reflector mtools dosfstools btrfs-progs pacman-contrib`

### **Artix**

	- (intel-ucode or amd-ucode)
- `basestrap /mnt base base-devel linux-lts linux-lts-headers runit elogind-runit linux-firmware git vim intel-ucode mtools dosfstools btrfs-progs`
### **OLDPC**

- ` pacstrap /mnt base linux linux-headers linux-firmware intel-ucode git vim nano`

#### Generate the FSTAB file with:

- `genfstab -U /mnt >> /mnt/etc/fstab`

**Artix**

- `fstabgen -U /mnt >> /mnt/etc/fstab` 

#### Enter in the installation directory

- `arch-chroot /mnt`

**Artix**

- `artix-chroot /mnt`


```OldPC
    OldMac

    bootctl --path=/boot install
```

- `cd /boot/`
- `cd /loader`
- `vim loader.conf`
- change the last string to `arch-*`
- `cd /entries/`
- **make file arch.conf**
- `vim arch.conf`
- paste commands with your image:

```entries
title   Arch Linux
linux   /vmlinuz-linux
initrd  /initramfs-linux.img
options root=/dev/sda3 rw
```

1.  Download the git repository with git clone
2.  cd arch-basic
### Anothers way to create swap file:
    - fallocate -l 3GB /swapfile
    - chmod 600 /swapfile
    - mkswap /swapfile
    - swapon /swapfile

 - Using **ZRAM** (Best)
   - `pacman -S zramd`
   - edit **/etc/default/zramd**, uncomment **MAX_SIZE**, put your desired value
   - `MAX_SIZE=3072` (3GB)
   - enable the service: `sudo sytemctl enable --now zramd.service`
   - check if it's enabled: `lsblk`

-echo "swapfile none swap defaults 0 0" >> /etc/fstab

## Other Configurations after install

 - `Add to mkinitcpio.conf`
   - MODULES = `(btrfs i915 nvidia)`
   - ON HOOKS remove **fsck** and add `btrfs` `grub-btrfs-overlayfs`
   - ON BINARIES put `"/usr/bin/btrfs"`

 - `Optimus Manager`
   - edit the config file `sudo nano /etc/optimus-manager/optimus-manager.conf`
   - On **[nvidia]** change the `dynamic_power_management` to **fine**
   - On **[optimus]** change the `startup_mode` to **hybrid**

## Other Repos

### Chaotic-AUR

**Install the primary key, with it install our keyring, and finishing installing our mirrorlist.**

`pacman-key --recv-key 3056513887B78AEB --keyserver keyserver.ubuntu.com`\
`pacman-key --lsign-key 3056513887B78AEB`\
`pacman -U 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-keyring.pkg.tar.zst' 'https://cdn-mirror.chaotic.cx/chaotic-aur/chaotic-mirrorlist.pkg.tar.zst'`

Append (add to the **end** of the file) `/etc/pacman.conf`

`[chaotic-aur]`\
`Include = /etc/pacman.d/chaotic-mirrorlist`

### Liquorix

**Key-ID:** `9AE4078033F8024D`

`pacman-key --keyserver hkps://keyserver.ubuntu.com --recv-keys 9AE4078033F8024D` \
`pacman-key --lsign-key 9AE4078033F8024D`

`[liquorix]`\
`Server = https://liquorix.net/archlinux/$repo/$arch`
