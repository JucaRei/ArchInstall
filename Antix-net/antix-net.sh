#!/bin/bash

#####################################
####Gptfdisk Partitioning example####
#####################################

apt update
apt install neovim btrfs-progs -y

sgdisk -Z /dev/vda

# -s script call | -a optimal
parted -s -a optimal /dev/vda mklabel gpt

# Create new partition
sgdisk -n 0:0:100MiB /dev/vda
# sgdisk -n 0:0:2000MiB /dev/vda
sgdisk -n 0:0:0 /dev/vda

# Change the name of partition
sgdisk -c 1:AntixBoot /dev/vda
# sgdisk -c 2:Swap /dev/vda
sgdisk -c 2:Antixlinux /dev/vda

# Change Types
sgdisk -t 1:ef00 /dev/vda
# sgdisk -t 2:8200 /dev/vda
sgdisk -t 2:8300 /dev/vda

sgdisk -p /dev/vda

#####################################
##########  FileSystem  #############
#####################################

mkfs.vfat -F32 /dev/vda1 -n "EFIBoot"
# mkswap /dev/sda4
# swapon /dev/sda4
mkfs.btrfs /dev/vda2 -f -L "Antixlinux"

cli-installer
