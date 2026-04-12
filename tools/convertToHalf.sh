#!/bin/bash

# check required software
CHECK=("convert")
for i in "${CHECK[@]}"; do
  if ! command -v $i >/dev/null 2>&1; then
    echo "Error: '$i' not found (install the appropriate package)" 1>&2
    exit 1
  fi
done

for file; do
    if [ ! -e $file ]; then
      continue
    fi
    to_name="${file%.*}_half.${file##*.}"
    #echo $file > "log.txt"
    #echo $to_name >> "log.txt"
    #convert -resize $resize% -quality $QUALITY "${file}" "${to_name}"
    convert "${file}" -resize 50% "${to_name}"
done
