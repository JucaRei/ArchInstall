#!/usr/bin/env bash

u=$(xprop -name "tray" _NET_WM_PID | grep -o '[[:digit:]]*')
kill $u
