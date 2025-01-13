#!/usr/bin/env bash

find / -iname "*.so" \
       -user juca    \
       -type f       \
       -size +1M     \
       -exec ls {}   \;
