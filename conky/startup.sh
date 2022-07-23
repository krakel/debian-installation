#!/bin/bash

killall conky
sleep 10s

conky -c "$HOME/.conky/titus.conkyrc" &
