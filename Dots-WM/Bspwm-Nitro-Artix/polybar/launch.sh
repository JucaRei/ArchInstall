#!/usr/bin/env bash



# Terminate already running bar instances
killall -q polybar
# If all your bars have ipc enabled, you can also use 
# polybar-msg cmd quit


# Launch bar1 and bar2
#echo "---" | tee -a /tmp/polybar1-$USER.log /tmp/polybar2-$USER.log
#polybar black >>/tmp/polybar1.log 2>&1 & disown
#polybar example -r >>/tmp/polybar1-$USER.log 2>&1 & disown

if type "xrandr"; then
  for m in $(xrandr --query | grep " connected" | cut -d" " -f1); do
    sleep 1
    MONITOR=$m polybar --reload main &
  done
else
  polybar --reload main &
fi

echo "Bars launched..."
