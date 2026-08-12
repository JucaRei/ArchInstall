# 1. Verificar se algo está usando /mnt
sudo fuser -vm /mnt 2>&1
sudo lsof +D /mnt 2>/dev/null | head -20

# 2. Desmontar na ordem certa
sudo umount /mnt/run
sudo umount /mnt/sys
sudo umount /mnt/proc
sudo umount /mnt/dev
sudo umount /mnt/boot/efi
sudo umount /mnt/boot
sudo umount /mnt/var/lib/containers
sudo umount /mnt/var/lib/libvirt
sudo umount /mnt/var/swap
sudo umount /mnt/.snapshots
sudo umount /mnt/var/cache
sudo umount /mnt/var/tmp
sudo umount /mnt/var/spool
sudo umount /mnt/var/log
sudo umount /mnt/opt
sudo umount /mnt/nix
sudo umount /mnt/home
sudo umount /mnt

# 3. Confirmar
mount | grep /mnt
