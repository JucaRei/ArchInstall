## Arch Linux Installation Process for a Legacy/BIOS/MBR System

We will tackle this process in 10 steps listed below.

I didn't want to repeat some sections well explained in the [UEFI Process](https://gist.github.com/3516ee4582f74fc3c41fee3541369fd5#file-arch-linux-installation-on-uefi-gpt-system-md).
You can refer there and follow due process.

Namely;

- Connecting to WiFi.
- Installing Base System(pacstrap).
- Setting Timezone & Language.
- Adding Super User and Configurations.
- Optimizing Mirrors.
- Installing Fonts and Various Packages.
- Enabling Vital System Services.


### Step 1: Why

Many Operating Systems often try to craft a one size fits all partition layout for their file systems.
This is quite wrong since they don't know about the details of your hardware and how you plan to use your computer(your needs).

But a linux distribution like [Arch Linux](https://archlinux.org), and to an extend [ArchLabs](https://archlabslinux.com) gives you that freedom to [do it yourself!](https://en.wikipedia.org/wiki/Do_it_yourself).

Another thing to note is that, if your *kernel* and *initramfs* are on the root file system, you may be unable
to perform the recovery in case you system crushes for one reason or another.

By having the *bootloader*, *kernel* and *initramfs* all on a single filesystem that is rarely accessed or updated, you can increase your chances of recovering the rest of the system.

There are many ways that you can layout your partitions, but for my use case, I will focus on:

1. Type of Hardware *(BIOS or UEFI)*
   - I have one `bios` and another `uefi` laptop.
2. The Brand of the Bootloader *(GRUB or Syslinux)*
   - I will use GRUB for UEFI laptop and Syslinux for Legacy, since I tried using GRUB with the later,I didn't make it.More of a surrendering mode.
   - Actually from ArchWikis,they say  syslinux works quite well with legacy and it is known that GRUB has issues of not working especially on the `grub-install  /dev/sdX` part.
3. I use my laptops for technical work, so *the order*,*the type* and *the size* of partitions matter for my use case.
4. I am just a speed enthusiast, like High Performance Computing and why not try to learn by doing it!

Actually some of my MAIN reasons of installing vanilla linux(Arch Linux) are:

- **No Bloatware** - Imagine `4GB` image for Windows, `2GB`+ for Fedora or Ubuntu but Arch Linux approx. `700MB`.
  Softwares preinstalled that you will never use.
- **Performance & Security** - You install other distros; some crapware/spyware you didn't install are working in the background slowing your machine and making you quite uncomfortable.
- **Learning** - you get to understand linux better, nitty gritty.
- **Minimalism** - We Keep It Simple Stupid (KISS)

  

### Step 2: Boot Options
First change the boot options to follow this order, we need to clear out this one first.

**Boot Mode**

* Legacy *(ensure this is selected)*
*  UEFI Hybrid (With CSM)
*  UEFI Native (Without CSM)

**Legacy Boot Order**

* Notebook Hard Drive *(ensure this appears at the top of list)*
* USB Hard Drive
* USB CD-ROM
* Optical Disk Drive
* USB Floppy
* Notebook Ethernet
* SD Card


### Step 3: What is Different from UEFI Process

The installation is quite similar to the one for [UEFI](https://gist.github.com/3516ee4582f74fc3c41fee3541369fd5#file-arch-linux-installation-on-uefi-gpt-system-md) but with key differences in: 
- Installing and configuring the Bootloader (Syslinux)
- Partitioning - Refer to my partitioning scheme for [Legacy System](https://gist.github.com/1891ee0c2e7c9584a42b99587716f69c#file-why-this-partitioning-scheme-md)

**Note to Self:**
For most part of the installation procedure use the UEFI one but switch immediately to the above process especially on the key items listed above.

### Step 4: Formatting and mounting the Partitions

#### 4.1 /boot partition (A)
```
$ mkdir -p /mnt/boot
$ mkfs.ex4 /dev/sda1
$ mount /dev/sda1 /mnt/boot
```

Don't forget to verify the `boot flag` has been set for this partition.
Otherwise, If you forgot to do it.Run the below commands consecutively.

**Note:** If you forget to set the bootable flag for obvious reasons, you system won't boot.
Then you will be left wondering what went wrong and you won't love the troubleshooting process.

```bash
$ parted /dev/sda

```
Then one inside `(parted)`

```bash
$ set 1 boot on
```
Above command simply means, in lay terms
We are using parted command on our physical hard disk `/dev/sda` and setting partition 1 as bootable.
Our partition 1 is `/dev/sda1`

#### 4.2 / - root partition (B)
```
$ mkfs.ext4 /dev/sda2
$ mount /dev/sda2 /mnt
```

#### 4.3  /home partition (C)
```
$ mkdir -p /mnt/home
$ mkfs.ext4 /dev/sda3
$ mount /dev/sda /mnt/home
```

#### 4.4 /var partition (D)
```
$ mkdir -p /mnt/var
$ mkfs.ext4 /dev/sda4
$ mount /dev/sda4 /mnt/var
```

**No swap for my legacy system because you are allowed a maximum of 4 partition!**
- /boot
- /       -> root partition
- /home        
- /var

**Important to Note:**
*Mounting* the partitions to their respective filesystems is VERY important.Because if you happen
to forget this key step, all your installation i.e `# pacman -S linux linux-firmware` or `pacstrap /mnt base base-devel`
will be futile.

But the following step will help us verify that we have mounted everything and we are good to go!

### Step 5: Generating Fstab File and Editing it for Performance

Run the following command ONCE to generate fstab file
```
$ genfstab -U /mnt >> /mnt/etc/fstab
```
To verify this  we can type
```
$cat /mnt/etc/fstab
```

You will probably see something similar to this file contents

```
# /dev/sda3
UUID=8ecbb432-2adc-4c5d-8ce7-aa46838879c2     /          <omitted_details_here>

# /dev/sda1
UUID=853332ca-3428-4fb5-9b6b-626afc36e734    /boot       <omitted_details_here> 

# /dev/sda2                                   
UUID=eea1eccf-f57a-420d-9a16-64c5b9cee480    /var        <omitted_details_here>                         

# /dev/sda4
UUID=dce64fe0-4f6e-455c-b744-61852b56a711    /home       <omitted_details_here>

```

Now edit that file to look like the one below

Run, to do the editing
```
# nano /mnt/etc/fstab
```

```
# dev/sda3
/dev/sda3              /                  <omitted_details_here>

# dev/sda1
/dev/sda1              /boot              <omitted_details_here> 

# /dev/sda2                                   
/dev/sda2              /var               <omitted_details_here>                         

# /dev/sda4
/dev/sda4              /home              <omitted_details_here>   

```

You will notice we are only replacing the UUID  with the corresponding partition above.
This actually improves the speed/performance of your machine when booting. Got this trick from Arch Wikis.
And I saw it in works!

If in any case your fstab file is blank,no need to proceed from here.Go back and have all partitions mounted and done correctly.
Otherwise if you proceed, you are definitely be beating your head against the wall.

Note: you can't edit this file unless you install nano first, maybe check the file is OK first with the UUID and revisit it immediately after nano or vim has been installed.



### Step 6: Install Linux Kernel and Firmware (lts)
lts - Long Term Support
```
# pacman -S linux-lts linux-firmware intel-ucode linux-headers

```
Other important applications to install
```
# pacman nano dialog iw wpa_supplicant networkmanager
```
### Step 7: Install Syslinux bootloader for Legacy System
```
# pacman -S syslinux 
```

#### 7.1 Create Entries for the Boot Menu

```
# syslinux-install_update -i -a -m

```
Output for the above command should be:

```
Syslinux BIOS install successful
Boot Flag Set - /dev/sda1
Installed MBR (/usr/lib/syslinux/bios/mbr.bin) to /dev/sda
```
The key thing to note in that output is where the Boot Flag has been set!
It should be `/dev/sda1` which in my case is correct.


#### 7.2 Edit the syslinux config to point to the correct kernel/root partition

```
# nano /boot/syslinux/syslinux.cfg

```
My root partition is/in  `/dev/sda2`.

Now run the following command to ensure everything is OK.You may get 2 or few warnings ignore(do note them though).
What you can't ignore are the errors.

```
# mkinitcpio -p linux-lts

```

#### 7.3  syslinux.cfg
The `syslinux.cfg` file is located in `/boot/syslinux/`, so the absolute path is`/boot/syslinux/syslinux.cfg`

An example `syslinux.cfg` file here taken from `ArchLabs`  installer.

```
UI vesamenu.c32
MENU TITLE ArchLinux Boot Menu
MENU BACKGROUND splash.png
TIMEOUT 50
DEFAULT Arch

# see: https://www.syslinux.org/wiki/index.php/Comboot/menu.c32
MENU WIDTH 78
MENU MARGIN 4
MENU ROWS 4
MENU VSHIFT 10
MENU TIMEOUTROW 13
MENU TABMSGROW 14
MENU CMDLINEROW 14
MENU HELPMSGROW 16
MENU HELPMSGENDROW 29
MENU COLOR border       30;44   #40ffffff #a0000000 std
MENU COLOR title        1;36;44 #9033ccff #a0000000 std
MENU COLOR sel          7;37;40 #e0ffffff #20ffffff all
MENU COLOR unsel        37;44   #50ffffff #a0000000 std
MENU COLOR help         37;40   #c0ffffff #a0000000 std
MENU COLOR timeout_msg  37;40   #80ffffff #00000000 std
MENU COLOR timeout      1;37;40 #c0ffffff #00000000 std
MENU COLOR msg07        37;40   #90ffffff #a0000000 std
MENU COLOR tabmsg       31;40   #30ffffff #00000000 std

LABEL ArchLinux
MENU LABEL Arch Linux 
LINUX ../vmlinuz-linux-lts
APPEND  root=/dev/sda2 rw
INITRD ../intel-ucode.img,../initramfs-linux-lts.img

LABEL ArchLinuxfallback
MENU LABEL Arch Linux Fallback
LINUX ../vmlinuz-linux-lts
APPEND  root=/dev/sda2 rw
INITRD ../intel-ucode.img,../initramfs-linux-lts-fallback.img

```
From the above config file, we are interested specifically in these sections.

- LINUX  - verify it is the correct kernel
- APPEND - should point to your root filesystem
- INITRD - verify correct initramfs and intel-ucode images

Same process applies for the fallback

You can navigate to that directory and check it contents
```
$ cd /boot
$ ls
```
That directory should have your `kernel` and `initramfs` as well as `syslinux` directory.
Within the syslinux directory various `*.c32` files and `syslinux.cfg`,file above.
```
LABEL ArchLinux
MENU LABEL Arch Linux 
LINUX ../vmlinuz-linux-lts
APPEND  root=/dev/sda2 rw
INITRD ../intel-ucode.img,../initramfs-linux-lts.img

LABEL ArchLinuxfallback
MENU LABEL Arch Linux Fallback
LINUX ../vmlinuz-linux-lts
APPEND  root=/dev/sda2 rw
INITRD ../intel-ucode.img,../initramfs-linux-lts-fallback.img

```

### Step 8: Install Display Server

Our display server will be `xorg`

```
# pacman -S xorg xorg-apps xorg-server xorg-drivers terminator mesa  xdg-user-dirs fuse2 ntfs-3g exfat-utils pulseaudio pulseaudio-bluetooth bluez-utils pavucontrol  gvfs dkms haveged git unrar unzip htop feh lsb-release  firefox 
```
The display server and its accompanying packages are
`xorg xorg-apps xorg-server xorg-drivers`
from the list above.

### Step 9: Install Display Manager and Configure it with the Desktop Environment

Our display manager will be `lightdm`

```
# pacman -S lightdm lightdm-gtk-greeter 

```

#### 9.1 Configure Light Display Manager
```
# nano /etc/lightdm/lightdm.conf
```

```
greeter-session=lightdm-gtk-greeter

user-session=cinnamon-session-cinnamon

```

#### 9.2 Enable LightDM Service
```
# systemctl enable lightdm
```

You may as well take the opportunity enable the Network Manager

```
# systemctl enable NetworkManager

```

#### 9.3 Check the sessions you have in your system
```
# ls /usr/share/xsessions
```
### Step 10: Install Cinnamon Desktop Environment

`cinnamon` will be our desktop environment.We can later experiment with `i3`

```
# pacman -S cinnamon

```

After we are done with the last bit.It is time to unmount our partition and reboot our system.

First exit root
```
# exit
```
Unmount the root partition, all the other partitions unmount as well if you run the following command

```
$ umount -R /mnt

```
Reboot
```
$ reboot
```

Note:You may refer [here](https://gist.github.com/833a90963feca8b6f0958cc9689b8b83#file-sw-to-install-after-arch-install-md) incase you need to configure cinnamon further


### Troubleshooting

#### 1. Force disable service
```
systemctl disable -f gdm.service
Removed /etc/systemd/system/display-manager.service
```

#### 2. Check what is 'eating'  your space
```
# pacman -S  ncdu

# ncdu -x /
```
Above command check for root directory

you can rather use
```
# df -h -t ext4 
```

#### 3. TIMED OUT ERROR

  [TIME] Timed out waiting for device /dev/disk/by-uuid/E6B9-2FS

  [DEPEND] Dependency failed for File System check on /dev/disk/by-uuid/.....

  [DEPEND] Dependency failed for /boot/efi

  [DEPEND] Dependency failed for Local File Systems

  I have seen this error get fixed by editing the fstab file.

#### 4. Check you network interface once you login

`$ iw dev` or  `$ iwconfig`

`sudo iwlist wlan0 scan | grep ESSID`

or `ip addr show`

#### 5. Wipe File Systems

```
# wipefs -a /dev/sda

```
If that does not work

```
# sgdisk -Z /dev/sda
```

### References

- https://legends2k.github.io/note/arch_install/

- https://sudaraka.org/how-to/archlinux-installation-guide-2019/
  
- https://haefelfinger.ch/posts/2019/2019-07-22-Install-arch-linux-with-archfi/

- https://ssh.guru/arch-linux-installation-step-by-step/
