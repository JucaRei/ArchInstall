#!/bin/bash

xdg-user-dirs-update

sleep 3

mkdir -pv ~/.cache/xdgr

doas chmod 0700 ~/.cache/xdgr

doas vpm i libXft-devel libX11-devel harfbuzz-devel libXext-devel libXrender-devel libXinerama-devel --yes
doas vpm i bspwm autorandr arandr jq curl viewnior glu st gping pcmanfm papirus-folders papirus-icon-theme sxhkd glow sxiv ImageMagick fontmanager ranger polybar flameshot light-locker rxvt-unicode rxvt-unicode-terminfo urxvt-perls kitty st font-firacode font-awesome dmenu nitrogen feh unclutter xclip libinput libinput-gestures zathura rofi dunst scrot lxappearance lightdm lightdm-gtk3-greeter light-locker mpc neofetch geany xarchiver zip zenmap --yes


# marktext xinput xsetmode xinput_calibrator xf86-input-evdev
# Old mac
# sudo vpm i kbdlight mbpfan
# git clone https://github.com/linux-on-mac/mbpfan.git
# cd mbpfan/
# make
# sudo make install
# sudo make
sudo vpm i sassc gtk-engine-murrine

mkdir -p ~/Documents/workspace/{Github,Builds,Others,Customizations,Configs,Tests,Composes}
mkdir -p ~/.local/share/fonts
mkdir -p ~/.urxvt/ext
mkdir -p ~/.config/{bspwm,rofi,sxhkd,dunst,polybar}
mkdir -p ~/.config/mpd
mkdir -p ~/.local/bin
mkdir -p ~/.ncmpcpp
cd ~/.config/mpd
touch database mpd.conf mpd.fifo mpd.log mpdstate

cd ~/Documents/workspace/Builds
mkdir -p Xdeb AppImagesFolder Void-Packages
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

cd ~/Documents/workspace/Builds/Void-Packages
git clone --depth=1 https://github.com/void-linux/void-packages BinaryBuilder
# Web-Greeter
git clone  --depth=1 https://github.com/JezerM/web-greeter Lightdm-Web-GREETER
cd Lightdm-Web-GREETER
pip install -r requirements.txt
sudo make install
cd

# Install ASDF
git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.9.0
# echo ". $HOME/.asdf/asdf.sh" >> ~/.bashrc
# echo ". $HOME/.asdf/completions/asdf.bash" >> ~/.bashrc

cd ~/Documents/workspace/Customizations
git clone --depth=1 https://github.com/JucaRei/rofi
# git clone --depth=1 https://github.com/JucaRei/polybar-themes
# git clone =depth=1   https://github.com/JucaRei/dotfiles
# git clone https://github.com/JucaRei/fonts

cd ~/Documents/workspace/Configs
git clone --depth 1 https://github.com/JucaRei/ArchInstall
cd /Documents/workspace/Configs/ArchInstall/Dots-WM
cp -rf bashrc-Void ~/.bashrc
cd ..
cp -r wallpapers ~/Pictures/Wallpapers
cd


# Font Preview
# mkdir ~/scripts
# cd ~/scripts
cd ~/Documents/workspace/Others
git clone https://github.com/JucaRei/fontpreview
cd fontpreview
sudo make install
# echo 'export PATH="$HOME/scripts/fontpreview:$PATH"' >> ~/.bashrc
mv fontpreview ~/.local/bin
cd ..
rm -rf fontpreview/
source ~/.bashrc

cd

# cd ~/Documents/workspace/Customizations/rofi
# chmod +x setup.sh
# ./setup.sh

# Install Fonts
# cd ~/Documents/workspace/Configs/ArchInstall/fonts && cp *.ttf *.otf ~/.local/share/fonts
cd ~/Documents/workspace/Configs/ArchInstall/fonts && cp -r ** ~/.local/share/fonts
fc-cache -fv

# mpd e ncmpcpp
cd

cp -f ~/Documents/workspace/Configs/ArchInstall/Dots-WM/mpd/mpd.conf ~/.config/mpd
cp -f ~/Documents/workspace/Configs/ArchInstall/Dots-WM/ncmpcpp/config ~/.ncmpcpp

# Xresources | Fehgb | Xprofile etc
cd
cp -rf ~/Documents/workspace/Configs/ArchInstall/Dots-WM/Bspwm-Nitro-Artix/local ~/.local
cp -rf ~/Documents/workspace/Configs/ArchInstall/Dots-WM/Bspwm-Nitro-Artix/polybar ~/.config
cp -rf ~/Documents/workspace/Configs/ArchInstall/Dots-WM/Bspwm-Nitro-Artix/zathura ~/.config
cp -rf ~/Documents/workspace/Configs/ArchInstall/Dots-WM/Bspwm-Nitro-Artix/xprofile ~/.xprofile
cp -rf ~/Documents/workspace/Configs/ArchInstall/Dots-WM/Bspwm-Nitro-Artix/Xresources ~/.Xresources
cp -rf ~/Documents/workspace/Configs/ArchInstall/Dots-WM/Bspwm-Nitro-Artix/geany ~/.config
cp -rf ~/Documents/workspace/Configs/ArchInstall/Dots-WM/Bspwm-Nitro-Artix/sxhkd ~/.config
cp -rf ~/Documents/workspace/Configs/ArchInstall/Dots-WM/Bspwm-Nitro-Artix/themes ~/.themes
cp -rf ~/Documents/workspace/Configs/ArchInstall/Dots-WM/Bspwm-Nitro-Artix/icons ~/.icons
cp -rf ~/Documents/workspace/Configs/ArchInstall/Dots-WM/Bspwm-Nitro-Artix/polybar ~/.config
cp -rf ~/Documents/workspace/Configs/ArchInstall/Dots-WM/Bspwm-Nitro-Artix/starship~/.config
cp -rf ~/Documents/workspace/Configs/ArchInstall/Dots-WM/Bspwm-Nitro-Artix/conky ~/.conky
cp -rf ~/Documents/workspace/Configs/ArchInstall/Dots-WM/Bspwm-Nitro-Artix/picom ~/.config
cp -rf ~/Documents/workspace/Configs/ArchInstall/Dots-WM/Bspwm-Nitro-Artix/nano ~/.config
cp -rf ~/Documents/workspace/Configs/ArchInstall/Dots-WM/Bspwm-Nitro-Artix/mpv ~/.config
cp -rf ~/Documents/workspace/Configs/ArchInstall/Dots-WM/Bspwm-Nitro-Artix/dunst ~/.config
cp -f ~/Documents/workspace/Configs/ArchInstall/Dots-WM/Bspwm-Nitro-Artix/rxvt/vtwhell ~/.urxvt/ext
cp -f ~/Documents/workspace/Configs/ArchInstall/Dots-WM/Bspwm-Nitro-Artix/rxvt/config-reload ~/.urxvt/ext
mkdir ~/.bin
cp -f ~/Documents/workspace/Configs/ArchInstall/Dots-WM/bin/ ~/.bin

sudo sed -i 's/#greeter-session=example-gtk-gnome/greeter-session=lightdm-gtk-greeter/g' /etc/lightdm/lightdm.conf

# echo 'eval "$(starship init bash)"' >> ~/.bashrc

sudo ln -s /etc/sv/mpd /var/service


cd

# Bash Insulter
sudo wget -O /etc/bash.command-not-found https://gitlab.com/dwt1/bash-insulter/-/raw/master/src/bash.command-not-found

# ASDF
git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.9.0

### DT Shell Color script
cd $HOME/Documents/Workspace/Others
git clone https://gitlab.com/dwt1/shell-color-scripts.git
cd shell-color-scripts
rm -rf /opt/shell-color-scripts || return 1
sudo mkdir -p /opt/shell-color-scripts/colorscripts || return 1
sudo cp -rf colorscripts/* /opt/shell-color-scripts/colorscripts
sudo cp colorscript.sh /usr/bin/colorscript

# optional for zsh completion
sudo cp zsh_completion/_colorscript /usr/share/zsh/site-functions

cd /etc/lightdm/
doas touch checkmonitors.sh
doas cat << EOF > checkmonitors.sh
#!/bin/sh
# eDP1 - Lap Screen  |  HDMI-1-0 External monitor
# Lightdm or other script for dual monitor

#xrandr --setprovideroffloadsink NVIDIA-G0 Intel &
#xrandr --setprovideroffloadsink 1 0 &
#xrandr --setprovideroffloadsink modesetting NVIDIA-G0 &
xrandr --setprovideroffloadsink NVIDIA-G0 modesetting &
#xrandr --setprovideroutputsource 1 0 &
xrandr --setprovideroutputsource modesetting NVIDIA-G0 &

numlockx on &

XCOM0=$(xrandr -q | grep 'HDMI-1-0 connected')
XCOM1=$(xrandr --output eDP1 --primary --auto --output HDMI-1-0 --auto --left-of eDP1)
XCOM2=$(xrandr --output eDP1 --primary --auto)
# if the external monitor is connected, then we tell XRANDR to set up an extended desktop
if [ -n "$XCOM0" ] || [ ! "$XCOM0" = "" ]; then
    echo $XCOM1
# if the external monitor is disconnected, then we tell XRANDR to output only to the laptop screen
else
    echo $XCOM2
fi

exit 0

EOF

echo "Installation finished! Please, reboot."