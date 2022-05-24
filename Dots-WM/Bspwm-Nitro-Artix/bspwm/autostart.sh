#!/bin/bash

function run {
  if ! pgrep $1 ;
  then
    $@&
  fi
}

#Find out your monitor name with xrandr or arandr (save and you get this line)
#xrandr --output VGA-1 --primary --mode 1360x768 --pos 0x0 --rotate normal
#xrandr --output DP2 --primary --mode 1920x1080 --rate 60.00 --output LVDS1 --off &
#xrandr --output LVDS1 --mode 1366x768 --output DP3 --mode 1920x1080 --right-of LVDS1
#xrandr --output HDMI2 --mode 1920x1080 --pos 1920x0 --rotate normal --output HDMI1 --primary --mode 1920x1080 --pos 0x0 --rotate normal --output VIRTUAL1 --off
#autorandr horizontal

pgrep -x sxhkd > /dev/null || sxhkd &

#bspc monitor -d I II III IV V VI VII VIII IX X
#~/.bin/dualbsp-VM.sh
setxkbmap br &
dbus-launch pcmanfm --daemon &
xsetroot -cursor_name left_ptr &
#$HOME/.local/bin/fehauto.sh &
while true; do feh --randomize --bg-fill ~/Pictures/Wallpapers; sleep 600; done &
$HOME/.config/polybar/launch.sh &
picom --experimental-backends --config ~/.config/picom/picom.conf &
/usr/bin/dunst &
#pulseaudio &
#~/.bin/pipewire.sh &
# pipewire &
# pipewire-pulse &
# pipewire-media-session &
#bluetoothctl power on &
#wireplumber &
pulseaudio --start -D &
/usr/lib/mate-polkit/polkit-mate-authentication-agent-1 &
udevil &
devmon &
xfce4-power-manager &
wmname LG3D &
#$HOME/.bin/dualbsp-VM.sh
#$HOME/.config/polybar/scripts/polybar_autohide/autohide &

#mkdir -p /tmp/${USER}-runtime && chmod -R 0700 /tmp/${USER}-runtime &
#export XDG_RUNTIME_DIR=/tmp/${USER}-runtime &

# Add font path
#xset +fp /home/junior/.local/share/fonts/ &
#xset fp rehash &

#XDG DATA DIR
export XDG_DATA_DIRS="$HOME/.local/share/applications" &

# XDG USER DIR
#mkdir -p /tmp/${USER}-runtime && chmod -R 0700 /tmp/${USER}-runtime &
#export XDG_RUNTIME_DIR=/tmp/${USER}-runtime &

if [ -z "${XDG_RUNTIME_DIR}" ]; then
	export XDG_RUNTIME_DIR="/tmp/runtime-dir-${UID}"
	if [ ! -d "${XDG_RUNTIME_DIR}" ]; then
		mkdir "${XDG_RUNTIME_DIR}" 
		chmod 0700 "${XDG_RUNTIME_DIR}"
	fi
fi &


# Flatpak
export XDG_RUNTIME_DIR="/var/lib/flatpak/exports/share" &
export XDG_RUNTIME_DIR="/home/juca/.local/share/flatpak/exports/share" &

#XDGR
mkdir -pv ~/.cache/xdgr
chmod 0700 ~/.cache/xdgr
export XDG_RUNTIME_DIR=$PATH:~/.cache/xdgr



# exec folders
exec /user/lib/xdg-desktop-portal-gtk &

~/.bin/dualbsp-VM.sh &

rm -rf ~/.cache weather.json
rm -rf ~/.cache weather-icon.png


~/.conky/conky-startup.sh &