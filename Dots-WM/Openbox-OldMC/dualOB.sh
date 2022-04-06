#!/bin/sh

if xrandr -q | grep 'HDMI-1-0 connected'; then
   xrandr --output HDMI-1-0 --mode 1920x1080 --left-of LVDS-1 --mode 1920x1200
else
  xrandr --output LVDS-1 --mode 1920x1200
fi

# xrandr --output LVDS-1 --mode 1920x1080