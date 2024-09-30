#!/bin/bash

function helpMsg() {
  echo 'Usage:
  get_libs [verison]
  get_libs list'
}

if [[ $# -lt 1  ]]; then
	helpMsg
	exit
fi

VERSION=$1
LOCATION='https://repo1.maven.org/maven2/org'
DEST="TestFX$VERSION"

function doCommand() {
    case "$1" in
     "list") listVersions;;
     *) getVersion;;
    esac
}

function wgetFile() {
	if [ -f $2 ]; then
		echo "$2 already exists!"
	else
		wget $1 -O $2
	fi
}

function listVersions() {
	local meta='maven-metadata.xml'
	if [ -f $meta ]; then
		rm -f $meta
	fi
	local file="$LOCATION/testfx/testfx-core/$meta"
	wgetFile $file $meta
	grep '<version>' $meta  | grep -v 'ea' | sed 's/<version>//' | sed 's/<\/version>//' > /dev/stdout
	if [ -f $meta ]; then
		rm -f $meta
	fi
}

function checkFile() {
	local file="$LOCATION/testfx/testfx-$1/$VERSION/testfx-$1-$VERSION.jar"
	local srcs="$LOCATION/testfx/testfx-$1/$VERSION/testfx-$1-$VERSION-sources.jar"
	if [[ -f "$file" ]]; then
		echo "$file already exists!"
	else
		wgetFile $file "testfx-$1.jar"
		wgetFile $srcs "testfx-$1-sources.jar"
	fi
}

function getVersion() {
	if [ ! -d $DEST ]; then
		mkdir $DEST
	fi
	cd $DEST

	# https://repo1.maven.org/maven2/org/testfx/testfx-junit5/4.0.18/testfx-junit5-4.0.18.jar

	checkFile 'core'
	checkFile 'junit5'
	cd ..

	if [ ! -f "$DEST.userlibraries" ]; then
		cat <<- EOT >> "$DEST.userlibraries"
			<?xml version="1.0" encoding="UTF-8" standalone="no"?>
			<eclipse-userlibraries version="2">
			    <library name="$DEST" systemlibrary="false">
			        <archive path="/mnt/data/DeepSpace/libs/$DEST/testfx-core.jar"   source="/mnt/data/DeepSpace/libs/$DEST/testfx-core-sources.jar"/>
			        <archive path="/mnt/data/DeepSpace/libs/$DEST/testfx-junit5.jar" source="/mnt/data/DeepSpace/libs/$DEST/testfx-junit5-sources.jar"/>
			    </library>
			</eclipse-userlibraries>
		EOT
	fi
}

doCommand $1
