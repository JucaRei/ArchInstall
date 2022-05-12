#!/bin/bash

killall conky
sleep 2s
		
conky -c $HOME/.config/conky/Aludra/Aludra.conf &> /dev/null &
