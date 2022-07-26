#!/bin/bash

if [[ $# -eq 0  ]]; then
	echo 'Usage: colorNegate [folder]
	read all mp4 at [folder] and write converted file to [folder]A'
	exit
fi

for f in $1/*.mp4; do
	#echo "$f"
	n=$(basename $f)
	echo $n
	ffmpeg -hide_banner -loglevel error -i "$1/$n" -vf "negate" "${1}A/$n"
done
