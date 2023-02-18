#!/bin/sh

###########################
########## XFCE4 ##########
###########################

### xfwm4 
# apt install -y libxfce4ui-utils thunar xfce4-appfinder xfce4-panel \
# xfce4-pulseaudio-plugin xfce4-whiskermenu-plugin xfce4-session xfce4-settings \
# xfce4-terminal xfconf xfdesktop4 xfwm4 adwaita-qt qt5ct \
# xdg-user-dirs-gtk xdg-utils debian-goodies zenity zenity-common

### Openbox
sudo apt install -y libxfce4ui-utils thunar thunar-archive-plugin xfce4-appfinder xfce4-panel \
xfce4-pulseaudio-plugin xfce4-whiskermenu-plugin xfce4-session xfce4-settings \
stterm thunar-archive-plugin xfconf xfdesktop4 obconf adwaita-qt qt5ct \
xdg-user-dirs-gtk xdg-utils blueman xfwm4 pavucontrol debian-goodies zenity zenity-common xfce4-battery-plugin \
xfce4-notifyd xfce4-xkb-plugin xfce4-power-manager thunar-volman thunar-font-manager \
lightdm at-spi2-core orchis-gtk-theme network-manager-gnome slick-greeter lightdm-settings light-locker xfce4-places-plugin \
mpv xfce4-appmenu-plugin gnome-disk-utility thunar-media-tags-plugin gigolo xfce4-weather-plugin fancontrol \
xfce4-systemload-plugin

# Install pacstall
yes | sudo bash -c "$(curl -fsSL https://git.io/JsADh || wget -q https://git.io/JsADh -O -)"

###########################
########## KDE ############
###########################

#apt purge -y konqueror

#apt install --no-install-recommends -y kde-config-plymouth kde-config-screenlocker plasma-discover \
#kde-config-sddm xdg-utils xdg-user-dirs xdg-desktop-portal-kde systemsettings kde-plasma-desktop \
#plasma-desktop plasma-workspace plasma-integration plasma-pa plasma-nm firefox-esr kate arc kcalc \
#plasma-discover-backend-snap plasma-discover-backend-flatpak kwin-x11 \
#kio-extras qml-module-qtbluetooth plasma-discover-backend-fwupd kde-spectacle okular powerdevil bluedevil \
#qml-module-org-kde-newstuff shedtool kwalletmanager ark kscreen libcanberra-pulse qt5-style-kvantum qt5-style-kvantum-themes \

###########################
########## LXQT ###########
###########################

# apt install --no-install-recommends -y lxqt-qtplugin lxqt-core
apt install --no-install-recommends lxqt-core pcmanfm-qt obconf-qt ark preload featherpad picom qt5-style-kvantum poppler-utils openbox breeze-icon-theme breeze-cursor-theme kde-style-breeze qshutdown upower pavucontrol-qt synaptic gdebi lxappearance lxappearance-obconf \
stterm qt5-style-kvantum-themes
###########################
########## GNOME ##########
###########################

# apt install gdm3 gnome-backgrounds gnome-session adwaita-icon-theme \
# gnome-themes-standard gnome-control-center gnome-tweaks software-properties-gtk \
# network-manager pulseaudio gnome-terminal nautilus firefox gnome-core --no-install-recommends

apt install gdm3 gnome-backgrounds gnome-session adwaita-icon-theme \
gnome-themes-standard gnome-control-center gnome-tweaks software-properties-gtk \
network-manager pulseaudio gnome-terminal nautilus firefox-esr gnome \
python3-nautilus python3-psutil python3-pip libglib2.0-bin dconf-editor --no-install-recommends

sudo pip3 install nautilus-terminal
sudo nautilus-terminal --install-system


/etc/gdm3/daemon.conf

WaylandEnable=false
DefaultSession=gnome-xorg.desktop
