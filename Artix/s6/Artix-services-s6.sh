#!/bin/bash


#Options
aur_helper=true


if [[ $aur_helper = true ]]; then
 cd /tmp
 git clone https://aur.archlinux.org/paru.git
 cd paru/
 makepkg -si --noconfirm
 cd 
fi

paru -S netmount-s6 nfs-utils nfs-utils-s6 samba samba-s6 fusesmb metalog metalog-s6 mpd mpd-s6 zramen-s6

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


sudo s6-rc-bundle add default nfs-server nmbd smbd statd rpcbind mpd metalog

sudo s6-rc -u change nfs-server
sudo s6-rc -u change nmbd
sudo s6-rc -u change smbd
sudo s6-rc -u change statd
sudo s6-rc -u change rpcbind
sudo s6-rc -u change mpd
sudo s6-rc -u change metalog
