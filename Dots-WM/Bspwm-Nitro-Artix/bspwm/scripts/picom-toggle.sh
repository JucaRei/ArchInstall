#!/bin/bash
if pgrep -x "picom" > /dev/null
then
	killall picom
else
	# picom -b --config ~/.config/bspwm/picom.conf
    picom -b --experimental-backends --config ~/.config/picom/picom.conf
fi
