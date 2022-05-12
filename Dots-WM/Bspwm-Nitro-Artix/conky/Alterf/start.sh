#!/bin/bash

killall conky
sleep 2s
		
conky -c $HOME/.config/conky/Alterf/Aterf.conf &> /dev/null &
