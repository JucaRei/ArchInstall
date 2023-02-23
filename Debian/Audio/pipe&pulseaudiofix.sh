#!/bin/sh

# Only pipewire
systemctl --user mask pulseaudio.{socket,service}
systemctl --user --now enable pipewire{,-pulse}.{socket,service}

# Only pulseaudio
systemctl --user mask pipewire{,-pulse}.{socket,service}
systemctl --user --now enable pulseaudio.{socket,service}