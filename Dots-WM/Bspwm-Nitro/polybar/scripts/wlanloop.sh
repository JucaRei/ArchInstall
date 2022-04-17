#!/bin/sh
#Az : Loop to refresh the wifi strenght
while true
do
    polybar-msg hook wlan-eth 2
    sleep 5
done
