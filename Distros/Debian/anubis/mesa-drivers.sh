#!/usr/bin/env bash

####################
### Mesa Drivers ###
####################
apt purge xserver-xorg-video-intel intel-opencl-icd i965-va-driver-shaders -y

#apt install -y glx-alternative-mesa libegl-mesa0 libgbm1 libgl1-mesa-dri libglapi-mesa libglu1-mesa libglx-mesa0 mesa-opencl-icd mesa-utils mesa-utils-extra mesa-va-drivers mesa-vulkan-drivers update-glx
apt install -y glx-alternative-mesa libegl-mesa0 libgbm1 libgl1-mesa-dri libglapi-mesa libglu1-mesa libglx-mesa0 mesa-opencl-icd mesa-utils mesa-utils-extra mesa-va-drivers mesa-vulkan-drivers update-glx

rm -rf /etc/X11/xorg.conf.d/20-intel.conf

cat <<EOF >/etc/X11/xorg.conf.d/20-modesetting.conf
Section "Device"
    Identifier  "modesetting"
    Driver      "modesetting"
    Option      "TearFree"      "True"
EndSection
EOF
