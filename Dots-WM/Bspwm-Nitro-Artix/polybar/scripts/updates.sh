#!/bin/bash

icon=/usr/share/icons/Papirus-Dark/32x32/apps/org.kde.kapman.svg
updates_arch=$(checkupdates 2> /dev/null | wc -l)
updates_aur=$(pikaur -Qua 2> /dev/null | wc -l)
updates=$(("$updates_arch" + "$updates_aur"))

if [ "$updates" -ge 30 ]; then
    echo " $updates"
    dunstify -u critical -i $icon "Arch updates" "$updates new packages"
elif [ "$updates" -ge 10 ]; then
    echo " $updates"   
    dunstify -u normal -i $icon "Arch updates" "$updates new packages"
elif [ "$updates" -ge 1 ]; then
    echo " $updates"
    dunstify -u low -i $icon "Arch updates" "$updates new packages"
elif [ "$updates" -eq 0 ]; then
    echo " -"
fi
