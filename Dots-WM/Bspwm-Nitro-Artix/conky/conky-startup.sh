#!/bin/sh

if [ "$DESKTOP_SESSION" = "bspwm" ]; then 
   sleep 10s
   killall conky
   cd "$HOME/.config/conky/Aludra"
   conky -c "$HOME/.config/conky/Aludra/Aludra.conf" &
   exit 0
fi
