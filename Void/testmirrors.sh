#!/bin/bash
#
# Ref: https://www.reddit.com/r/voidlinux/comments/6xor9j/automatically_find_fastest_update_mirror_and_use/
# Ref: https://edpsblog.wordpress.com/2019/08/24/how-to-escolhendo-espelhos-mais-rapidos-no-void-linux/
#

# mkdir -p ~/bin
# Add to path 
# export PATH=$HOME/bin:$PATH

# Require: xbps-install -S geoip
 
declare -a arr=("alpha.de.repo.voidlinux.org" \
        "mirror.clarkson.edu" \
        "repo-fi.voidlinux.org" \
        "alpha.us.repo.voidlinux.org" \
        "mirrors.servercentral.com" \
        "repo-us.voidlinux.org" \
        "void.webconverger.org" \
        "mirror.ps.kz/voidlinux" \
        "mirrors.bfsu.edu.cn/voidlinux" \ 
        "mirrors.cnnic.cn/voidlinux" \
        "mirrors.tuna.tsinghua.edu.cn/voidlinux" \
        "mirror.sjtu.edu.cn/voidlinux" \
        "void.webconverger.org" \
        "mirror.aarnet.edu.au/pub/voidlinux" \
        "ftp.swin.edu.au/voidlinux" \
        "void.cijber.net" \ 
        "mirror.erickochen.nl/voidlinux" \
        "ftp.dk.xemacs.org/voidlinux" \
        "mirrors.dotsrc.org/voidlinux" \
        "quantum-mirror.hu/mirrors/pub/voidlinux" \
        "voidlinux.mirror.garr.it" \
        "voidlinux.qontinuum.space:4443" \
        "mirror.fit.cvut.cz/voidlinux" \
        "ftp.debian.ru/mirrors/voidlinux" \
        "mirror.yandex.ru/mirrors/voidlinux" \
        "cdimage.debian.org/mirror/voidlinux" \
        "ftp.acc.umu.se/mirror/voidlinux" \
        "ftp.lysator.liu.se/pub/voidlinux" \
        "ftp.sunet.se/mirror/voidlinux" \
        "mirror.clarkson.edu/voidlinux")
 
fping=10000
frepo=""
 
for repo in "${arr[@]}"
    do
geo=`geoiplookup $repo | head -1 | sed 's/^.*: //'`
    echo ""
    echo "Testing ping for $repo ($geo)"
ping=`ping -c 4 $repo | tail -1| awk '{print $4}' | cut -d '/' -f 2 | bc -l`
    echo "$repo Average ping: $ping"
    if (( $(bc <<< "$ping<$fping") ))
    then
    frepo=$repo
    fping=$ping
    fi
done
 
geo=`geoiplookup $frepo | head -1 | sed 's/^.*: //'`
    echo ""
    echo "Recommended repo is: $frepo ($geo)"
echo "Ping: $fping"