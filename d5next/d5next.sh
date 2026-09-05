#!/bin/bash

########## old D5Next
#declare -a CURVE=(
#	"39,100,100"
#	"36,90,100"
#	"33,80,95"
#	"30,50,95"
#	"25,40,90"
#	"20,30,90"
#	"15,20,80"
#	 "0,20,80"
#)

#WATER=$(liquidctl --match d5 status | grep temperature  | cut -d ' ' -f 8)
#WATER=${WATER%%.*}
#echo "WATER=$WATER"

########## new
declare -a CURVE=(
	"90,100,100"
	"85,90,100"
	"80,80,95"
	"70,70,95"
	"60,60,90"
	"50,50,90"
	"40,40,80"
	"30,30,80"
	"20,20,70"
	 "0,20,70"
)

CPU_ADAPTER='k10temp-pci-00c3'
GPU_ADAPTER='amdgpu-pci-0300'

CPU=$(sensors $CPU_ADAPTER | grep 'Tctl' | awk {'print $2'})
CPU=${CPU%%.*}
CPU=${CPU:1}
#echo "CPU=$CPU"

GPU=$(sensors $GPU_ADAPTER | grep 'junction' | awk {'print $2'})
GPU=${GPU%%.*}
GPU=${GPU:1}
#echo "GPU=$GPU"

for str in ${CURVE[@]}; do
	#echo "$str"
	set -f
	arr=(${str//,/ })
	#echo $arr
	temp=${arr[0]}
	fan=${arr[1]}
	pump=${arr[2]}
	if [[ $CPU -gt $temp ]] || [ $GPU -gt $temp ]; then
#		echo "$temp $fan $pump"
		liquidctl --match d5 set fan  speed $fan  > /dev/null 2>&1
		liquidctl --match d5 set pump speed $pump > /dev/null 2>&1
		break
	fi
done
