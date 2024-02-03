#!/bin/sh

drive=/dev/vda

sgdisk -Z ${drive}


cat | parted ${drive} << END
mklabel msdos
mkpart primary ext2 1 2
set 1 boot on
mkpart primary xfs 2 100%
print
quit
END

0;