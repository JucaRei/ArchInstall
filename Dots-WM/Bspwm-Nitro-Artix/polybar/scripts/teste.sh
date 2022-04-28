#!bin/bash

bluetoothctl paired-devices | cut -d' ' -f2 | xargs -i -n1 bash -c "bluetoothctl info {} | grep -q 'connected: yes' && bluetoothctl info {} | grep -o 'Alias: .*'" | awk -vORS=', ' '{sub($1 OFS,"")}1' | sed -e 's/, $//'
