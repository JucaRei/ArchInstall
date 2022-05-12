#!/bin/bash

killall conky
sleep 2s
		
conky -c $HOME/.config/conky/Zavijava/Zavijava.conf &> /dev/null &
