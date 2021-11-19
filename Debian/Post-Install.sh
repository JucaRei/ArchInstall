#!/bin/bash

sudo apt install firewalld build-essential polybar bspwm sxhkd dmenu nitrogen xclip youtube-dl unclutter rofi dunst feh xfce4-terminal picom gawk evince scrot lightdm htop mpd ncmpcpp geany lxappearance neovim spacefm-gtk3

mkdir -p $HOME/.config/{rofi,dunst,bspwm,sxhkd}

sudo firewall-cmd --add-port=1025-65535/tcp --permanent
sudo firewall-cmd --add-port=1025-65535/udp --permanent
sudo firewall-cmd --reload
