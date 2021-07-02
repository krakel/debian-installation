#!/bin/bash

function helpMsg() {
  echo 'Usage:
  sudo install [commands]*

Commands:
  help      this help
  test      only script tests

  java      Java 8+15 openjdk + adoptopenjdk
  lean      Lean is a theorem prover and programming language.
  scala     Scala 2
  dotty     Scala 3
  ruby      Ruby + jekyll

  bloop     build server for scala
  coursier  scala Artifact Fetching
  dotnet    .NET for Linux
  metals    scala language server
  sbt       scala sbt

  atom      Atom IDE
  cuda      CudaText editor (little bit unusable)
  sub       Sublime editor (better, need license)'
}

declare -A SELECT=(
	[atom]=DO_ATOM
	[bloop]=DO_BLOOP
	[coursier]=DO_COURSIER
	[cuda]=DO_CUDA_TEXT
	[dotnet]=DO_DOTNET
	[dotty]=DO_DOTTY
	[java]=DO_JAVA
	[lean]=DO_LEAN
	[metals]=DO_METALS
	[ruby]=DO_RUBY
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
KEY_RING_DIR='/usr/share/keyrings'

cd $HOME_USER

if [[ $(id -u) != 0 ]]; then
	 echo
	 echo 'Ups, I am not root!'
	 exit 1
fi

#####################################################################
## some functions
#####################################################################

# insertPathFkts file
function insertPathFkts() {
	if ! grep -F -q 'path_add()' $1 ; then
		cat <<- 'EOT' | sudo -u $SUDO_USER tee -a $1 > /dev/null

			path_add() {
			  NEW_ELEMENT=${1%/}
			  if [ -d "$1" ] && ! echo $PATH | grep -E -q "(^|:)$NEW_ELEMENT(:|$)" ; then
			    if [ "$2" = "after" ] ; then
			      PATH="$PATH:$NEW_ELEMENT"
			    else
			      PATH="$NEW_ELEMENT:$PATH"
			    fi
			  fi
			}

			path_rm() {
			  PATH="$(echo $PATH | sed -e 's;\(^\|:\)${1%/}\(:\|\$\);\1\2;g' -e 's;^:\|:$;;g' -e 's;::;:;g')"
			}
		EOT
		# dont forget 'export PATH'
	fi
}

# addBinToPath file path <after>
function addBinToPath() {
	insertPathFkts $1
	local addPathStr="path_add '$2'"

	if ! grep -F -q "$addPathStr" $1 ; then
		echo "add '$2' to '$1'"
		cat <<- EOT | sudo -u $SUDO_USER tee -a $1 > /dev/null

			$addPathStr $3
			export PATH
		EOT
	else
		echo "'$1' already contain '$addPathStr'!"
	fi
}

# addExportEnv file env value
function addExportEnv() {
	insertPathFkts $1
	local exportStr="export $2=\"$3\""

	if ! grep -F -q "$exportStr" $1 ; then
		echo "add '$exportStr' to '$1'"
		cat <<- EOT | sudo -u $SUDO_USER tee -a $1 > /dev/null

			$exportStr
		EOT
	else
		echo "'$1' already contain '$exportStr'!"
	fi
}

function listFile() {
	ls -t $HOME_USER/$1 2>/dev/null | head -1
}

# downloadDriver download-url default-url search-mask dst-dir dst-name
function downloadDriver() {
	if [[ -z "$4" ]]; then
		local dst='Downloads'
	else
		local dst="Downloads/$4"
	fi
	if [[ ! -z "$5" ]]; then
		rm -f $HOME_USER/$dst/$5
	fi
	local searchObj=$(listFile $dst/$3)
	if [[ ! -z "$2" ]] && [[ ! -f "$searchObj" ]]; then
		if [[ -z "$5" ]]; then
			sudo -u $SUDO_USER wget -P $dst $2
		else
			sudo -u $SUDO_USER wget -c $dst/$5 $2
		fi
		searchObj=$(listFile $dst/$3)
	fi
	if [[ ! -z "$1" ]] && [[ ! -f "$searchObj" ]]; then
		sudo -u $SUDO_USER bash -c "DISPLAY=:0.0 x-www-browser $1"
		read -p "Press [Enter] key to continue if you finished the download of the latest driver to '~/$dst/'"
		searchObj=$(listFile $dst/$3)
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
		wget -nv $gpgServer -O - | gpg --no-default-keyring --keyring temp-keyring.gpg --import
		gpg --no-default-keyring --keyring temp-keyring.gpg --export --output $KEY_RING_DIR/$gpgFile
		rm temp-keyring.gpg
		#wget -nv $gpgServer -O - | gpg --no-default-keyring --keyring $KEY_RING_DIR/$gpgFile --import
		#gpg --no-default-keyring --keyring $KEY_RING_DIRp/$gpgFile --export > /etc/apt/trusted.gpg.d/$gpgFile
	else 												# use a key server
		gpg --no-default-keyring --keyring $KEY_RING_DIR/$gpgFile --keyserver $gpgServer --recv-keys $gpgKey
#		gpg --ignore-time-conflict --no-options --no-default-keyring --secret-keyring /tmp/tmp.rh1myoBdSE --trustdb-name /etc/apt/trustdb.gpg --keyring /etc/apt/trusted.gpg --primary-keyring /etc/apt/trusted.gpg --keyserver keyserver.ubuntu.com --recv 7F0CEB10
		gpg --export --keyring $KEY_RING_DIR/$gpgFile > /etc/apt/trusted.gpg.d/$gpgFile
	fi
}

function getLatestRelease() {
	curl --silent "$1/latest" | sed -E 's|.*/tag/([^"]+).*|\1|'
}

function updateAlternatives() {
	local dir=$1
	local pack=$2
	local nr=$3
	update-alternatives --install /usr/bin/$pack $pack "$dir/bin/$pack" $nr
}

#####################################################################
#####################################################################
######### java
# update-alternatives --config java
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
	echo "deb [signed-by=$KEY_RING_DIR/jfrog.gpg] $JFROG_BUILDS/deb/ buster main" > $SOURCES_DIR/jfrog.list
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

	SCALA_URL0='https://github.com/scala/scala/releases'
	SCALA_REL=$(getLatestRelease $SCALA_URL0)
	SCALA_REL=${SCALA_REL:1}
#	SCALA_REL='2.13.5'
	echo $SCALA_REL

	SCALA_URL='https://www.scala-lang.org/download/'
	SCALA_GET='https://downloads.lightbend.com/scala'
	SCALA_DEF="scala-$SCALA_REL.tgz"
	SCALA_SRC='scala-*.tgz'

#	echo $SCALA_GET/$SCALA_REL/$SCALA_DEF
	SCALA_DRV=$(downloadDriver $SCALA_URL $SCALA_GET/$SCALA_REL/$SCALA_DEF $SCALA_SRC scala)

	SCALA_DIR='/usr/lib/scala'
	SCALA_FLR=$(basename $SCALA_DRV .tgz)
	SCALA_PRI=${SCALA_REL//[!0-9]}

	mkdir -p $SCALA_DIR
	if [[ ! -d "$SCALA_DIR/$SCALA_FLR" ]]; then
		tar -xvzf $SCALA_DRV --directory $SCALA_DIR

		updateAlternatives "$SCALA_DIR/$SCALA_FLR" scala    $SCALA_PRI
		updateAlternatives "$SCALA_DIR/$SCALA_FLR" scalac   $SCALA_PRI
		updateAlternatives "$SCALA_DIR/$SCALA_FLR" scaladoc $SCALA_PRI
	else
		echo "version '$SCALA_FLR' already installed"
	fi
fi

#####################################################################
#####################################################################
######### scala 3
if [[ ! -z "$DO_DOTTY" ]]; then
	echo '######### install scala 3'

	DOTTY_URL='https://github.com/lampepfl/dotty/releases'
	DOTTY_REL=$(getLatestRelease $DOTTY_URL)
#	DOTTY_REL='3.0.0-RC3'
	echo $DOTTY_REL

	DOTTY_DEF="scala3-$DOTTY_REL.zip"
	DOTTY_SRC='scala3-*.zip'
#	echo "downloadDriver $DOTTY_URL $DOTTY_URL/download/$DOTTY_REL/$DOTTY_DEF $DOTTY_DEF scala"
	DOTTY_DRV=$(downloadDriver $DOTTY_URL $DOTTY_URL/download/$DOTTY_REL/$DOTTY_DEF $DOTTY_DEF scala)

	DOTTY_DIR='/usr/lib/scala'
	DOTTY_FLR=$(basename $DOTTY_DRV .zip)
	DOTTY_PRI=${DOTTY_REL//[!0-9]}
	if (( DOTTY_PRI < 1000 )); then
		DOTTY_PRI="${DOTTY_PRI}9"
	fi

	mkdir -p $DOTTY_DIR
	if [[ ! -d "$DOTTY_DIR/$DOTTY_FLR" ]]; then
		unzip $DOTTY_DRV -d $DOTTY_DIR

		updateAlternatives "$DOTTY_DIR/$DOTTY_FLR" scala    $DOTTY_PRI
		updateAlternatives "$DOTTY_DIR/$DOTTY_FLR" scalac   $DOTTY_PRI
		updateAlternatives "$DOTTY_DIR/$DOTTY_FLR" scaladoc $DOTTY_PRI
	else
		echo "version '$DOTTY_FLR' already installed"
	fi
fi

#####################################################################
#####################################################################
######### scala sbt
if [[ ! -z "$DO_SBT" ]]; then
	echo '######### install sbt'

	addPgpKey 'sbt.gpg' 'https://keyserver.ubuntu.com/pks/lookup?op=get&search=0x2EE0EA64E40A89B84B2DF73499E82A75642AC823'
	echo "deb [signed-by=$KEY_RING_DIR/sbt.gpg] https://dl.bintray.com/sbt/debian /" > $SOURCES_DIR/sbt.list

	apt update
	apt install sbt
fi

#####################################################################
#####################################################################
######### scala coursier
# https://get-coursier.io/
# https://github.com/coursier/coursier
if [[ ! -z "$DO_COURSIER" ]]; then
	echo '######### install scala coursier'

	COURSIER_URL='https://github.com/coursier/coursier/releases'
	COURSIER_REL=$(getLatestRelease $COURSIER_URL)
	COURSIER_BIN="Downloads/scala/coursier_${COURSIER_REL}"
	COURSIER_DST="$HOME_USER/.local/share/coursier"
	COURSIER_CMD="$COURSIER_DST/bin/coursier"

	if [[ -f "$COURSIER_CMD" ]]; then
		sudo -u $SUDO_USER $COURSIER_CMD update coursier
	else
		sudo -u $SUDO_USER wget "$COURSIER_URL/download/$COURSIER_REL/coursier" -O $COURSIER_BIN;
		chmod +x $COURSIER_BIN;
		sudo -u $SUDO_USER $COURSIER_BIN install coursier
		sudo -u $SUDO_USER $COURSIER_BIN install cs
		addBinToPath '.profile' "$COURSIER_DST/bin" after
	fi
fi

#####################################################################
#####################################################################
######### scala metals
if [[ ! -z "$DO_METALS" ]]; then
	echo '######### install scala metals server'

	METALS_URL='https://github.com/scalameta/metals/releases'
	METALS_REL=$(getLatestRelease $METALS_URL)
	METALS_REL=${METALS_REL:1}
	#coursier bootstrap \
	#	--java-opt -Xss4m \
	#	--java-opt -Xms100m \
	#	--java-opt -Dmetals.client=sublime \
	#	org.scalameta:metals_2.12:$METALS_REL \
	#	-r bintray:scalacenter/releases \
	#	-r sonatype:snapshots \
	#	-o /usr/local/bin/metals-sublime -f
fi

#####################################################################
#####################################################################
######### scala bloop
if [[ ! -z "$DO_BLOOP" ]]; then
	echo '######### install scala bloop server'

	COURSIER_DST="$HOME_USER/.local/share/coursier"
	COURSIER_CMD="$COURSIER_DST/bin/coursier"

	if [[ ! -f "$COURSIER_CMD" ]]; then
		echo "missing coursier!!!"
		exit 1
	fi

	if $COURSIER_CMD list | grep bloop; then
		sudo -u $SUDO_USER $COURSIER_CMD update bloop
	else
		sudo -u $SUDO_USER $COURSIER_CMD install bloop
	fi

	sudo -u $SUDO_USER mkdir -p "$COURSIER_DST/sysetmd"
	BLOOP_SRV="$COURSIER_DST/sysetmd/bloop.service"

	if sudo -u $SUDO_USER systemctl is-active bloop ; then
		sudo -u $SUDO_USER systemctl --user stop bloop
		sudo -u $SUDO_USER systemctl --user disable $BLOOP_SRV
	fi

	if [[ ! -f "$BLOOP_SRV" ]]; then
		cat <<- EOT | sudo -u $SUDO_USER tee $BLOOP_SRV > /dev/null
			[Unit]
			Description=Bloop Scala build server

			[Service]
			ExecStart=$COURSIER_DST/bin/bloop server
			StandardOutput=journal
			StandardError=journal
			SyslogIdentifier=bloop

			[Install]
			WantedBy=default.target
		EOT
	fi

	sudo -u $SUDO_USER systemctl --user enable $BLOOP_SRV
	sudo -u $SUDO_USER systemctl --user start bloop
fi

#####################################################################
#####################################################################
######### lean
# https://leanprover-community.github.io
if [[ ! -z "$DO_LEAN" ]]; then
	LEAN_URL='https://raw.githubusercontent.com/leanprover-community/mathlib-tools/master/scripts'
	LEAN_BIN='install_debian.sh'

	apt install git curl python3 python3-pip python3-venv
	# The following test is needed in case VScode was installed by other
	# means (e.g. using Ubuntu snap)
	if ! which code; then
		echo "VScode not installed!!!"
		exit 1
	fi
	code --install-extension jroesch.lean

	sudo -u $SUDO_USER wget https://raw.githubusercontent.com/Kha/elan/master/elan-init.sh
	sudo -u $SUDO_USER bash elan-init.sh -y
	rm elan-init.sh
	python3 -m pip install --user pipx
	python3 -m pipx ensurepath
	. ~/.profile
	pipx install mathlibtools
fi

#####################################################################
#####################################################################
######### ruby
if [[ ! -z "$DO_RUBY" ]]; then
	echo '######### install ruby'

	apt install ruby-full build-essential zlib1g-dev

	RUBY_GEM="$HOME_USER/.local/share/gem"

	addExportEnv '.profile' 'GEM_HOME' $RUBY_GEM
	addBinToPath '.profile' "$RUBY_GEM/bin" after

	. ~/.profile
	sudo -u $SUDO_USER gem install jekyll bundler
fi

#####################################################################
#####################################################################
######### dotnet
if [[ ! -z "$DO_DOTNET" ]]; then
	echo '######### install dotnet'

	DOTNET_URL='https://packages.microsoft.com/config/debian'
	DOTNET_DEF="packages-microsoft-prod.deb"
	DOTNET_DRV=$(downloadDriver $DOTNET_URL $DOTNET_URL/10/$DOTNET_DEF)

	dpkg -i $DOTNET_DRV
	apt install dotnet-sdk-5.0

#	apt install aspnetcore-runtime-5.0
#	apt install dotnet-runtime-5.0
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
	echo "deb [signed-by=$KEY_RING_DIR/sublime.gpg] https://download.sublimetext.com/ apt/stable/" > $SOURCES_DIR/sublime.list
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
