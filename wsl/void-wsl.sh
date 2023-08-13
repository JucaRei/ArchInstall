# Based on https://gist.github.com/kmatt/71603170556ef8ffd14984af77ff10c5
# prompt ">" indicates Powershell commands

# https://docs.microsoft.com/en-us/windows/wsl/install-win10

> dism.exe /online /enable-feature /featurename:Microsoft-Windows-Subsystem-Linux /all /norestart
> dism.exe /online /enable-feature /featurename:VirtualMachinePlatform /all /norestart

# install https://wslstorestorage.blob.core.windows.net/wslblob/wsl_update_x64.msi

> wsl --set-default-version 2

# use rootfs tarball from https://voidlinux.org/download
# ex.: https://alpha.de.repo.voidlinux.org/live/current/void-x86_64-ROOTFS-20210930.tar.xz
# uncompress but do not unzip tar file

> wsl.exe --import $DISTRONAME $STORAGEPATH void-$VERSION.tar

> wsl -d $DISTRONAME 

# optional - update xbps mirrors 
$ cp /usr/share/xbps.d/*-repository-*.conf /etc/xbps.d/
# if in US https://voidlinux.org/news/2021/10/mirror-retirement.html

$ xbps-install -Su xbps
$ xbps-install -u
$ xbps-install base-system
$ xbps-remove base-voidstrap
$ xbps-reconfigure -fa

$ useradd -m -G wheel -s /bin/bash $USERNAME
$ passwd $USERNAME
$ su - $USERNAME

# get Linux UID
$ id -u
1000

# use visudo to grant wheel group sudo

# set default linux user
> Get-ItemProperty Registry::HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Lxss\*\ DistributionName | Where-Object -Property DistributionName -eq $DISTRONAME   | Set-ItemProperty -Name DefaultUid -Value $UID