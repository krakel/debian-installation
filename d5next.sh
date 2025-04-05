#!/bin/bash

declare -a CURVE=(
	"50,100,100"
	"40,90,95"
	"35,80,90"
	"30,50,85"
	"25,40,80"
	"20,30,75"
	"15,20,70"
	"0,20,65"
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
