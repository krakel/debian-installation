#!/bin/bash


function moveWindow() {
	local window=$1
	local xBeg=$2
	local yBeg=$3
	local xEnd=$4
	local yEnd=$5
	echo $screen $xBeg $yBeg $xEnd $yEnd
}

window=$(printf '0x0%x' $(xdotool getwindowfocus))
xPos=$(wmctrl -l -G | grep $window | awk '{print $3; }')
yPos=$(wmctrl -l -G | grep $window | awk '{print $4; }')
xSize=$(xdotool getwindowfocus getdisplaygeometry | awk '{print $1; }')
ySize=$(xdotool getwindowfocus getdisplaygeometry | awk '{print $2; }')
xCenter=$((xPos + xSize/2))
yCenter=$((yPos + ySize/2))

#offset=$(((xPos / xSize) * xSize))

#new_xSize=$(($xSize * 90 / 100))
#new_ySize=$(($ySize * 80 / 100))
#new_xPos=$(($xSize * 5 / 100 + offset))
#new_yPos=$(($ySize * 10 / 100))

#echo $window
echo $xPos
echo $yPos
echo $xSize
echo $ySize
echo $xCenter
echo $yCenter
#echo $offset
#echo $new_xSize
#echo $new_ySize
#echo $new_xPos
#echo $new_yPos

#wmctrl -i -r $window -b remove,maximized_horz,maximized_vert
#wmctrl -i -r $window -e 0,$new_xPos,$new_yPos,$new_xSize,$new_ySize


mapfile -t xrand < <(xrandr --listactivemonitors)
unset -v 'xrand[0]'
#(IFS=$'\n'; echo "${xrand[*]}")

for value in "${xrand[@]}"; do
	screen=$(echo $value | cut -d ' ' -f 1)
	params=$(echo $value | cut -d ' ' -f 3)

	size=$(echo $params | cut -d '+' -f 1)
	xBeg=$(echo $params | cut -d '+' -f 2)
	yBeg=$(echo $params | cut -d '+' -f 3)

	ww=$(echo $size | cut -d 'x' -f 1)
	hh=$(echo $size | cut -d 'x' -f 2)
	width=${ww%[[.slash.]]*}
	height=${hh%[[.slash.]]*}

	xEnd=$((xBeg + width))
	yEnd=$((yBeg + height))

	if ((xCenter >= xBeg)) && ((xCenter < xEnd)) && ((yCenter >= yBeg)) && ((yCenter < yEnd)); then
		moveWindow $screen $xBeg $yBeg $xEnd $yEnd
		exit
	fi
done
