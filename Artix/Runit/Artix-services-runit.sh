#!/bin/bash

xdg-user-dirs-update

sleep 3

mkdir -pv Documents/workspace/{Github,Configs}

cd $HOME/Documents/workspace/Configs
git clone --depth=1 https://github.com/JucaRei/ArchInstall

cd $HOME/Documents/workspace/Configs/ArchInstall/Arch/Arch_pkgs
sudo pacman -U paru**.zst
sudo pacman -U hfsprogs**.zst
sudo pacman -U nosystemd-boot**.zst

paru -Syu

cd

paru -S netmount-runit nfs-utils nfs-utils-runit samba samba-runit fusesmb metalog metalog-runit mpd mpd-runit zramen-runit

# paru -S nvidia-tweaks nvidia-prime xf86-video-intel 


sudo cat <<EOF > /etc/samba/smb.conf
[global]
   workgroup = WORKGROUP
   dns proxy = no
   log file = /var/log/samba/%m.log
   max log size = 1000
   client min protocol = NT1
   server role = standalone server
   passdb backend = tdbsam
   obey pam restrictions = yes
   unix password sync = yes
   passwd program = /usr/bin/passwd %u
   passwd chat = *New*UNIX*password* %n\n *ReType*new*UNIX*password* %n\n *passwd:*all*authentication*tokens*updated*successfully*
   pam password change = yes
   map to guest = Bad Password
   usershare allow guests = yes
   name resolve order = lmhosts bcast host wins
   security = user
   guest account = nobody
   usershare path = /var/lib/samba/usershare
   usershare max shares = 100
   usershare owner only = yes
   force create mode = 0070
   force directory mode = 0070

[homes]
   comment = Home Directories
   browseable = no
   read only = yes
   create mask = 0700
   directory mask = 0700
   valid users = %S

[printers]
   comment = All Printers
   browseable = no
   path = /var/spool/samba
   printable = yes
   guest ok = no
   read only = yes
   create mask = 0700

[print$]
   comment = Printer Drivers
   path = /var/lib/samba/printers
   browseable = yes
   read only = yes
   guest ok = no
EOF

#Fix mount external HD
sudo mkdir -pv /etc/udev/rules.d
sudo cat << EOF > /etc/udev/rules.d/99-udisks2.rules
# UDISKS_FILESYSTEM_SHARED
# ==1: mount filesystem to a shared directory (/media/VolumeName)
# ==0: mount filesystem to a private directory (/run/media/$USER/VolumeName)
# See udisks(8)
ENV{ID_FS_USAGE}=="filesystem|other|crypto", ENV{UDISKS_FILESYSTEM_SHARED}="1"
EOF

# Not asking for password

sudo mkdir -pv /etc/polkit-1/rules.d
sudo cat << EOF > /etc/polkit-1/rules.d/10-udisks2.rules
// Allow udisks2 to mount devices without authentication
// for users in the "wheel" group.
polkit.addRule(function(action, subject) {
    if ((action.id == "org.freedesktop.udisks2.filesystem-mount-system" ||
         action.id == "org.freedesktop.udisks2.filesystem-mount") &&
        subject.isInGroup("wheel")) {
        return polkit.Result.YES;
    }
});
EOF

sudo cat << EOF > /etc/runit/sv/zramen/conf
export ZRAM_COMP_ALGORITHM='zstd'
#export ZRAM_PRIORITY=32767
export ZRAM_SIZE=100
#export ZRAM_STREAMS=1
EOF

sudo ln -s /etc/runit/sv/netmount /run/runit/service
sudo ln -s /etc/runit/sv/nfs-server /run/runit/service
sudo ln -s /etc/runit/sv/nmbd /run/runit/service
sudo ln -s /etc/runit/sv/smbd /run/runit/service
sudo ln -s /etc/runit/sv/statd /run/runit/service
sudo ln -s /etc/runit/sv/zramen /run/runit/service
sudo ln -s /etc/runit/sv/rpcbind /run/runit/service
sudo ln -s /etc/runit/sv/mpd /run/runit/service
sudo ln -s /etc/runit/sv/metalog /run/runit/service