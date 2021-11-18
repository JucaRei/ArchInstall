#!/bin/bash

sudo ln -s /etc/runit/sv/NetworkManager /run/runit/service
sudo ln -s /etc/runit/sv/sshd /run/runit/service
sudo ln -s /etc/runit/sv/acpid /run/runit/service
sudo ln -s /etc/runit/sv/ntpd /run/runit/service
sudo ln -s /etc/runit/sv/bluetoothd /run/runit/service
sudo ln -s /etc/runit/sv/wpa_supplicant /run/runit/service
sudo ln -s /etc/runit/sv/avahi-daemon /run/runit/service
sudo ln -s /etc/runit/sv/alsa /run/runit/service
sudo ln -s /etc/runit/sv/cupsd /run/runit/service
sudo ln -s /etc/runit/sv/tlp /run/runit/service
