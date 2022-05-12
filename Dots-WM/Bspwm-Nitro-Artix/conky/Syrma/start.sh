#!/bin/bash

killall conky
sleep 2s
		
conky -c $HOME/.config/conky/Syrma/Syrma.conf &> /dev/null &
conky -c $HOME/.config/conky/Syrma/Syrma1.conf &> /dev/null &
conky -c $HOME/.config/conky/Syrma/Syrma2.conf &> /dev/null &
