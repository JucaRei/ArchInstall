###################################
############# XFCE4 ###############
###################################

cat <<EOF > /etc/xbps.d/90-xfce-ignore.conf
ignorepkg=ristretto
# ignorepkg=mousepad
# ignorepkg=xfce4-terminal
ignorepkg=parole
EOF

vpm i xfce4 xfce4-datetime-plugin xfce4-docklike-plugin network-manager-applet blueman xfce4-fsguard-plugin xfce4-weather-plugin xfce4-systemload-plugin xfce4-pulseaudio-plugin xfce4-panel-appmenu xfce4-places-plugin xfce4-genmon-plugin xfce4-i3-workspaces-plugin xfce4-mpc-plugin lightdm light-locker thunar-archive-plugin thunar-media-tags-plugin gnome-icon-theme-xfce pavucontrol -y

ln -svrf /etc/sv/lightdm /var/service