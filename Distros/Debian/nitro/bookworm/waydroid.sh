#!/usr/bin/env bash

apt update
apt install curl ca-certificates 

apt install weston -y

curl https://repo.waydro.id | bash
# curl https://repo.waydro.id | sudo bash
# curl https://repo.waydro.id > install.sh

sudo apt install waydroid -y

touch ~/.config/weston.ini
cat <<EOF > ~/.config/weston.ini
[libinput]
enable-tap=true

[shell]
panel-position=none
EOF

touch /usr/local/bin/waydroid-session.sh
cat <<EOF > /usr/local/bin/waydroid-session.sh
#!/bin/bash

# Start Weston
weston --xwayland --backend=x11-backend.so --width=486 --height=1000 &
WESTON_PID=$!
export WAYLAND_DISPLAY=wayland-1
sleep 2

# Launch Waydroid
waydroid show-full-ui &
WAYDROID_PID=$!

# Function to stop Waydroid
stop_waydroid() {
    waydroid session stop
    kill $WESTON_PID
    kill $WAYDROID_PID 2>/dev/null
}

# Wait for Weston to finish
wait $WESTON_PID

# Stop Waydroid after Weston exits
stop_waydroid
EOF

chmod +x /usr/local/bin/waydroid-session.sh

touch /usr/share/applications/waydroid-session.desktop
cat <<EOF > /usr/share/applications/waydroid-session.desktop
[Desktop Entry]
Version=1.0
Type=Application
Name=Waydroid Session
Comment=Launch Waydroid X11 Session
Exec=/bin/bash -c "cd /usr/local/bin && ./waydroid-session.sh"
Icon=waydroid
Terminal=false
Categories=System;Emulator;
StartupNotify=true
EOF

chmod +x /usr/share/applications/waydroid-session.desktop