#!/bin/sh

device="~/.config/polybar/scripts/teste.sh"

if [ $(bluetoothctl show | grep "Powered: yes" | wc -c) -eq 0 ]; then
  echo "%{F#66ffffff}"
else
  if [ $(echo info | bluetoothctl | grep 'Device' | wc -c) -eq 0 ]; then
    echo ""
    #echo "  "
  #else
	#if [ $(bluetoothctl show | grep "Connected: yes" | wc -c) -eq 0 ]; then
	# $(device)
	#fi
  fi
  echo "%{F#2193ff}"  
fi
