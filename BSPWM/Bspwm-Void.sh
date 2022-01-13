#!/bin/bash

xdg-user-dirs-update

sudo vpm -S bspwm xorg-minimal autorandr arandr pcmanfm sxhkd glow ranger polybar light-locker rxvt-unicode rxvt-unicode-terminfo urxvt-perls playerctl font-firacode font-awesome dmenu nitrogen feh unclutter xclip libinput libinput-gestures picom evince neovim rofi dunst scrot lxappearance lightdm lightdm-webkit2-greeter font-iosevka light-locker mpd ncmpcpp mpv mpc neofetch nvtop htop geany

mkdir -p ${HOME}/Documents/workspace/{Github,Others,Customizations,Configs,Tests,Composes}
mkdir -p ${HOME}/.local/share/fonts
mkdir -p ${HOME}/.urxvt/ext
mkdir -p ${HOME}/.config/{bspwm,rofi,sxhkd,dunst,polybar}
mkdir -p ${HOME}/.config/{mpd,ncmpcpp} && cd ${HOME}/.config/mpd
touch database mpd.conf mpd.fifo mpd.log mpdstate

cd

cd ${HOME}/Documents/workspace/Customizations
git clone https://github.com/JucaRei/rofi
git clone https://github.com/JucaRei/polybar-themes
git clone https://github.com/JucaRei/dotfiles
git clone https://github.com/JucaRei/fonts

cd ${HOME}/Documents/workspace/Configs
git clone https://github.com/JucaRei/ArchInstall

# Font Preview
mkdir ${HOME}/scripts
curl -L https://git.io/raw_fontpreview > fontpreview && chmod +x fontpreview
echo "export PATH=$HOME/scripts/fontpreview:$PATH" >> ${HOME}/.bashrc
source ${HOME}/.bashrc

cd ${HOME}/Documents/workspace/Customizations/rofi
chmod +x setup.sh
./setup.sh

# Install Fonts
cd ${HOME}/Documents/workspace/Customizations/fonts/fonts && cp *.ttf *.otf ${HOME}/.local/share/fonts
fc-cache -fv

# mpd e ncmpcpp
cd

cp -f ${HOME}/ArchInstall/BSPWM/mpd/mpd.conf ${HOME}/.config/mpd
cp -f ${HOME}/ArchInstall/BSPWM/ncmpcpp/config ${HOME}/.config/ncmpcpp

# Xresources | Fehgb | Xprofile etc
cd
cp -f ${HOME}/Documents/workspace/Configs/Customizations/dotfiles/wallpaper.jpg ${HOME}/Pictures
cp -f ${HOME}/Documents/workspace/Configs/Customizations/dotfiles/polybar ${HOME}/.config
cp -f ${HOME}/Documents/workspace/Configs/ArchInstall/BSPWM/Xresources ${HOME}/.Xresources
cp -f ${HOME}/Documents/workspace/Configs/ArchInstall/BSPWM/fehbg ${HOME}/.fehgb
cp -f ${HOME}/Documents/workspace/Configs/ArchInstall/BSPWM/xprofile ${HOME}/.xprofile
cp -f ${HOME}/Documents/workspace/Configs/ArchInstall/BSPWM/vtwhell ${HOME}/.urxvt/ext
cp -f ${HOME}/Documents/workspace/Configs/ArchInstall/BSPWM/dualbsp.sh ${HOME}/scripts
cp -f ${HOME}/Documents/workspace/Configs/ArchInstall/BSPWM/DualMonPolybar.sh ${HOME}/scripts
sudo cp -f ${HOME}/Documents/workspace/Configs/ArchInstall/BSPWM/display-lightdm.sh /etc/lightdm
sudo cp -f /etc/dunst/dunstrc ${HOME}/.config/dunst
install -Dm755 /usr/share/doc/bspwm/examples/bspwmrc ~/.config/bspwm/bspwmrc
install -Dm644 /usr/share/doc/bspwm/examples/sxhkdrc ~/.config/sxhkd/sxhkdrc


cat << EOF >> ${HOME}/.config/bspwm/bspwmrc

${HOME}/.fehbg &
xrdb ${HOME}/.Xresources &
${HOME}/.config/polybar/launch.sh &
setxkbmap br &
picom -f &
xsetroot -cursor_name left_ptr &
${HOME}/scripts/dualbsp.sh
EOF 