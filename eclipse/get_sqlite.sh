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
DEST="SQLite$VERSION"

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
	local file="$LOCATION/xerial/sqlite-jdbc/$meta"
	wgetFile $file $meta
	grep '<version>' $meta  | sed 's/<version>//' | sed 's/<\/version>//' > /dev/stdout
	if [ -f $meta ]; then
		rm -f $meta
	fi
}

function checkFile() {
	local file="$LOCATION/xerial/sqlite-jdbc/$VERSION/sqlite-jdbc-$VERSION.jar"
	local srcs="$LOCATION/xerial/sqlite-jdbc/$VERSION/sqlite-jdbc-$VERSION-sources.jar"
	wgetFile $file "sqlite-jdbc.jar"
	wgetFile $srcs "sqlite-jdbc-sources.jar"
}

function getVersion() {
	if [ ! -d $DEST ]; then
		mkdir $DEST
	fi
	cd $DEST

	# https://repo1.maven.org/maven2/org/xerial/sqlite-jdbc/3.45.3.0/sqlite-jdbc-3.45.3.0.jar

	checkFile

	cd ..

	if [ ! -f "$DEST.userlibraries" ]; then
		cat <<- EOT >> "$DEST.userlibraries"
			<?xml version="1.0" encoding="UTF-8" standalone="no"?>
			<eclipse-userlibraries version="2">
			    <library name="$DEST" systemlibrary="false">
			        <archive path="/mnt/data/DeepSpace/libs/$DEST/sqlite-jdbc.jar" source="/mnt/data/DeepSpace/libs/$DEST/sqlite-jdbc-sources.jar"/>
			    </library>
			</eclipse-userlibraries>
		EOT
	fi
}

doCommand $1
