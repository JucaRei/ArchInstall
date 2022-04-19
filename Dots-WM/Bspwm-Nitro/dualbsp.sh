#!/bin/sh

if xrandr -q | grep 'HDMI-1-0 connected'; then
  #xrandr --output HDMI-1-0 --mode 1920x1080 --left-of eDP-1
  xrandr --output eDP-1 --mode 1920x1080 --pos 1920x0 --rotate normal --output HDMI-1-0 --primary --mode 1920x1080 --pos 0x0 --rotate normal --left-of eDP-1
  bspc monitor HDMI-1-0 -d I II III IV 
  bspc monitor eDP-1 -d V VI VII VIII 
else
  bspc monitor eDP-1 -d I II III IV V VI VII VIII
fi

# xrandr --output eDP1 --mode 1920x1080