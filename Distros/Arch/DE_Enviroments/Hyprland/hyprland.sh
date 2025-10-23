#!/usr/bin/env bash

# Minimal Packages
yay -S dolphin dunst grim hyprland kitty polkit-kde-agent \
        qt5-wayland qt6-wayland slurp wwsm wofi xdg-desktop-portal-hyprland
        
######################
### Core Utilities ###
######################
pacman -S git --noconfirm # Git version control system. 
pacman -S base-devel --ignore sudo --noconfirm # Basic development tools for building packages. 
yay -S wget --noconfirm # Command-line utility for downloading files from the web.
yay -S tar --noconfirm # Archiving utility.
yay -S unzip --noconfirm # Utility for extracting compressed files.
yay -S jq --noconfirm # Command-line JSON processor.
yay -S xclip --noconfirm # Command-line interface to the X11 clipboard.
yay -S fzf --noconfirm # Command-line fuzzy finder.
yay -S eza --noconfirm # A modern replacement for 'ls'.
yay -S ripgrep --noconfirm # Fast search tool for searching text within files.
yay -S bat --noconfirm # A cat clone with syntax highlighting and Git integration.
yay -S fd --noconfirm # Simple, fast and user-friendly alternative to 'find'.
yay -S neofetch --noconfirm # Command-line system information tool.
yay -S htop --noconfirm # Interactive process viewer for the terminal.
yay -S figlet --noconfirm # Command-line tool for creating ASCII art text banners.
yay -S rsync --noconfirm # Utility for fast incremental file transfer.

###############################
### Hyprland Basic Packages ###
###############################
yay -S hyprland --noconfirm # Dynamic tiling Wayland compositor.
yay -S hyprctl --noconfirm # Hyprland command-line interface tool.
yay -S xdg-desktop-portal-gtk --noconfirm # GTK implementation of xdg-desktop-portal (used by Flatpak).
yay -S alacritty --noconfirm # GPU-accelerated terminal emulator.
yay -S xdg-desktop-portal-hyprland --noconfirm # Hyprland integration for xdg-desktop-portal. 

########################
### Hyperland Extras ###
########################
yay -S hyprpicker --noconfirm # Color picker for Hyprland.
yay -S hyprlock --noconfirm # Screen locker for Hyprland.
yay -S hypridle --noconfirm # Idle management for Hyprland.
# yay -S swaybg --noconfirm # Wallpaper setter for Wayland.
yay -S hyprpaper --noconfirm # Wallpaper manager for Hyprland.
yay -S waypaper --noconfirm # Wallpaper setter for Wayland.
yay -S grim --noconfirm # Screenshot utility for Wayland.
yay -S grimblast-git --noconfirm # Enhanced screenshot tool built on grim/slurp.
yay -S slurp --noconfirm # Selection utility for Wayland.
yay -S wl-clipboard --noconfirm # Command-line clipboard utilities for Wayland.
yay -S cliphist --noconfirm # Clipboard history manager for Wayland.
# yay -S mako --noconfirm # Lightweight notification daemon for Wayland.
# yay -S libnotify --noconfirm # Library for sending desktop notifications.        
yay -S swaync --noconfirm # Notification center for Wayland.
yay -S waybar --noconfirm # Highly customizable status bar for Wayland.
yay -S rofi-wayland --noconfirm # Rofi build for Wayland.
yay -S wlogout --noconfirm # Logout menu for Wayland.

yay -S nwg-dock-hyprland --noconfirm # Dock application for Hyprland.

#########################
### Wayland Utilities ###
#########################
# yay -S wayland --noconfirm # Core Wayland libraries.
yay -S xdg-desktop-portal --noconfirm # Desktop portal for Wayland. 
# yay -S wlroots --noconfirm # Modular Wayland compositor library.
yay -S wayland-protocols --noconfirm # Wayland protocols.
yay -S xorg-xwayland --noconfirm # XWayland - X server running as a Wayland client.
yay -S qt5-wayland --noconfirm # Qt5 Wayland platform plugin.
yay -S qt6-wayland --noconfirm # Qt6 Wayland platform plugin.

###########################
### File & System Tools ###
###########################
yay -S xdg-user-dirs --noconfirm # Tool to manage user directories like Documents, Downloads, etc.
yay -S gvfs --noconfirm # Virtual filesystem for accessing remote files.
yay -S libnotify --noconfirm # Library for sending desktop notifications.
yay -S tumbler --noconfirm # Thumbnailing service for file managers.
yay -S brightnessctl --noconfirm # Utility to control screen brightness.
yay -S power-profiles-daemon --noconfirm # Daemon to manage power profiles.

# yay -S flatpak --noconfirm # Application sandboxing and distribution framework.

#######################
### Display Manager ###
#######################
yay -S sddm-git --noconfirm # Simple Desktop Display Manager (SDDM) for Wayland and X11.
yay -S sddm-theme-chili --noconfirm # Chili SDDM theme.

sed -i '/^\[Theme\]/,/^\[/{s/^Current=.*/Current=chilli/}' /usr/lib/sddm/sddm.conf.d/default.conf

####################
### Polkit Agent ###
####################
yay -S polkit-kde-agent --noconfirm # Polkit authentication agent for KDE Plasma.

#####################
### Video Drivers ###
#####################

## Intel GPU Support

# yay -S intel-media-driver --noconfirm # Intel Media Driver for VAAPI
# yay -S intel-gmmlib --noconfirm # Intel Graphics Memory Management Library
# yay -S intel-ucode --noconfirm # Intel CPU microcode updates
# yay -S libva-utils --noconfirm # Utilities for VAAPI
# yay -S libvpl --noconfirm # Video Processing Library
# yay -S linux-firmware-intel --noconfirm # Intel firmware files
# yay -S onetbb --noconfirm # OneAPI Threading Building Blocks
# yay -S vulkan-intel --noconfirm # Intel Vulkan driver

## MESA
yay -S mesa --noconfirm # Open-source implementation of the OpenGL specification - a system for rendering interactive 3D graphics.
yay -S glu --noconfirm # OpenGL Utility Library
yay -S vulkan-mesa-device-select --noconfirm # Vulkan device selection for Mesa

###################
### Basic Fonts ###
###################
yay -S ttf-dejavu \
        noto-fonts \
        noto-fonts-emoji \
        ttf-liberation --noconfirm

##################
### Networking ###
##################
yay -S nm-connection-editor --noconfirm # GUI for editing NetworkManager connections.
yay -S network-manager-applet --noconfirm # System tray applet for managing networks.

#########################
### Audio & Bluetooth ###
#########################
yay -S pipewire --noconfirm # Modern audio and video routing and processing framework.
# yay -S blueman --noconfirm # Bluetooth manager and tools.
# yay -S bluez bluez-tools bluez-utils --noconfirm # Bluetooth protocol stack and utilities.

##############
### Codecs ###
##############
yay -S gst-libav --noconfirm # GStreamer libav plugin.
yay -S gst-plugins-bad --noconfirm # GStreamer plugins from the "bad" set.
yay -S gst-plugins-good --noconfirm # GStreamer plugins from the "good" set. 
yay -S gst-plugins-ugly --noconfirm # GStreamer plugins from the "ugly" set.
yay -S ffmpeg --noconfirm # Complete solution to record, convert and stream audio and video.
yay -S gstreamer --noconfirm # GStreamer multimedia framework.

############################
### Appearance & Theming ###
############################

yay -S nwg-look --noconfirm #  GTK theme switcher for Wayland.
yay -S qt6ct --noconfirm #Qt6 configuration tool for theming.
yay -S papirus-icon theme --noconfirm # Papirus Icon Theme.
yay -S breeze --noconfirm # KDE Default theme (includes icons, cursors, etc).
yay -S bibata-cursor-theme --noconfirm # Bibata Cursor Theme.
yay -S otf-font-awesome ttf-fira-sans ttf-fira-code ttf-firacode-nerd \ 
        ttf-cascadia-code-nerd ttf-cascadia-mono-nerd ttf-fira-code ttf-fira-mono ttf-fira-sans \
        ttf-firacode-nerd ttf-iosevka-nerd ttf-iosevkaterm-nerd ttf-jetbrains-mono-nerd \
        ttf-jetbrains-mono ttf-nerd-fonts-symbols ttf-nerd-fonts-symbols ttf-nerd-fonts-symbols-mono --noconfirm # Fonts for UI, coding, and icons.

systemctl enable sddm.service