#!/usr/bin/env bash

# -x = show every command executed
# -e = abort on failure
set -xe

main() {
    # :: swap :: #
    swapoff /var/swap/swapfile || true

    truncate -s 0 /var/swap/swapfile
    chattr +C /var/swap/swapfile

    btrfs property set /var/swap/swapfile compression none

    dd if=/dev/zero of=/var/swap/swapfile bs=1M count=8000 status=progress
    chmod 600 /var/swap/swapfile
    mkswap /var/swap/swapfile
    swapon /var/swap/swapfile

    # :: btrfs_map_physical :: #
    wget https://raw.githubusercontent.com/osandov/osandov-linux/master/scripts/btrfs_map_physical.c
    gcc -O2 -o btrfs_map_physical btrfs_map_physical.c

    # :: edit grub :: #
    offset=$(./btrfs_map_physical /var/swap/swapfile)
    offset_arr=($(echo ${offset}))
    offset_pagesize=($(getconf PAGESIZE))
    offset=$((offset_arr[25] / offset_pagesize))
    btrfsroot=`findmnt / -no UUID`

    sed -i "s#loglevel=3#resume=UUID=$btrfsroot loglevel=3#" /etc/default/grub
    sed -i "s/loglevel=3/resume_offset=$offset loglevel=3/" /etc/default/grub
    # sed -i 's/keymap consolefont filesystems/keymap consolefont filesystems resume/' /etc/mkinitcpio.conf

    # :: remake images :: #
    grub-mkconfig -o /boot/grub/grub.cfg
    # mkinitcpio -P

    # :: cleanup :: #
    rm -f btrfs_map_physical.c
    rm -f btrfs_map_physical

    echo 'All done, please reboot!'
}

main "$@"