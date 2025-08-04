#!/usr/bin/env bash

#####################################
#### intel Hardware Acceleration ####
#####################################

chroot /mnt apt update
chroot /mnt apt install intel-media-va-driver-non-free libva2 vainfo intel-gpu-tools firmware-misc-nonfree mesa-va-drivers

touch /mnt/etc/modprobe.d/i915.conf
cat <<EOF >/mnt/etc/modprobe.d/i915.conf
## Boot Faster with intel ##
# options i915 enable_guc=2 enable_fbc=1 enable_dc=4 enable_hangcheck=0 error_capture=0 enable_dp_mst=0 fastboot=1 #parameters may differ
options i915 enable_guc=2 enable_psr=2 enable_fbc=1 enable_dc=4 enable_hangcheck=0 error_capture=0 enable_dp_mst=0 fastboot=1 guc_log_level=3
EOF

touch /mnt/etc/dracut.conf.d/intel.conf
cat <<EOF >/mnt/etc/dracut.conf.d/intel.conf
force_drivers+=" i915 "
EOF

# Fix tearing with intel
touch /etc/X11/xorg.conf.d/20-modesetting.conf
cat <<EOF >/etc/X11/xorg.conf.d/20-modesetting.conf
Section "Device"
#   Identifier "Intel Graphics 630"
#   Driver "intel"
#   Option "AccelMethod" "sna"
#   Option "TearFree" "True"
#   Option "Tiling" "True"
#   Option "SwapbuffersWait" "True"
#   Option "DRI" "3"

    Identifier  "Intel Graphics"
    Driver      "modesetting"
    Option      "TearFree"       "True"
    Option      "DRI"            "3"
    # Option    "AccelMethod"    "glamor"
    # Option    "TripleBuffer"   "True"
EndSection
EOF

# cat <<EOF >/mnt/etc/initramfs-tools/modules
# # i915.modeset=1
# # intel_agp
# EOF