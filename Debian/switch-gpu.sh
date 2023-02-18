#!/bin/bash

# Switch GPU on Debian system with reboot.

# Because there's no nvidia-prime package for Debian distro,
# I did some work to achieve the same functionality as nvidia-prime provide.

# Follow the instructions here:

# 1. Follow instructions here to install nvidia proprietary driver:

# https://wiki.debian.org/NvidiaGraphicsDrivers

# sudo apt update
# sudo apt install linux-headers-$(uname -r|sed 's/[^-]*-[^-]*-//') nvidia-driver

# Do not reboot now!

# 2. Follow instructions here to configure Nvidia Optimus:

# https://wiki.debian.org/NvidiaGraphicsDrivers/Optimus


# sudo touch /etc/X11/xorg.conf

# Add the following:

# Section "Module"
#     Load "modesetting"
# EndSection

# Section "Device"
#     Identifier "nvidia"
#     Driver "nvidia"
#     BusID "PCI:X:Y:Z"
#     Option "AllowEmptyInitialConfiguration"
# EndSection


# Where "BusID" X:Y:Z are the shortened/truncated numbers from the ID gathered using 'lspic' command. 
# For example, if the output of lspci displayed a PCI ID of 09:00.0, the BusID entry would read: BusID "9:0:0"


# sudo touch /usr/share/gdm/greeter/autostart/optimus.desktop
# sudo touch /etc/xdg/autostart/optimus.desktop

# Both add the following:

# [Desktop Entry]
# Type=Application
# Name=Optimus
# Exec=sh -c "xrandr --setprovideroutputsource modesetting NVIDIA-0; xrandr --auto"
# NoDisplay=true
# X-GNOME-Autostart-Phase=DisplayServer


# sudo reboot


# 3. Follow instructions here to configure bbswitch:

# https://github.com/Bumblebee-Project/bbswitch


# sudo apt install bbswitch-dkms

# sudo vi /etc/modules
# Add the following:
# bbswitch load_state=0

# sudo touch /etc/modprobe.d/bbswitch.conf
# Add the following:
# options bbswitch load_state=0

# sudo touch /etc/modules-load.d/bbswitch.conf
# Add the following:
# bbswitch

# sudo update-initramfs -u

# 4. Follow instructions here to configure crontab:


# sudo crontab -e

# Add this script to crontab:

# @reboot /home/asuka/local/pathtool/switch-gpu.sh


# 5. All done, now you can switch GPU with this script like:

# switch-gpu.sh nvidia
# switch-gpu.sh intel

# You can add this script to PATH for convinient.



GPU="$1"


switch_to_nvidia () {
	sudo sed -i 's|options bbswitch load_state.*|options bbswitch load_state=1|g' /etc/modprobe.d/bbswitch.conf
	sudo crontab -l | sed 's|^@reboot /home|#@reboot /home|' | sudo crontab -
}


switch_to_intel () {
	sudo sed -i 's|options bbswitch load_state.*|options bbswitch load_state=0|g' /etc/modprobe.d/bbswitch.conf
	sudo crontab -l | sed 's|^#@reboot /home|@reboot /home|' | sudo crontab -
}


ask_reboot () {
	while true; do
    	read -p "Do you wish to reboot system now? " yn
    	case $yn in
        	[Yy]* ) sudo reboot; break;;
        	[Nn]* ) echo "The GPU will switch to $GPU on the next reboot."; exit;;
        	* ) echo "Please answer yes or no.";;
    	esac
	done
}

#Try turn off nvidia if no arg specified.
if [ -z "$GPU" ]
then
	tee /proc/acpi/bbswitch <<<OFF
	exit 0
fi


if [ $GPU = "nvidia" ]
then
	echo "switch GPU to Nvidia"
	switch_to_nvidia
elif [ $GPU = "intel" ] 
then
	echo "switch GPU to Intel"
	switch_to_intel
else
	echo "Wrong GPU param."
	exit 1
fi

ask_reboot
