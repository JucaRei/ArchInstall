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