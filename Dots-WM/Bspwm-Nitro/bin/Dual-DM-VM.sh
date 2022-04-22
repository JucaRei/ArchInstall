#!/bin/sh
#VM TESTE
# Virtual-1 - Lap Screen  |  HDMI-1-0 External monitor
# Lightdm or other script for dual monitor

xrandr --setprovideroutputsource 1 0 &

XCOM0=$(xrandr -q | grep 'HDMI-1-0 connected')
XCOM1=$(xrandr --output Virtual-1 --primary --auto --output HDMI-1-0 --auto --left-of Virtual-1)
XCOM2=$(xrandr --output Virtual-1 --primary --auto)
# if the external monitor is connected, then we tell XRANDR to set up an extended desktop
if [ -n "$XCOM0" ] || [ ! "$XCOM0" = "" ]; then
    echo $XCOM1
# if the external monitor is disconnected, then we tell XRANDR to output only to the laptop screen
else
    echo $XCOM2
fi

exit 0
