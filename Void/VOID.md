# Void Linux installation (btrfs without luks or lvm)

loadkeys br-abnt2

### Connecting with Wifi


### Connecting to the internet
```console
# cp /etc/wpa_supplicant/wpa_supplicant.conf /etc/wpa_supplicant/wpa_supplicant-<wlan-interface>.conf
# wpa_passphrase <ssid> <passphrase> >> /etc/wpa_supplicant/wpa_supplicant-<wlan-interface>.conf
# sv restart dhcpcd
# ip link set up <interface>
```

### Update the repo
```update
  xbps-install -Su xbps
```

### Make 3 partitions for boot, root and home.

```format
mkfs.fat -F32 /dev/sdX
mkfs.btrfs /dev/sdX
mkfs.btrfs /dev/sdX
```

### Mounting partitions

- mount /dev/sdaX /mnt

```subvol
btrfs subvolume create /mnt/@
btrfs subvolume create /mnt/@home
btrfs subvolume create /mnt/@snapshots
btrfs subvolume create /mnt/@var_log
```
- umount /mnt

```mount
  - mount -o noatime,ssd,compress-force=zstd:20,space_cache=v2,commit=120,discard=async,subvol=@ /dev/sdaX /mnt

  - mkdir -p /mnt/{boot/efi,home,.snapshots,var/log}

  - mount -o noatime,ssd,compress-force=zstd:20,space_cache=v2,commit=120,discard=async,subvol=@ /dev/sdaX /mnt/home

  - mount -o noatime,ssd,compress-force=zstd:20,space_cache=v2,commit=120,discard=async,subvol=@ /dev/sdaX /mnt/.snapshots

  - mount -o noatime,ssd,compress-force=zstd:20,space_cache=v2,commit=120,discard=async,subvol=@ /dev/sdaX /mnt/var/log

  - mount /dev/sdX /mnt/boot/efi
```

### Add REPO

```config
REPO=https://alpha.de.repo.voidlinux.org/current
ARCH=x86_64
```
### Install base system

```base
XBPS_ARCH=$ARCH xbps-install -S -r /mnt -R "$REPO" base-system vim git wget efibootmgr btrfs-progs nano ntfs-3g mtools dosfstools grub-x86_64-efi grub-btrfs grub-btrfs-runit void-repo-nonfree elogind vsv vpm polkit dbus chrony neofetch duf lua bat glow bluez bluez-alsa xdg-user-dirs xdg-utils
```

### Bind before chroot

```bind
- mount --rbind /sys /mnt/sys && mount --make-rslave /mnt/sys

- mount --rbind /dev /mnt/dev && mount --make-rslave /mnt/dev

- mount --rbind /proc /mnt/proc && mount --make-rslave /mnt/proc
```

### Copy network config to mnt

```net
cp /etc/resolv.conf /mnt/etc
```
### Chroot

 - chroot /mnt /bin/bash

###  Set your zone

- ln -sf /usr/share/zoneinfo/America/Sao_Paulo /etc/localtime

### add locales (US, pt-BR)

- vim /etc/default/libc-locales 

 - xbps-reconfigure -f glibc-locales

### Add hostname and edit hosts
- **echo "desiredname" > /etc/hostname**

### Configuring hosts file 
**Place below content in the file /etc/hosts**

```hosts
127.0.0.1 localhost
::1 localhost
127.0.1.1 desiredname.localdomain desiredname
```
### Change Root password
```pass
  passwd
```
### Add user
```user
useradd juca -m -c "Full User Name" -s /bin/bash
passwd juca
usermod -aG wheel,audio,video,optical,kvm,lp,storage juca

  - visudo
  (uncomment %wheel ALL=(ALL) ALL)
```
### Generate fstab and fix
```fstab
cat /proc/mounts >> /etc/fstab
  - remove proc mounts (efi  must be 2 at the end)
```
### Install Bootloader


```grub
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=VOID

update-grub
```
### Installing network-related packages 
```internet
xbps-install -Sy NetworkManager pavucontrol
```

### Check if everything is ok
```check
xbps-reconfigure -fa

hwclock --systohc
```

GRUB CONFIGS
================================================================

### 1. Silent GRUB                                                                                     
                                                                                                         
  To hide all the grub output which is displayed during boot.  Copy these parameters to                  
  GRUB_CMDLINE_LINUX_DEFAULT, then update the grub                                                       
                                                                                                       
    loglevel=0 console=tty2 udev.log_level=0 vt.global_cursor_default==0                                 
                                                                                                         
  The above will esentially hide kernel logs and put them in tty2. But still, there are some messages    
  that can be hidden like "Welcome to GRUB!" which can be removed by this                                
  https://github.com/ccontavalli/grub-shusher. Also, you can hide booting messages by going to           
                                                                                                       
    sudo nano /boot/grub/grub.cfg                                                         
                                                                                                         
  And here you can remove all the echo messages. Remember this resets everytime grub is updated This     
  provides a clean-looking boot, which I prefer.                                                         
                                                                                                         
  ### 2. Turn off Mitigations                                                                            
                                                                                                         
  You can turn off CPU mitigations for the highest performance, but least security. If you run a lot of  
  unknown code, then you should skip this. To learn how this affects your pc, go here                    
  https://linuxreviews.org/HOWTO_make_Linux_run_blazing_fast_(again)_on_Intel_CPUs. To know what kind of 
  vulnerability might arise, you can go here https://meltdownattack.com/ To enable this, add this to     
  GRUB_CMDLINE_LINUX_DEFAULT, then update the grub                                                       
                                                                                                       
    mitigations=off                                                                                      
                                                                                                         
  ### 3. Disable Watchdog                                                                                
                                                                                                         
  Watchdog is used to monitor if a system is running. It is supposed to automatically reboot hanged      
  systems due to unrecoverable software errors.  Personal computer users don’t need a watchdog, as they  
  can reset the system manually. You can learn more about this from here https://linuxhint.com/linux-kernel-watchdog-explained/ To enable this, add this to GRUB_CMDLINE_LINUX_DEFAULT, then update the grub
                                                                                                       
    nowatchdog                                                                                           
                                                                                                         
  ### 4. Kernel Parameters                                                                               
                                                                                                         
  These are some kernel parameters that boost my computer, most of them optimizations are from Clear     
  Linux. These basically disables some checks on boot time, making it faster.                            
                                                                                                       
    intel_idle.max_cstate=1 cryptomgr.notests initcall_debug intel_iommu=igfx_off no_timer_check noreplace-smp page_alloc.shuffle=1 rcupdate.rcu_expedited=1 tsc=reliable                               
                                                                                                         
  This is what my GRUB looks like after adding the parameters                                            
                                                                                                       
    #                                                                                                    
    # Configuration file for GRUB.                                                                       
    #                                                                                                    
    GRUB_DEFAULT=0                                                                                       
    GRUB_TIMEOUT=0                                                                                       
    GRUB_CMDLINE_LINUX_DEFAULT="loglevel=0 console=tty2 udev.log_level=0 vt.global_cursor_default=0 mitigations=off nowatchdog msr.allow_writes=on pcie_aspm=force module.sig_unenforce intel_idle.max_cstate=1 cryptomgr.notests initcall_debug intel_iommu=igfx_off no_timer_check noreplace-smp page_alloc.shuffle=1 rcupdate.rcu_expedited=1 tsc=reliable                                                                                 
    GRUB_DISABLE_OS_PROBER=true                                                                          
    GRUB_DISABLE_RECOVERY=true                                                                           
    GRUB_DISABLE_SUBMENU=true           

    sudo update-grub


## Power Options without password
- Login as root
```x
# echo "username ALL=(ALL) NOPASSWD: /usr/bin/halt, /usr/bin/poweroff, /usr/bin/reboot, /usr/bin/shutdown, /usr/bin/zzz, /usr/bin/ZZZ" >> /etc/sudoers.d/username
```

  REBOOT
=========================================================

### Post Installation

#### Enabling RTC service 
```conf
ln -s /etc/sv/chronyd /var/service/
```
#### Enabling network-related services 
```conf
ln -s /etc/sv/{dhcpcd,NetworkManager} /var/service/
```
#### Enabling services for seat 
```conf
ln -srf /etc/sv/{dbus,polkitd,elogind} /var/service
```
#### Install some packages
```packages
sudo xbps-install -S intel-ucode pulseaudio pavucontrol alsa-plugins-pulseaudio
```

#### Video

```video
#Intel
sudo xbps-install -S xf86-video-intel

# Open Source
sudo xbps-install -S xf86-video-nouveau

#Nvidia
sudo xbps-install -S nvidia
```

#### Virtual Machines

```vm
sudo xbps-install virt-manager qemu bridge-utils
```
#### **Load Services**

```sv
sudo ln -s /etc/sv/libvirtd /var/service
sudo ln -s /etc/sv/virtlockd /var/service
sudo ln -s /etc/sv/virtlogd /var/service

# Check services

sudo sv status libvirtd 
sudo sv status virtlogd 
sudo sv status virtlockd
``` 

#### Other Services
```sv
sudo ln -s /etc/sv/NetworkManager /var/service
sudo ln -s /etc/sv/acpid /var/service
sudo ln -s /etc/sv/ntpd /var/service
sudo ln -s /etc/sv/iptables /var/service
sudo ln -s /etc/sv/iptables6 /var/service
sudo ln -s /etc/sv/bluetoothd /var/service
sudo ln -s /etc/sv/bluez-alsa /var/service
```
Install your Desktop Enviroment or Window Manager
================================================================

# BSPWM

### Packages

```pkg
sudo xbps-install -S bspwm xorg autorandr arandr Thunar thunar-archive-plugin thunar-media-tags-plugin thunar-volman sxhkd glow ranger polybar xfce4-terminal light-locker alacritty playerctl font-firacode flatpak fzf geoip dmenu nitrogen feh unclutter xclip libinput libinput-gestures picom evince neovim rofi dunst scrot lxappearance lightdm gvfs-smb lightdm-gtk3-greeter-2.0.8_1 lightdm-gtk-greeter-settings xfce4-settings font-iosevka light-locker mpd ncmpcpp mpc neofetch htop geany base-devel
```

### Instalar Void packages

```pkg
git clone https://github.com/void-linux/void-packages.git
cd void-packages
./xbps-src binary-bootstrap
echo XBPS_ALLOW_RESTRICTED=yes >> etc/conf

```

### Picom com blur
- After installed void-packages
- Download the template repo and copy into **"srcpkgs"**:
```pkg
git clone https://github.com/ibhagwan/picom-ibhagwan-template
mv picom-ibhagwan-template ./srcpkgs/picom-ibhagwan
```
- Build & install the package:
```build
./xbps-src pkg picom-ibhagwan
sudo xbps-install --repository=hostdir/binpkgs picom-ibhagwan 
```

  Or if you have xtools

```xtools
xi -f picom-ibhagwan
```

### Tranformar aplicativos debian em xbps

        https://github.com/toluschr/xdeb

- Faça o download da ultima versão do xdeb
- instale os pacotes: **binutils tar curl xbps xz**
- Coloque os dois arquivos (**.deb e xdeb** ) na mesma pasta e de permissão para xdeb (**chmod +x**)
- Rode **./xdeb -Sde pacoteAserInstalado.deb** 
- Depois de finalizado, sera criado o aplicativo xbps na pasta **binpkgs**
- instale o app:
```install
  sudo xbps-install -R . pacoteAserInstalado
```
- Pacote foi instalado
