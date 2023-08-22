#!/bin/sh

# Podman
doas cat <<EOF >>/etc/containers/registries.conf

[registries.search]
registries = ['docker.io', 'registry.fedoraproject.org', 'quay.io', 'registry.access.redhat.com', 'registry.centos.org']
EOF

podman system migrate
doas loginctl enable-linger $USER
doas loginctl user-status $USER
# rootless
mkdir -pv /home/$USER/.config/{systemd,containers}

# LXQT Packages and custom
vpm i blueman FeatherPad ImageMagick ncdu avahi avahi-discover breeze-cursors picom kde-gtk-config5 kvantum xdg-desktop-portal-lxqt xdg-utils lxqt pavucontrol-qt lxqt-themes lxtask mbpfan menumaker numix-themes papirus-folders papirus-icon-theme qtpass sddm sddm-kcm xarchiver xclip xclipboard yaru --yes

# Apps
vpm i firefox-esr flameshot fontmanager geany geany-plugins geany-plugins-extra kcalc mpd mpv ncmpcpp playerctl qbittorrent vscode --yes

# St suckless
vpm i libXft-devel libX11-devel harfbuzz-devel libXext-devel libXrender-devel libXinerama-devel gd-devel --yes


# Graphics
# vpm i intel-gpu-tools inxi libva-intel-driver --yes

sleep 1
xdg-user-dirs-update
sleep 1

curl https://raw.githubusercontent.com/jarun/advcpmv/master/install.sh --create-dirs -o ./advcpmv/install.sh && (cd advcpmv && sh install.sh)

mkdir -pv ~/.runit/{sv,runsvdir}
mkdir -pv /home/$USER/Documents/workspace/{Github,Configs,Tests}

git clone --depth=1 https://github.com/madand/runit-services /home/$USER/Documents/workspace/Configs/runit-services
git clone --depth=1 https://github.com/siduck/st /home/$USER/Documents/workspace/Configs/st
cd /home/$USER/Documents/workspace/Configs/runit-services
git clone --depth=1 https://github.com/Nefelim4ag/Ananicy.git Ananicy
cd /home/$USER/Documents/workspace/Configs/runit-services/Ananicy
doas make install
doas rm -rf /lib/systemd
doas mkdir /etc/sv/ananicy
doas touch /etc/sv/ananicy/{run,finish}
doas cat <<EOF >>/etc/sv/ananicy/run
#!/bin/sh
exec /usr/bin/ananicy start
EOF
doas cat <<EOF >>/etc/sv/ananicy/finish
#!/bin/sh
exec /sbin/sysctl -e kernel.sched_autogroup_enabled=1
EOF
doas ln -sfv /etc/sv/ananicy /var/service

# /usr/share/plymouth/plymouthd.defaults

#usr/share/sddm/scripts/Xsetup


vpm i lxqt kvantum sddm sddm-kcm --yes

cat <<EOF >/etc/xbps.d/90-lxqt-ignore.conf
ignorepkg=lxqt-sudo
ignorepkg=qterminal
ignorepkg=wayland
ignore=pkg=xorg-server-xwayland
ignore=pkg=kwayland
ignore=pkg=kwayland-devel
ignore=pkg=kwayland-server
EOF

vpm i xorg-minimal xhost xorg-server-xdmx mesa-dri libva-intel-driver mesa-vulkan-intel vulkan-loader xrdb xsetroot xprop xrefresh xorg-fonts xdpyinfo xclipboard xcursorgen mkfontdir mkfontscale xcmsdb libXinerama-devel xf86-input-libinput libinput-gestures setxkbmap fuse-exfat fatresize xauth xrandr arandr font-misc-misc terminus-font dejavu-fonts-ttf --yes