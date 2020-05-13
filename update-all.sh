#!/bin/bash

THIS_NAME=$(basename "${BASH_SOURCE[0]}")

function got_error() {
  echo "$THIS_NAME: I got a error!"
  exit 1
}

apt list --upgradable
[ $? -eq 0 ] || got_error

apt update
[ $? -eq 0 ] || got_error

apt upgrade
[ $? -eq 0 ] || got_error

apt dist-upgrade
[ $? -eq 0 ] || got_error

dpkg --configure -a
[ $? -eq 0 ] || got_error

apt install -f
[ $? -eq 0 ] || got_error

apt clean
[ $? -eq 0 ] || got_error

apt autoremove
[ $? -eq 0 ] || got_error

apt autoremove --purge
[ $? -eq 0 ] || got_error

echo "$THIS_NAME: successful"
