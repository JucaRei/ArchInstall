#!/usr/bin/env bash

apt install bluedevil
apt install plymouth kde-config-plymouth plymouth-themes

apt install sddm kde-config-sddm sddm-theme-debian-breeze
mkdir -p /etc/sddm.conf.d

# sudo sed -i 's/^Current=.*/Current=debian-breeze/' /etc/sddm.conf.d/theme.conf
# echo -e "[Theme]\nCurrent=debian-breeze" | sudo tee /etc/sddm.conf.d/theme.conf

grep -q '^Current=' /etc/sddm.conf.d/theme.conf \
  && sudo sed -i 's/^Current=.*/Current=debian-breeze/' /etc/sddm.conf.d/theme.conf \
  || echo "Current=debian-breeze" | sudo tee -a /etc/sddm.conf.d/theme.conf

apt install bluedevil kio-extras xdg-utils xdg-user-dirs xdg-desktop-portal xdg-desktop-portal-kde plasma-desktop plasma-workspace kde-plasma-desktop \
  konsole dolphin kate plasma-nm systemsettings powerdevil ark \
  plasma-systemmonitor systemsettings kde-config-screenlocker kscreen plasma-discover plasma-pa okular gwenview mpv ark

