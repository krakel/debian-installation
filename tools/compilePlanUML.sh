#!/bin/bash

for file; do
    if [ ! -e $file ]; then
      continue
    fi
	java -jar /opt/lib/plantuml-1.2025.4.jar -darkmode "${file}"
done
