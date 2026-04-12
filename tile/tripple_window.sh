#!/bin/bash


function moveWindow() {
	local pos=$1
	local wnd=$2
	local xBeg=$3
	local yBeg=$4
	local xSize=$5
	local ySize=$6
	echo $pos $wnd $xBeg $yBeg $xSize $ySize
	case $pos in
		vt)
			xdotool windowmove --sync $wnd $xBeg $yBeg
			xdotool windowsize --sync $wnd $xSize $((ySize/3))
			;;
		vc)
			xdotool windowmove --sync $wnd $xBeg $((yBeg + ySize/3))
			xdotool windowsize --sync $wnd $xSize $((ySize/3))
			;;
		vb)
			xdotool windowmove --sync $wnd $xBeg $((yBeg + 2*ySize/3))
			xdotool windowsize --sync $wnd $xSize $((ySize/3))
			;;
		hl)
			xdotool windowmove --sync $wnd $xBeg $yBeg
			xdotool windowsize --sync $wnd $((xSize/3)) $ySize
			;;
		hc)
			xdotool windowmove --sync $wnd $((xBeg + xSize/3)) $yBeg
			xdotool windowsize --sync $wnd $((xSize/3)) $ySize
			;;
		hr)
			xdotool windowmove --sync $wnd $((xBeg + 2*xSize/3)) $yBeg
			xdotool windowsize --sync $wnd $((xSize/3)) $ySize
			;;
		*)
			;;
	esac
}

window=$(printf '0x0%x' $(xdotool getwindowfocus))
coord=$(wmctrl -l -G | grep $window | tr -s ' ')
xPos=$(echo $coord | cut -d ' ' -f 3)
yPos=$(echo $coord | cut -d ' ' -f 4)
xSize=$(echo $coord | cut -d ' ' -f 5)
ySize=$(echo $coord | cut -d ' ' -f 6)
xCenter=$((xPos + xSize/2))
yCenter=$((yPos + ySize/2))

#echo $window
#echo $xPos
#echo $yPos
#echo $xSize
#echo $ySize
#echo $xCenter
#echo $yCenter

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

	xRel=$((xCenter - xBeg))
	yRel=$((yCenter - yBeg))

	echo $screen $xBeg $yBeg $width $height

	if ((xRel >= 0)) && ((xRel < width)) && ((yRel >= 0)) && ((yRel < height)); then
		moveWindow 'vx' $window $xBeg $yBeg $width $height
		exit
	fi
done
