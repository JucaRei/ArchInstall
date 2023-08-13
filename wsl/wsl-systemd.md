# Enable SystemD 

type :
>sudo -e /etc/wsl.conf

Add the following:

```systemd
[boot]
systemd=true
command="mount --make-shared /"  # podman
command="service docker start" 

[automount]
enable = true
root = /
#options = "metadata,umask=022,fmask=111,case=off"
```

root = / changes the mount root for windows local drives to '/' instead of the default '/mnt/, so instead of C: mounted at '/mnt/c' it will be mounted at '/c'.

case=off will make all directories created from within WSL to be case insensitive in the windows file system, because even if Windows is case sensitive the applications run on windows is not necessary case sensitive.

### Use Windows Home Folder

```shell
wsl -u root usermod --home /c/Users/win-user wsl-user 
```

download wslgit

### Fonts

```shell
git clone https://github.com/powerline/fonts.git --depth=1
cd fonts
Set-ExecutionPolicy Bypass
./install.ps1
cd ..
Remove-Item fonts -Recurse -Force
```

If you already have ssh keys and configurations in $HOME/.ssh that were created in windows then you must change the file permission on those files to 600. Also fix $HOME/.gnupg if you are using GnuPG.

```shell
chmod -R 600 .ssh
chmod -R 600 .gnupg
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

echo "# allow starting the docker daemon without password\n%docker ALL=(ALL)  NOPASSWD: /usr/bin/dockerd" >> /etc/sudoers

# put into ~/.bashrc:
if [ ! -S /var/run/docker.sock ]; then
        nohup sudo -b dockerd < /dev/null > ~/dockerd.log 2>&1
fi

### Mount disk C: with "metadata" flag
This will allow users to set the owner and group of files using chmod/chown and modify read/write/execute permissions in WSL.

unmount drvfs
```shell
sudo umount /mnt/c
```
remount it with the "metadata" flag
```
sudo mount -t drvfs C: /mnt/c -o metadata
```
mount automatically with "metadata" enabled
```
sudo vi /etc/wsl.conf and add the following lines,
```
# The common settings for WSL

These are recommended steps for setting up your WSL

## Mount disk C: with "metadata" flag

This will allow users to set the owner and group of files using chmod/chown and modify read/write/execute permissions in WSL.

1. unmount drvfs

```bash
sudo umount /mnt/c
```

2. remount it with the "metadata" flag

```bash
sudo mount -t drvfs C: /mnt/c -o metadata
```

3. mount automatically with "metadata" enabled

`sudo vi /etc/wsl.conf` and add the following lines,

```ini
# mount with options
[automount]
options = "metadata"
[boot]
systemd=true
```

## Set WSL to use your Windows home directory

It would be very convenient to keep home in sync among Windows and different WSL distros.

1. change home path

`sudo vi /etc/passwd` and find the line defines your username. It will look like this,

```passwd
david:x:1000:1000:,,,:/home/david:/bin/bash
```

Change it to,

```passwd
david:x:1000:1000:,,,:/mnt/c/users/bindai:/bin/bash
```

2. change permission

Exit WSL and re-open it. Home is now changed to new path. Then set home directory permission.

```bash
chown david ~
chgrp david ~
chmod 755 ~
```

## How to start SSH server under WSL

1. install openssh server

```bash
sudo apt update
sudo apt install openssh-server
```

2. generate hostkeys

```bash
sudo dpkg-reconfigure openssh-server
```

3. edit the `/etc/ssh/sshd_config` configuration file to allow password authentication

```config
PasswordAuthentication yes
```

4. restart the ssh server

```bash
sudo service ssh --full-restart
```

## Fix WSL2 DNS resolution

It is convenient to use the same DNS server with the Window host.

1. `sudo vi /etc/wsl.conf` and add the following lines,
```ini
[network]
generateResolvConf = false
```
restart wsl2: `wsl --terminate $WSL_DISTRO_NAME`.

2. get the name servers and optional the search domain
```bash
ipconfig /all | grep "DNS Servers" | awk '{print "nameserver " $NF}'
ipconfig /all | grep -Po "DNS Suffix .* : \K([^\s]+)" | sort | uniq
```
`sudo vi /etc/resolv.conf` and put the above nameservers.

restart wsl2: `wsl --terminate $WSL_DISTRO_NAME`.

## Run `ping` or other tools without `sudo`

If you directly run `ping`, you will probably get `ping: socket: Operation not permitted`. This usually happens in WSL1. Below command will fix

```bash
sudo chmod u+s `which ping`
```

## Bridged networking under WSL2

1. Create an external switch in Hyper-v, say `Bridge-WSL`.

2. Create a file named `.wslconfig` under `%USERPROFILE%` in Windows.
```conf
[wsl2]
networkingMode=bridged
vmSwitch=Bridge-WSL # change this to the bridge name just created.
ipv6=true
```

3. restart wsl2: `wsl --terminate $WSL_DISTRO_NAME`.

Check `ip a` to see if it actually works.

## References

* [Automatically Configuring WSL](https://devblogs.microsoft.com/commandline/automatically-configuring-wsl/)
* [Using the same Home Directory in Windows and WSL](https://jeremyskinner.co.uk/2018/07/27/sharing-home-directory-between-windows-and-wsl/)
* [Fix DNS resolution in WSL2](https://gist.github.com/coltenkrauter/608cfe02319ce60facd76373249b8ca6)
* [Ping is not working](https://github.com/microsoft/WSL/issues/18#issuecomment-450057702)