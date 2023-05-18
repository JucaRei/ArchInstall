#!/bin/bash

#### Podman ####
set -e
USER='junior'

touch /etc/{subgid,subuid}

cat <<EOF >/etc/subuid
$USER:100000:65536
test:165536:65536
EOF

cat <<EOF >/etc/subgid
$USER:100000:65536
test:165536:65536
EOF

chmod 644 /etc/subgid /etc/subuid
usermod --add-subuids 100000-165535 --add-subgids 100000-165535 $USER

sysctl -w "net.ipv4.ping_group_range=0 2000000"

# Install podman needed (arch)
pacman -S podman slirp4netns buildah cni-plugins podman-compose podman-dnsname podman-docker fuse-overlayfs aardvark-dns --needed --noconfirm
# Voidlinux
vpm i podman slirp4netns buildah cni-plugins podman-compose fuse-overlayfs containers.image --yes

# Nvidia Podman or Docker
pikaur -S libnvidia-container --noconfirm
# nvidia-container-toolkit

# Make podman able to run another architectures
pacman -Sy qemu-user-static qemu-user-static-binfmt --noconfirm
vpm i qemu-user-static binfmt-support --yes


cat <<EOF >>/etc/containers/registries.conf

[registries.search]
registries = ['docker.io', 'registry.fedoraproject.org', 'quay.io', 'registry.access.redhat.com', 'registry.centos.org']
EOF

# Nvidia Hook 
doas touch /usr/share/containers/oci/hooks.d/oci-nvidia-hook.json
doas cat <<EOF >> /usr/share/containers/oci/hooks.d/oci-nvidia-hook.json
{
  "hook": "/usr/bin/nvidia-container-runtime-hook",
  "arguments": ["prestart"],
  "annotations": ["sandbox"],
  "stage": [ "prestart" ]
}
EOF

# Configure Nvidia-container-runtime

doas mkdir -pv /etc/nvidia-container-runtime/
doas touch /etc/nvidia-container-runtime/config.toml
doas cat << EOF >> /etc/nvidia-container-runtime/config.toml
disable-require = false

[nvidia-container-cli]
#root = "/run/nvidia/driver"
#path = "usr/bin/nvidia-container-cli"
environment = []
#debug = "/var/log/nvidia-container-runtime-hook.log"
#ldcache = "/etc/ld.so.cache"
load-kmods = true
#user = "root:video"
ldconfig = "@/sbin/ldconfig.real"

# Rootless Podman
debug = "~/.local/nvidia-container-runtime.log"
no-cgroups = true
EOF


podman system migrate
loginctl enable-linger $USER
loginctl user-status $USER
# rootless
mkdir -pv /home/$USER/.config/{systemd,containers}

sudo mount -o remount,shared / /
sudo mount --make-rshared /


## Make persistence
# $ podman generate systemd --name nginx --files
# $ systemctl --user daemon-reload
# $ systemctl --user enable --now container-nginx.service
# $ systemctl --user status container-nginx.service

printf "\e[1;32mDone! Podman was installed successfully.\e[0m"
