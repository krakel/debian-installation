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
LOCATION='https://repo1.maven.org/maven2/com'
DEST="Jackson$VERSION"

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
	local file="$LOCATION/fasterxml/jackson/jackson-bom/$meta"
	wgetFile $file $meta
	grep '<version>' $meta  | grep -v 'rc' | sed 's/<version>//' | sed 's/<\/version>//' > /dev/stdout
	if [ -f $meta ]; then
		rm -f $meta
	fi
}

function checkFile() {
	local file="$LOCATION/fasterxml/jackson/$1/jackson-$2/$VERSION/jackson-$2-$VERSION.jar"
	local srcs="$LOCATION/fasterxml/jackson/$1/jackson-$2/$VERSION/jackson-$2-$VERSION-sources.jar"
	wgetFile $file "jackson-$2.jar"
	wgetFile $srcs "jackson-$2-sources.jar"
}

function getVersion() {
	if [ ! -d $DEST ]; then
		mkdir $DEST
	fi
	cd $DEST

	# https://repo1.maven.org/maven2/com/fasterxml/jackson/core/jackson-annotations/2.17.1/jackson-annotations-2.17.1.jar
	# https://repo1.maven.org/maven2/com/fasterxml/jackson/core/jackson-core/2.17.1/jackson-core-2.17.1.jar
	# https://repo1.maven.org/maven2/com/fasterxml/jackson/core/jackson-databind/2.17.1/jackson-databind-2.17.1.jar 
	# https://repo1.maven.org/maven2/com/fasterxml/jackson/dataformat/jackson-dataformat-yaml/2.17.1/jackson-dataformat-yaml-2.17.1.jar

	checkFile 'core'       'annotations'
	checkFile 'core'       'core'
	checkFile 'core'       'databind'
	checkFile 'dataformat' 'dataformat-yaml'
	cd ..

	if [ ! -f "$DEST.userlibraries" ]; then
		cat <<- EOT >> "$DEST.userlibraries"
			<?xml version="1.0" encoding="UTF-8" standalone="no"?>
			<eclipse-userlibraries version="2">
			    <library name="$DEST" systemlibrary="false">
			        <archive path="/mnt/data/DeepSpace/libs/$DEST/jackson-annotations.jar"     source="/mnt/data/DeepSpace/libs/$DEST/jackson-annotations-sources.jar"/>
			        <archive path="/mnt/data/DeepSpace/libs/$DEST/jackson-core.jar"            source="/mnt/data/DeepSpace/libs/$DEST/jackson-core-sources.jar"/>
			        <archive path="/mnt/data/DeepSpace/libs/$DEST/jackson-databind.jar"        source="/mnt/data/DeepSpace/libs/$DEST/jackson-databind-sources.jar"/>
			        <archive path="/mnt/data/DeepSpace/libs/$DEST/jackson-dataformat-yaml.jar" source="/mnt/data/DeepSpace/libs/$DEST/jackson-dataformat-yaml-sources.jar"/>
			    </library>
			</eclipse-userlibraries>
		EOT
	fi
}

doCommand $1
