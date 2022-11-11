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

pacman -S podman slirp4netns buildah cni-plugins podman-compose podman-dnsname podman-docker fuse-overlayfs --noconfirm

cat <<EOF >>/etc/containers/registries.conf

[registries.search]
registries = ['docker.io', 'registry.fedoraproject.org', 'quay.io', 'registry.access.redhat.com', 'registry.centos.org']
EOF

podman system migrate
loginctl enable-linger $USER
loginctl user-status $USER
# rootless
mkdir -pv /home/$USER/.config/systemd/

## Make persistence
# $ podman generate systemd --name nginx --files
# $ systemctl --user daemon-reload
# $ systemctl --user enable --now container-nginx.service
# $ systemctl --user status container-nginx.service

printf "\e[1;32mDone! Podman was installed successfully.\e[0m"
