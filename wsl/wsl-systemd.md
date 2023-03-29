# Enable SystemD 

type :
>sudo -e /etc/wsl.conf

Add the following:

```systemd
[boot]
systemd=true
```

Shutdown wsl:

```wsl
wsl --shutdown
```

Restart and check:

```sh
sudo systemctl status
```

### If it didn't work, just try:

```apt
sudo apt-get update && sudo apt-get install -yqq daemonize dbus-user-session fontconfig

sudo daemonize /usr/bin/unshare --fork --pid --mount-proc /lib/systemd/systemd --system-unit=basic.target

exec sudo nsenter -t $(pidof systemd) -a su - $LOGNAME

snap version

```