#!/usr/bin/env bash

#####################
### Intel Drivers ###
#####################
apt purge -y glx-alternative-mesa libegl-mesa0 libgbm1 libgl1-mesa-dri libglapi-mesa libglu1-mesa libglx-mesa0 mesa-opencl-icd mesa-utils mesa-utils-extra mesa-va-drivers mesa-vulkan-drivers update-glx

apt install xserver-xorg-video-intel intel-opencl-icd i965-va-driver-shaders

rm -rf /etc/X11/xorg.conf.d/20-modesetting.conf

cat <<EOF >/etc/X11/xorg.conf.d/20-intel.conf
Section "Device"
    Identifier  "Intel Graphics"
    Driver      "intel"
    Option      "TearFree"         "true"
EndSection
EOF
