#!/bin/sh

# Teste VM

if xrandr -q | grep 'HDMI-1-0 connected'; then
  xrandr --output HDMI-1-0 --mode 1920x1080 --left-of Virtual-1
  bspc monitor Virtual-1 -d I II III IV
  bspc monitor HDMI-1-0 -d V XI XII XIII
else
  bspc monitor Virtual-1 -d I II III IV V VI VII VIII
fi

# xrandr --output Virtual-1 --mode 1920x1080
