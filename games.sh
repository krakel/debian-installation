#!/bin/bash

function helpMsg() {
  echo 'Usage:
  sudo games [commands]*

Commands:
  help      this help
  test      only script tests

  amdvlk    AMDVLK
  wine      Wine
  steam     Steam
  lutris    Lutris
  dxvk      vulkan-based compatibility layer for Direct3D
  dnet      Microsoft .Net 4.6.1 (do not use)
  multimc   Minecraft MultiMC'
  obs       OBS Studio
}

declare -A SELECT=(
	[amdvlk]=DO_AMD_VLK
	[dnet]=DO_DOT_NET
	[dxvk]=DO_DXVK
	[lutris]=DO_LUTRIS
	[multimc]=DO_MULTI_MC
	[obs]=DO_OBS
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
######### AMDVLK
if [[ ! -z "$DO_AMD_VLK" ]]; then
	echo '######### install AMDVLK'

	# sudo wget -qO - http://repo.radeon.com/amdvlk/apt/debian/amdvlk.gpg.key | sudo apt-key add -
	# sudo sh -c 'echo deb [arch=amd64,i386] http://repo.radeon.com/amdvlk/apt/debian/ bionic main > /etc/apt/sources.list.d/amdvlk.list'
	AMDVLK_BUILDS='https://repo.radeon.com/amdvlk/apt/debian'
	addPgpKey 'amdvlk.gpg' "$AMDVLK_BUILDS/amdvlk.gpg.key"
	echo "deb [signed-by=$KEY_RING_DIR/amdvlk.gpg] $AMDVLK_BUILDS/ bionic main" > $SOURCES_DIR/amdvlk.list
	apt update

fi

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
#	addPgpKey 'steam.gpg' "/archive/stable/steam.gpg"
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
if [[ ! -z "$DO_OBS" ]]; then
	echo '######### install OBS Studio'

	MULTIMEDIA_URL='https://www.deb-multimedia.org'
	MULTIMEDIA_REL='2016.8.1_all'
	MULTIMEDIA_DEF="deb-multimedia-keyring_$MULTIMEDIA_REL.deb"
	MULTIMEDIA_SRC='deb-multimedia-keyring_*.deb'
	MULTIMEDIA_DRV=$(downloadDriver $MULTIMEDIA_URL $MULTIMEDIA_URL/pool/main/d/deb-multimedia-keyring/$MULTIMEDIA_DEF $MULTIMEDIA_SRC)

	dpkg -i $MULTIMEDIA_DRV

	echo <<- EOT > $SOURCES_DIR/deb-multimedia.list
		deb $MULTIMEDIA_URL testing main non-free
		#deb $MULTIMEDIA_URL testing-backports main
	EOT

	apt update
	apt upgade
	apt upgrade -t testing

	#apt install build-essential ccache clang clang-format cmake cmake-curses-gui curl fdkaac
  #apt install fonts-roboto git glslang-dev glslang-tools glslc libasio-dev libasound2-dev libavcodec-dev libavdevice-dev
  #apt install libavfilter-dev libavformat-dev libavutil-dev libcmocka-dev libcurl4-openssl-dev libdrm-dev libfdk-aac-dev
  #apt install libfontconfig-dev libfreetype6-dev libgl1-mesa-dev libgles2-mesa libgles2-mesa-dev libglu1-mesa-dev
  #apt install libglvnd-dev libjack-jackd2-dev libjansson-dev libluajit-5.1-dev libmbedtls-dev libpci-dev libpulse-dev
  #apt install libqrcodegencpp-dev libqt6svg6-dev librist-dev libshaderc-dev libsndio-dev libspeexdsp-dev
  #apt install libsrt-openssl-dev libswresample-dev libswscale-dev libudev-dev libv4l-dev libva-dev libvlc-dev libvpl-dev
  #apt install libwayland-dev libwebsocketpp-dev libx11-dev libx11-xcb-dev libx264-dev libxaw7-dev libxcb1-dev
  #apt install libxcb-composite0-dev libxcb-icccm4-dev libxcb-keysyms1-dev libxcb-randr0-dev libxcb-shm0-dev
  #apt install libxcb-util-dev libxcb-xfixes0-dev libxcb-xinerama0-dev libxcb-xinput-dev libxcb-xkb-dev libxcb-xtest0-dev
  #apt install libxcomposite-dev libxinerama-dev libxkbcommon-x11-dev libxkbfile-dev libxres-dev libxss-dev libxtst-dev
  #apt install libxv-dev ninja-build nlohmann-json3-dev pkg-config python3-dev qt6-base-dev qt6-base-private-dev
  #apt install qt6-image-formats-plugins qt6-wayland swig

  apt install ccache clang clang-format cmake cmake-curses-gui fdkaac
  apt install glslang-dev glslang-tools glslc
  apt install libasio-dev libasound2-dev libavcodec-dev libavdevice-dev
  apt install libavfilter-dev libavformat-dev libavutil-dev libcmocka-dev libcurl4-openssl-dev libdrm-dev libfdk-aac-dev
  apt install libfontconfig-dev libfreetype-dev libgl1-mesa-dev libgles2-mesa-dev libglu1-mesa-dev
  apt install libglvnd-dev libjack-jackd2-dev libjansson-dev libluajit-5.1-dev libmbedtls-dev libpci-dev libpulse-dev
  apt install libqrcodegencpp-dev libqt6svg6-dev librist-dev libshaderc-dev libsndio-dev libspeexdsp-dev
  apt install libsrt-openssl-dev libswresample-dev libswscale-dev libudev-dev libv4l-dev libva-dev libvlc-dev libvpl-dev
  apt install libwayland-dev libwebsocketpp-dev libx11-dev libx11-xcb-dev libx264-dev libxaw7-dev libxcb1-dev
  apt install libxcb-composite0-dev libxcb-icccm4-dev libxcb-keysyms1-dev libxcb-randr0-dev libxcb-shm0-dev
  apt install libxcb-util-dev libxcb-xfixes0-dev libxcb-xinerama0-dev libxcb-xinput-dev libxcb-xkb-dev libxcb-xtest0-dev
  apt install libxcomposite-dev libxinerama-dev libxkbcommon-x11-dev libxkbfile-dev libxres-dev libxss-dev libxtst-dev
  apt install libssl-dev libxv-dev nlohmann-json3-dev
  apt install ninja-build pkg-config python3-dev qt6-base-dev qt6-base-private-dev
  apt install qt6-image-formats-plugins qt6-wayland swig

  sudo -u $SUDO_USER wget -P Downloads/linux https://cdn-fastly.obsproject.com/downloads/cef_binary_5060_linux64.tar.bz2
  sudo -u $SUDO_USER tar xf Downloads/linux/cef_binary_5060_linux64.tar.bz2

	cd git

	sudo -u $SUDO_USER git clone --recursive https://github.com/paullouisageneau/libdatachannel
	cd libdatachannel
	sudo -u $SUDO_USER rm -rf build
	sudo -u $SUDO_USER cmake -B build -DUSE_GNUTLS=0 -DUSE_NICE=0 -DCMAKE_BUILD_TYPE=Release
	cd build/
	sudo -u $SUDO_USER make -j$(nproc)
	sudo -u $SUDO_USER make install

	cd $HOME_USER/git
	sudo -u $SUDO_USER git clone --recursive https://github.com/obsproject/obs-studio
	cd obs-studio
	sudo -u $SUDO_USER rm -rf build

	git branch -a
	git tag -l | sort -V

	#sudo -u $SUDO_USER git checkout master
	sudo -u $SUDO_USER git checkout 30.0.2
	#sudo -u $SUDO_USER git checkout 29.1.3

git reset --hard HEAD
git clean -f -f
git pull
git submodule init
git submodule update

	sudo -u $SUDO_USER cmake -S . -B build -G Ninja -DENABLE_PIPEWIRE=0 -DENABLE_BROWSER=1 -DLINUX_PORTABLE=0 -DENABLE_DECKLINK=0 \
	  -DENABLE_JACK=1 -DENABLE_SERVICE_UPDATES=0 -DCEF_ROOT_DIR="$HOME_USER/Downloads/linux/cef_binary_5060_linux64" \
	  -DBUILD_FOR_DISTRIBUTION=1 -DENABLE_ALSA=1 -DENABLE_LIBFDK=1 -DENABLE_PULSEAUDIO=0 \
	  -DCMAKE_INSTALL_PREFIX=/usr -DENABLE_SNDIO=0 -DENABLE_WEBRTC=1 -DOAUTH_BASE_URL="http://127.0.0.1" \
	  -DCALM_DEPRECATION=ON -DX11_Xaw_INCLUDE_PATH="/usr/include/X11/Xaw" -DENABLE_AJA=1

	sudo -u $SUDO_USER ccmake -S . -B build -G Ninja -DENABLE_PIPEWIRE=0 -DENABLE_BROWSER=1 -DLINUX_PORTABLE=0 -DENABLE_DECKLINK=0 \
	  -DENABLE_JACK=1 -DENABLE_SERVICE_UPDATES=0 -DCEF_ROOT_DIR="$HOME_USER/Downloads/linux/cef_binary_5060_linux64" \
	  -DBUILD_FOR_DISTRIBUTION=1 -DENABLE_ALSA=1 -DENABLE_LIBFDK=1 -DENABLE_PULSEAUDIO=0 \
	  -DCMAKE_INSTALL_PREFIX=/usr -DENABLE_SNDIO=0 -DENABLE_WEBRTC=1 -DOAUTH_BASE_URL="http://127.0.0.1" \
	  -DCALM_DEPRECATION=ON -DX11_Xaw_INCLUDE_PATH="/usr/include/X11/Xaw" -DENABLE_AJA=1

	# Then in ccmake, hit "c" twice to get options. Hit "t" for more pages of options. Hit "g" to generate.
	# Compile it thusly. Nice to have ccache setup as it takes a pretty "long" time to build.

	sudo -u $SUDO_USER cmake --build build -j$(nproc)
	sudo -u $SUDO_USER cmake --build build --target package -j$(nproc)

	ls -lh build/*.deb

	#dpkg -i build/obs-studio-29.1.3-50-Linux.deb
	#apt-mark hold obs-studio
	#apt -f install

fi

#####################################################################
#####################################################################
if [[ ! -z "$DO_TEST" ]]; then
	echo 'nothing here for now'

fi
