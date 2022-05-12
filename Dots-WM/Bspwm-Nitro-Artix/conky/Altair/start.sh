#!/bin/bash

killall conky
sleep 2s

conky -c $HOME/.config/conky/Altair/Altair.conf &> /dev/null &
