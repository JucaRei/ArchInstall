#!/bin/bash

#xdg-user-dirs-update

sudo vpm i bspwm xorg-minimal autorandr arandr pcmanfm sxhkd glow sviv ImageMagick ranger polybar flameshot light-locker rxvt-unicode rxvt-unicode-terminfo urxvt-perls playerctl font-firacode font-awesome dmenu nitrogen feh unclutter xclip libinput libinput-gestures picom evince neovim rofi dunst scrot lxappearance lightdm lightdm-gtk3-greeter font-iosevka light-locker mpd ncmpcpp mpv mpc neofetch htop geany

mkdir -p ~/Documents/workspace/{Github,Others,Customizations,Configs,Tests,Composes}
mkdir -p ~/.local/share/fonts
mkdir -p ~/.urxvt/ext
mkdir -p ~/.config/{bspwm,rofi,sxhkd,dunst,polybar}
mkdir -p ~/.config/{mpd,ncmpcpp} 
cd ~/.config/mpd
touch database mpd.conf mpd.fifo mpd.log mpdstate

cd

cd ~/Documents/workspace/Customizations
git clone https://github.com/JucaRei/rofi
git clone https://github.com/JucaRei/polybar-themes
git clone https://github.com/JucaRei/dotfiles
git clone https://github.com/JucaRei/fonts

cd ~/Documents/workspace/Configs
git clone https://github.com/JucaRei/ArchInstall

# Font Preview
mkdir ~/scripts
cd ~/scripts
https://github.com/JucaRei/fontpreview
cd fontpreview
sudo make install 
echo 'export PATH="$HOME/scripts/fontpreview:$PATH"' >> ~/.bashrc
source ~/.bashrc

cd

cd ~/Documents/workspace/Customizations/rofi
chmod +x setup.sh
./setup.sh

# Install Fonts
cd ~/Documents/workspace/Customizations/fonts/fonts && cp *.ttf *.otf ~/.local/share/fonts
fc-cache -fv

# mpd e ncmpcpp
cd

cp -f ~/Documents/workspace/Configs/ArchInstall/BSPWM/mpd/mpd.conf ~/.config/mpd
cp -f ~/Documents/workspace/Configs/ArchInstall/BSPWM/ncmpcpp/config ~/.config/ncmpcpp

# Xresources | Fehgb | Xprofile etc
cd
cp -f ~/Documents/workspace/Customizations/dotfiles/wallpaper.jpg ~/Pictures
cp -rf ~/Documents/workspace/Customizations/dotfiles/polybar ~/.config
cp -f ~/Documents/workspace/Configs/ArchInstall/BSPWM/Xresources ~/.Xresources
cp -f ~/Documents/workspace/Configs/ArchInstall/BSPWM/fehbg ~/.fehgb
cp -f ~/Documents/workspace/Configs/ArchInstall/BSPWM/xprofile ~/.xprofile
cp -f ~/Documents/workspace/Configs/ArchInstall/BSPWM/vtwhell ~/.urxvt/ext
cp -f ~/Documents/workspace/Configs/ArchInstall/BSPWM/dualbsp.sh ~/scripts
cp -f ~/Documents/workspace/Configs/ArchInstall/BSPWM/DualMonPolybar.sh ~/scripts
sudo cp -f ~/Documents/workspace/Configs/ArchInstall/BSPWM/display-lightdm.sh /etc/lightdm
cp -f /etc/dunst/dunstrc ~/.config/dunst/
install -Dm755 /usr/share/doc/bspwm/examples/bspwmrc ~/.config/bspwm/bspwmrc
install -Dm644 /usr/share/doc/bspwm/examples/sxhkdrc ~/.config/sxhkd/sxhkdrc

sudo sed -i 's/#greeter-session=example-gtk-gnome/greeter-session=lightdm-gtk-greeter/g' /etc/lightdm/lightdm.conf

cat << EOF >> ~/.config/bspwm/bspwmrc

~/.fehbg &
xrdb ~/.Xresources &
~/.config/polybar/launch.sh &
setxkbmap br &
picom -f &
xsetroot -cursor_name left_ptr &
~/scripts/dualbsp.sh
EOF