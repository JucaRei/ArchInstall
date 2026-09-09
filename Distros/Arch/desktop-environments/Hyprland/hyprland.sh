#!/usr/bin/env bash

# Minimal Packages
yay -S dolphin dunst grim hyprland kitty polkit-kde-agent \
        qt5-wayland qt6-wayland slurp wwsm wofi xdg-desktop-portal-hyprland
        
pikaur -S hyprland uwsm foot nemo --noconfirm --needed

# swww matugen waybar wl-clipboard cliphist dunst network-manager-applet polkit-kde-agent man-db sddm
# grim slurp

# ufw

######################
### Core Utilities ###
######################
pacman -S git --noconfirm # Git version control system. 
pacman -S base-devel --ignore sudo --noconfirm # Basic development tools for building packages. 
pikaur -S wget --noconfirm # Command-line utility for downloading files from the web.
pikaur -S tar --noconfirm # Archiving utility.
pikaur -S unzip --noconfirm # Utility for extracting compressed files.
pikaur -S jq --noconfirm # Command-line JSON processor.
pikaur -S xclip --noconfirm # Command-line interface to the X11 clipboard.
pikaur -S fzf --noconfirm # Command-line fuzzy finder.
pikaur -S eza --noconfirm # A modern replacement for 'ls'.
pikaur -S ripgrep --noconfirm # Fast search tool for searching text within files.
pikaur -S bat --noconfirm # A cat clone with syntax highlighting and Git integration.
pikaur -S fd --noconfirm # Simple, fast and user-friendly alternative to 'find'.
pikaur -S neofetch --noconfirm # Command-line system information tool.
pikaur -S htop --noconfirm # Interactive process viewer for the terminal.
pikaur -S figlet --noconfirm # Command-line tool for creating ASCII art text banners.
pikaur -S rsync --noconfirm # Utility for fast incremental file transfer.

###############################
### Hyprland Basic Packages ###
###############################
pikaur -S hyprland --noconfirm # Dynamic tiling Wayland compositor.
pikaur -S hyprctl --noconfirm # Hyprland command-line interface tool.
pikaur -S xdg-desktop-portal-gtk --noconfirm # GTK implementation of xdg-desktop-portal (used by Flatpak).
pikaur -S alacritty --noconfirm # GPU-accelerated terminal emulator.
pikaur -S xdg-desktop-portal-hyprland --noconfirm # Hyprland integration for xdg-desktop-portal. 

########################
### Hyperland Extras ###
########################
pikaur -S hyprpicker --noconfirm # Color picker for Hyprland.
pikaur -S hyprlock --noconfirm # Screen locker for Hyprland.
pikaur -S hypridle --noconfirm # Idle management for Hyprland.
# pikaur -S swaybg --noconfirm # Wallpaper setter for Wayland.
pikaur -S hyprpaper --noconfirm # Wallpaper manager for Hyprland.
pikaur -S waypaper --noconfirm # Wallpaper setter for Wayland.
pikaur -S grim --noconfirm # Screenshot utility for Wayland.
pikaur -S grimblast-git --noconfirm # Enhanced screenshot tool built on grim/slurp.
pikaur -S slurp --noconfirm # Selection utility for Wayland.
pikaur -S wl-clipboard --noconfirm # Command-line clipboard utilities for Wayland.
pikaur -S cliphist --noconfirm # Clipboard history manager for Wayland.
# pikaur -S mako --noconfirm # Lightweight notification daemon for Wayland.
# pikaur -S libnotify --noconfirm # Library for sending desktop notifications.        
pikaur -S swaync --noconfirm # Notification center for Wayland.
pikaur -S waybar --noconfirm # Highly customizable status bar for Wayland.
pikaur -S rofi-wayland --noconfirm # Rofi build for Wayland.
pikaur -S wlogout --noconfirm # Logout menu for Wayland.

pikaur -S nwg-dock-hyprland --noconfirm # Dock application for Hyprland.

#########################
### Wayland Utilities ###
#########################
# pikaur -S wayland --noconfirm # Core Wayland libraries.
pikaur -S xdg-desktop-portal --noconfirm # Desktop portal for Wayland. 
# pikaur -S wlroots --noconfirm # Modular Wayland compositor library.
pikaur -S wayland-protocols --noconfirm # Wayland protocols.
pikaur -S xorg-xwayland --noconfirm # XWayland - X server running as a Wayland client.
pikaur -S qt5-wayland --noconfirm # Qt5 Wayland platform plugin.
pikaur -S qt6-wayland --noconfirm # Qt6 Wayland platform plugin.

###########################
### File & System Tools ###
###########################
pikaur -S xdg-user-dirs --noconfirm # Tool to manage user directories like Documents, Downloads, etc.
pikaur -S gvfs --noconfirm # Virtual filesystem for accessing remote files.
pikaur -S libnotify --noconfirm # Library for sending desktop notifications.
pikaur -S tumbler --noconfirm # Thumbnailing service for file managers.
pikaur -S brightnessctl --noconfirm # Utility to control screen brightness.
pikaur -S power-profiles-daemon --noconfirm # Daemon to manage power profiles.

# pikaur -S flatpak --noconfirm # Application sandboxing and distribution framework.

#######################
### Display Manager ###
#######################
pikaur -S sddm-git --noconfirm # Simple Desktop Display Manager (SDDM) for Wayland and X11.
pikaur -S sddm-theme-chili --noconfirm # Chili SDDM theme.

sed -i '/^\[Theme\]/,/^\[/{s/^Current=.*/Current=chilli/}' /usr/lib/sddm/sddm.conf.d/default.conf

####################
### Polkit Agent ###
####################
pikaur -S polkit-kde-agent --noconfirm # Polkit authentication agent for KDE Plasma.

#####################
### Video Drivers ###
#####################

## Intel GPU Support

# pikaur -S intel-media-driver --noconfirm # Intel Media Driver for VAAPI
# pikaur -S intel-gmmlib --noconfirm # Intel Graphics Memory Management Library
# pikaur -S intel-ucode --noconfirm # Intel CPU microcode updates
# pikaur -S libva-utils --noconfirm # Utilities for VAAPI
# pikaur -S libvpl --noconfirm # Video Processing Library
# pikaur -S linux-firmware-intel --noconfirm # Intel firmware files
# pikaur -S onetbb --noconfirm # OneAPI Threading Building Blocks
# pikaur -S vulkan-intel --noconfirm # Intel Vulkan driver

## MESA
pikaur -S mesa --noconfirm # Open-source implementation of the OpenGL specification - a system for rendering interactive 3D graphics.
pikaur -S glu --noconfirm # OpenGL Utility Library
pikaur -S vulkan-mesa-device-select --noconfirm # Vulkan device selection for Mesa

###################
### Basic Fonts ###
###################
pikaur -S ttf-dejavu \
        noto-fonts \
        noto-fonts-emoji \
        ttf-liberation --noconfirm

##################
### Networking ###
##################
pikaur -S nm-connection-editor --noconfirm # GUI for editing NetworkManager connections.
pikaur -S network-manager-applet --noconfirm # System tray applet for managing networks.

#########################
### Audio & Bluetooth ###
#########################
pikaur -S pipewire --noconfirm # Modern audio and video routing and processing framework.
# pikaur -S blueman --noconfirm # Bluetooth manager and tools.
# pikaur -S bluez bluez-tools bluez-utils --noconfirm # Bluetooth protocol stack and utilities.

##############
### Codecs ###
##############
pikaur -S gst-libav --noconfirm # GStreamer libav plugin.
pikaur -S gst-plugins-bad --noconfirm # GStreamer plugins from the "bad" set.
pikaur -S gst-plugins-good --noconfirm # GStreamer plugins from the "good" set. 
pikaur -S gst-plugins-ugly --noconfirm # GStreamer plugins from the "ugly" set.
pikaur -S ffmpeg --noconfirm # Complete solution to record, convert and stream audio and video.
pikaur -S gstreamer --noconfirm # GStreamer multimedia framework.

############################
### Appearance & Theming ###
############################

pikaur -S nwg-look --noconfirm #  GTK theme switcher for Wayland.
pikaur -S qt6ct --noconfirm #Qt6 configuration tool for theming.
pikaur -S papirus-icon theme --noconfirm # Papirus Icon Theme.
pikaur -S breeze --noconfirm # KDE Default theme (includes icons, cursors, etc).
pikaur -S bibata-cursor-theme --noconfirm # Bibata Cursor Theme.
pikaur -S otf-font-awesome ttf-fira-sans ttf-fira-code ttf-firacode-nerd \ 
        ttf-cascadia-code-nerd ttf-cascadia-mono-nerd ttf-fira-code ttf-fira-mono ttf-fira-sans \
        ttf-firacode-nerd ttf-iosevka-nerd ttf-iosevkaterm-nerd ttf-jetbrains-mono-nerd \
        ttf-jetbrains-mono ttf-nerd-fonts-symbols ttf-nerd-fonts-symbols ttf-nerd-fonts-symbols-mono --noconfirm # Fonts for UI, coding, and icons.

systemctl enable sddm.service