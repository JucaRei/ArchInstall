#
#   Instructions for making hybrid GPT/MBR boot USB thumb drive.
#   The Slackware Linux installer will be added to the image as an example,
#   however the syslinux configuration can be modified to include any desired
#   image.
#
#   A USB thumb drive formatted with these instructions was able to
#   boot the Slackware Installer on a:
#
#      Dell Latitude E6430 in Legacy BIOS mode
#      SuperMicro E300-9A in UEFI mode
#
#   Minimum Required Packages (in order of use):
#
#      syslinux 6.03
#      gptfdisk 1.0.0
#      util-linux 2.27.1
#      dosfstools 3.0.28
#

# download and untar syslinux package
cd
rm -f  syslinux-6.03.tar.xz
wget https://www.kernel.org/pub/linux/utils/boot/syslinux/syslinux-6.03.tar.xz
rm -Rf syslinux-6.03
tar -xvf syslinux-6.03.tar.xz
cd syslinux-6.03
sudo rm -Rf /tmp/syslinux
make -s install INSTALLROOT=/tmp/syslinux


# partition disk
   # clear existing data
   sudo sgdisk /dev/sdb --zap-all

   # create 1st partition
   sudo sgdisk /dev/sdb --new=1:0:+1M
   sudo sgdisk /dev/sdb --typecode=1:EF02

   # create 2nd parition
   sudo sgdisk /dev/sdb --new=2:0:0
   sudo sgdisk /dev/sdb --typecode=2:0700

   # make hybrid
   sudo sgdisk /dev/sdb --hybrid=1:2

   # convert to MBR and activate partition 2
   sudo sgdisk /dev/sdb --zap
   sudo sfdisk --activate /dev/sdb 2

   # add boot code to MBR
   sudo dd \
      bs=440 count=1 conv=notrunc \
      if=~/syslinux-6.03/efi64/mbr/gptmbr.bin \
      of=/dev/sdb

   # backup MBR table
   sudo rm -f /tmp/mbr.backup
   sudo dd bs=512 count=1 conv=notrunc \
      if=/dev/sdb \
      of=/tmp/mbr.backup

   # convert back to GPT and adjust partition numbers
   sudo sgdisk /dev/sdb --mbrtogpt
   sudo sgdisk /dev/sdb --transpose=1:2
   sudo sgdisk /dev/sdb --transpose=2:3

   # re-adjust partition 2 information for GPT
   sudo sgdisk /dev/sdb --typecode=2:EF00
   sudo sgdisk /dev/sdb --change-name=2:"BootDisk"
   sudo sgdisk /dev/sdb --attributes=2:set:2

   # convert GPT to hybrid GPT
   sudo sgdisk /dev/sdb --hybrid=1:2

   # restore MBR with bootable partition 2
   sudo dd bs=512 count=1 conv=notrunc \
      if=/tmp/mbr.backup \
      of=/dev/sdb

   # refresh partition table in kernel memory
   sudo partprobe /dev/sdb


# review partition tables
   # using fdisk
   sudo fdisk -l /dev/sdb

   # using gdisk
   sudo gdisk -l /dev/sdb
   sudo fdisk -i 1 /dev/sdb
   sudo fdisk -i 2 /dev/sdb
   sudo fdisk -i 3 /dev/sdb

   # using parted
   sudo parted -a optimal -s /dev/sdb print


# create and mount file-system
sudo mkdosfs -F 32 -I -n "BOOTDISK" /dev/sdb2
sudo mount /dev/sdb2 /mnt/tmp
sudo mkdir -p /mnt/tmp/EFI/BOOT
sudo mkdir -p /mnt/tmp/boot
sudo mkdir -p /mnt/tmp/syslinux/bin


# download slackware installer
sudo wget \
   -O /mnt/tmp/boot/bzImage \
   https://mirrors.kernel.org/slackware/slackware64-14.2/kernels/huge.s/bzImage
sudo wget \
   -O /mnt/tmp/boot/initrd \
   https://mirrors.kernel.org/slackware/slackware64-14.2/isolinux/initrd.img


# copy EFI64 syslinux to USB disk
sudo cp ~/syslinux-6.03/efi64/efi/syslinux.efi                  /mnt/tmp/EFI/BOOT/BOOTX64.EFI
sudo cp ~/syslinux-6.03/efi64/com32/elflink/ldlinux/ldlinux.e64 /mnt/tmp/EFI/BOOT/
sudo cp /lib/modules/$(uname -r)/modules.alias                  /mnt/tmp/EFI/BOOT/modules.als
sudo cp /usr/share/hwdata/pci.ids                               /mnt/tmp/EFI/BOOT/
sudo find ~/syslinux-6.03/efi64 -type f -name '*.c32' -exec sudo cp -v {} /mnt/tmp/EFI/BOOT/ \;


# copy BIOS syslinux to USB disk
sudo rsync -ra /tmp/syslinux/usr/share/syslinux/ /mnt/tmp/syslinux
sudo rsync -ra /tmp/syslinux/usr/bin/            /mnt/tmp/syslinux/bin
sudo cp /lib/modules/$(uname -r)/modules.alias   /mnt/tmp/syslinux/modules.als
sudo cp /usr/share/hwdata/pci.ids                /mnt/tmp/syslinux/


# install syslinux in MBR
sudo /mnt/tmp/syslinux/bin/syslinux -i /dev/sdb2


# create initial configuration
sudo rm -f /tmp/syslinux.cfg
cat << EOF |sed -e 's/^   //g' > /tmp/syslinux.cfg

   serial 0 9600
   prompt 1
   UI menu.c32

   MENU TITLE USB Boot Disk Menu
   MENU TABMSG Press [TAB] to edit options, or [ESC] for CLI.
   MENU ROWS 13
   MENU HELPMSGROW 20
   MENU WIDTH 78
   MENU MARGIN 6

   menu color screen       37;40      #80ffffff #00000000 std
   menu color border       30;44      #40000000 #00000000 std
   menu color title        1;36;44    #c00090f0 #00000000 std
   menu color unsel        37;44      #90ffffff #00000000 std
   menu color hotkey       1;37;44    #ffffffff #00000000 std
   menu color sel          1;30;47    #e0000000 #20ff8000 all
   menu color hotsel       1;7;37;40  #e0400000 #20ff8000 all
   menu color disabled     1;30;44    #60cccccc #00000000 std
   menu color scrollbar    30;44      #40000000 #00000000 std
   menu color tabmsg       31;40      #90ffff00 #00000000 std
   menu color cmdmark      1;36;40    #c000ffff #00000000 std
   menu color cmdline      37;40      #c0ffffff #00000000 std
   menu color pwdborder    30;47      #80ffffff #20ffffff std
   menu color pwdheader    31;47      #80ff8080 #20ffffff std
   menu color pwdentry     30;47      #80ffffff #20ffffff std
   menu color timeout_msg  37;40      #80ffffff #00000000 std
   menu color timeout      1;37;40    #c0ffffff #00000000 std
   menu color help         37;40      #c0ffffff #00000000 std
   menu color msg07        37;40      #90ffffff #00000000 std


   MENU BEGIN
   MENU LABEL ^Syslinux Modules

   label cli
       MENU LABEL Syslinux ^CLI
       TEXT HELP
       Enter Syslinux CLI to use Syslinux utilities found in /syslinux/ or to
       manually boot the system using one of the system targets.
       ENDTEXT
       MENU QUIT

   label hdt
      MENU LABEL ^Hardware Detection Tool
      kernel hdt.c32
      append pciids=/syslinux/pci.ids modules_alias=/syslinux/modules.als

   label dmitest
      MENU LABEL ^DMI Information
      kernel dmitest.c32

   label local
      MENU LABEL Boot from ^local drive
      localboot 0xffff

   label reboot
       MENU LABEL System ^Reboot
       kernel reboot.c32

   label poweroff
       MENU LABEL System ^Power Off
       kernel poweroff.com

   MENU END

   label slackware
       MENU LABEL Slackware Linux 14.2 Install (64 bits)
       TEXT HELP
       Boot 64 bit Slackware installer for system builds or troubleshooting.

       Press [TAB] to append required boot options (i.e. console=ttyS1,115200).
       ENDTEXT
       kernel /boot/bzImage
       initrd /boot/initrd
       append load_ramdisk=1 prompt_ramdisk=0 rw printk.time=0  nomodeset

EOF
sudo cp /tmp/syslinux.cfg /mnt/tmp/EFI/BOOT/syslinux.cfg
sudo cp /tmp/syslinux.cfg /mnt/tmp/syslinux/syslinux.cfg


# umount and exit
cd
sudo umount /mnt/tmp


# end of document
