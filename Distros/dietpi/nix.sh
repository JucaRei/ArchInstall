#!/bin/sh

## Multiuser

sudo apt install xz-utils -y 
mkdir -pv ~/.config/nix
touch ~/.config/nix/nix.conf
echo "experimental-features = nix-command flakes" >> ~/.config/nix/nix.conf

## Install nix package manager
yes | sh <(curl -L https://nixos.org/nix/install) --daemon