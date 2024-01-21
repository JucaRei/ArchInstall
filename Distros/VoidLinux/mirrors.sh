#!/bin/sh

# PKG_PATH="current/glibc-2.32_2.x86_64.xbps"
PKG_PATH="current/glibc-2.38.x86_64.xbps"
SPEED_LIMIT="1048576" # 1M

# MIRRORLIST=$(curl -s 'https://docs.voidlinux.org/xbps/repositories/mirrors/index.html' | pup 'table a attr{href}')

MIRRORLIST=$(curl -s 'https://xmirror.voidlinux.org/index.html' | pup 'table a attr{href}')

show_usage() {
	: "${progname:="${0##*/}"}"
	cat <<_EOF | GREP_COLORS='ms=1' egrep --color "$progname|$"
Usage: $progname                    show usage info
       $progname -w [file.csv]      save speedtest results to file
       $progname -r file.csv        format speedtest results from file
       $progname -f file.csv        format speedtest results from file and pass to fzf

pkg path: ${PKG_PATH}
speed limit: $(echo $SPEED_LIMIT | numfmt --to=iec-i --suffix=B/s)
mirrors for testing: $(echo "$MIRRORLIST" | wc -l)
_EOF
}

format_speedtest_results() {
	cat "$1" | sort -t, -nrk4 | while IFS=, read url info time_appconnect download_speed; do
		f_time=$(printf "%.2fs" $time_appconnect)
		f_speed=$(echo $download_speed | numfmt --to=iec-i --suffix=B/s)
		echo "${url},${info},${f_time},${f_speed}"
	done | column -s, -t
}

time_appconnect() {
	curl --connect-timeout 2 -o/dev/null -sw '%{time_appconnect}' -I $1
}

download_speed() {
	curl -Y $SPEED_LIMIT --progress-bar $1 -o/dev/null --write-out "%{speed_download}"
}

mirror_speedtest() {
	count=1
	echo "$MIRRORLIST" | while read -r mirror etc; do
		pkg_url="${mirror}${PKG_PATH}"
		info=$(echo $etc | sed 's/,//g')
		>&2 echo "${count}. $pkg_url"
		echo "${mirror},${info},$(time_appconnect $pkg_url),$(download_speed $pkg_url)"
		>&2 echo
		count=$((count + 1))
	done
}

case $1 in
	-r) format_speedtest_results $2;;
	-f) format_speedtest_results $2 | fzf +s;;
	-w) [ -z $2 ] && { mirror_speedtest; exit 0; } || { mirror_speedtest >"$2"; exit 0; };;
	*) show_usage;;
esac
exit 0
