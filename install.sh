#!/bin/bash

# check before
# dmesg         # print or control the kernel ring buffer
# journalctl    # query the systemd journal

# lvm VG root vg

function helpMsg() {
	echo 'Usage:'
	echo 'install su'
	echo 'sudo install [commands]*'
	echo
	echo 'Sudo:     !!! run without sudo'
	echo 'su        only add user to sudo group'
	echo
	echo 'Commands:'
	echo 'help      this help'
	echo 'test      only script tests'
	echo
	echo 'src       debian testing (use this first)'
	echo 'visudo    some sudo cmd definitions'
	echo 'amd       amd/ati driver         (1 reboot)'
	echo 'nvidia    nvidia driver          (1 reboot)'
	echo 'nvidia2   nvidia driver official (1 reboot, 2 runs)'
	echo
	echo 'cifs      Access Windows Share'
	echo 'conky     lightweight free system monitor'
	echo 'ohmyz     ohmyz shell extension'
	echo 'samba     Samba Server, access from Windows (not used, I use only cifs)'
	echo 'snap      rsnapshot+rsync backups on local system'
	echo 'tools     xfce tools'
	echo
	echo 'kvm       KVM, QEMU with Virt-Manager (1 reboot)'
	echo 'iso       install a iso'
	echo 'virtual   VirtualBox with SID library (removed from debian testing)'
	echo 'anbox     Anbox, a Android Emulator (very alpha)'
	echo
	echo 'wine      Wine'
	echo 'steam     Steam'
	echo 'lutris    Lutris'
	echo 'dxvk      vulkan-based compatibility layer for Direct3D'
	echo 'dnet      Microsoft .Net 4.6.1 (do not use)'
	echo 'java      java 8+11 jdk'
	echo 'multimc   Minecraft MultiMC'
	echo
	echo 'discord   Discord'
	echo 'dream     Dreambox Edit'
	echo 'mozilla   Firefox + Thunderbird'
	echo 'spotify   Spotify, some music'
	echo 'twitch    twitch gui + VideoLan + Chatty'
	echo
	echo 'atom      Atom IDE'
	echo 'cuda      CudaText editor (little bit unusable)'
	echo 'sub       Sublime editor (better, need license)'
	echo
	echo 'gpic      GPicview image viewer'
	echo 'viewnior  Viewnior image viewer'
	echo
	echo 'login     Autologin'
	echo 'moka      nice icon set'
	echo 'pwsafe    Password Safe'
	echo 'screen    XScreensaver'
}

declare -A SELECT=(
	[anbox]=DO_ANBOX
	[amd]=DO_AMD
	[atom]=DO_ATOM
	[cifs]=DO_CIFS
	[conky]=DO_CONKY
	[cuda]=DO_CUDA_TEXT
	[discord]=DO_DISCORD
	[dnet]=DO_DOT_NET
	[dream]=DO_DREAMBOX_EDIT
	[dxvk]=DO_DXVK
	[gpic]=DO_GPIC
	[iso]=DO_ISO
	[java]=DO_JAVA
	[kvm]=DO_KVM
	[login]=DO_AUTO_LOGIN
	[lutris]=DO_LUTRIS
	[moka]=DO_MOKA
	[mozilla]=DO_MOZILLA
	[multimc]=DO_MULTI_MC
	[nvidia2]=DO_NVIDIA_OFFICAL
	[nvidia]=DO_NVIDIA
	[ohmyz]=DO_OHMYZ
	[pwsafe]=DO_PASSWORD_SAFE
	[samba]=DO_SAMBA
	[screen]=DO_SCREENSAVER
	[spotify]=DO_SPOTIFY
	[src]=DO_SOURCE
	[steam]=DO_STEAM
	[snap]=DO_SNAPSHOT
	[su]=ONLY_SUDOER
	[sub]=DO_SUBLIME
	[test]=DO_TEST
	[tools]=DO_TOOLS
	[twitch]=DO_TWITCH_GUI
	[viewnior]=DO_VIEWNIOR
	[virtual]=DO_VIRTUAL_BOX
	[visudo]=DO_VISUDO
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

 =/etc/apt/sources.list.d
SUDO_USER=$(logname)
HOME_USER=/home/$SUDO_USER
cd $HOME_USER

# I use the same name
WINDOWS_USER=$SUDO_USER     # change this to your windows user name
WINDOWS_DOMAIN='work.local'	# change this to your windows domain

# apt update      # refreshes repository index
# apt upgrade     # upgrades all upgradable packages
# apt autoremove  # removes unwanted packages
# apt install     # install a package
# apt remove      # remove a package
# apt search      # searche for a program
# apt install --fix-broken

function logoutNow() {
	echo
	echo -n 'You need to logout now!'
	read
	exit
}

if [[ ! -z "$ONLY_SUDOER" ]]; then
	echo "enter your root password to add $SUDO_USER to group sudo"
	su - root -c bash -c "/sbin/usermod -aG sudo $SUDO_USER"    # add to group sudo
	echo

	logoutNow
fi

if [[ $(id -u) != 0 ]]; then
	 echo
	 echo 'Ups, I am not root!'
	 exit 1
fi

#####################################################################
## some functions
#####################################################################
function continueNow() {
	echo
	echo -n "$1 (Y/n)!"
	read answer
	if [[ "$answer" != "${answer#[Nn]}" ]]; then
		exit 1
	fi
}

function breakNow() {
	echo
	echo -n "$1 (y/N)!"
	read answer
	if [[ "$answer" == "${answer#[Yy]}" ]]; then
		exit 1
	fi
}

function rebootNow() {
	continueNow 'You NEED to reboot now!'
	systemctl reboot
}

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

# addBinToPath file path
function addBinToPath() {
	insertPathFkts $1
	local addPathStr="path_add \"$2\""

	if ! grep -F -q "$addPathStr" $1 ; then
		echo "add '$2' to '$1'"
		cat <<- EOT | sudo -u $SUDO_USER tee -a $1 > /dev/null

		$addPathStr after
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

# installLib lib-name
function installLib() {
	ldconfig -p | grep -F "$1"
	if [[ "$?" != "0" ]]; then
		apt install $1
		apt autoremove
	fi
}

function listFile() {
	ls -t Downloads/$1 2>/dev/null | head -1
}

# downloadDriver download-url default-url search-mask dst-name
function downloadDriver() {
	if [[ ! -z "$4" ]]; then
		rm -f Downloads/$4
	fi
	local searchObj=$(listFile $3)
	if [[ ! -z "$1" ]] && [[ ! -f "$searchObj" ]]; then
		sudo -u $SUDO_USER bash -c "DISPLAY=:0.0 x-www-browser $1"
		read -p "Press [Enter] key to continue if you finished the download of the latest driver to '~/Downloads/'"
		searchObj=$(listFile $3)
	fi
	if [[ ! -z "$2" ]] && [[ ! -f "$searchObj" ]]; then
		if [[ -z "$4" ]]; then
			sudo -u $SUDO_USER wget -P Downloads $2
		else
			sudo -u $SUDO_USER wget -P Downloads $2 -c $4
		fi
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

function createSudoer() {
	local sudoerFile="/etc/sudoers.d/$1"
	shift

	cat $@ > $sudoerFile
	chmod 0440 $sudoerFile
	visudo -c
}

function addPgpKey() {
	if [[ -z "$2" ]]; then
		wget -nv $1 -O - | apt-key add -
	else
#		wget -nv $1 -O - | apt-key --keyring /etc/apt/trusted.gpg.d/$2 add -
		wget -nv $1 -O - | gpg --no-default-keyring --keyring /tmp/$2 --import
		gpg --keyring /tmp/$2 --export > /etc/apt/trusted.gpg.d/$2
	fi
}

#####################################################################
if [[ ! -z "$DO_SOURCE" ]]; then
	SOURCES='/etc/apt/sources.list'
	ORIGINAL='/etc/apt/sources.orig'
	TMPFILE='/tmp/sources.list'

	if [[ ! -f $SOURCES ]]; then
		echo "bad, missing file: $SOURCES"
		exit 1
	fi

	if [[ -f $TMPFILE ]]; then
		echo "delete old temp file: $TMPFILE"
		rm -f $TMPFILE
	fi

	echo "create new source file: $TMPFILE"
	touch $TMPFILE

	cat <<- EOT > $TMPFILE
	deb     http://deb.debian.org/debian               testing           main contrib non-free
	deb-src http://deb.debian.org/debian               testing           main contrib non-free

	deb     http://deb.debian.org/debian               testing-updates   main contrib non-free
	deb-src http://deb.debian.org/debian               testing-updates   main contrib non-free

	deb     http://security.debian.org/debian-security testing-security  main contrib non-free
	deb-src http://security.debian.org/debian-security testing-security  main contrib non-free

	deb     http://deb.debian.org/debian/              sid               main contrib non-free
	deb-src http://deb.debian.org/debian/              sid               main contrib non-free

	# do not use backports !
	# deb     http://deb.debian.org/debian/              testing-backports main contrib non-free
	# deb-src http://deb.debian.org/debian/              testing-backports main contrib non-free

	# deb     http://deb.debian.org/debian/              stable            main contrib non-free
	# deb-src http://deb.debian.org/debian/              stable            main contrib non-free

	# deb     http://security.debian.org                 stable/updates    main contrib non-free
	# deb-src http://security.debian.org                 stable/updates    main contrib non-free

	# deb     http://deb.debian.org/debian               buster-backports  main contrib non-free
	# deb-src http://deb.debian.org/debian               buster-backports  main contrib non-free
	EOT

	if [[ ! -f $ORIGINAL ]]; then
		mv $SOURCES $ORIGINAL
	fi
	mv $TMPFILE $SOURCES

	cat <<- EOT > /etc/apt/preferences.d/debian-sid
	Package: *
	Pin: release n=testing
	Pin-Priority: 900

	Package: *
	Pin: release n=sid
	Pin-Priority: -10
	EOT

	dpkg --add-architecture i386
	apt update

	# TARGET_BACKPORT="-t testing-backports"

	apt install net-tools
	apt install apt-transport-https
	apt install firmware-linux-nonfree
	apt install $TARGET_BACKPORT linux-headers-$(uname -r | sed 's/[^-]*-[^-]*-//')
	apt install build-essential
	# apt install dkms  # conflict kernel 5.7 with official nvidia driver
	apt autoremove

	update-ca-certificates --fresh
fi

#####################################################################
#####################################################################
if [[ ! -z "$DO_VISUDO" ]]; then
	createSudoer "main-cmds" <<- EOT
	Cmnd_Alias SHUTDOWN_CMDS = /sbin/poweroff, /sbin/reboot, /sbin/halt
	Cmnd_Alias NETZWORK_CMDS = /usr/sbin/tunctl, /sbin/ifconfig, /usr/sbin/brctl, /sbin/ip
	Cmnd_Alias PRINTING_CMDS = /usr/sbin/lpc, /usr/sbin/lprm
	$SUDO_USER ALL= NOPASSWD: SHUTDOWN_CMDS
	$SUDO_USER ALL= NOPASSWD: NETZWORK_CMDS
	ALL ALL=(ALL) NOPASSWD: PRINTING_CMDS
	# Cmnd_Alias ADMIN_CMDS = /usr/sbin/passwd, /usr/sbin/useradd, /usr/sbin/userdel, /usr/sbin/usermod, /usr/sbin/visudo
	# $SUDO_USER ALL= ADMIN_CMDS
	# USERS WORKSTATIONS=(ADMINS) ADMIN_CMDS
	EOT
fi

#####################################################################
#####################################################################
if [[ ! -z "$DO_TOOLS" ]]; then
	apt update
	apt install gparted       # graphical device manager
	apt install menulibre     # menu editor
	apt install fonts-noto    # nice font
	apt autoremove

	CLEAR_SANS_URL='https://www.fontsquirrel.com/fonts/download/clear-sans'
	sudo -u $SUDO_USER wget -P Downloads/ $CLEAR_SANS_URL/clear-sans.zip
	if [[ -f 'Downloads/clear-sans.zip' ]]; then
		CLEAR_SANS_DST='/usr/share/fonts/clear-sans'
		mkdir -p $CLEAR_SANS_DST
		unzip Downloads/clear-sans.zip -d $CLEAR_SANS_DST

		xfconf-query -c xsettings -p /Gtk/FontName  -s 'Clear Sans 10'
		xfconf-query -c xsettings -p /Xft/Hinting   -t 'bool' -s 'true'
		xfconf-query -c xsettings -p /Xft/HintStyle -s 'hintslight'
		xfconf-query -c xsettings -p /Xft/RGBA      -s 'rgb'

		xfconf-query -c xfwm4 -p /general/title_font  -s 'Clear Sans 10'
	fi

	sudo -u $SUDO_USER mkdir -p $HOME_USER/.icons
	sudo -u $SUDO_USER mkdir -p $HOME_USER/.themes

	if [[ -f "Downloads/gtk.css" ]]; then
		sudo -u $SUDO_USER mkdir -p $HOME_USER/.config/gtk-3.0
		sudo -u $SUDO_USER cp Downloads/gtk.css $HOME_USER/.config/gtk-3.0/
	fi
fi

#####################################################################
#####################################################################
if [[ ! -z "$DO_NVIDIA_OFFICAL" ]]; then
	DO_NVIDIA=true
fi

if [[ ! -z "$DO_AMD" ]] && [[ ! -z "$DO_NVIDIA" ]]; then
	echo 'install only one type of graphic driver (AMD or NVIDIA)'
	exit 1
fi

#####################################################################
#####################################################################
# graphicCheckCard card-name
function graphicCheckCard() {
	local graficCard=$(lspci -nn | grep -E -i '3d|display|vga')
	echo $graficCard
	if [[ "$graficCard" =~ "$1" ]]; then
		continueNow 'Do you want to install the driver now?'
	else
		echo "### Graphic card not match $1! ###"
		breakNow 'Do you want to install the driver?'
	fi
}

#####################################################################
#####################################################################
######### NVIDIA driver 440.xx
if [[ ! -z "$DO_NVIDIA" ]]; then
	NVIDIA_STEP1='nvidia-step1'
	NVIDIA_STEP2='nvidia-step2'

	graphicCheckCard 'NVIDIA'
	echo "######### install NVIDIA driver for $OPSYSTEM"
	dpkg --add-architecture i386
	installLib nvidia-detect
	nvidia-detect
	read -p 'Press [Enter] key to continue...'

	if [[ -f "$NVIDIA_STEP2" ]]; then
		echo 'You finished the installation of the NVIDIA driver!'
		rm -f $NVIDIA_STEP1
		rm -f $NVIDIA_STEP2
	elif [[ -z "$DO_NVIDIA_OFFICAL" ]]; then
		apt install nvidia-driver
		apt autoremove
		sudo -u $SUDO_USER touch $NVIDIA_STEP2
		rebootNow
	else
		NVIDIA_URL='https://www.nvidia.com/en-us/drivers/unix/'
		NVIDIA_REL='450.66' # 440.82 440.100
		NVIDIA_DEF="http://us.download.nvidia.com/XFree86/Linux-x86_64/$NVIDIA_REL/NVIDIA-Linux-x86_64-$NVIDIA_REL.run"
		NVIDIA_SRC='NVIDIA-Linux-x86_64-*.run'
		NVIDIA_DRV=$(downloadDriver $NVIDIA_URL $NVIDIA_DEF $NVIDIA_SRC)
		if [[ -f "$NVIDIA_STEP1" ]]; then
			# official nvidia.com package step 2
			apt remove --purge '^nvidia.*'

			sh $NVIDIA_DRV  # execute NVIDIA-Linux-x86_64-*.run

			apt install mesa-vulkan-drivers mesa-vulkan-drivers:i386
			apt install libvulkan1 libvulkan1:i386
			apt install vulkan-utils

			sudo -u $SUDO_USER touch $NVIDIA_STEP2
			systemctl set-default graphical.target
		else
			# official nvidia.com package step 1
			cat <<- EOT > /etc/modprobe.d/blacklist-nvidia-nouveau.conf
			blacklist nouveau
			options nouveau modeset=0
			EOT

			update-initramfs -u

			apt install libgl1-mesa-dri libgl1-mesa-dri:i386
			apt install libgl1-mesa-glx libgl1-mesa-glx:i386

			sudo -u $SUDO_USER touch $NVIDIA_STEP1
			systemctl set-default multi-user.target
		fi
		rebootNow
	fi
fi

#####################################################################
#####################################################################
######### AMD driver
if [[ ! -z "$DO_AMD" ]]; then
	echo '######### install AMD driver'
	AMD_DONE='amd-done'

	graphicCheckCard 'AMD'
	if [[ -f "$AMD_DONE" ]]; then
		echo 'You finished the installation of the AMD driver!'
		rm -f $AMD_DONE
	else
		echo '######### install AMD driver'
		dpkg --add-architecture i386
		apt install xserver-xorg-video-amdgpu
		# apt install libgl1-fglrx-glx-i386

		apt install libgl1-mesa-dri libgl1-mesa-dri:i386
		apt install libgl1-mesa-glx libgl1-mesa-glx:i386
		apt install mesa-vulkan-drivers mesa-vulkan-drivers:i386
		apt install libvulkan1 libvulkan1:i386
		apt install vulkan-utils
		apt autoremove
		sudo -u $SUDO_USER touch "$AMD_DONE"
		rebootNow
	fi
fi

#####################################################################
#####################################################################
######### Autologin
if [[ ! -z "$DO_AUTO_LOGIN" ]]; then
	echo '######### enable Autologin'
	LIGHT_DM='/etc/lightdm/lightdm.conf'
	if [[ ! -f "$LIGHT_DM.old" ]]; then
		cp $LIGHT_DM $LIGHT_DM.old
	fi

	sed -i "s/^#autologin-user=.*/autologin-user=$SUDO_USER/"       $LIGHT_DM
	sed -i "s/^#autologin-user-timeout=0/autologin-user-timeout=0/" $LIGHT_DM
fi

#####################################################################
# Virtualization
#####################################################################

#####################################################################
#####################################################################
######### KVM - QEMU with Virt-Manager
#ISO_PATH='/media/data/iso'
ISO_PATH='/var/kvm/images'
ETH0=$(ip addr | grep MULTICAST | head -1 | cut -d ' ' -f 2 | cut -d ':' -f 1)
BRIDGE='bridge0'

if [[ ! -z "$DO_KVM" ]]; then
	echo '######### install KVM'

	function kvmAddPolkitRule() {
		apt install libvirt-python

	#  rulePath='/etc/polkit-1/rules.d/49-polkit-pkla-compat.rules'
		local rulePath='/etc/polkit-1/rules.d/50-libvirt.rules'
		cat <<- 'EOT' | sudo -u $SUDO_USER tee $rulePath > /dev/null
		polkit.addRule(function(action, subject) {
		  if (action.id == 'org.libvirt.unix.manage' && subject.isInGroup('kvm')) {
		    return polkit.Result.YES;
		  }
		});
		EOT

		virsh pool-list --all
	}

	function kvmCreateBridge() {
		local theBridge=$1
		local thePort=$2

		cat <<- 'EOT' > "/etc/network/interfaces.d/$theBridge"
		# The loopback network interface
		auto lo
		iface lo inet loopback

		# The primary network interface
		auto $thePort
		iface $thePort inet manual

		auto $theBridge
		# Configure bridge and give it a dhcp ip
		#iface $theBridge inet dhcp
		# Configure bridge and give it a static ip
		iface $theBridge inet static
		  address         192.168.0.20
		  broadcast       192.168.0.255
		  netmask         255.255.255.0
		  gateway         192.168.0.1
		  dns-nameservers 192.168.0.1
		  dns-search      192.168.0.1
		  bridge_ports    $thePort
		  bridge_stp      off
		  bridge_fd       0
		  bridge_maxwait  5
		  bridge_maxage   12
		  bridge_waitport 0
		EOT

		systemctl restart libvirtd
		virsh -c qemu:///system net-list --all
	}

	function kvmActivateBridge() {
		local theBridge=$1
		local activeBridge="/tmp/activate-$theBridge.yaml"

		cat <<- 'EOT' | sudo -u $SUDO_USER tee "$activeBridge" > /dev/null
		<network>
		  <name>$theBridge</name>
		  <forward mode="bridge"/>
		  <bridge name="$theBridge"/>
		</network>
		EOT

		virsh -c qemu:///system net-define    --file "$activeBridge"
		virsh -c qemu:///system net-autostart $theBridge
		virsh -c qemu:///system net-start     $theBridge
		virsh -c qemu:///system net-list      --all
	#  virsh -c qemu:///system pool-undefine $theBridge
	}

	grep -E -o -c '(vmx|svm)' /proc/cpuinfo
	continueNow 'You need some processors with vmx or svm support (number > 0)'

	mkdir -p $ISO_PATH
	chgrp -R users $ISO_PATH
	chmod -R 2777 $ISO_PATH

	apt install qemu-kvm                  # QEMU Full virtualization on x86 hardware

	apt install libvirt-bin               # a C toolkit to interact with the virtualization capabilities of recent versions of Linux
	apt install libvirt-clients           # programs for the libvirt library
	apt install libvirt-daemon            # virtualization daemon
	apt install libvirt-daemon-system     # libvirt daemon configuration files

	# apt install libguestfs-tools        # allows accessing and modifying guest disk images.
	apt install libosinfo-bin             # contains the runtime files to detect operating systems and query the database.

	apt install virtinst                  # a set of commandline tools to create virtual machines using libvirt
	apt install virt-manager              # desktop application for managing virtual machines
	apt install virt-top                  # a top-like utility for showing stats of virtualized domains.
	# apt install virt-viewer             # displaying the graphical console of a virtual machine (part of virtinst)

	# apt install acpid                   # Advanced Configuration and Power Interface event daemon
	# apt install binutils                # GNU assembler, linker and binary utilities
	# apt install genisoimage             # genisoimage is a pre-mastering program for creating ISO-9660 CD-ROM filesystem images
	# apt install spice-client            # GObject for communicating with Spice servers
	# apt install spice-vdagent           # spice-vdagent is the spice agent for Linux, it is used in conjunction with spice-compatible hypervisor
	apt install bridge-utils              # contains utilities for configuring the Linux Ethernet bridge in Linux.

	systemctl stop    NetworkManager
	systemctl stop    NetworkManager-wait-online
	systemctl stop    NetworkManager-dispatcher

	systemctl disable NetworkManager
	systemctl disable NetworkManager-wait-online
	systemctl disable NetworkManager-dispatcher

	systemctl stop    network-manager
	systemctl disable network-manager
	apt autoremove --purge network-manager

	if ! systemctl is-active libvirtd ; then
		systemctl enable libvirtd
		systemctl start  libvirtd
	fi

	#if ! systemctl is-active acpid ; then
	#	systemctl enable acpid
	#	systemctl start  acpid
	#fi

	#cat <<- EOT >> "/etc/sysctl.conf"
	## Enable netfilter on bridges.
	#net.bridge.bridge-nf-call-ip6tables = 1
	#net.bridge.bridge-nf-call-iptables  = 1
	#net.bridge.bridge-nf-call-arptables = 1
	#EOT

	usermod -aG libvirt      $SUDO_USER
	usermod -aG libvirt-qemu $SUDO_USER
	usermod -aG kvm          $SUDO_USER

	#	createSudoer "kvm-cmds" <<- EOT
	# Cmnd_Alias KVM = /usr/sbin/tunctl, /sbin/ifconfig, /usr/sbin/brctl, /sbin/ip
	# %kvm ALL=(ALL) NOPASSWD: KVM
	# EOT


	virsh net-list --all
	virsh net-autostart --disable default
	virsh net-destroy             default
	#virsh net-undefine            default

	# improve the performance of KVM VMs
	modprobe vhost_net
	if ! grep -F -q "vhost_net" /etc/modules ; then
		echo "vhost_net" | sudo tee -a /etc/modules
	fi
	lsmod | grep vhost

	# kvmAddPolkitRule

	cat /etc/group | grep libvirt
	virsh list --all

	kvmCreateBridge   $BRIDGE $ETH0
	kvmActivateBridge $BRIDGE
	# ip a s $BRIDGE

	addExportEnv '.bashrc' 'LIBVIRT_DEFAULT_URI' 'qemu:///system'
	addExportEnv '.zshrc'  'LIBVIRT_DEFAULT_URI' 'qemu:///system'

	rebootNow
fi

#####################################################################
#####################################################################
######### KVM - install a image
if [[ ! -z "$DO_ISO" ]]; then
	echo '######### install a iso'

	function isoInstallCentos() {
		local centImg='centos8.qcow2'
		local centOS=$(ls -t $ISO_PATH/CentOS-$1*.iso 2>/dev/null | head -1)
		if [[ ! -f "$centOS" ]]; then
			echo 'missing iso!'
			exit 1
		fi
	#	virsh vol-create-as default $centImg 40G --format qcow2
		virt-install \
			--virt-type  kvm \
			--name       centos$1 \
			--ram        2048 \
			--vcpus      2 \
			--os-variant centos8 \
			--hvm \
			--network    bridge=$2,model=virtio \
			--graphics   Spice \
			--cdrom      $centOS \
			--disk       path=/var/lib/libvirt/images/$centImg,size=40,bus=virtio,format=qcow2
	#		--disk       vol=default/$centImg,bus=virtio,format=qcow2
	}

	function isoInstallDebian() {
		local debianImg='debian.qcow2'
		local debianOS=$(ls -t $ISO_PATH/debian-$1*.iso 2>/dev/null | head -1)
		if [[ ! -f "$debianOS" ]]; then
			echo 'missing iso!'
			exit 1
		fi
	#	virsh vol-create-as default $debianImg 40G --format qcow2
		virt-install \
			--virt-type  kvm \
			--name       $1 \
			--ram        2048 \
			--vcpus      2 \
			--os-variant debian10 \
			--hvm \
			--network    bridge=$2,model=virtio \
			--graphics   spice \
			--cdrom      $debianOS \
			--disk       path=/var/lib/libvirt/images/$debianImg,size=40,bus=virtio,format=qcow2
	#		--disk       vol=default/$debianImg,bus=virtio,format=qcow2
	}

	function isoInstallAndroid86() {
		local androidImg='android9.img'
		local androidOS=$(ls -t $ISO_PATH/android*.iso 2>/dev/null | head -1)
		if [[ ! -f "$androidOS" ]]; then
			echo 'missing iso!'
			exit 1
		fi
		qemu-img create -f qcow2 $androidImg 2G
		qemu-system-x86_64 \
			-enable-kvm \
			-m         2048 \
			-smp       30 \
			-cpu       host \
			-boot      menu=on \
			-device    virtio-mouse-pci \
			-device    virtio-keyboard-pci \
			-device    virtio-vga,virgl=on \
			-display   gtk \
			-soundhw   es1370 \
			-net       nic \
			-net       user \
			-usb \
			-usbdevice tablet \
			-hda       $androidImg \
			-cdrom     $androidOS
	}

#	isoInstallCentos 8 $BRIDGE
	isoInstallDebian bullseye $BRIDGE
fi

#####################################################################
#####################################################################
######### VirtualBox
# https://wiki.debian.org/VirtualBox
if [[ ! -z "$DO_VIRTUAL_BOX" ]]; then
	echo '######### install VirtualBox'
#  apt install libvncserver1 libgsoap-2.8.91 dkms kbuild linux-headers-amd64

#  cd /tmp
#  wget -nv http://ftp.de.debian.org/debian/pool/contrib/v/virtualbox/virtualbox-dkms_6.1.0-dfsg-2_amd64.deb
#  wget -nv http://ftp.de.debian.org/debian/pool/contrib/v/virtualbox-ext-pack/virtualbox-ext-pack_6.1.0-1_all.deb
#  wget -nv http://ftp.de.debian.org/debian/pool/non-free/v/virtualbox-guest-additions-iso/virtualbox-guest-additions-iso_6.0.10-1_all.deb
#  wget -nv http://ftp.de.debian.org/debian/pool/contrib/v/virtualbox/virtualbox-qt_6.1.0-dfsg-2_amd64.deb
#  wget -nv http://ftp.de.debian.org/debian/pool/contrib/v/virtualbox/virtualbox-source_6.1.0-dfsg-2_amd64.deb
#  wget -nv http://ftp.de.debian.org/debian/pool/contrib/v/virtualbox/virtualbox_6.1.0-dfsg-2_amd64.deb

#  dpkg -i virtualbox-guest-additions-iso_6.0.10-1_all.deb
#  dpkg -i virtualbox-dkms_6.1.0-dfsg-2_amd64.deb
#  dpkg -i virtualbox-source_6.1.0-dfsg-2_amd64.deb
#  dpkg -i virtualbox_6.1.0-dfsg-2_amd64.deb
#  dpkg -i virtualbox-qt_6.1.0-dfsg-2_amd64.deb
#  dpkg -i virtualbox-ext-pack_6.1.0-1_all.deb

#  addPgpKey 'https://www.virtualbox.org/download/oracle_vbox_2016.asc' 'oracle.gpg'
#  echo 'deb https://download.virtualbox.org/virtualbox/debian buster contrib' > $SOURCES_DIR/virtualbox.list
#  apt update

	apt install virtualbox/sid    # found at debian sid repository
fi

#####################################################################
#####################################################################
######### Android in a Box
# https://anbox.io/
# https://docs.anbox.io/
if [[ ! -z "$DO_ANBOX" ]]; then
	echo '######### install Anbox'

#  ANBOX_BUILDS='http://ppa.launchpad.net/morphis/anbox-support/ubuntu'
#  cat <<- EOT > $SOURCES_DIR/anbox.list
#	deb     [arch=amd64,i386] $ANBOX_BUILDS focal main
#	deb-src [arch=amd64,i386] $ANBOX_BUILDS focal main
#	EOT
#  apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 21C6044A875B67B7
#  apt update
#  apt install anbox-modules-dkms

	sudo -u $SUDO_USER mkdir -p git
	sudo -u $SUDO_USER cd /git
	sudo -u $SUDO_USER git clone https://github.com/anbox/anbox-modules.git
	cd anbox-modules

	cp anbox.conf /etc/modules-load.d/
	cp 99-anbox.rules /lib/udev/rules.d/

	cp -rT ashmem /usr/src/anbox-ashmem-1
	cp -rT binder /usr/src/anbox-binder-1

	dkms install anbox-ashmem/1
	dkms install anbox-binder/1
	cd $HOME_USER

	modprobe ashmem_linux
	modprobe binder_linux
	lsmod | grep -e ashmem_linux -e binder_linux
	ls -alh /dev/binder /dev/ashmem

	# snap install --devmode --beta anbox
	# snap refresh --beta --devmode anbox
	# snap info anbox
	# wget -O /var/lib/anbox/android.img https://build.anbox.io/android-images/2018/07/19/android_amd64.img
	# There are two systemd services.
	# sudo systemctl start anbox-container-manager.service
	# systemctl --user start anbox-session-manager.service
	# If you want these services to start when booting, just
	# sudo systemctl enable anbox-container-manager.service
	# systemctl --user enable anbox-session-manager.service
	apt install anbox

# to remove all this
#  cat <<- EOT > /etc/modprobe.d/blacklist.conf
#	blacklist ashmem_linux
#	blacklist binder_linux
#	EOT
#  depmod -a
#  update-initramfs -u
#  reboot
#  modprobe -r ashmem_linux binder_linux
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
	# addPgpKey "https://$OBS_URL/Release.key" 'wine.gpg'
	# echo 'deb http://$OBS_URL ./' > $SOURCES_DIR/wine-obs.list
	# apt update

	# LIB_SDL=libsdl2-2.0-0_2.0.10+dfsg1-1_amd64.deb
	# sudo -u $SUDO_USER wget -P Downloads -nv http://ftp.us.debian.org/debian/pool/main/libs/libsdl2/$LIB_SDL
	# dpkg -i Downloads/$LIB_SDL
	# apt install libsdl2-2.0-0

	# LIB_FAUDIO=libfaudio0_20.01-0~bullseye_amd64.deb
	# sudo -u $SUDO_USER wget -P Downloads -nv https://$OBS_URL/amd64/$LIB_FAUDIO
	# dpkg -i Downloads/$LIB_FAUDIO
	# apt install libfaudio0

	# winehq-stable:    Stable builds provide the latest stable version
	# winehq-staging:   Staging builds contain many experimental patches intended to test some features or fix compatibility issues.
	# winehq-devel:     Developer builds are in-development, cutting edge versions.

	WINE_BUILDS='https://dl.winehq.org/wine-builds'
	addPgpKey "$WINE_BUILDS/winehq.key" 'wineHQ.gpg'
	echo "deb $WINE_BUILDS/debian/ bullseye main" > $SOURCES_DIR/wine.list
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

	addBinToPath '.bashrc' '/opt/wine-staging/bin'
	addBinToPath '.zshrc'  '/opt/wine-staging/bin'

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
#	addPgpKey "$STEAM_BUILDS/archive/stable/steam.gpg" 'steam.gpg'
	addPgpKey "$STEAM_BUILDS/archive/precise/steam.gpg" 'steam.gpg'
	cat <<- EOT > $SOURCES_DIR/steam.list
	deb     [arch=amd64,i386] $STEAM_BUILDS stable steam
	deb-src [arch=amd64,i386] $STEAM_BUILDS stable steam
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
	addPgpKey "$LUTRIS_URL/Release.key" 'lutris.gpg'
	echo "deb $LUTRIS_URL/ ./" > $SOURCES_DIR/lutris.list
	apt update
	apt install lutris
	apt install gamemode

	find /usr -iname 'libgamemode*'
	LUTRIS_PRE=$(find /usr -iname 'libgamemode*' | grep auto | head -1)
	echo
	echo "add to Lutris preferences and try other if not working (I don't know if needed)"
	echo "LD_PRELOAD    = $LUTRIS_PRE"
	echo "mesa_glthread = true"
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
######### java
# sudo update-alternatives --config java
if [[ ! -z "$DO_JAVA" ]]; then
	echo '######### install java'
	apt install default-jre
	apt install default-jdk

	# https://www.oracle.com/java/technologies/javase-jdk8-downloads.html
	# apt install oracle-java8-installer

	JFROG_BUILDS='https://adoptopenjdk.jfrog.io/adoptopenjdk'
	addPgpKey "$JFROG_BUILDS/api/gpg/key/public" 'jfrog.gpg'
	echo "deb $JFROG_BUILDS/deb/ buster main" > $SOURCES_DIR/jfrog.list
	apt update

	JAVA_VERSION=14
	apt install "adoptopenjdk-${JAVA_VERSION}-hotspot"
#  apt install "adoptopenjdk-${JAVA_VERSION}-hotspot-jre"
#  apt install" adoptopenjdk-${JAVA_VERSION}-openj9-jre"
fi

#####################################################################
#####################################################################
######### MultiMC
# https://multimc.org
if [[ ! -z "$DO_MULTI_MC" ]]; then
	echo '######### install Minecraft MultiMC'

	apt install qt5-default

	MULTIMC_URL='https://multimc.org'
	MULTIMC_REL='1.4-1'
	MULTIMC_DEF="multimc_$MULTIMC_REL.deb"
	MULTIMC_SRC='multimc_*.deb'
	MULTIMC_DRV=$(downloadDriver $MULTIMC_URL $MULTIMC_URL/download/$MULTIMC_DEF $MULTIMC_SRC)

	dpkg -i $MULTIMC_DRV
fi

#####################################################################
# Media
#####################################################################

#####################################################################
#####################################################################
######### Discord
# https://linuxconfig.org/how-to-install-discord-on-linux
if [[ ! -z "$DO_DISCORD" ]]; then
	echo '######### install Discord'

	DISCORD_URL='https://discordapp.com/api/download?platform=linux&format=deb'
	DISCORD_SRC='discord*.deb'
	DISCORD_LST='discord-latest.deb'
	echo "ownload_driver '' $DISCORD_URL $DISCORD_SRC"
	DISCORD_DRV=$(downloadDriver '' $DISCORD_URL $DISCORD_SRC $DISCORD_LST)

	apt install libgconf-2-4

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
######### Firefox + Thunderbird

if [[ ! -z "$DO_MOZILLA" ]]; then
	echo '######### install Firefox + Thunderbird'

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
			[Profile1]
			Name=win10profile
			IsRelative=1
			Path=win10profile
			EOT
		fi
	}

	apt remove --purge iceweasel

	apt install -t unstable firefox
	apt install -t unstable thunderbird

	FIREFOX_WINDOWS="/mnt/work_c/Users/$WINDOWS_USER/AppData/Roaming/Mozilla/Firefox"
	FIREFOX_LINUX="$HOME_USER/.mozilla/firefox"

	THUNDERBIRD_WINDOWS="/mnt/work_c/Users/$WINDOWS_USER/AppData/Roaming/Thunderbird"
	THUNDERBIRD_LINUX="$HOME_USER/.thunderbird"

	mozillaCopyProfile 'Download/firefox.zip'     $FIREFOX_LINUX     $FIREFOX_WINDOWS
	mozillaCopyProfile 'Download/thunderbird.zip' $THUNDERBIRD_LINUX $THUNDERBIRD_WINDOWS
fi

#####################################################################
#####################################################################
######### Spotify
# https://wiki.debian.org/spotify
# https://www.spotify.com/de/download/linux/
if [[ ! -z "$DO_SPOTIFY" ]]; then
	echo '######### install Spotify'

	addPgpKey 'https://download.spotify.com/debian/pubkey.gpg' 'spotify.gpg'
#	echo deb 'https://repository.spotify.com stable non-free' > $SOURCES_DIR/spotify.list
	echo deb 'https://repository.scdn.co stable non-free' > $SOURCES_DIR/spotify.list
	apt update

	apt install spotify-client
fi

#####################################################################
#####################################################################
######### twitch gui + VideoLan + Chatty
# https://www.videolan.org
# https://github.com/streamlink/streamlink-twitch-gui
# https://www.hiroom2.com/2018/05/27/ubuntu-1804-twitch-en/
if [[ ! -z "$DO_TWITCH_GUI" ]]; then
	echo '######### install VideoLan'
	apt install vlc

	echo '######### install Streamlink'
	apt install streamlink

	echo '######### install twitch gui'
	TWITCH_URL='https://github.com/streamlink/streamlink-twitch-gui/releases'
	TWITCH_REL='v1.9.1'
	TWITCH_DEF="streamlink-twitch-gui-${TWITCH_REL}-linux64.tar.gz"
	TWITCH_SRC='streamlink-twitch-gui-*-linux64.tar.gz'
	TWITCH_DRV=$(downloadDriver $TWITCH_URL $TWITCH_URL/download/$TWITCH_REL/$TWITCH_DEF $TWITCH_SRC)

	tar -xzvf $TWITCH_DRV -C /opt
	apt install xdg-utils libgconf-2-4
	/opt/streamlink-twitch-gui/add-menuitem.sh
	ln -s /opt/streamlink-twitch-gui/start.sh /usr/bin/streamlink-twitch-gui

	echo '######### install Chatty'
	apt install default-jre

	CHATTY_URL='https://github.com/chatty/chatty/releases'
	CHATTY_REL='0.11'
	CHATTY_DEF="Chatty_$CHATTY_REL.zip"
	CHATTY_SRC='Chatty_*.zip'
	CHATTY_DRV=$(downloadDriver $CHATTY_URL $CHATTY_URL/download/v$CHATTY_REL/$CHATTY_DEF $CHATTY_SRC)

	unzip $CHATTY_DRV -d /opt/chatty
fi

#####################################################################
# Diverse
#####################################################################

#####################################################################
#####################################################################
######### Atom
# https://linuxhint.com/install_atom_text_editor_debian_10/
if [[ ! -z "$DO_ATOM" ]]; then
	echo '######### install Atom IDE'
	ATOM_URL='https://github.com/atom/atom/releases'
	ATOM_REL='v1.46.0'
	ATOM_DEF='atom-amd64.deb'
	ATOM_SRC='atom_*.deb'
	ATOM_DRV=$(downloadDriver $ATOM_URL $ATOM_URL/download/$ATOM_REL/$ATOM_DEF $ATOM_SRC)

	dpkg -i $ATOM_DRV

	atom --version
fi

#####################################################################
#####################################################################
######### lightweight free system monitor
# https://github.com/brndnmtthws/conky
# https://itsfoss.com/conky-gui-ubuntu-1304/
if [[ ! -z "$DO_CONKY" ]]; then
	echo '######### install Conky'
	apt install conky-all

# project dead
#  CONKY_URL=https://github.com/teejee2008/conky-manager/releases
#  CONKY_REL='v2.4'
#  CONKY_DEF='conky-manager-v2.4-amd64.deb'
#  CONKY_SRC='conky-manager-*-amd64.deb'
#  CONKY_DRV=$(downloadDriver $CONKY_URL $CONKY_URL/download/$CONKY_REL/$CONKY_DEF $CONKY_SRC)

#  CONKY_FONT_URL=http://mxrepo.com/mx/repo/pool/main/m/mx-conky/
#  CONKY_FONT_REL='20.4'
#  CONKY_FONT_DEF='mx-conky_20.4_amd64.deb'
#  CONKY_FONT_SRC='mx-conky_*_amd64.deb'
#  CONKY_FONT_DRV=$(downloadDriver $CONKY_FONT_URL $CONKY_FONT_URL/$CONKY_FONT_DEF $CONKY_FONT_SRC)
#  dpkg -i $CONKY_FONT_DRV

#  CONKY_URL=http://mxrepo.com/mx/repo/pool/main/c/conky-manager/
#  CONKY_REL='2.7'
#  CONKY_DEF='conky-manager_2.7+dfsg1-3mx19+2_amd64.deb'
#  CONKY_SRC='conky-manager_*+dfsg1-3mx19+2_amd64.deb'
#  CONKY_DRV=$(downloadDriver $CONKY_URL $CONKY_URL/$CONKY_DEF $CONKY_SRC)
#  dpkg -i $CONKY_DRV

#  CONKY_BUILDS='http://ppa.launchpad.net/tomtomtom/conky-manager/ubuntu'
#  cat <<- EOT > $SOURCES_DIR/conky.list
#	deb     [arch=amd64,i386] $CONKY_BUILDS focal main
#	deb-src [arch=amd64,i386] $CONKY_BUILDS focal main
#	EOT
#  apt-key adv --keyserver keyserver.ubuntu.com --recv-keys b90e9186f0e836fb
#  apt update
#  apt install conky-manager

	conky --version
fi

#####################################################################
#####################################################################
######### better text editor
# https://www.sublimetext.com/
if [[ ! -z "$DO_SUBLIME" ]]; then
	echo '######### install Sublime editor'

	addPgpKey 'https://download.sublimetext.com/sublimehq-pub.gpg' 'sublime.gpg'
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
######### nice icon sets
# https://snwh.org/moka
if [[ ! -z "$DO_MOKA" ]]; then
	echo '######### install Moka'
	LAUNCHMAD_LIBS='https://launchpadlibrarian.net'

	sudo -u $SUDO_USER wget -P Downloads -nv $LAUNCHMAD_LIBS/425937281/moka-icon-theme_5.4.523-201905300105~daily~ubuntu18.04.1_all.deb -O moka-icon-theme_5.4.523.deb
	sudo -u $SUDO_USER wget -P Downloads -nv $LAUNCHMAD_LIBS/375793783/faba-icon-theme_4.3.317-201806241721~daily~ubuntu18.04.1_all.deb -O faba-icon-theme_4.3.317.deb
# sudo -u $SUDO_USER wget -P Downloads -nv $LAUNCHMAD_LIBS/373757993/faba-mono-icons_4.4.102-201604301531~daily~ubuntu18.04.1_all.deb -O faba-mono-icons_4.4.102.deb

	dpkg -i Downloads/moka-icon-theme_5.4.523.deb
	dpkg -i Downloads/faba-icon-theme_4.3.317.deb
fi

#####################################################################
#####################################################################
######### nice shell extension
# https://ohmyz.sh
if [[ ! -z "$DO_OHMYZ" ]]; then
	echo '######### install OHMYZ shell extension'
	apt install git
	apt install zsh
	apt install curl

	sudo -u $SUDO_USER bash -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
	sudo -u $SUDO_USER sed -i '0,/ZSH_THEME="[^"]*"/s//ZSH_THEME="robbyrussell"/' .zshrc     # ZSH_THEME="robbyrussell"
	sudo -u $SUDO_USER sort .bash_history | uniq | awk '{print ": :0:;"$0}' >> .zsh_history

	logoutNow
fi

#####################################################################
#####################################################################
######### Password Safe
# https://howtoinstall.co/en/debian/stretch/passwordsafe-common
if [[ ! -z "$DO_PASSWORD_SAFE" ]]; then
	echo '######### install Password Safe'

	apt install passwordsafe
fi

#####################################################################
#####################################################################
######### Samba
# https://devconnected.com/how-to-install-samba-on-debian-10-buster/

if [[ ! -z "$DO_SAMBA" ]]; then
	echo '######### install Samba Server'

	SAMBA_CONF='/etc/samba/smb.conf'
	SAMBA_SHARE='/home/samba'

	function sambaCreateSmbUser() {
		local smbUser=$1
		echo "create a samba user '$smbUser' with working directory at '$SAMBA_SHARE'"
		useradd -M -d $SAMBA_SHARE/$smbUser -s /usr/sbin/nologin -G sambashare $smbUser
		mkdir -p $SAMBA_SHARE/$smbUser
		smbpasswd -a $smbUser
		smbpasswd -e $smbUser
		chown $smbUser:sambashare $SAMBA_SHARE/$smbUser
		chmod 2770 $SAMBA_SHARE/smbadmin
	}

	function sambaCreateSmbUserConfig() {
		local smbUser=$1
		if ! grep -F -q "[$smbUser]" $SAMBA_CONF ; then
			cat <<- 'EOT' >> $SAMBA_CONF
			[$smbUser]
			  path = $SAMBA_SHARE/$smbUser
			  read only = no
			  browseable = $2
			  force create mode = 0660
			  force directory mode = 2770
			  valid users = @$smbUser @sambashare
			EOT
		fi
	}

	# groups: user sudo netdev cdrom
	apt install samba
#  apt install smbclient cifs-utils
	apt install ufw

	mkdir -p $SAMBA_SHARE
	chmod 777 $SAMBA_SHARE
	chgrp sambashare $SAMBA_SHARE

	if ! grep -F -q '[Docs]' $SAMBA_CONF ; then
		cat <<- 'EOT' >> $SAMBA_CONF
		[Docs]
		  path = $SAMBA_SHARE
		  writable = yes
		  guest ok = yes
		  guest only = yes
		  create mode = 0777
		  directory mode = 0777
		EOT
	fi

	sambaCreateSmbUser $SUDO_USER
	sambaCreateSmbUser smbadmin

	sambaCreateSmbUserConfig $SUDO_USER no
	sambaCreateSmbUserConfig smbadmin   yes

	nano $SAMBA_CONF

	testparm
	if [[ "$?" == "0" ]]; then
		systemctl restart smbd nmbd
		systemctl status  smbd nmbd
	else
		echo 'something was going wrong :('
		exit 1
	fi

	ufw allow 'Samba'
	ufw status

	samba -V
	smbclient -L localhost

	# smbclient //192.168.122.52/$SUDO_USER -U $SUDO_USER
fi

#####################################################################
#####################################################################
######### Access Windows Share
FSTAB='/etc/fstab'

if [[ ! -z "$DO_CIFS" ]]; then
	echo '######### install Access Windows Share'

	echo "used windows domain: $WINDOWS_DOMAIN"
	echo "used windows user: $WINDOWS_USER"
	echo "default windows share names: work_c, work_d, work_e"
	continueNow 'Do you want to use this values?'
	echo

	echo -n "type your windows password for $WINDOWS_USER:"
	read -s WINDOWS_PW
	echo

	apt install cifs-utils

	# my old windows disks
	mkdir -p /mnt/work_c
	mkdir -p /mnt/work_d
	mkdir -p /mnt/work_e

	WIN_CREDENTIALS='/etc/win-credentials'
	cat <<- EOT > $WIN_CREDENTIALS
	username=$WINDOWS_USER
	password=$WINDOWS_PW
	domain=$WINDOWS_DOMAIN
	EOT
	chown root: $WIN_CREDENTIALS
	chmod 600 $WIN_CREDENTIALS

	USER_UID=$(sudo -u $SUDO_USER id -u $SUDO_USER)
	USER_GID=$(sudo -u $SUDO_USER id -g $SUDO_USER)
	WIN_OPTIONS="noauto,uid=$USER_UID,gid=$USER_GID,forceuid,forcegid,dir_mode=0755,file_mode=0644"

	mount -t cifs -o credentials=$WIN_CREDENTIALS,$WIN_OPTIONS //$WINDOWS_DOMAIN/c /mnt/work_c
	mount -t cifs -o credentials=$WIN_CREDENTIALS,$WIN_OPTIONS //$WINDOWS_DOMAIN/d /mnt/work_d
	mount -t cifs -o credentials=$WIN_CREDENTIALS,$WIN_OPTIONS //$WINDOWS_DOMAIN/e /mnt/work_e

	if ! grep -F -q "//$WINDOWS_DOMAIN" $FSTAB ; then
		if [[ ! -f "$FSTAB.old" ]]; then
			cp $FSTAB $FSTAB.old
		fi
		cat <<- EOT >> $FSTAB
		//$WINDOWS_DOMAIN/c  /mnt/work_c  cifs  credentials=$WIN_CREDENTIALS,$WIN_OPTIONS 0 0
		//$WINDOWS_DOMAIN/d  /mnt/work_d  cifs  credentials=$WIN_CREDENTIALS,$WIN_OPTIONS 0 0
		//$WINDOWS_DOMAIN/e  /mnt/work_e  cifs  credentials=$WIN_CREDENTIALS,$WIN_OPTIONS 0 0
		EOT
	fi

	WIN_SHELL="/mnt/mount-win.sh"
	cat <<- EOT > "$WIN_SHELL"
	#!/bin/bash
	mount //$WINDOWS_DOMAIN/c
	mount //$WINDOWS_DOMAIN/d
	mount //$WINDOWS_DOMAIN/e
	EOT
	chmod +x $WIN_SHELL

	createDesktopEntry "windows.desktop" <<- EOT
	[Desktop Entry]
	Name=Windows Shares
	Comment=mount windows folder
	Exec=bash -c "sudo $WIN_SHELL > /dev/null 2>&1 & xdg-open /mnt/work_c"
	Icon=drive-removable-media
	Terminal=false
	Type=Application
	Categories=System;Utility;FileTools;FileManager;
	StartupNotify=true
	EOT

	createSudoer "win-cmds" <<- EOT
	$SUDO_USER ALL= NOPASSWD: $WIN_SHELL
	EOT

	df -h
fi

#####################################################################
#####################################################################
######### XScreensaver
if [[ ! -z "$DO_SCREENSAVER" ]]; then
	echo '######### install XScreensaver'
	apt install xscreensaver xscreensaver-gl-extra xscreensaver-data-extra
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
######### rsync + rsnapshot
# https://wiki.archlinux.de/title/Rsnapshot
# https://www.thomas-krenn.com/de/wiki/Backup_unter_Linux_mit_rsnapshot
# https://wiki.ubuntuusers.de/USB-Datentr%C3%A4ger_automatisch_einbinden/
if [[ ! -z "$DO_SNAPSHOT" ]]; then
	echo '######### install rsync + rsnapshot'
	apt install rsync rsnapshot
	apt install autofs

	AUTO_TYPE=usb
	AUTO_DIR=/var/autofs/$AUTO_TYPE
	AUTO_CONF=/etc/auto.$AUTO_TYPE
	AUTO_MASTER='/etc/auto.master'

	mkdir -p $AUTO_DIR
	if ! grep -F -q "$AUTO_DIR" $AUTO_MASTER ; then
		if [[ ! -f "$AUTO_MASTER.old" ]]; then
			cp $AUTO_MASTER $AUTO_MASTER.old
		fi
		echo "$AUTO_DIR $AUTO_CONF --timeout=60 --ghost" >> $AUTO_MASTER
	fi

	blkid -o list
	AUTO_BACKUP_UUID=$(blkid | grep 'ext2' | grep '/dev/sd' | sed 's/.*\sUUID="\([^"]*\).*/\1/')
	echo "usb backup uuid=$AUTO_BACKUP_UUID"
	if [[ ! -z "$AUTO_BACKUP_UUID" ]]; then
		echo "backup  -fstype=ext2,sync,rw,user,noauto  :/dev/disk/by-uuid/$AUTO_BACKUP_UUID" > $AUTO_CONF
		if ! grep -F -q "$AUTO_BACKUP_UUID" $FSTAB ; then
			echo "UUID=$AUTO_BACKUP_UUID $AUTO_DIR ext2 noauto,rw 0 0" >> $FSTAB
		fi
	fi

	systemctl reload autofs
	echo
	echo "edit your '/etc/rsnapshot.conf'"
fi

#####################################################################
#####################################################################
if [[ ! -z "$DO_TEST" ]]; then
	echo 'nothing here for now'

#	RC_LOCAL='/etc/rc.d/rc.local'
#	TEST_FILE='/opt/scripts/run-script-on-boot.sh'
#	TEST_OUTPUT='/root/on-boot-output.txt'

#	cat <<- EOT > $TEST_FILE
#	#!/bin/bash
#	date     >> $TEST_OUTPUT
#	hostname >> $TEST_OUTPUT
#	EOT

#	chmod +x $TEST_FILE
#	chmod +x $RC_LOCAL
#	echo $TEST_FILE | sudo -u $SUDO_USER tee -a $RC_LOCAL > /dev/null
#	reboot
fi
