#!/bin/sh

if ! updates_artix=$(checkupdates 2>/dev/null | wc -l); then
    updates_artix=0
fi

if [ $updates_artix -gt 0 ]; then
    echo " $updates_artix"
else
    echo ""
fi
