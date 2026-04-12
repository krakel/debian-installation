#!/bin/bash

declare -a CURVE=(
	"39,100,100"
	"36,90,100"
	"33,80,95"
	"30,50,95"
	"25,40,90"
	"20,30,90"
	"15,20,80"
	"0,20,80"
)

TEMPX=$(liquidctl --match d5 status | grep temperature  | cut -d ' ' -f 8)
TEMP=${TEMPX%%.*}

#echo $TEMP

for str in ${CURVE[@]}; do
	temp=${str%%,*}
	help=${str#*,}
	fan=${help%%,*}
	pump=${help##*,}
	if [[ $TEMP -gt $temp ]]; then
#		echo $temp $fan $pump
		liquidctl --match d5 set fan  speed $fan  > /dev/null 2>&1
		liquidctl --match d5 set pump speed $pump > /dev/null 2>&1
		break
	fi
done
