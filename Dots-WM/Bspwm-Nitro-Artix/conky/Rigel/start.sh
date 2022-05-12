#!/bin/bash

killall conky
sleep 2s
		
conky -c $HOME/.config/conky/Rigel/Rigel.conf &> /dev/null &
