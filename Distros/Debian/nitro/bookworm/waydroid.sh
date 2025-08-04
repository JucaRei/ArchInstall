#!/usr/bin/env bash

apt update
apt install curl ca-certificates 

# curl https://repo.waydroid.id | bash
# curl https://repo.waydro.id | sudo bash
curl https://repo.waydro.id > install.sh
