#!/usr/bin/env bash

#############
### XFCE4 ###
#############

chroot mnt apt install \
  xfce4-panel \
  xfce4-session \
  xfce4-settings \
  xfce4-terminal \
  xfwm4 \
  xfdesktop4 \
  thunar \
  xfce4-appfinder \
  xfconf \
  libxfce4ui-utils

chroot /mnt apt install lightdm

chroot /mnt apt install \
  dbus-x11 \
  xfce4-notifyd \
  xfce4-power-manager \
  gvfs-backends \
  network-manager-gnome \
  xfce4-pulseaudio-plugin \
  xfce4-power-manager-plugins \
  xdg-desktop-portal \
  librsvg2-common \
  solaar \
  at-spi2-core \
  ristretto \
  tumbler

# edid-decode

cat <<EOF > /etc/udev/rules.d/99-logitech-receiver.rules
KERNEL=="hidraw*", SUBSYSTEM=="hidraw", MODE="0660", GROUP="plugdev", TAG+="uaccess"
EOF

chroot /mnt apt install firefox ffmpeg libavcodec-extra pavucontrol

##############
### FCITX5 ###
##############
chroot /mnt apt install fcitx5 libfcitx5-qt1 fcitx5-config-qts
cat <<EOF >>$HOME/.bashrc
export GTK_IM_MODULE=fcitx
export QT_IM_MODULE=fcitx
export XMODIFIERS="@im=fcitx"
EOF

cat <<EOF >$HOME/.XCompose
<dead_acute> <c> : "ç"
<dead_acute> <C> : "Ç"
EOF