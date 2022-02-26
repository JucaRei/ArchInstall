#!/bin/sh

# checa se existem dois monitores definidos
#MON=$(xrandr --listmonitors | grep Monitors | cut -b 11-)

# caso tenha, executa o setup para dois
#if [[ $MON == 2 ]]; then
#  xrandr --output HDMI-1-0 --primary --left-of eDP1 --auto &
#  bspc monitor HDMI-1-0 -d 1 2 3 4
#  bspc monitor eDP1 -d 5 6 7 8
#else
#  bspc monitor eDP1 -d 1 2 3 4 5 6 7 8
#fi

#### INSTALE mons 

if [[ mons == 2 ]]; then
  mons -e left &
  bspc monitor HDMI-1-0 -d 1 2 3 4
  bspc monitor eDP1 -d 5 6 7 8
else
  bspc monitor eDP1 -d 1 2 3 4 5 6 7 8
fi
