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
DEST="JavaFX$VERSION"

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
	local file="$LOCATION/openjfx/javafx/$meta"
	wgetFile $file $meta
	grep '<version>' $meta  | grep -v 'ea' | sed 's/<version>//' | sed 's/<\/version>//' > /dev/stdout
	if [ -f $meta ]; then
		rm -f $meta
	fi
}

function checkFile() {
	local file="$LOCATION/openjfx/javafx-$1/$VERSION/javafx-$1-$VERSION-linux.jar"
	local srcs="$LOCATION/openjfx/javafx-$1/$VERSION/javafx-$1-$VERSION-sources.jar"
	wgetFile $file "javafx-$1-linux.jar"
	wgetFile $srcs "javafx-$1-sources.jar"
}

function getVersion() {
	if [ ! -d $DEST ]; then
		mkdir $DEST
	fi
	cd $DEST

	# https://repo1.maven.org/maven2/org/openjfx/javafx-base/22.0.1/javafx-base-22.0.1-linux.jar

	checkFile 'base'
	checkFile 'controls'
	checkFile 'fxml'
	checkFile 'graphics'
	checkFile 'media'
	checkFile 'swing'
	checkFile 'web'

	cd ..

	if [ ! -f "$DEST.userlibraries" ]; then
		cat <<- EOT >> "$DEST.userlibraries"
			<?xml version="1.0" encoding="UTF-8" standalone="no"?>
			<eclipse-userlibraries version="2">
			    <library name="$DEST" systemlibrary="false">
			        <archive path="/home/uwe/Data/DeepSpace/libs/$DEST/javafx-base-linux.jar"     source="/home/uwe/Data/DeepSpace/libs/$DEST/javafx-base-sources.jar"/>
			        <archive path="/home/uwe/Data/DeepSpace/libs/$DEST/javafx-controls-linux.jar" source="/home/uwe/Data/DeepSpace/libs/$DEST/javafx-controls-sources.jar"/>
			        <archive path="/home/uwe/Data/DeepSpace/libs/$DEST/javafx-fxml-linux.jar"     source="/home/uwe/Data/DeepSpace/libs/$DEST/javafx-fxml-sources.jar"/>
			        <archive path="/home/uwe/Data/DeepSpace/libs/$DEST/javafx-graphics-linux.jar" source="/home/uwe/Data/DeepSpace/libs/$DEST/javafx-graphics-sources.jar"/>
			        <archive path="/home/uwe/Data/DeepSpace/libs/$DEST/javafx-media-linux.jar"    source="/home/uwe/Data/DeepSpace/libs/$DEST/javafx-media-sources.jar"/>
			        <archive path="/home/uwe/Data/DeepSpace/libs/$DEST/javafx-swing-linux.jar"    source="/home/uwe/Data/DeepSpace/libs/$DEST/javafx-swing-sources.jar"/>
			        <archive path="/home/uwe/Data/DeepSpace/libs/$DEST/javafx-web-linux.jar"      source="/home/uwe/Data/DeepSpace/libs/$DEST/javafx-web-sources.jar"/>
			    </library>
			</eclipse-userlibraries>
		EOT
	fi
}

doCommand $1
