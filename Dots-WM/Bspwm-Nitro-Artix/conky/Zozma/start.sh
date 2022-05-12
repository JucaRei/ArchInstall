#!/bin/bash

killall conky
sleep 2s
		
conky -c $HOME/.config/conky/Zozma/Zozma.conf &> /dev/null &
conky -c $HOME/.config/conky/Zozma/Zozma2.conf &> /dev/null &
