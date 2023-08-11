#!/bin/sh

apt install --no-install-recommends -y kde-config-plymouth kde-config-screenlocker plasma-discover \
kde-config-sddm xdg-utils xdg-user-dirs xdg-desktop-portal-kde systemsettings kde-plasma-desktop  \
plasma-desktop plasma-workspace plasma-integration plasma-pa plasma-nm firefox-esr kate arc kcalc \
plasma-discover-backend-snap plasma-discover-backend-flatpak kde-config-flatpak kwin-x11 kde-config-gtk-style \
kio-extras qml-module-qtbluetooth plasma-discover-backend-fwupd kde-spectacle okular powerdevil bluedevil sddm \
qml-module-org-kde-newstuff schedtool kwalletmanager ark kscreen libcanberra-pulse qt5-style-kvantum qt5-style-kvantum-themes \
kde-config-gtk-style-preview kde-config-systemd kde-zeroconf kdegraphics-thumbnailers materia-kde \
plasma-disks plasma-firewall plasma-wallpapers-addons mpv kdiskmark konqueror-

systemctl enable sddm

# openbox-kde-session plasma-wayland-protocols plasma-workspace-wayland syncthingtray-kde-plasma
# vlc vlc-plugin-samba