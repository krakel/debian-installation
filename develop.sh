#!/bin/bash

function helpMsg() {
  echo 'Usage:
  sudo install [commands]*

Commands:
  help      this help
  test      only script tests

  java      java 8+14 jdk
  scala     scala 2
  dotty     scala 3
  sbt       scala sbt
  coursier  scala Artifact Fetching

  atom      Atom IDE
  cuda      CudaText editor (little bit unusable)
  sub       Sublime editor (better, need license)'
}

declare -A SELECT=(
	[atom]=DO_ATOM
	[cuda]=DO_CUDA_TEXT
	[coursier]=DO_COURSIER
	[dotty]=DO_DOTTY
	[java]=DO_JAVA
	[sbt]=DO_SBT
	[scala]=DO_SCALA
	[sub]=DO_SUBLIME
	[test]=DO_TEST
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

cd $HOME_USER

if [[ $(id -u) != 0 ]]; then
	 echo
	 echo 'Ups, I am not root!'
	 exit 1
fi

#####################################################################
## some functions
#####################################################################
function listFile() {
	ls -t Downloads/$1 2>/dev/null | head -1
}

# downloadDriver download-url default-url search-mask dst-name
function downloadDriver() {
	if [[ ! -z "$4" ]]; then
		rm -f Downloads/$4
	fi
	local searchObj=$(listFile $3)
	if [[ ! -z "$2" ]] && [[ ! -f "$searchObj" ]]; then
		if [[ -z "$4" ]]; then
			sudo -u $SUDO_USER wget -P Downloads $2
		else
			sudo -u $SUDO_USER wget -P Downloads $2 -c $4
		fi
		searchObj=$(listFile $3)
	fi
	if [[ ! -z "$1" ]] && [[ ! -f "$searchObj" ]]; then
		sudo -u $SUDO_USER bash -c "DISPLAY=:0.0 x-www-browser $1"
		read -p "Press [Enter] key to continue if you finished the download of the latest driver to '~/Downloads/'"
		searchObj=$(listFile $3)
	fi
	if [[ ! -f "$searchObj" ]]; then
		echo 'missing driver!'
		exit 1
	fi
	echo $searchObj
}

function createDesktopEntry() {
	local entryName=$1
	shift

	cat $@ | sudo -u $SUDO_USER tee "Desktop/$entryName" > /dev/null
	chmod +x "Desktop/$entryName"
	cp "Desktop/$entryName" /usr/share/applications/
	chmod 644 /usr/share/applications/$entryName
}

function addPgpKey() {
	local gpgFile=$1
	local gpgServer=$2
	local gpgKey=$3

	if [[ -z "$gpgServer" ]]; then 			# old version
		wget -nv $gpgFile -O - | apt-key add -
	elif [[ -z "$gpgKey" ]]; then 			# new version
		wget -nv $gpgServer -O - | gpg --no-default-keyring --keyring /tmp/$gpgFile --import
		gpg --export --keyring /tmp/$gpgFile > /etc/apt/trusted.gpg.d/$gpgFile
	else 												# use a key server
		gpg --no-default-keyring --keyring /tmp/$gpgFile --keyserver $gpgServer --recv-keys $gpgKey
#		gpg --ignore-time-conflict --no-options --no-default-keyring --secret-keyring /tmp/tmp.rh1myoBdSE --trustdb-name /etc/apt/trustdb.gpg --keyring /etc/apt/trusted.gpg --primary-keyring /etc/apt/trusted.gpg --keyserver keyserver.ubuntu.com --recv 7F0CEB10
		gpg --export --keyring /tmp/$gpgFile > /etc/apt/trusted.gpg.d/$gpgFile
	fi
}

#####################################################################
#####################################################################
######### java
# sudo update-alternatives --config java
if [[ ! -z "$DO_JAVA" ]]; then
	echo '######### install java'
	apt install default-jre
	apt install default-jdk

	apt install openjdk-15-jdk
	apt install openjdk-8-jdk

	# https://www.oracle.com/java/technologies/javase-jdk8-downloads.html
	# apt install oracle-java8-installer

	JFROG_BUILDS='https://adoptopenjdk.jfrog.io/adoptopenjdk'
	addPgpKey 'jfrog.gpg' "$JFROG_BUILDS/api/gpg/key/public"
	echo "deb $JFROG_BUILDS/deb/ buster main" > $SOURCES_DIR/jfrog.list
	apt update

	apt install "adoptopenjdk-15-hotspot"
	apt install "adoptopenjdk-8-hotspot"
#  apt install "adoptopenjdk-8-hotspot-jre"
#  apt install" adoptopenjdk-8-openj9-jre"
fi

#####################################################################
#####################################################################
######### scala 2
if [[ ! -z "$DO_SCALA" ]]; then
	echo '######### install scala 2'

	SCALA_URL='https://www.scala-lang.org/download/'
	SCALA_GET='https://downloads.lightbend.com/scala'
	SCALA_REL='2.13.4'
	SCALA_DEF="scala-$SCALA_REL.tgz"
	SCALA_SRC='scala-*.tgz'
	SCALA_DRV=$(downloadDriver $SCALA_URL $SCALA_GET/$SCALA_REL/$SCALA_DEF $SCALA_SRC)

	SCALA_DIR='/usr/lib/scala'
	SCALA_FLR=$(basename $SCALA_DRV .tgz)
	SCALA_PRI=${SCALA_FLR#scala-}
	SCALA_PRI=${SCALA_PRI//.}

	mkdir -p $SCALA_DIR
	rm -rf $SCALA_DIR/$SCALA_FLR

	tar -xvzf $SCALA_DRV --directory $SCALA_DIR

	update-alternatives --install /usr/bin/scala  scala  "$SCALA_DIR/$SCALA_FLR/bin/scala"  $SCALA_PRI
	update-alternatives --install /usr/bin/scalac scalac "$SCALA_DIR/$SCALA_FLR/bin/scalac" $SCALA_PRI
	update-alternatives --install /usr/bin/scalad scalad "$SCALA_DIR/$SCALA_FLR/bin/scalad" $SCALA_PRI
fi

#####################################################################
#####################################################################
######### scala 3
if [[ ! -z "$DO_DOTTY" ]]; then
	echo '######### install scala 3'

	DOTTY_URL='https://github.com/lampepfl/dotty/releases'
	DOTTY_REL='3.0.0-M3'
	DOTTY_DEF="scala3-$DOTTY_REL.zip"
	DOTTY_SRC='scala3-*.zip'
	DOTTY_DRV=$(downloadDriver $DOTTY_URL $DOTTY_URL/download/$DOTTY_REL/$DOTTY_DEF $DOTTY_SRC)

	DOTTY_DIR='/usr/lib/scala'
	DOTTY_FLR=$(basename $DOTTY_DRV .zip)
	DOTTY_PRI=${DOTTY_FLR#scala3-}
	DOTTY_PRI=${DOTTY_PRI//[!0-9]}

	mkdir -p $DOTTY_DIR
	rm -rf $DOTTY_DIR/$DOTTY_FLR

	unzip $DOTTY_DRV -d $DOTTY_DIR

	update-alternatives --install /usr/bin/scala  scala  "$DOTTY_DIR/$DOTTY_FLR/bin/scala"  $DOTTY_PRI
	update-alternatives --install /usr/bin/scalac scalac "$DOTTY_DIR/$DOTTY_FLR/bin/scalac" $DOTTY_PRI
	update-alternatives --install /usr/bin/scalad scalad "$DOTTY_DIR/$DOTTY_FLR/bin/scalad" $DOTTY_PRI
fi

#####################################################################
#####################################################################
######### scala sbt
if [[ ! -z "$DO_SBT" ]]; then
	echo '######### install sbt'

	addPgpKey 'sbt.gpg' 'https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x2EE0EA64E40A89B84B2DF73499E82A75642AC823'
	echo 'deb https://dl.bintray.com/sbt/debian /' > $SOURCES_DIR/sbt.list

	sudo apt-get update
	sudo apt-get install sbt
fi

#####################################################################
#####################################################################
######### scala coursier
if [[ ! -z "$DO_COURSIER" ]]; then
	echo '######### install scala coursier'

	# https://github.com/coursier/coursier/releases/download/v2.0.8/coursier
	COURSIER_URL='https://github.com/coursier/coursier/releases/download'
	COURSIER_REL='v2.0.8'
	COURSIER_DEF="coursier"
	COURSIER_BIN="Downloads/${COURSIER_DEF}_${COURSIER_REL}"
	METALS_REL='0.9.8'

	sudo -u $SUDO_USER wget "$COURSIER_URL/$COURSIER_REL/$COURSIER_DEF" -O $COURSIER_BIN

	chmod +x $COURSIER_BIN
	$COURSIER_BIN bootstrap \
		--java-opt -Xss4m \
		--java-opt -Xms100m \
		--java-opt -Dmetals.client=sublime \
		org.scalameta:metals_2.12:$METALS_REL \
		-r bintray:scalacenter/releases \
		-r sonatype:snapshots \
		-o /usr/local/bin/metals-sublime -f
fi

#####################################################################
#####################################################################
######### Atom
# https://linuxhint.com/install_atom_text_editor_debian_10/
if [[ ! -z "$DO_ATOM" ]]; then
	echo '######### install Atom IDE'
	ATOM_URL='https://github.com/atom/atom/releases'
	ATOM_REL='1.51.0'
	ATOM_DEF='atom-amd64.deb'
	ATOM_SRC='atom-*.deb'
	ATOM_DRV=$(downloadDriver $ATOM_URL $ATOM_URL/download/v$ATOM_REL/$ATOM_DEF $ATOM_SRC)

	apt install gvfs-bin
	dpkg -i $ATOM_DRV

	atom --version
fi

#####################################################################
#####################################################################
######### nice text editor
# http://uvviewsoft.com/cudatext/
if [[ ! -z "$DO_CUDA_TEXT" ]]; then
	echo '######### install CudaText editor'
	CUDA_URL='https://www.fosshub.com/CudaText.html'
	CUDA_DEF='cudatext_1.98.0.0-1_gtk2_amd64.deb'
	CUDA_SRC='cudatext_*_gtk2_amd64.deb'
	CUDA_DEB=$(downloadDriver $CUDA_URL '' $CUDA_SRC)

	echo "execute 'sudo dpkg -i $CUDA_DEB'"
	dpkg -i $CUDA_DEB

	createDesktopEntry "cudatext.desktop" <<- EOT
		[Desktop Entry]
		Version=1.0
		Name=Cuda Text
		Comment=a cross-platform text editor
		Exec=cudatext
		Icon=cudatext-512.png
		Terminal=false
		Type=Application
		Categories=Utility;Application;Editor;
		StartupNotify=true
	EOT

	PHYLIB=$(find /usr -name 'libpython3.*so*' 2>/dev/null | head -1)

	CUDA_SETTING='.config/cudatext/settings'
	sudo -u $SUDO_USER mkdir -p "$CUDA_SETTING"

	cat <<- 'EOT' | sudo -u $SUDO_USER tee "$CUDA_SETTING/user.json" > /dev/null
		{
		  "auto_close_brackets": "([{\"'",
		  "font_name__linux": "Monospace",
		  "font_size__linux": 10,
		  "indent_size": 2,
		  "numbers_show": false,
		  "pylib__linux": "$(basename $PHYLIB)",
		  "saving_force_final_eol": true,
		  "saving_trim_spaces": true,
		  "tab_size": 4,
		  "ui_one_instance": true,
		  "ui_reopen_session": false,
		  "ui_sidebar_show": false,
		  "ui_theme": "ebony",
		  "ui_theme_syntax": "ebony",
		  "ui_toolbar_show": true,
		}
	EOT

	find /usr -name 'libpython3.*so*' 2>/dev/null
	echo
	echo "at <options>..<Settings - user> change entry 'pylib__linux' and try other if not working"
	echo "\"pylib__linux\" : \"$(basename $PHYLIB)\""
	echo
	echo "install with <Plugins><Addon Manager> 'Highlight Occurrences' if you want"
fi

#####################################################################
#####################################################################
######### better text editor
# https://www.sublimetext.com/
if [[ ! -z "$DO_SUBLIME" ]]; then
	echo '######### install Sublime editor'

	addPgpKey 'sublime.gpg' 'https://download.sublimetext.com/sublimehq-pub.gpg'
	echo 'deb https://download.sublimetext.com/ apt/stable/' > $SOURCES_DIR/sublime.list
	apt update

	apt install sublime-text

	ln -s /opt/sublime_text/sublime_text /usr/bin/sublime_text

	createDesktopEntry "sublime.desktop" <<- EOT
		[Desktop Entry]
		Version=1.0
		Name=Sublime
		Comment=a cross-platform text editor
		Exec=/opt/sublime_text/sublime_text %F
		Icon=sublime-text.png
		Terminal=false
		Type=Application
		Categories=Utility;Application;Editor;
		StartupNotify=true
	EOT

	if [[ -d "Downloads/sublime/User" ]]; then
		CONFIG_SUBLIME="~/.config/sublime-text-3/Packages/User/"
		sudo -u $SUDO_USER mkdir -p $CONFIG_SUBLIME
		sudo -u $SUDO_USER cp -r Downloads/sublime/User/* $CONFIG_SUBLIME
	fi
fi

#####################################################################
#####################################################################
if [[ ! -z "$DO_TEST" ]]; then
	echo 'nothing here for now'

fi
