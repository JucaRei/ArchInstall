#! /usr/bin/env bash
sudo apt update

sudo apt install -y build-essential cmake cmake-extras curl gettext gir1.2-graphene-1.0 git glslang-tools gobject-introspection golang hwdata jq libavcodec-dev libavformat-dev libavutil-dev libcairo2-dev libdeflate-dev libdisplay-info-dev libdrm-dev libegl1-mesa-dev libgbm-dev libgdk-pixbuf-2.0-dev libgdk-pixbuf2.0-bin libgirepository1.0-dev libgl1-mesa-dev libgraphene-1.0-0 libgraphene-1.0-dev libgtk-3-dev libgulkan-0.15-0 libgulkan-dev libinih-dev libinput-dev libjbig-dev libjpeg-dev libjpeg62-turbo-dev liblerc-dev libliftoff-dev liblzma-dev libnotify-bin libpam0g-dev libpango1.0-dev libpipewire-0.3-dev libqt6svg6 libseat-dev libstartup-notification0-dev libswresample-dev libsystemd-dev libtiff-dev libtiffxx6 libtomlplusplus-dev libudev-dev libvkfft-dev libvulkan-dev libvulkan-volk-dev libwayland-dev libwebp-dev libxcb-composite0-dev libxcb-cursor-dev libxcb-dri3-dev libxcb-ewmh-dev libxcb-icccm4-dev libxcb-present-dev libxcb-render-util0-dev libxcb-res0-dev libxcb-util-dev libxcb-xinerama0-dev libxcb-xinput-dev libxcb-xkb-dev libxkbcommon-dev libxkbcommon-x11-dev libxkbregistry-dev libxml2-dev libxxhash-dev meson ninja-build openssl psmisc python3-mako python3-markdown python3-markupsafe python3-yaml qt6-base-dev scdoc seatd spirv-tools vulkan-utility-libraries-dev wayland-protocols xdg-desktop-portal xwayland

sudo apt install -t testing build-essential git cmake libwayland-dev libxkbcommon-dev libpixman-1-dev
sudo apt install -t unstable hyprland hyprland-backgrounds hyprland-protocols xdg-desktop-portal-hyprland

sudo apt install -t testing \
xdg-desktop-portal xdg-desktop-portal-wlr xdg-desktop-portal-gtk \
waybar swaybg wl-clipboard mako-notifier \
fonts-noto fonts-noto-color-emoji \
pipewire pipewire-audio wireplumber pipewire-pulse \
alacritty wofi

# Regreetd
sudo apt install lld build-essential libgtk-4-dev libpam0g-dev libxcb1-dev libxcb-xkb-dev libxkbcommon-dev libxkbcommon-x11-dev pkg-config curl
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
source $HOME/.cargo/env
rustup update
rustup default stable
# sudo apt install libgtk-4-dev
git clone --branch 0.2.0 --depth=1 https://github.com/rharish101/ReGreet
sudo cp target/release/regreet /usr/bin/ 


sudo apt install -t unstable hyprland hyprland-backgrounds hyprland-protocols xdg-desktop-portal-hyprland
sudo apt install alacritty swaybg waybar wofi wl-clipboard mako-notifier grim slurp grimblast
sudo apt install thunar thunar-archive-plugin thunar-media-tags-plugin thunar-volman tumbler \
    thunar-data thunar-font-manager gir1.2-thunarx-3.0

sudo apt install man fzf zoxide ripgrep bat eza fd-find btop gh
sudo apt install mpv