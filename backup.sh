#!/bin/bash

SRC_DIR='backup.txt'
DST_DIR='backupTemp'
LOG_FILE="backupscript.log"
LOG_SUCC=

RCLONE_NAME='Remote'
RCLONE_DIR='BackupDaily'
#DRY_RUN='--dry-run'

#DISCORD_HOOK="https://discord.com/api/webhooks/1385572846365048952/VzaPQ2ihxwarKRFm7xl6isgkzZ4SwI-NS51CW7uJG1qv_AtA3fIjkxHmKriaAt20gsvx"
DISCORD_HOOK="https://discord.com/api/webhooks/1385607411137646613/n7DUqOLKCwShxXIG1UenPoTlJ3Bh3dYSZWxwNhi-1mrJjjzyQbBPmNMiXBAr8rLoMG02"
HOST_NAME="`hostname`"

START=
ELAPSED=
SIZE=
DATE=$(date +"%d.%m.%Y %H:%M:%S")

# Clear Log Files
clearLog() {
	true > $LOG_FILE
}

# Check if temp folder exists if not create it
createFolder() {
	if [[ ! -d $DST_DIR ]]; then	
		mkdir -p $DST_DIR
	fi
}

# Start the timer
startTimer() {
	START="$(date +%s)"
}

# Stop the timer
stopTimer() {
	local time="$(($(date +%s) - START))"
	ELAPSED="$(($time / 3600)):$((($time / 60) % 60)):$(($time % 60))"
	#echo "The backup has finished it took $ELAPSED"
}

startSize() {
	SIZE=`stat -c%s $LOG_FILE`
}

checkSize() {
	local folder=$1
	local newSize=`stat -c%s $LOG_FILE`
	if [[ $SIZE == $newSize ]]; then
		LOG_SUCC="${LOG_SUCC}\n$1"
	else
		LOG_SUCC="${LOG_SUCC}\nErrors - $1"
	fi
	SIZE=$newSize
}

# Check if the report errors function is true
reportDiscord() {
	if [[ -s $LOG_FILE ]]; then
		MSG="The sync of $DATE failed.\nPlease check the backupscript.log file.\nIt took $ELAPSED\n$LOG_SUCC."
		CLR="16711680"
	else
		MSG="The sync of $DATE finished successfully.\nIt took $ELAPSED\n$LOG_SUCC."
		CLR="655104"
	fi
	curl -H "Accept: application/json" -H "Content-Type: application/json" -X POST -d "{\"username\":\"Backupscript\", \"embeds\":[{\"title\":\"$HOST_NAME\",\"description\":\"$MSG\",\"color\":$CLR}]}" $DISCORD_HOOK
	#echo "Content-Type: application/json" -X POST -d "{\"username\":\"Backupscript\", \"embeds\":[{\"title\":\"$HOST_NAME\",\"description\":\"$MSG\",\"color\":$CLR}]}" $DISCORD_HOOK
}

zipFiles() {
	local src=$1
	local name=$2
	if [[ -d $src ]]; then
		zip -r $DST_DIR/$name $src
	fi
}

# Sync the files to a remote location
syncFiles() {
	local src=$1
	local dst=$2
	rclone sync  "$src" "$RCLONE_NAME:$RCLONE_DIR/$dst" $DRY_RUN --quiet --log-file=$LOG_FILE
	rclone check "$src" "$RCLONE_NAME:$RCLONE_DIR/$dst" $DRY_RUN --quiet --log-file=$LOG_FILE
}

echoLog() {
	if [[ -s $LOG_FILE ]]; then
		echo "[FAILED] - $DATE - Please check the backup.log file to see the errors"
		cat $LOG_FILE
	else
		echo "[FINISHED] - $DATE"
	fi
}

syncList() {
	oIFS="$IFS"
	IFS=";"
	while read -r line; do
		#echo $line
		if [[ ${line:0:1} == '#' ]]; then
			continue
		fi
		startSize
		declare -a fields=($line)
		fldName=${fields[1]}
		fldFldr=${fields[2]}
		if [[ ${fields[0]} == 'zip' ]]; then
			zipFiles  $fldFldr $fldName
			syncFiles "$DST_DIR/$fldName.zip"
		else
			syncFiles "$fldFldr" $fldName
		fi
		checkSize $fldName
		unset fields
		unset fldName
		unset fldFldr
	done < $SRC_DIR
	IFS="$oIFS"
	unset oIFS
}

startTimer
clearLog
createFolder
syncList
stopTimer
reportDiscord
echoLog
