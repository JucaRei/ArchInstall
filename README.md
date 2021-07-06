# Arch Basic Install Commands-Script

Remember that the first part of the Arch Linux install is manual, that is you will have to partition, format and mount the disk yourself. Install the base packages and make sure to include git so that you can clone the repository in chroot.

#### A small summary:

```sh
  ip a (see ip address to ssh installsudo)
```

- If needed, load your keymap
    - `loadkeys br-abnt2`

2.  Refresh the servers with pacman -Syy and fix sync time
    - `sudo pacman -Syyy`
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
    - btrfs su cr /mnt/@
- Home subvolume:
    - btrfs su cr /mnt/@home
- Snapshots subvolume:
    - btrfs su cr /mnt/@snapshots
- Var_log subvolume:
    - btrfs su cr /mnt/@var_log

9.  Umount to fix their own respective directories:

	- umount /mnt

10. Mount the subvolumes:

```compress
  choose lzo or zstd for compression  (compress-force=ztsd:5  | compress-force=lzo:4)
```

- `mount -o noatime,compress=lzo,space_cache=v2,subvol=@ /dev/sda(filesytemNumber) /mnt`
- `mkdir -p /mnt/{boot,home,.snapshots,var_log}`
- `mount -o noatime,compress=lzo,space_cache=v2,subvol=@home /dev/sda(filesytemNumber) /mnt/home`
- `mount -o noatime,compress=lzo,space_cache=v2,subvol=@snapshots /dev/sda(filesytemNumber) /mnt/.snapshots`
- `mount -o noatime,compress=lzo,space\_cache=v2,subvol=@var\_log /dev/sda(filesytemNumber) /mnt/var_log`
    - Dont forget to mount boot:
        - mount /dev/sd**X** *(boot)* /mnt/boot

11. Check if everything is ok:

- lsblk

### Now install the base packages for the System

12. Install the base packages into /mnt (`pacstrap /mnt base linux-zen linux-zen-headers linux-firmware git vim (intel-ucode or amd-ucode) reflector mtools dosfstools btrfs-progs`

#### Generate the FSTAB file with:

- `genfstab -U /mnt >> /mnt/etc/fstab`

#### Enter in the installation directory

- `arch-chroot /mnt`

1.  Download the git repository with git clone
2.  cd arch-basic
3.  Create swap file:
    -	fallocate -l 1GB /swapfile
    -	chmod 600 /swapfile
    -	mkswap /swapfile
    -	swapon /swapfile

-echo "swapfile none swap defaults 0 0" >> /etc/fstab
12\. chmod +x install-uefi.sh
13\. run with ./install-uefi.sh