#!/bin/bash
#xdg-user-dirs-update

mkdir -pv ~/.cache/xdgr

doas chmod 0700 ~/.cache/xdgr

# Base LXQT
doas vpm i sddm lxqt nm-tray bluedevil kvantum qtpass FeatherPad kcalc qlipper obconf-qt compton-conf xdg-desktop-portal-lxqt lxqt-themes lximage-qt udiskie compton-conf firefox-esr flatpak mpv pavucontrol-qt picom jq xkill menumaker gping papirus-folders papirus-icon-theme ImageMagick feh xclip unclutter scrot flameshot fontmanager --yes

# Some themes
doas vpm i Adapta yaru numix-themes --yes

# lxqt-notificationd lxappearance-obconf

doas vpm i lightdm lightdm-gtk3-greeter --yes

# More Packages
doas vpm i alsa-firmware alsa-plugins-ffmpeg alsa-plugins-jack alsa-plugins-samplerate alsa-plugins-speex zathura mpv mpd ncmpcpp neofetch viewnior udevil htop geany geany-plugins-extra geany-plugins xarchiver zip --yes

### terminals ###      
doas vpm i xterm rxvt-unicode rxvt-unicode-terminfo urxvt-bidi urxvt-perls urxvtconfig --yes
# doas vpm i kitty kitty-terminfo --yes


mkdir -p ~/.local/share/applications
mkdir -p ~/Documents/workspace/{Github,Builds/Void-Packages,Others,Customizations,Configs,Tests,Composes}
mkdir -p ~/.local/share/fonts
mkdir -p ~/.urxvt/ext
mkdir -p ~/.config/rofi
mkdir -p ~/.config/mpd
mkdir -p ~/.local/bin
mkdir -p ~/.bin
mkdir -p ~/.ncmpcpp 
cd ~/.config/mpd
touch database mpd.conf mpd.fifo mpd.log mpdstate

# marktext xinput xsetmode xinput_calibrator xf86-input-evdev
# Old mac
cd ~/Documents/workspace/Builds
git clone https://github.com/linux-on-mac/mbpfan.git
cd mbpfan/
make 
sudo make install
sudo make   
sudo vpm i sassc gtk-engine-murrine --yes

cd ~/Documents/workspace/Builds
mkdir -p Xdeb AppImagesFolder 
cd Xdeb 
wget -c https://github.com/toluschr/xdeb/releases/download/1.3/xdeb
mv xdeb ~/.local/bin && cd ~/.local/bin
chmod +x xdeb

# cat << EOF >> ~/.bashrc
# ### Xdeb Configs ###

# export PATH="/home/juca/Documents/workspace/Builds/Xdeb:$PATH"
# export XDEB_OPT_DEPS=true
# export XDEB_OPT_SYNC=true
# export XDEB_OPT_WARN_CONFLICT=true
# export XDEB_OPT_FIX_CONFLICT=true
# EOF

# Xbps-Src

cd ~/Documents/workspace/Builds/Void-Packages
git clone --depth 1 https://github.com/void-linux/void-packages BinaryBuilder
cd ~/Documents/workspace/Builds/Void-Packages/BinaryBuilder
./xbps-src binary-bootstrap
echo XBPS_ALLOW_RESTRICTED=yes >> etc/conf

# Install Picom Ibhagwan
# git clone --depth=1 https://github.com/ibhagwan/picom-ibhagwan-template
# mv picom-ibhagwan-template ./srcpkgs/picom-ibhagwan
# ./xbps-src pkg picom-ibhagwan
# doas xbps-install --repository=hostdir/binpkgs picom-ibhagwan 
# cd

# Install ASDF
git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.9.0
# echo ". $HOME/.asdf/asdf.sh" >> ~/.bashrc
# echo ". $HOME/.asdf/completions/asdf.bash" >> ~/.bashrc

cd ~/Documents/workspace/Customizations
git clone https://github.com/JucaRei/rofi
# git clone https://github.com/JucaRei/polybar-themes
# git clone https://github.com/JucaRei/dotfiles
# git clone https://github.com/JucaRei/fonts

cd ~/Documents/workspace/Configs
git clone --depth 1 https://github.com/JucaRei/ArchInstall

# Font Preview
# mkdir ~/scripts
# cd ~/scripts
cd ~/Documents/workspace/Others
git clone --depth=1 https://github.com/JucaRei/fontpreview
cd fontpreview
sudo make install 
# echo 'export PATH="$HOME/scripts/fontpreview:$PATH"' >> ~/.bashrc
mv fontpreview ~/.local/bin
cd ..
rm -rf fontpreview/
source ~/.bashrc

cd

cd ~/Documents/workspace/Customizations/rofi
chmod +x setup.sh
./setup.sh

# Install Fonts
# cd ~/Documents/workspace/Configs/ArchInstall/fonts && cp *.ttf *.otf ~/.local/share/fonts
cd ~/Documents/workspace/Configs/ArchInstall/fonts && cp -r ** ~/.local/share/fonts
fc-cache -fv

# mpd e ncmpcpp
cd

cp -f ~/Documents/workspace/Configs/ArchInstall/Dots-WM/mpd/mpd.conf ~/.config/mpd
cp -f ~/Documents/workspace/Configs/ArchInstall/Dots-WM/ncmpcpp/config ~/.ncmpcpp

# Openbox themes
git clone --depth=1 https://github.com/addy-dclxvi/openbox-theme-collections ~/.themes

# Xresources | Fehgb | Xprofile etc
cd
mkdir -pv ~/Pictures/{Screenshots,Wallpapers}
cp -r ~/Documents/workspace/Configs/ArchInstall/Dots-WM/openbox/{rc.xml,menu.xml,autostart,environment} ~/.config/openbox
cp -f ~/Documents/workspace/Configs/ArchInstall/wallpapers/** ~/Pictures/Wallpapers
cp -f ~/Documents/workspace/Configs/ArchInstall/Dots-WM/Xresources ~/.Xresources
# cp -f ~/Documents/workspace/Configs/ArchInstall/Dots-WM/fehbg ~/.fehbg
cp -f ~/Documents/workspace/Configs/ArchInstall/Dots-WM/fehauto.sh ~/.local/bin
chmod +x ~/.local/bin/fehauto.sh
cp -f ~/Documents/workspace/Configs/ArchInstall/Dots-WM/openbox/{lxde-rc.xml,autostart} ~/.config/openbox/
cp -f ~/Documents/workspace/Configs/ArchInstall/Dots-WM/xprofile ~/.xprofile
cp -f ~/Documents/workspace/Configs/ArchInstall/Dots-WM/rxvt/vtwhell ~/.urxvt/ext
cp -f ~/Documents/workspace/Configs/ArchInstall/Dots-WM/rxvt/config-reload ~/.urxvt/ext
cp -f ~/Documents/workspace/Configs/ArchInstall/Dots-WM/dualbsp.sh ~/.bin
cp -f ~/Documents/workspace/Configs/ArchInstall/Dots-WM/DualMonPolybar.sh ~/.bin
sudo cp -f ~/Documents/workspace/Configs/ArchInstall/Dots-WM/display-lightdm.sh /etc/lightdm

sudo sed -i 's/#greeter-session=example-gtk-gnome/greeter-session=lightdm-gtk-greeter/g' /etc/lightdm/lightdm.conf


# echo 'eval "$(starship init bash)"' >> ~/.bashrc

sudo ln -s /etc/sv/mpd /var/service

cd ~/Documents/workspace/Configs/ArchInstall/Dots-WM/
cp -f bashrc ~/.bashrc
cp -f zshrc ~/.zshrc

cd

# Bash Insulter
sudo wget -O /etc/bash.command-not-found https://gitlab.com/dwt1/bash-insulter/-/raw/master/src/bash.command-not-found

# ASDF
git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.9.0

### DT Shell Color script
cd $HOME/Documents/Workspace/Others
git clone --depth=1 https://gitlab.com/dwt1/shell-color-scripts.git
cd shell-color-scripts
rm -rf /opt/shell-color-scripts || return 1
doas mkdir -p /opt/shell-color-scripts/colorscripts || return 1
doas cp -rf colorscripts/* /opt/shell-color-scripts/colorscripts
doas cp colorscript.sh /usr/bin/colorscript

# optional for zsh completion
doas cp zsh_completion/_colorscript /usr/share/zsh/site-functions

# generate menu
# mmaker -vf OpenBox3

echo "Installation finished! Please, reboot."
