#!/usr/bin/env bash

##################################
#### Nvidia Drivers with Cuda ####
##################################

apt install nvidia-kernel-dkms nvidia-driver firmware-misc-nonfree  # Proprietary
# apt install nvidia-open-kernel-dkms nvidia-driver firmware-misc-nonfree  # Open drivers

# Enable Video Acceleration
apt install vdpauinfo libvdpau1 nvidia-vdpau-driver libnvidia-encode1 libnvcuvid1 nvidia-vaapi-driver mesa-va-drivers 

# Vdpau
apt install nvidia-vdpau-driver libvdpau-va-gl1

cat <<EOF >/etc/dracut.conf.d/10-nvidia.conf 
# Include NVIDIA modules at boot
add_drivers+=" nvidia nvidia_modeset nvidia_uvm nvidia_drm "
# (Optional) ensure no host-only stripping
hostonly="no"
# install_items+=" /etc/modprobe.d/nvidia-blacklists-nouveau.conf /etc/modprobe.d/nvidia.conf /etc/modprobe.d/nvidia-options.conf "
EOF

echo "options nvidia-drm modeset=1" >> /mnt/etc/modprobe.d/nvidia-options.conf
echo "options nvidia NVreg_PreserveVideoMemoryAllocations=1" >> /mnt/etc/modprobe.d/nvidia-options.conf

cat <<EOF >/00-disable-nvidia-current-drm.conf
install nvidia-current-drm /bin/true
EOF

cat <<EOF >/etc/modprobe.d/nvidia-blacklists-nouveau.conf
# You need to run "update-initramfs -u" after editing this file.

# see #580894
blacklist nouveau
EOF

cat <<EOF >//etc/modprobe.d/nvidia.conf
install nvidia modprobe -i nvidia-current $CMDLINE_OPTS

install nvidia-modeset modprobe nvidia ; modprobe -i nvidia-current-modeset $CMDLINE_OPTS

#install nvidia-drm modprobe nvidia-modeset ; modprobe -i nvidia-current-drm $CMDLINE_OPTS

install nvidia-uvm modprobe nvidia ; modprobe -i nvidia-current-uvm $CMDLINE_OPTS

install nvidia-peermem modprobe nvidia ; modprobe -i nvidia-current-peermem $CMDLINE_OPTS

# unloading needs the internal names (i.e. upstream's names, not our renamed files)

remove nvidia modprobe -r -i nvidia-drm nvidia-modeset nvidia-peermem nvidia-uvm nvidia

remove nvidia-modeset modprobe -r -i nvidia-drm nvidia-modeset


alias char-major-195* nvidia

# These aliases are defined in *all* nvidia modules.
# Duplicating them here sets higher precedence and ensures the selected
# module gets loaded instead of a random first match if more than one
# version is installed. See #798207.
alias   pci:v000010DEd00000E00sv*sd*bc04sc80i00*        nvidia
alias   pci:v000010DEd00000AA3sv*sd*bc0Bsc40i00*        nvidia
alias   pci:v000010DEd*sv*sd*bc03sc02i00*               nvidia
alias   pci:v000010DEd*sv*sd*bc03sc00i00*               nvidia
EOF

cat <<EOF >/etc/modprobe.d/nvidia-options.conf
#options nvidia-current NVreg_DeviceFileUID=0 NVreg_DeviceFileGID=44 NVreg_DeviceFileMode=0660

# To grant performance counter access to unprivileged users, uncomment the following line:
#options nvidia-current NVreg_RestrictProfilingToAdminUsers=0

# Uncomment to enable this power management feature:
options nvidia-current NVreg_PreserveVideoMemoryAllocations=1

# Uncomment to enable this power management feature:
options nvidia-current NVreg_EnableS0ixPowerManagement=1
EOF

sed -i 's/quiet/& nvidia-drm.modeset=1/' /etc/default/grub

dracuf --force --kver $(uname -r)
update-grub

touch /etc/X11/xorg.conf.d/30-nvidia.conf
cat <<EOF >/mnt/etc/X11/xorg.conf.d/30-nvidia.conf
Section "Device"
    Identifier "Nvidia GTX 1050"
    Driver  "nvidia"
    BusID   "PCI:1:0:0"
    Option  "DPI" "96 x 96"
    Option  "AllowEmptyInitialConfiguration"    "Yes"
    Option  "Coolbits"                          "28"    # Enables fan control + overclocking
    Option  "TripleBuffer"                      "true"  # Improves frame pacing
    Option  "SwapbuffersWait"                   "true"  # Syncs buffer swaps to VBlank
    #Option "AccelMethod"                       "none"
    #Option "UseDisplayDevice"                  "none"
EndSection
EOF


# touch /mnt/etc/modprobe.d/nouveau-kms.conf
# cat <<EOF | tee /mnt/etc/modprobe.d/nouveau-kms.conf
# ## Disable nouveau on earlyboot ##
# blacklist nouveau
# blacklist lbm-nouveau
# options nouveau modeset=0
# EOF

# mkdir -pv /mnt/etc/modprobe.d
# touch /mnt/etc/modprobe.d/bbswitch.conf
# cat <<EOF >/mnt/etc/modprobe.d/bbswitch.conf
# ## Early module for bbswitch dual graphics ##
# # options bbswitch load_state=0 unload_state=1
# EOF

