#!/bin/bash
WLANCONNECT=false
ETHCONNECT=false
WLANLOOP="wlanloop"

update(){
    sleep 1
    kill $(pgrep -x "$WLANLOOP") > /dev/null 2>&1
    if $ETHCONNECT;then
        if $WLANCONNECT;then
            #if [ $(ifconfig enp4s0 | awk '$1=="inet" {print $2}') == "" ];then
            #    while [ $(ifconfig enp4s0 | awk '$1=="inet" {print $2}') == "" ];do
            #        sleep 2 #
            #    done
            #fi
            polybar-msg hook wlan-eth 4
        else
            #if [ $(ifconfig enp4s0 | awk '$1=="inet" {print $2}') == "" ];then
            #    while [ $(ifconfig enp4s0 | awk '$1=="inet" {print $2}') == "" ];do
            #        sleep 2 #
            #    done
            #fi
            polybar-msg hook wlan-eth 3
            sleep 0.5 
            polybar-msg hook corona 1
            polybar-msg hook repoup 1
        fi
    elif $WLANCONNECT;then
        ~/scripts/polybar/wlanloop &
        sleep 1 
        polybar-msg hook corona 1
        polybar-msg hook repoup 1
    else
        polybar-msg hook wlan-eth 1
    fi



}

[ "$(nmcli d | awk '$1=="wlan0" {print $3}')" == "connected" ] && WLANCONNECT=true
[ "$(nmcli d | awk '$1=="eth0" {print $3}')" == "connected" ] && ETHCONNECT=true
update
#update a second time after delay in case polybar was not loaded yet
#eval "sleep 3 && update &"
#sleep 3 && update

nmcli d monitor |
while read LINE; do
    [ "$LINE" == "eth0: connected" ] && ETHCONNECT=true && update
    [ "$LINE" == "wlan0: connected" ] && WLANCONNECT=true && update
    [ "$LINE" == "eth0: unavailable" ] && ETHCONNECT=false && update
    [ "$LINE" == "wlan0: unavailable" ] && WLANCONNECT=false && update
done

