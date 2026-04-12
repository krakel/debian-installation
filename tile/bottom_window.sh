#!/bin/bash

window=$(printf '0x0%x' $(xdotool getwindowfocus))
x_pos=($(wmctrl -l -G | grep $window | awk '{print $3; }'))
y_pos=($(wmctrl -l -G | grep $window | awk '{print $4; }'))
x_size=($(xdotool getwindowfocus getdisplaygeometry | awk '{print $1; }'))
y_size=($(xdotool getwindowfocus getdisplaygeometry | awk '{print $2; }'))
offset=$(((x_pos / x_size) * x_size))

new_x_size=$(($x_size * 97 / 100))
new_y_size=$((($y_size / 2) * 86 / 100))
new_x_pos=$(($x_size * 2 / 100 + $offset))
new_y_pos=$((($y_size / 2) + ($y_size * 2 / 100)))

wmctrl -i -r $window -b remove,maximized_horz,maximized_vert
wmctrl -i -r $window -e 0,$new_x_pos,$new_y_pos,$new_x_size,$new_y_size
