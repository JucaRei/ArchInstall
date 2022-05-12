#!/bin/bash

killall conky
sleep 2s
		
conky -c $HOME/.config/conky/Adhafera/Adhafera.conf &> /dev/null &
