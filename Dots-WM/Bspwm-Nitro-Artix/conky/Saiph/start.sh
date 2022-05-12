#!/bin/bash

killall conky
sleep 2s
		
conky -c $HOME/.config/conky/Saiph/Saiph.conf &> /dev/null &
conky -c $HOME/.config/conky/Saiph/Saiph2.conf &> /dev/null &
