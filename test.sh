#!/bin/bash

su 

mkdir /etc/pacman.d/hooks
touch /etc/pacman.d/hooks/50-bootbackup.hook
echo "[Trigger]" >> /etc/pacman.d/hooks/50-bootbackup.hook
echo "Operation = Upgrade" >> /etc/pacman.d/hooks/50-bootbackup.hook
echo "Operation = Install" >> /etc/pacman.d/hooks/50-bootbackup.hook
echo "Operation = Remove" >> /etc/pacman.d/hooks/50-bootbackup.hook
echo "Type = Path" >> /etc/pacman.d/hooks/50-bootbackup.hook
echo "Target = boot/*" >> /etc/pacman.d/hooks/50-bootbackup.hook
echo "[Action]" >> /etc/pacman.d/hooks/50-bootbackup.hook
echo "Depends = rsync" >> /etc/pacman.d/hooks/50-bootbackup.hook
echo "Description = Backing up /boot..." >> /etc/pacman.d/hooks/50-bootbackup.hook
echo "When = PreTransaction" >> /etc/pacman.d/hooks/50-bootbackup.hook
echo "Exec = /usr/bin/rsync -a --delete /boot /.bootbackup" >> /etc/pacman.d/hooks/50-bootbackup.hook

touch /etc/pacman.d/hooks/clean_cache.hook
echo "[Trigger]" >> /etc/pacman.d/hooks/clean_cache.hook
echo "Operation = Upgrade" >> /etc/pacman.d/hooks/clean_cache.hook
echo "Operation = Install" >> /etc/pacman.d/hooks/clean_cache.hook
echo "Operation = Remove" >> /etc/pacman.d/hooks/clean_cache.hook
echo "Type = Package" >> /etc/pacman.d/hooks/clean_cache.hook
echo "Target = *" >> /etc/pacman.d/hooks/clean_cache.hook

echo "[Action]" >> /etc/pacman.d/hooks/clean_cache.hook
echo "Description = Cleaning pacman cache..." >> /etc/pacman.d/hooks/clean_cache.hook
echo "When = PostTransaction" >> /etc/pacman.d/hooks/clean_cache.hook
echo "Exec = /usr/bin/paccache -rk 1" >> /etc/pacman.d/hooks/clean_cache.hook

touch /etc/pacman.d/hooks/nvidia.hook
echo "[Trigger]" >> /etc/pacman.d/hooks/nvidia.hook
echo "Operation=Install" >> /etc/pacman.d/hooks/nvidia.hook
echo "Operation=Upgrade" >> /etc/pacman.d/hooks/nvidia.hook
echo "Operation=Remove" >> /etc/pacman.d/hooks/nvidia.hook
echo "Type=Package" >> /etc/pacman.d/hooks/nvidia.hook
echo "Target=nvidia-dkms" >> /etc/pacman.d/hooks/nvidia.hook
echo "Target=linux-zen" >> /etc/pacman.d/hooks/nvidia.hook
echo "# Change the linux part above and in the Exec line if a different kernel is used" >> /etc/pacman.d/hooks/nvidia.hook

echo "[Action]" >> /etc/pacman.d/hooks/nvidia.hook
echo "Description=Update Nvidia module in initcpio" >> /etc/pacman.d/hooks/nvidia.hook
echo "Depends=mkinitcpio" >> /etc/pacman.d/hooks/nvidia.hook
echo "When=PostTransaction" >> /etc/pacman.d/hooks/nvidia.hook
echo "NeedsTargets" >> /etc/pacman.d/hooks/nvidia.hook
echo "Exec=/bin/sh -c 'while read -r trg; do case $trg in linux) exit 0; esac; done; /usr/bin/mkinitcpio -P'" >> /etc/pacman.d/hooks/nvidia.hook
