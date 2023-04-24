#!/bin/sh

mkdir -pv /home/dietpi/{builds,documents,downloads,music,read,scripts,videos,workspace}
mkdir -pv ~/.local/share/containers/storage/

sudo -i

apt update && apt upgrade -y
apt install btrfs-progs git iptables libassuan-dev libbtrfs-dev libc6-dev libdevmapper-dev libglib2.0-dev libgpgme-dev libgpg-error-dev libprotobuf-dev libprotobuf-c-dev  libseccomp-dev libselinux1-dev libsystemd-dev pkg-config runc uidmap make curl vim gcc --no-install-recommends -y

libassuan-dev libblkid-dev libbtrfs-dev libc-dev-bin libc6-dev libcrypt-dev libdevmapper-dev libffi-dev libglib2.0-bin libglib2.0-data libglib2.0-dev
  libglib2.0-dev-bin libgpg-error-dev libgpgme-dev libgpm2 libmount-dev libnsl-dev libpcre16-3 libpcre2-16-0 libpcre2-32-0 libpcre2-dev libpcre2-posix2 libpcre3-dev
  libpcre32-3 libpcrecpp0v5 libprotobuf-c-dev libprotobuf-dev libprotobuf-lite23 libprotobuf23 libseccomp-dev libselinux1-dev libsepol1-dev libsystemd-dev
  libtirpc-dev libudev-dev linux-libc-dev pkg-config runc uuid-dev vim vim-common vim-runtime xxd zlib1g-dev

# common

cd /home/dietpi/builds
git clone --depth=1 https://github.com/containers/conmon
cd conmon
export GOCACHE="$(mktemp -d)"
make
make podman
cd /home/dietpi/builds

# runc

git clone --depth=1 https://github.com/opencontainers/runc.git $GOPATH/src/github.com/opencontainers/runc
cd $GOPATH/src/github.com/opencontainers/runc
make BUILDTAGS="selinux seccomp"
cp runc /usr/bin/runc
cd /home/dietpi/builds
runc --version 

# CNI networking plugins
mkdir -pv /etc/containers
curl -L -o /etc/containers/registries.conf https://src.fedoraproject.org/rpms/containers-common/raw/main/f/registries.conf
curl -L -o /etc/containers/policy.json https://src.fedoraproject.org/rpms/containers-common/raw/main/f/default-policy.json
apt install -y libapparmor-dev libsystemd-dev

# install Podman 4 
cd /home/dietpi/builds
apt install curl wget -y
TAG=$(curl -s https://api.github.com/repos/containers/podman/releases/latest|grep tag_name|cut -d '"' -f 4)
rm -rf podman*
wget -c https://github.com/containers/podman/archive/refs/tags/${TAG}.tar.gz
tar xvf ${TAG}.tar.gz
cd podman*/
make BUILDTAGS="selinux seccomp"
make install PREFIX=/usr
podman version

# slirp4netns 
cd /home/dietpi/builds
TAG=$( curl -s https://api.github.com/repos/rootless-containers/slirp4netns/releases/latest|grep tag_name|cut -d '"' -f 4)
curl -o slirp4netns --fail -L https://github.com/rootless-containers/slirp4netns/releases/download/$TAG/slirp4netns-$(uname -m)
chmod +x slirp4netns
sudo cp slirp4netns /usr/local/bin
slirp4netns --version

apt install buildah containers-storage fuse-overlayfs slirp4netns catatonit tini nftables lrzip golang-github-containernetworking-plugin-dnsname dbus-x11 firewalld ipset python-dbus-doc python3-dbus-dbg bridge-utils systemd-container open-infrastructure-container-tools --no-install-recommends -y


printf "\e[1;32mDone! Check if everything was installed correctly.\e[0m"

# pip3 install https://github.com/containers/podman-compose/archive/devel.tar.gz
# driver = "fuse-overlayfs"

cd /home/dietpi/downloads
wget -c https://github.com/containernetworking/plugins/releases/download/v1.2.0/cni-plugins-linux-arm64-v1.2.0.tgz
tar xvf cni-plugins-linux-arm64-v1.2.0.tgz
rm -f cni-plugins-linux-arm64-v1.2.0.tgz
mkdir -pv /opt/cni/bin
mv ** /opt/cni/bin/
cd /home/dietpi

# machinectl shell -q dietpi@

# netavark aardvark-dns 