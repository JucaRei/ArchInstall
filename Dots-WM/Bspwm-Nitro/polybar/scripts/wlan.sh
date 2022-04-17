#!/bin/sh
SIGNAL=$(nmcli -f ACTIVE,SIGNAL dev wifi list | awk '$1=="yes" {print $2}')
if [ $SIGNAL -gt 70 ] 
then
    STRENGTH="%{T9}󰤨%{T-}"
elif [ $SIGNAL -gt 60 ]
then
    STRENGTH="%{T9}󰤥%{T-}"
elif [ $SIGNAL -gt 40 ]
then
    STRENGTH="%{T9}󰤢%{T-}"
elif [ $SIGNAL -gt 20 ]
then
    STRENGTH="%{T9}󰤟%{T-}"
elif [ $SIGNAL -gt 0 ]
then
    STRENGTH="%{T9}󰤫%{T-}"
fi
ESSID=$(iwgetid -r)

echo "%{F#555}$STRENGTH%{F-} $ESSID"

