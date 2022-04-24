#!/bin/sh

if ! updates_artix=$(checkupdates 2> /dev/null | wc -l ); then
	updates_artix=0
fi

if [ $updates_artix -gt 0 ]; then
   echo " $updates_artix"
else
    echo ""
fi

#!/bin/sh

# Only Aur 

#if ! updates=$(yay -Qum 2> /dev/null | wc -l); then
# if ! updates=$(paru -Qum 2> /dev/null | wc -l); then
# if ! updates=$(cower -u 2> /dev/null | wc -l); then
# if ! updates=$(trizen -Su --aur --quiet | wc -l); then
#if ! updates=$(pikaur -Qua 2> /dev/null | wc -l); then
# if ! updates=$(rua upgrade --printonly 2> /dev/null | wc -l); then
#    updates=0
#fi

#if [ "$updates" -gt 0 ]; then
#    echo "# $updates"
#else
#    echo ""
#fi

