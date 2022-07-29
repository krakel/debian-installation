#!/bin/bash

function helpMsg() {
  echo 'Usage:
  sudo games [commands]*

Commands:
  help      this help
  test      only script tests

  wine      Wine
  steam     Steam
  lutris    Lutris
  dxvk      vulkan-based compatibility layer for Direct3D
  dnet      Microsoft .Net 4.6.1 (do not use)
  multimc   Minecraft MultiMC'
}

declare -A SELECT=(
	[dnet]=DO_DOT_NET
	[dxvk]=DO_DXVK
	[lutris]=DO_LUTRIS
	[multimc]=DO_MULTI_MC
	[steam]=DO_STEAM
	[test]=DO_TEST
	[wine]=DO_WINE
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
# Gaming
#####################################################################

#####################################################################
#####################################################################
######### Wine
######### WineHQ
if [[ ! -z "$DO_WINE" ]]; then
	echo '######### install Wine'
	apt install gnupg2 software-properties-common

	# not at latest debian testing
	# repositories and images created with the Open Build Service
	# OBS_URL='https://download.opensuse.org/repositories/Emulators:/Wine:/Debian/Debian_Testing_standard'
	# addPgpKey 'wine.gpg' "https://$OBS_URL/Release.key"
	# echo 'deb [signed-by=$KEY_RING_DIR/wine.gpg] http://$OBS_URL ./' > $SOURCES_DIR/wine-obs.list
	# apt update

	# LIB_SDL=libsdl2-2.0-0_2.0.10+dfsg1-1_amd64.deb
	# sudo -u $SUDO_USER wget -P Downloads http://ftp.us.debian.org/debian/pool/main/libs/libsdl2/$LIB_SDL
	# dpkg -i Downloads/$LIB_SDL
	# apt install libsdl2-2.0-0

	# LIB_FAUDIO=libfaudio0_20.01-0~bullseye_amd64.deb
	# sudo -u $SUDO_USER wget -P Downloads https://$OBS_URL/amd64/$LIB_FAUDIO
	# dpkg -i Downloads/$LIB_FAUDIO
	# apt install libfaudio0

	# winehq-stable:    Stable builds provide the latest stable version
	# winehq-staging:   Staging builds contain many experimental patches intended to test some features or fix compatibility issues.
	# winehq-devel:     Developer builds are in-development, cutting edge versions.

	WINE_BUILDS='https://dl.winehq.org/wine-builds'
	addPgpKey 'wineHQ.gpg' "$WINE_BUILDS/winehq.key"
	echo "deb [signed-by=$KEY_RING_DIR/wineHQ.gpg] $WINE_BUILDS/debian/ bookworm main" > $SOURCES_DIR/wine.list
	# echo "deb $WINE_BUILDS/debian/ testing  main" > $SOURCES_DIR/wine.list # <-- broken, not working
	apt update

	function wineInstallWine() {
		WINEOPT=''
		if [[ ! -z "$1" ]]; then
			WINEOPT="-$1"
		fi
		if [[ ! -z "$2" ]]; then
			WINEOPT="$WINEOPT=$2"
		fi
		apt install --install-recommends wine$WINEOPT wine32$WINEOPT wine64$WINEOPT libwine$WINEOPT libwine:i386$WINEOPT fonts-wine$WINEOPT
	}

	function wineInstallWineHQ() {
		WINEOPT=''
		if [[ ! -z "$1" ]]; then
			WINEOPT="-$1"
		fi
		if [[ ! -z "$2" ]]; then
			WINEOPT="$WINEOPT=$2"
		fi
		apt install --install-recommends winehq$WINEOPT
	}

	# apt-cache policy winehq-staging
	WINE_VER=$(apt search wine-staging | grep -F 'wine-staging/' | cut -d ' ' -f 2)
	if [[ -z "WINE_VER" ]]; then
		echo 'missing wine-staging version'
		apt search wine-staging
		exit 1
	fi
	wineInstallWine   'staging' $WINE_VER
	wineInstallWineHQ 'staging' $WINE_VER

	sudo -u $SUDO_USER winecfg    # mono,gecko will be installed
	if [[ "$?" != "0" ]]; then
		echo 'something goes wrong!'
		exit 1
	fi

	addBinToPath '.profile' '/opt/wine-staging/bin' after

	apt install mono-complete
	apt install winetricks
	apt autoremove
	wine --version
fi

#####################################################################
#####################################################################
######### Steam
if [[ ! -z "$DO_STEAM" ]]; then
	echo '######### install Steam'
	STEAM_BUILDS='https://repo.steampowered.com/steam'
#	addPgpKey 'steam.gpg' "$STEAM_BUILDS/archive/stable/steam.gpg"
	addPgpKey 'steam.gpg' "$STEAM_BUILDS/archive/precise/steam.gpg"
	cat <<- EOT > $SOURCES_DIR/steam.list
		deb     [signed-by=$KEY_RING_DIR/steam.gpg] $STEAM_BUILDS stable steam
		deb-src [signed-by=$KEY_RING_DIR/steam.gpg] $STEAM_BUILDS stable steam
	EOT

	apt update
#  apt install libgl1-mesa-dri libgl1-mesa-dri:i386
#  apt install libgl1-mesa-glx libgl1-mesa-glx:i386
	apt install steam
	# apt install  steam-launcher

	usermod -aG video,audio $SUDO_USER
	apt autoremove
	echo
	echo "run steam and enable 'Steam Play' and 'Proton'"
fi

#####################################################################
#####################################################################
######### Lutris
if [[ ! -z "$DO_LUTRIS" ]]; then
	echo '######### install Lutris'
	LUTRIS_URL='https://download.opensuse.org/repositories/home:/strycore/Debian_Testing'
	addPgpKey 'lutris.gpg' "$LUTRIS_URL/Release.key"
	echo "deb [signed-by=$KEY_RING_DIR/lutris.gpg] $LUTRIS_URL/ ./" > $SOURCES_DIR/lutris.list
	apt update
	apt install lutris
	apt install gamemode

	find /usr -iname 'libgamemode*'
	LUTRIS_PRE=$(find /usr -iname 'libgamemode*' | grep auto | head -1)
	echo
	echo "add to Lutris preferences and try other if not working (I don't know if needed)"
	echo "LD_PRELOAD    = $LUTRIS_PRE"
	echo "mesa_glthread = true"

#	wget https://cdn.discordapp.com/attachments/538903130704838656/796102070825779250/dxvk_versions.json -P $HOME/.local/share/lutris/runtime/dxvk
fi

#####################################################################
#####################################################################
######### dxvk is a Vulkan-based compatibility layer for Direct3D 11
if [[ ! -z "$DO_DXVK" ]]; then
	echo '######### install DXVK'
	apt install dxvk/sid
fi

#####################################################################
#####################################################################
######### Microsoft .Net 4.6.1
if [[ ! -z "$DO_DOT_NET" ]]; then
	echo '######### install .Net'
	apt install winetricks
	env WINEPREFIX=winedotnet wineboot --init
	env WINEPREFIX=winedotnet winetricks dotnet461 corefonts
fi

#####################################################################
#####################################################################
######### MultiMC
# https://multimc.org
if [[ ! -z "$DO_MULTI_MC" ]]; then
	echo '######### install Minecraft MultiMC'

	#apt install qt5-default
	apt install libqt5xml5

	MULTIMC_URL='https://multimc.org'
	MULTIMC_REL='1.5-1'
	MULTIMC_DEF="multimc_$MULTIMC_REL.deb"
	MULTIMC_SRC='multimc_*.deb'
	MULTIMC_DRV=$(downloadDriver $MULTIMC_URL $MULTIMC_URL/download/$MULTIMC_DEF $MULTIMC_SRC)

	dpkg --force-depends -i $MULTIMC_DRV
	#apt install multimc
fi

#####################################################################
#####################################################################
if [[ ! -z "$DO_TEST" ]]; then
	echo 'nothing here for now'

fi
