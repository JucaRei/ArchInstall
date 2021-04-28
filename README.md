# Arch Basic Install Commands-Script

Remember that the first part of the Arch Linux install is manual, that is you will have to partition, format and mount the disk yourself. Install the base packages and make sure to inlcude git so that you can clone the repository in chroot.

A small summary:

```sh
  ip a (see ip address to ssh installsudo)
```

1. If needed, load your keymap
  -loadkeys br-abnt2
2. Refresh the servers with pacman -Syy
  -sudo pacman -Syyy
3. Partition the disk
  -cfdisk /dev/sda  (write)
4. Format the partitions
  mkfs.ext4 /dev/sda(number)    (can be any filesystem you like not only ext4)
5. Mount the partitions
  -mount /dev/sda(number) /mnt
  
  -(mount efi windows)  mkdir /mnt/boot
  -mount /dev/sda(efi windows number) /mnt/boot

  -(windows partition acessible on linux)  /mnt/windows10
  -mount /dev/sda(number)  /mnt/windows10
6. Install the base packages into /mnt (pacstrap /mnt base linux linux-firmware git vim (intel-ucode or amd-ucode))
7. Generate the FSTAB file with: 
  -genfstab -U /mnt >> /mnt/etc/FSTAB
8. Chroot in with arch-chroot /mnt
9.  Download the git repository with git clone
10. cd arch-basic
11. Create swap file:
  -fallocate -l 1GB  /swapfile
  -chmod 600 /swapfile
  -mkswap  /swapfile
  -swapon /swapfile

  -echo "swapfile none swap defaults 0 0" >> /etc/fstab
12. chmod +x install-uefi.sh
13. run with ./install-uefi.sh
