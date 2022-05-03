#!/bin/bash

xdg-user-dirs-update

sleep 3

mkdir -pv ~/.cache/xdgr

doas chmod 0700 ~/.cache/xdgr

doas vpm i libXft-devel libX11-devel harfbuzz-devel libXext-devel libXrender-devel libXinerama-devel --yes
doas vpm i bspwm autorandr arandr jq curl viewnior glu st gping pcmanfm papirus-folders papirus-icon-theme sxhkd glow sxiv ImageMagick fontmanager ranger polybar flameshot light-locker rxvt-unicode rxvt-unicode-terminfo urxvt-perls kitty font-firacode font-awesome dmenu nitrogen feh unclutter xclip libinput libinput-gestures zathura rofi dunst scrot lxappearance lightdm lightdm-gtk3-greeter light-locker mpc neofetch geany xarchiver zip zenmap --yes


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
git clone --depth 1 https://github.com/void-linux/void-packages BinaryBuilder

cd

# Install ASDF
git clone https://github.com/asdf-vm/asdf.git ~/.asdf --branch v0.9.0
# echo ". $HOME/.asdf/asdf.sh" >> ~/.bashrc
# echo ". $HOME/.asdf/completions/asdf.bash" >> ~/.bashrc

cd ~/Documents/workspace/Customizations
git clone https://github.com/JucaRei/rofi
git clone https://github.com/JucaRei/polybar-themes
git clone https://github.com/JucaRei/dotfiles
# git clone https://github.com/JucaRei/fonts

cd ~/Documents/workspace/Configs
git clone --depth 1 https://github.com/JucaRei/ArchInstall

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

cd ~/Documents/workspace/Customizations/rofi
chmod +x setup.sh
./setup.sh

# Install Fonts
# cd ~/Documents/workspace/Configs/ArchInstall/fonts && cp *.ttf *.otf ~/.local/share/fonts
cd ~/Documents/workspace/Configs/ArchInstall/fonts && cp -r ** ~/.local/share/fonts
fc-cache -fv

# mpd e ncmpcpp
cd

cp -f ~/Documents/workspace/Configs/ArchInstall/Dots-Bspwm/mpd/mpd.conf ~/.config/mpd
cp -f ~/Documents/workspace/Configs/ArchInstall/Dots-Bspwm/ncmpcpp/config ~/.ncmpcpp

# Xresources | Fehgb | Xprofile etc
cd
mkdir -pv ~/Pictures/Wallpapers
cp -f ~/Documents/workspace/Customizations/dotfiles/wallpaper.jpg ~/Pictures/Wallpapers
cp -rf ~/Documents/workspace/Customizations/dotfiles/polybar ~/.config
cp -f ~/Documents/workspace/Configs/ArchInstall/Dots-Bspwm/Xresources ~/.Xresources
cp -f ~/Documents/workspace/Configs/ArchInstall/Dots-Bspwm/fehbg ~/.fehgb
cp -f ~/Documents/workspace/Configs/ArchInstall/Dots-Bspwm/xprofile ~/.xprofile
cp -f ~/Documents/workspace/Configs/ArchInstall/Dots-Bspwm/rxvt/vtwhell ~/.urxvt/ext
cp -f ~/Documents/workspace/Configs/ArchInstall/Dots-Bspwm/rxvt/config-reload ~/.urxvt/ext
mkdir ~/.bin
cp -f ~/Documents/workspace/Configs/ArchInstall/Dots-Bspwm/dualbsp.sh ~/.bin
cp -f ~/Documents/workspace/Configs/ArchInstall/Dots-Bspwm/DualMonPolybar.sh ~/.bin
sudo cp -f ~/Documents/workspace/Configs/ArchInstall/Dots-Bspwm/display-lightdm.sh /etc/lightdm
cp -f /etc/dunst/dunstrc ~/.config/dunst/
install -Dm755 /usr/share/doc/bspwm/examples/bspwmrc ~/.config/bspwm/bspwmrc
install -Dm644 /usr/share/doc/bspwm/examples/sxhkdrc ~/.config/sxhkd/sxhkdrc

sudo sed -i 's/#greeter-session=example-gtk-gnome/greeter-session=lightdm-gtk-greeter/g' /etc/lightdm/lightdm.conf

cat <<EOF >>~/.config/bspwm/bspwmrc

~/.fehbg &
xrdb ~/.Xresources &
~/.config/polybar/launch.sh &
picom -f &
xsetroot -cursor_name left_ptr &
~/.bin/dualbsp.sh
EOF

# echo 'eval "$(starship init bash)"' >> ~/.bashrc

sudo ln -s /etc/sv/mpd /var/service

cd ~/Documents/workspace/Configs/ArchInstall/Dots-Bspwm/
cp -f bashrc ~/.bashrc
cp -f zshrc ~/.zshrc

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

echo "Installation finished! Please, reboot."
