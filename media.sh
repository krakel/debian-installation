#!/bin/bash

function helpMsg() {
  echo 'Usage:
  sudo media [commands]*

Commands:
  help      this help
  test      only script tests

  chatty    Chatty
  discord   Discord
  dream     Dreambox Edit
  signal    Signal
  spotify   Spotify, some music
  telegram  Telegram
  twitch    twitch gui
  video     VideoLan
  webex     Webex
  zoom      Zoom

  gpic      GPicview image viewer
  viewnior  Viewnior image viewer
  mirage    Mirage image viewer (best)

  brave     Brave Browser
  chrome    Google Chrome
  deluge    Deluge Torrent Client
  firefox   Firefox move profile
  mozilla   Firefox + Thunderbird
  thunder   Thunderbird move profile'
}

declare -A SELECT=(
	[brave]=DO_BRAVE
	[chatty]=DO_CHATTY
	[chrome]=DO_CHROME
	[deluge]=DO_DELUGE
	[discord]=DO_DISCORD
	[dream]=DO_DREAMBOX_EDIT
	[firefox]=DO_FIREFOX
	[gpic]=DO_GPIC
	[mirage]=DO_MIRAGE
	[mozilla]=DO_MOZILLA
	[signal]=DO_SIGNAL
	[spotify]=DO_SPOTIFY
	[telegram]=DO_TELEGRAM
	[test]=DO_TEST
	[test]=DO_TEST
	[thunder]=DO_THUNDER
	[twitch]=DO_TWITCH_GUI
	[video]=DO_VIDEOLAN
	[viewnior]=DO_VIEWNIOR
	[webex]=DO_WEBEX
	[zoom]=DO_ZOOM
)

if [[ $# -eq 0  ]]; then
	helpMsg
	exit
fi

while [[ $# -gt 0 ]]; do
	key=${1#-}
	value=${SELECT[$key]}

	if [[ -z "$value" ]]; then
		helpMsg
		exit
	fi

	printf -v "$value" '%s' 'true'
	shift
done

SUDO_USER=$(logname)
HOME_USER="/home/$SUDO_USER"

SOURCES_DIR='/etc/apt/sources.list.d'
KEY_RING_DIR='/usr/share/keyrings'

#####################################################################
## some functions
#####################################################################
source functions

cd $HOME_USER

if [[ $(id -u) != 0 ]]; then
	 echo
	 echo 'Ups, I am not root!'
	 exit 1
fi

#####################################################################
# Media
#####################################################################

#####################################################################
#####################################################################
######### Chatty
if [[ ! -z "$DO_CHATTY" ]]; then
	echo '######### install Chatty'
	apt install default-jre

	CHATTY_URL='https://github.com/chatty/chatty/releases'
	CHATTY_REL=$(getLatestRelease $CHATTY_URL)
	CHATTY_REL=${CHATTY_REL:1}
	CHATTY_DEF="Chatty_$CHATTY_REL.zip"
	CHATTY_SRC='Chatty_*.zip'
	CHATTY_DRV=$(downloadDriver $CHATTY_URL $CHATTY_URL/download/v$CHATTY_REL/$CHATTY_DEF $CHATTY_SRC)

	rm -rf /opt/chatty/*
	unzip $CHATTY_DRV -d /opt/chatty
fi

#####################################################################
#####################################################################
######### Discord
# https://linuxconfig.org/how-to-install-discord-on-linux
if [[ ! -z "$DO_DISCORD" ]]; then
	echo '######### install Discord'

	DISCORD_URL='https://discordapp.com/api/download?platform=linux&format=deb'
	DISCORD_SRC='discord*.deb'
	DISCORD_LST='discord-latest.deb'
	#echo "download_driver '' $DISCORD_URL $DISCORD_SRC"
	DISCORD_DRV=$(downloadDriver '' $DISCORD_URL $DISCORD_SRC $DISCORD_LST)

	#apt install libgconf-2-4

	dpkg -i $DISCORD_DRV
fi

#####################################################################
#####################################################################
######### Dreambox Edit
# https://blog.videgro.net/2013/10/running-dreamboxedit-at-linux/
if [[ ! -z "$DO_DREAMBOX_EDIT" ]]; then
	echo '######### install Dreambox Edit'

	DREAMBOX_URL='https://dreambox.de/board/index.php?board/47-sonstige-pc-software/'
	DREAMBOX_REL='7.2.1.0'
	DREAMBOX_DEF="dreamboxEDIT_without_setup_$DREAMBOX_REL.zip"
	DREAMBOX_SRC='dreamboxEDIT_without_setup_*.zip'
	DREAMBOX_DRV=$(downloadDriver $DREAMBOX_URL '' $DREAMBOX_SRC)

	echo $DREAMBOX_DRV
	DREAMBOX_DIR=/opt/dreamboxedit
	mkdir -p $DREAMBOX_DIR
	unzip $DREAMBOX_DRV -d $DREAMBOX_DIR
#  ln -s /opt/dreamboxedit_5_3_0_0/ $DREAMBOX_DIR

	groupadd dreamboxedit
	usermod -aG dreamboxedit $SUDO_USER
	chown -R root:dreamboxedit $DREAMBOX_DIR

	echo
	echo 'cd /opt/dreamboxedit'
	echo 'wine dreamboxEDIT.exe'
fi

#####################################################################
#####################################################################
######### Signal
if [[ ! -z "$DO_SIGNAL" ]]; then
	echo '######### install Signal'
	SIGNAL_URL='https://updates.signal.org/desktop/apt'

	addPgpKey 'signal.gpg' "$SIGNAL_URL/keys.asc"
	echo "deb [arch=amd64 signed-by=$KEY_RING_DIR/signal.gpg] $SIGNAL_URL xenial main" > $SOURCES_DIR/signal.list

	apt update
	apt install signal-desktop
fi

#####################################################################
#####################################################################
######### Spotify
# https://wiki.debian.org/spotify
# https://www.spotify.com/de/download/linux/
if [[ ! -z "$DO_SPOTIFY" ]]; then
	echo '######### install Spotify'

	addPgpKey 'spotify.gpg' 'hkps://keyserver.ubuntu.com:443' '7A3A762FAFD4A51F'
	echo "deb [signed-by=$KEY_RING_DIR/spotify.gpg] http://repository.spotify.com stable non-free" > $SOURCES_DIR/spotify.list
	apt update

	apt install spotify-client
fi

#####################################################################
#####################################################################
######### Telegram
if [[ ! -z "$DO_TELEGRAM" ]]; then
	echo '######### install Telegram'

	apt install telegram-desktop
fi

#####################################################################
#####################################################################
######### twitch gui
# https://github.com/streamlink/streamlink-twitch-gui
# https://www.hiroom2.com/2018/05/27/ubuntu-1804-twitch-en/
# --twitch-disable-ads --twitch-low-latency --hls-live-edge=2 --hls-segment-stream-data --hls-segment-threads=4 --stream-segment-threads=4 --retry-streams 10 --retry-max 100 --retry-open 10 --default-stream "best,720p,480p,worst"
if [[ ! -z "$DO_TWITCH_GUI" ]]; then
	echo '######### install Streamlink'
	apt install streamlink

	echo '######### install twitch gui'
	TWITCH_URL='https://github.com/streamlink/streamlink-twitch-gui/releases'
	TWITCH_REL='v2.3.0'
	TWITCH_DEF="streamlink-twitch-gui-${TWITCH_REL}-linux64.tar.gz"
	TWITCH_SRC='streamlink-twitch-gui-*-linux64.tar.gz'
	TWITCH_DRV=$(downloadDriver $TWITCH_URL $TWITCH_URL/download/$TWITCH_REL/$TWITCH_DEF $TWITCH_SRC)
	echo $TWITCH_DRV

	tar -xzvf $TWITCH_DRV -C /opt
	apt install xdg-utils libgconf-2-4
	/opt/streamlink-twitch-gui/add-menuitem.sh
	ln -s /opt/streamlink-twitch-gui/start.sh /usr/bin/streamlink-twitch-gui

	createDesktopEntry "streamlink.desktop" <<- EOT
		[Desktop Entry]
		Version=1.0
		Name=Streamlink Twitch GUI
		Comment=Browse Twitch.tv and watch streams in your videoplayer of choice
		Exec=/opt/streamlink-twitch-gui/streamlink-twitch-gui --twitch-disable-ads --twitch-low-latency --hls-live-edge=2 --hls-segment-stream-data --hls-segment-threads=4 --stream-segment-threads=4 --retry-streams 10 --retry-max 100 --retry-open 10 --default-stream "best,720p,480p,worst"
		Icon=streamlink-twitch-gui.png
		Terminal=false
		Type=Application
		Categories=Utility;Internet;Video;
		StartupNotify=true
	EOT
fi

#####################################################################
#####################################################################
######### VideoLan
# https://www.videolan.org
if [[ ! -z "$DO_VIDEOLAN" ]]; then
	echo '######### install VideoLan'
	apt install vlc
fi

#####################################################################
#####################################################################
######### Webex
if [[ ! -z "$DO_WEBEX" ]]; then
	echo '######### install Webex'
	#wget https://binaries.webex.com/WebexDesktop-Ubuntu-Official-Package/Webex.deb
	WEBEX_URL='https://binaries.webex.com/WebexDesktop-Ubuntu-Official-Package'
	WEBEX_SRC='Webex.deb'
	WEBEX_LST='Webex*.deb'
	echo "download_driver $WEBEX_URL $WEBEX_URL/$WEBEX_SRC $WEBEX_LST"
	WEBEX_DRV=$(downloadDriver $WEBEX_URL $WEBEX_URL/$WEBEX_SRC $WEBEX_LST)

	#addPgpKey 'webex.gpg' "$WEBEX_URL/webex_public.key"
	#echo "deb [arch=amd64 signed-by=$KEY_RING_DIR/webex.gpg] $WEBEX_URL xenial main" > $SOURCES_DIR/webex.list

	#apt update
	apt install $WEBEX_DRV
fi

#####################################################################
#####################################################################
######### Zoom
if [[ ! -z "$DO_ZOOM" ]]; then
	echo '######### install Zoom'
	ZOOM_URL='https://us06web.zoom.us'
	ZOOM_VER='5.12.2.4816'
	ZOOM_SRC='zoom_amd64.deb'
	ZOOM_LST='zoom*.deb'
	echo "download_driver $ZOOM_URL/client/$ZOOM_VER $ZOOM_URL/client/$ZOOM_VER/$ZOOM_SRC $ZOOM_LST"
	ZOOM_DRV=$(downloadDriver $ZOOM_URL/client/$ZOOM_VER $ZOOM_URL/client/$ZOOM_VER/$ZOOM_SRC $ZOOM_LST)

	# https://us06web.zoom.us/linux/download/pubkey
	#addPgpKey 'zoom.gpg' "$ZOOM_URL/linux/download/pubkey/package-signing-key.pub"
	#echo "deb [arch=amd64 signed-by=$KEY_RING_DIR/webex.gpg] $ZOOM_URL xenial main" > $SOURCES_DIR/webex.list

	echo $ZOOM_DRV
	#apt update
	apt install $ZOOM_DRV
fi

#####################################################################
#####################################################################
######### GPicview image viewer
if [[ ! -z "$DO_GPIC" ]]; then
	echo '######### install GPicview'
	apt install gpicview
fi

#####################################################################
#####################################################################
######### Viewnior image viewer
if [[ ! -z "$DO_VIEWNIOR" ]]; then
	echo '######### install Viewnior'
	apt install viewnior
fi

#####################################################################
#####################################################################
######### Mirage image viewer
if [[ ! -z "$DO_MIRAGE" ]]; then
	echo '######### install Mirage'
	apt install mirage
fi

#####################################################################
# Web
#####################################################################

#####################################################################
#####################################################################
######### Brave Browser
if [[ ! -z "$DO_BRAVE" ]]; then
	echo '######### install Brave Browser'
	apt install software-properties-common apt-transport-https curl ca-certificates

	BRAVE_URL='https://brave-browser-apt-release.s3.brave.com'
	wget -qO- $BRAVE_URL/brave-browser-archive-keyring.gpg | gpg --dearmor | tee $KEY_RING_DIR/brave.gpg > /dev/null
	# curl -fsSLo $KEY_RING_DIR/brave.gpg $BRAVE_URL/brave-browser-archive-keyring.gpg
	# echo "deb [signed-by=$KEY_RING_DIR/brave-keyring.gpg] $BRAVE_URL/ stable main" | tee $SOURCES_DIR/brave.list

	#addPgpKey 'brave.gpg' '$BRAVE_URL/brave-browser-archive-keyring.gpg'
	echo "deb [arch=amd64 signed-by=$KEY_RING_DIR/brave.gpg] $BRAVE_URL/ stable main" > $SOURCES_DIR/brave.list
	apt update

	# apt install brave-browser
fi

#####################################################################
#####################################################################
######### Chrome Browser
if [[ ! -z "$DO_CHROME" ]]; then
	echo '######### install Google Chrome'
	apt install software-properties-common apt-transport-https wget ca-certificates gnupg2

	CHROME_URL='https://dl.google.com/linux'

	addPgpKey 'chrome.gpg' '$CHROME_URL/linux_signing_key.pub'
	echo "deb [arch=amd64 signed-by=$KEY_RING_DIR/chrome.gpg] $CHROME_URL/chrome/deb/ stable main" > $SOURCES_DIR/chrome.list
	apt update

	apt install google-chrome-stable
fi

#####################################################################
#####################################################################
######### Firefox + Thunderbird

if [[ ! -z "$DO_MOZILLA" ]]; then
	echo '######### install Firefox + Thunderbird'

	apt remove --purge iceweasel

	apt install -t unstable firefox
	apt install -t unstable thunderbird
fi


function mozillaCopyProfile() {
	local profileZIP=$1
	local profileLIN=$2
	local profileWIN=$3
	local profileOLD="$profileLIN/win10profile"
	local profileINI="$profileLIN/profiles.ini"

	if [[ -d "$profileOLD" ]]; then
		echo 'windows profile already exist'
		return
	fi

	sudo -u $SUDO_USER mkdir -p $profileOLD

	if [[ -d "$profileWIN" ]]; then
		local winProf=$(grep "StartWithLastProfile" $profileWIN/profiles.ini | cut -d '=' -f 2 | tr -d '\r')
		local pathProf=$(grep -m${winProf:-1} -F '[Profile' $profileWIN/profiles.ini -A 3 | grep "Path" | cut -d '=' -f 2 | tr -d '\r')
		if [[ -z "$pathProf" ]]; then
			echo 'missing profile path entry'
			return
		fi
		echo "cp -f -r $profileWIN/$pathProf/* $profileOLD"
		sudo -u $SUDO_USER cp -f -r $profileWIN/$pathProf/* $profileOLD
	elif [[ -f "$profileZIP" ]]; then
		sudo -u $SUDO_USER unzip $profileZIP -d $pprofileOLD
	else
		echo 'missing copy of Windows profile'
		return
	fi

	if [[ ! -f "$profileINI" ]]; then
		cat <<- EOT | sudo -u $SUDO_USER tee $profileINI > /dev/null
			[General]
			StartWithLastProfile=0
			Version=2
		EOT
	fi
	sudo -u $SUDO_USER sed -i '0,/StartWithLastProfile=[0-9]*/s//StartWithLastProfile=0/' $profileINI
	if ! grep -F -q 'win10profile' $profileINI ; then
		cat <<- EOT | sudo -u $SUDO_USER tee -a $profileINI > /dev/null
			[Profile0]
			Name=win10profile
			IsRelative=1
			Path=win10profile

			[General]
			StartWithLastProfile=1
		EOT
	fi
}

#####################################################################
#####################################################################
######### Firefox Profile
if [[ ! -z "$DO_FIREFOX" ]]; then

	FIREFOX_WINDOWS="/mnt/work_c/Users/$WIN_USER/AppData/Roaming/Mozilla/Firefox"
	FIREFOX_LINUX="$HOME_USER/.mozilla/firefox"

	mozillaCopyProfile 'Download/firefox.zip'     $FIREFOX_LINUX     $FIREFOX_WINDOWS
fi

#####################################################################
#####################################################################
######### Thunderbird Profile
if [[ ! -z "$DO_THUNDER" ]]; then

	THUNDERBIRD_WINDOWS="/mnt/work_c/Users/$WIN_USER/AppData/Roaming/Thunderbird"
	THUNDERBIRD_LINUX="$HOME_USER/.thunderbird"

	mozillaCopyProfile 'Download/thunderbird.zip' $THUNDERBIRD_LINUX $THUNDERBIRD_WINDOWS
fi

#####################################################################
#####################################################################
######### Deluge Torrent Client
if [[ ! -z "$DO_DELUGE" ]]; then
	apt install deluge
fi

#####################################################################
#####################################################################
if [[ ! -z "$DO_TEST" ]]; then
	echo 'nothing here for now'

fi
