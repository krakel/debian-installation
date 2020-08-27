#!/bin/bash

# check before
# dmesg				# print or control the kernel ring buffer
# journalctl		# query the systemd journal

function help_msg() {
  echo "Usage:"
  echo "[sudo] install [flags]*"
  echo
  echo "Sudo:   	run without sudo for 'install su'"
  echo "su      	only add user to sudo group"
  echo "        	all other with sudo"
  echo
  echo "Flags:"
  echo "help    	this help"
  echo "test    	only script tests"
  echo
  echo "src     	debian testing (use this first)"
  echo "amd     	amd/ati driver         (1 reboot)"
  echo "nvidia  	nvidia driver          (1 reboot)"
  echo "nvidia2 	nvidia driver official (1 reboot, 2 runs)"
  echo "login     Autologin"
  echo
  echo "kvm     	KVM, QEMU with Virt-Manager (1 reboot)"
  echo "virtual 	VirtualBox with SID library (removed from debian testing)"
  echo "anbox   	Anbox, a Android Emulator (very alpha)"
  echo
  echo "wine    	Wine"
  echo "steam   	Steam"
  echo "lutris  	Lutris"
  echo "dxvk    	vulkan-based compatibility layer for Direct3D"
  echo "dnet    	Microsoft .Net 4.6.1 (do not use)"
  echo "java    	java 8+11 jdk"
  echo "multimc 	Minecraft MultiMC"
  echo
  echo "discord 	Discord"
  echo "dream   	Dreambox Edit"
  echo "mozilla 	Firefox + Thunderbird"
  echo "spotify 	Spotify, some music"
  echo "twitch  	twitch gui + VideoLan + Chatty"
  echo
  echo "atom    	Atom IDE"
  echo "cifs    	Access Windows Share"
  echo "conky    	lightweight free system monitor"
  echo "cuda    	CudaText editor"
  echo "gparted   graphical device manager"
  echo "gpic      GPicview image viewer"
  echo "moka    	nice icon set"
  echo "ohmyz   	ohmyz shell extension"
  echo "pwsafe  	Password Safe"
  echo "samba   	Samba Server, access from Windows, not needed, I use only cifs"
  echo "screen  	XScreensaver"
  echo "snap    	rsnapshot+rsync backups on local system"
  echo "sub       Sublime editor"
  echo "viewnior  Viewnior image viewer"
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
  [gparted]=DO_GPARTED
  [gpic]=DO_GPIC
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
  [twitch]=DO_TWITCH_GUI
  [viewnior]=DO_VIEWNIOR
  [virtual]=DO_VIRTUAL_BOX
  [wine]=DO_WINE
)

if [[ $# -eq 0  ]]; then
  help_msg
  exit
fi

while [[ $# -gt 0 ]]; do
  KEY=${1#-}
  VALUE=${SELECT[$KEY]}

  if [[ -z "$VALUE" ]]; then
    help_msg
    exit
  fi

  eval "$VALUE"=true		# eval is EVIL :)
  shift             		# past argument
done


SOURCES_DIR=/etc/apt/sources.list.d
SUDO_USER=$(logname)
HOME_USER=/home/$SUDO_USER
cd $HOME_USER

#####################################################################
function continue_now() {
  echo
  echo -n "$1 (Y/n)!"
  read ANSWER
  if [[ "$ANSWER" != "${ANSWER#[Nn]}" ]]; then
    exit 1
  fi
}

function break_now() {
  echo
  echo -n "$1 (y/N)!"
  read ANSWER
  if [[ "$ANSWER" == "${ANSWER#[Yy]}" ]]; then
    exit 1
  fi
}

function reboot_now() {
  continue_now "You NEED to reboot now!"
  systemctl reboot
}

function logout_now() {
  echo
  echo -n "You need to logout now!"
  read
  exit
}

if [[ ! -z "$ONLY_SUDOER" ]]; then
  echo "enter your root password to add $SUDO_USER to group sudo"
  su - root -c bash -c "/sbin/usermod -aG sudo $SUDO_USER"    # add to group sudo
  echo
  logout_now
fi

if [[ $(id -u) != 0 ]]; then
   echo
   echo "Ups, I am not root!"
   exit 1
fi

# apt update		# refreshes repository index
# apt upgrade		# upgrades all upgradable packages
# apt autoremove	# removes unwanted packages
# apt install		# install a package
# apt remove		# remove a package
# apt search		# searche for a program
# apt install --fix-broken

#####################################################################
function insert_path_fkts() {
  if ! grep -E -q "path_add\(\)" $1 ; then
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
		  PATH="$(echo $PATH | sed -e "s;\(^\|:\)${1%/}\(:\|\$\);\1\2;g" -e 's;^:\|:$;;g' -e 's;::;:;g')"
		}
		EOT
    # dont forget 'export PATH'
  fi
}

function add_bin_to_path() {
  insert_path_fkts $1
  if ! grep -E -q "path_add $2" $1 ; then
    echo "add '$2' to '$1'"
    cat <<- EOT | sudo -u $SUDO_USER tee -a $1 > /dev/null

		path_add "$2" after
		export PATH
		EOT
  else
    echo "'$1' already contain '$2'!"
  fi
}

function add_export_env() {
  insert_path_fkts $1
  if ! grep -E -q "$2" $1 ; then
    echo "add 'export $2=\"$3\"' to '$1'"
    cat <<- EOT | sudo -u $SUDO_USER tee -a $1 > /dev/null

		export $2="$3"
		EOT
  else
    echo "'$1' already contain 'export $2=\"$3\"'!"
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
    rm $TMPFILE
  fi

  echo "create new source file: $TMPFILE"
  touch $TMPFILE

  cat <<- EOT > $TMPFILE
	deb     http://deb.debian.org/debian               testing          main contrib non-free
	deb-src http://deb.debian.org/debian               testing          main contrib non-free

	deb     http://deb.debian.org/debian               testing-updates  main contrib non-free
	deb-src http://deb.debian.org/debian               testing-updates  main contrib non-free

	deb     http://security.debian.org/debian-security testing-security main contrib non-free
	deb-src http://security.debian.org/debian-security testing-security main contrib non-free

	deb     http://deb.debian.org/debian/              sid              main non-free contrib
	deb-src http://deb.debian.org/debian/              sid              main non-free contrib
	EOT

# do not use backports !
# deb     http://deb.debian.org/debian/ testing-backports main contrib non-free
# deb-src http://deb.debian.org/debian/ testing-backports main contrib non-free

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

  apt install net-tools
  apt install apt-transport-https
  apt install firmware-linux-nonfree
  apt install linux-headers-$(uname -r | sed 's/[^-]*-[^-]*-//')
  apt install build-essential
  apt install dkms
  apt autoremove

  update-ca-certificates --fresh
fi

#####################################################################
function install_lib() {
  ldconfig -p | grep "$1"
  if [[ "$?" != "0" ]]; then
    apt install $1
    apt autoremove
  fi
}

function check_card() {
  GRAFIC_CARD=$(lspci -nn | egrep -i "3d|display|vga")
  echo $GRAFIC_CARD
  if [[ "$GRAFIC_CARD" =~ "$1" ]]; then
    continue_now "Do you want to install the driver now?"
  else
    echo "### Graphic card not match $1! ###"
    break_now "Do you want to install the driver?"
  fi
}

function download_driver() {
  SEARCH_OBJ="Downloads/$3"
  SEARCH_DRV=$(ls -t $SEARCH_OBJ 2>/dev/null | head -1)
  if [[ ! -z "$1" ]] && [[ ! -f "$SEARCH_DRV" ]]; then
    sudo -u $SUDO_USER bash -c "DISPLAY=:0.0 x-www-browser $1"
    read -p "Press [Enter] key to continue if you finished the download of the latest driver to '~/Downloads/'"
    SEARCH_DRV=$(ls -t $SEARCH_OBJ 2>/dev/null | head -1)
  fi
  if [[ ! -z "$2" ]] && [[ ! -f "$SEARCH_DRV" ]]; then
    sudo -u $SUDO_USER wget -P Downloads $2
    SEARCH_DRV=$(ls -t $SEARCH_OBJ 2>/dev/null | head -1)
  fi
  if [[ ! -f "$SEARCH_DRV" ]]; then
    echo "missing driver!"
    exit 1
  fi
  echo $SEARCH_DRV
}

#####################################################################
if [[ ! -z "$DO_NVIDIA_OFFICAL" ]]; then
  DO_NVIDIA=true
fi

if [[ ! -z "$DO_AMD" ]] && [[ ! -z "$DO_NVIDIA" ]]; then
  echo "install only one type of graphic driver (AMD or NVIDIA)"
  exit 1
fi

#####################################################################
######### NVIDIA driver 440.xx
if [[ ! -z "$DO_NVIDIA" ]]; then
  NVIDIA_STEP1="nvidia-step1"
  NVIDIA_STEP2="nvidia-step2"

  check_card "NVIDIA"
  echo "######### install NVIDIA driver for $OPSYSTEM"
  dpkg --add-architecture i386
  install_lib nvidia-detect
  nvidia-detect
  read -p "Press [Enter] key to continue..."

  if [[ -f "$NVIDIA_STEP2" ]]; then
    echo "You finished the installation of NVIDIA driver!"
  elif [[ -z "$DO_NVIDIA_OFFICAL" ]]; then
    apt install nvidia-driver
    apt autoremove
    sudo -u $SUDO_USER touch $NVIDIA_STEP2
    reboot_now
  else
    NVIDIA_URL=https://www.nvidia.com/en-us/drivers/unix/
    NVIDIA_REL='440.82'
    NVIDIA_DEF=http://us.download.nvidia.com/XFree86/Linux-x86_64/${NVIDIA_REL}/NVIDIA-Linux-x86_64-${NVIDIA_REL}.run
    NVIDIA_SRC='NVIDIA-Linux-x86_64-*.run'
    NVIDIA_DRV=$(download_driver $NVIDIA_URL $NVIDIA_DEF $NVIDIA_SRC)
    if [[ -f "$NVIDIA_STEP1" ]]; then
      # official nvidia.com package step 2
      apt remove '^nvidia.*'
      sh $NVIDIA_DRV

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
    reboot_now
  fi
fi

#####################################################################
######### AMD driver
if [[ ! -z "$DO_AMD" ]]; then
  echo '######### install AMD driver'
  AMD_DONE="amd-done"

  check_card "AMD"
  if [[ -f "$AMD_DONE" ]]; then
    echo "You already installed the AMD driver!"
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
    reboot_now
  fi
fi

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
######### KVM - QEMU with Virt-Manager
function add_polkit_rule() {
  apt install libvirt-python

#  RULE_PATH='/etc/polkit-1/rules.d/49-polkit-pkla-compat.rules'
  RULE_PATH='/etc/polkit-1/rules.d/50-libvirt.rules'
  cat <<- EOT | sudo -u $SUDO_USER tee $RULE_PATH > /dev/null
	polkit.addRule(function(action, subject) {
	  if (action.id == "org.libvirt.unix.manage" && subject.isInGroup("kvm")) {
	    return polkit.Result.YES;
	  }
	});
	EOT

  virsh pool-list --all
}

function create_bridge() {
  THE_BRIDGE=$1
  THE_ETH0=$2

  cat <<- EOT | sudo -u $SUDO_USER tee "/etc/network/interfaces.d/$THE_BRIDGE" > /dev/null
	# Primary network interface
	auto $THE_ETH0
	iface $THE_ETH0 inet manual

	# Configure bridge and give it a dhcp ip
	auto $THE_BRIDGE
	iface $THE_BRIDGE inet dhcp
	  bridge_ports $THE_ETH0
	  bridge_stp off
	  bridge_waitport 0
	  bridge_maxwait 5
	  bridge_fd 0
	EOT

  systemctl restart libvirtd
  virsh -c qemu:///system net-list --all
}

function activate_bridge() {
  THE_BRIDGE=$1
  ACTIVATE_BRIDGE="/tmp/activate-$THE_BRIDGE.yaml"

  cat <<- EOT | sudo -u $SUDO_USER tee "$ACTIVATE_BRIDGE" > /dev/null
	<network>
	  <name>$THE_BRIDGE</name>
	  <forward mode="bridge"/>
	  <bridge name="$THE_BRIDGE"/>
	</network>
	EOT

  virsh -c qemu:///system net-define    --file "$ACTIVATE_BRIDGE"
  virsh -c qemu:///system net-autostart $THE_BRIDGE
  virsh -c qemu:///system net-start     $THE_BRIDGE
  virsh -c qemu:///system net-list      --all
#  virsh -c qemu:///system pool-undefine $THE_BRIDGE
}

ISO_PATH='/media/data/iso'

function install_centos() {
  CENT_OS=$(ls -t $ISO_PATH/CentOS*.iso 2>/dev/null | head -1)
  virt-install --virt-type=kvm --name centos8 --ram 2048 --vcpus=2 --os-variant=rhel7 --hvm \
    --network=bridge=$1,model=virtio --graphics Spice \
    --cdrom=$CENT_OS --disk path=/var/lib/libvirt/images/centos8.qcow2,size=40,bus=virtio,format=qcow2
}

function install_android86() {
  ANDROID_IMG='android9.img'
  ANDROID_OS=$(ls -t $ISO_PATH/android*.iso 2>/dev/null | head -1)
  qemu-img create -f qcow2 $ANDROID_IMG 2G
  qemu-system-x86_64 -enable-kvm -m 2048 -smp 30 -cpu host -boot menu=on \
    -device virtio-mouse-pci -device virtio-keyboard-pci -device virtio-vga,virgl=on \
    -display gtk -soundhw es1370 -net nic -net user -usb -usbdevice tablet \
    -hda $ANDROID_IMG -cdrom $ANDROID_OS
}

if [[ ! -z "$DO_KVM" ]]; then
  echo '######### install KVM'
  grep -o 'vmx\|svm' /proc/cpuinfo
  continue_now "You need some processors with vmx or svm support"

  mkdir -p $ISO_PATH
  chown -R $SUDO_USER:$SUDO_USER /media/data

  apt install qemu-kvm
  apt install libvirt-clients libvirt-daemon libvirt-daemon-system
  apt install libguestfs-tools libosinfo-bin binutils genisoimage
  apt install virtinst virt-viewer virt-manager
  apt install bridge-utils

  systemctl stop    NetworkManager
  systemctl stop    NetworkManager-wait-online
  systemctl stop    NetworkManager-dispatcher
  systemctl stop    network-manager

  systemctl disable NetworkManager
  systemctl disable NetworkManager-wait-online
  systemctl disable NetworkManager-dispatcher
  systemctl disable network-manager

  systemctl enable libvirtd
  systemctl start libvirtd

  adduser $SUDO_USER libvirt
  adduser $SUDO_USER libvirt-qemu

  newgrp libvirt
  newgrp libvirt-qemu

  usermod -aG kvm $SUDO_USER

#  add_polkit_rule

  cat /etc/group | grep libvirt
  virsh list --all

  IF_ETH0=$(ip addr | grep MULTICAST | head -1 | cut -d ' ' -f 2 | cut -d ':' -f 1)
  BRIDGE='bridge0'

  create_bridge   $BRIDGE $IF_ETH0
  activate_bridge $BRIDGE

  add_export_env '.bashrc' 'LIBVIRT_DEFAULT_URI' 'qemu:///system'
  add_export_env '.zshrc'  'LIBVIRT_DEFAULT_URI' 'qemu:///system'

  reboot_now
#  ip a s $BRIDGE
#  install_centos $BRIDGE
fi

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

#  wget -nv https://www.virtualbox.org/download/oracle_vbox_2016.asc -O - | apt-key add -
#  echo "deb https://download.virtualbox.org/virtualbox/debian buster contrib" | tee $SOURCES_DIR/virtualbox.list > /dev/null
#  apt update

  apt install virtualbox/sid		# found at debian sid repository
fi

#####################################################################
######### Android in a Box
# https://anbox.io/
# https://docs.anbox.io/
if [[ ! -z "$DO_ANBOX" ]]; then
  echo '######### install Anbox'

#  ANBOX_BUILDS="http://ppa.launchpad.net/morphis/anbox-support/ubuntu"
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
######### Wine
######### WineHQ
if [[ ! -z "$DO_WINE" ]]; then
  echo '######### install Wine'
  apt install gnupg2 software-properties-common

  # not at latest debian testing
  # repositories and images created with the Open Build Service
  # OBS_URL="https://download.opensuse.org/repositories/Emulators:/Wine:/Debian/Debian_Testing_standard"
  # wget -nv https://$OBS_URL/Release.key -O - | apt-key add -
  # echo "deb http://$OBS_URL ./" | tee $SOURCES_DIR/wine-obs.list > /dev/null
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

  WINE_BUILDS="https://dl.winehq.org/wine-builds"
  wget -nv  $WINE_BUILDS/winehq.key -O - | apt-key add -
  echo "deb $WINE_BUILDS/debian/ bullseye main" | tee $SOURCES_DIR/wine.list > /dev/null
  # echo "deb $WINE_BUILDS/debian/ testing  main" | tee $SOURCES_DIR/wine.list > /dev/null  # <-- broken, not working
  apt update

  function install_wine() {
    WINEOPT=""
    if [[ ! -z "$1" ]]; then
      WINEOPT="$WINEOPT-$1"
    fi
    if [[ ! -z "$2" ]]; then
      WINEOPT="$WINEOPT=$2"
    fi
    apt install --install-recommends wine$WINEOPT wine32$WINEOPT wine64$WINEOPT libwine$WINEOPT libwine:i386$WINEOPT fonts-wine$WINEOPT
  }

  function install_wineHQ() {
    WINEOPT=""
    if [[ ! -z "$1" ]]; then
      WINEOPT="$WINEOPT-$1"
    fi
    if [[ ! -z "$2" ]]; then
      WINEOPT="$WINEOPT=$2"
    fi
    apt install --install-recommends winehq$WINEOPT
  }

  # apt-cache policy winehq-staging
  WINE_VER='5.7~bullseye'
  install_wine 'staging'     $WINE_VER
  #install_wine 'development' $WINE_VER

  install_wineHQ 'staging' $WINE_VER
  #install_wineHQ 'devel'   $WINE_VER

  sudo -u $SUDO_USER winecfg		# mono,gecko will be installed
  if [[ "$?" != "0" ]]; then
    echo "something goes wrong!"
    exit 1
  fi

  add_bin_to_path '.bashrc' '/opt/wine-staging/bin'
  add_bin_to_path '.zshrc'  '/opt/wine-staging/bin'

  apt install mono-complete
  apt install winetricks
  apt autoremove
  wine --version
fi

#####################################################################
######### Steam
if [[ ! -z "$DO_STEAM" ]]; then
  echo '######### install Steam'
  STEAM_BUILDS="https://repo.steampowered.com/steam"
#  apt-key add --keyserver keyserver.ubuntu.com --recv-keys F24AEA9FB05498B7
  wget -nv  $STEAM_BUILDS/archive/precise/steam.gpg -O - | apt-key add -
  cat <<- EOT > $SOURCES_DIR/steam.list
	deb     [arch=amd64,i386] $STEAM_BUILDS precise steam
	deb-src [arch=amd64,i386] $STEAM_BUILDS precise steam
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
######### Lutris
if [[ ! -z "$DO_LUTRIS" ]]; then
  echo '######### install Lutris'
  LUTRIS_URL="https://download.opensuse.org/repositories/home:/strycore/Debian_Testing"
  wget -nv $LUTRIS_URL/Release.key -O - | apt-key add -
  echo "deb $LUTRIS_URL/ ./" | tee $SOURCES_DIR/lutris.list > /dev/null
  apt update
  apt install lutris
  apt install gamemode

  find /usr -iname "libgamemode*"
  LUTRIS_PRE=$(find /usr -iname "libgamemode*" | grep auto | head -1)
  echo
  echo "add to Lutris preferences and try other if not working (I don't know if needed)"
  echo "LD_PRELOAD    = $LUTRIS_PRE"
  echo "mesa_glthread = true"
fi

#####################################################################
######### dxvk is a Vulkan-based compatibility layer for Direct3D 11
if [[ ! -z "$DO_DXVK" ]]; then
  echo '######### install DXVK'
  apt install dxvk/sid
fi

#####################################################################
######### Microsoft .Net 4.6.1
if [[ ! -z "$DO_DOT_NET" ]]; then
  echo '######### install .Net'
  apt install winetricks
  env WINEPREFIX=winedotnet wineboot --init
  env WINEPREFIX=winedotnet winetricks dotnet461 corefonts
fi

#####################################################################
######### java
# sudo update-alternatives --config java
if [[ ! -z "$DO_JAVA" ]]; then
  echo '######### install java'
  apt install default-jre
  apt install default-jdk

  # https://www.oracle.com/java/technologies/javase-jdk8-downloads.html
  # apt install oracle-java8-installer

  JFROG_BUILDS="https://adoptopenjdk.jfrog.io/adoptopenjdk"
  wget -nv $JFROG_BUILDS/api/gpg/key/public -O - | apt-key add -
  echo "deb $JFROG_BUILDS/deb/ buster main" | tee $SOURCES_DIR/jfrog.list > /dev/null
  apt update

  apt install adoptopenjdk-8-hotspot
#  apt install adoptopenjdk-8-hotspot-jre
#  apt install adoptopenjdk-8-openj9-jre
fi

#####################################################################
######### MultiMC
# https://multimc.org
if [[ ! -z "$DO_MULTI_MC" ]]; then
  echo '######### install Minecraft MultiMC'

  apt install qt5-default

  MULTIMC_URL=https://multimc.org
  MULTIMC_REL='1.4-1'
  MULTIMC_DEF="multimc_${MULTIMC_REL}.deb"
  MULTIMC_SRC='multimc_*.deb'
  MULTIMC_DRV=$(download_driver $MULTIMC_URL $MULTIMC_URL/download/$MULTIMC_DEF $MULTIMC_SRC)

  dpkg -i $MULTIMC_DRV
fi

#####################################################################
# Media
#####################################################################

#####################################################################
######### Discord
# https://linuxconfig.org/how-to-install-discord-on-linux
if [[ ! -z "$DO_DISCORD" ]]; then
  echo '######### install Discord'

  DISCORD_URL=https://discordapp.com/api/download?platform=linux&format=deb
  DISCORD_SRC='discord*.deb'
  DISCORD_DRV=$(download_driver '' $DISCORD_URL $DISCORD_SRC)

  dpkg -i $DISCORD_DRV
fi

#####################################################################
######### Dreambox Edit
# https://blog.videgro.net/2013/10/running-dreamboxedit-at-linux/
if [[ ! -z "$DO_DREAMBOX_EDIT" ]]; then
  echo '######### install Dreambox Edit'

  DREAMBOX_URL=https://dreambox.de/board/index.php?board/47-sonstige-pc-software/
  DREAMBOX_REL='7.2.1.0'
  DREAMBOX_DEF="dreamboxEDIT_without_setup_${DREAMBOX_REL}.zip"
  DREAMBOX_SRC='dreamboxEDIT_without_setup_*.zip'
  DREAMBOX_DRV=$(download_driver $DREAMBOX_URL '' $DREAMBOX_SRC)

  DREAMBOX_DIR=/opt/dreamboxedit
  unzip $DREAMBOX_DRV -d $DREAMBOX_DIR
#  ln -s /opt/dreamboxedit_5_3_0_0/ $DREAMBOX_DIR

  groupadd dreamboxedit
  usermod -aG dreamboxedit $SUDO_USER
  chown -R root:dreamboxedit $DREAMBOX_DIR

  echo
  echo "cd /opt/dreamboxedit"
  echo "wine dreamboxEDIT.exe"
fi

#####################################################################
######### Firefox + Thunderbird

function copy_profile() {
  PROFILE_OLD=$1
  PROFILE_INI=$2
  if [[ ! -f "$PROFILE_OLD" ]]; then
    echo "missing copy of Windows profile"
    exit 1
  fi

  sudo -u $SUDO_USER mkdir -p $(dirname $PROFILE_INI)
  sudo -u $SUDO_USER unzip $PROFILE_OLD -d $(dirname $PROFILE_INI)
  sudo -u $SUDO_USER sed -i "0,/StartWithLastProfile=[0-9]*/s//StartWithLastProfile=0/" $PROFILE_INI

  if ! grep -E -q '[Profile1]' $PROFILE_INI ; then
    cat <<- 'EOT' | sudo -u $SUDO_USER tee -a $PROFILE_INI > /dev/null
		[Profile1]
		Name=win10profile
		IsRelative=1
		Path=win10profile
		EOT
  fi
}

if [[ ! -z "$DO_MOZILLA" ]]; then
  echo '######### install Firefox + Thunderbird'
  apt install mozilla-firefox
  apt install mozilla-thunderbird

  # Windows
  # C:\Users\<NAME>\AppData\Roaming\Mozilla\Firefox\Profiles
  # C:\Users\<NAME>\AppData\Roaming\Mozilla\Firefox\profiles.ini
  #cp -r /mnt/Users/<NAME>/AppData/Roaming/Mozilla/Firefox/*.default .mozilla/firefox/win10profile

  copy_profile 'Download/firefox.zip'     '.mozilla/firefox/profiles.ini'
  copy_profile 'Download/thunderbird.zip' '.mozilla/thunderbird/profiles.ini'
fi

#####################################################################
######### Spotify
# https://wiki.debian.org/spotify
# https://www.spotify.com/de/download/linux/
if [[ ! -z "$DO_SPOTIFY" ]]; then
  echo '######### install Spotify'

#  apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 4773BD5E130D1D45
#  apt-key adv --keyserver keyserver.ubuntu.com --recv-keys 931FF8E79F0876134EDDBDCCA87FF9DF48BF1C90
  wget -nv https://download.spotify.com/debian/pubkey.gpg -O - | apt-key add -
  echo "deb https://repository.spotify.com stable non-free" | tee $SOURCES_DIR/spotify.list > /dev/null
  apt update

  apt install spotify-client
fi

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
  TWITCH_URL=https://github.com/streamlink/streamlink-twitch-gui/releases
  TWITCH_REL='v1.9.1'
  TWITCH_DEF="streamlink-twitch-gui-${TWITCH_REL}-linux64.tar.gz"
  TWITCH_SRC='streamlink-twitch-gui-*-linux64.tar.gz'
  TWITCH_DRV=$(download_driver $TWITCH_URL $TWITCH_URL/download/$TWITCH_REL/$TWITCH_DEF $TWITCH_SRC)

  tar -xzvf $TWITCH_DRV -C /opt
  apt install xdg-utils libgconf-2-4
  /opt/streamlink-twitch-gui/add-menuitem.sh
  ln -s /opt/streamlink-twitch-gui/start.sh /usr/bin/streamlink-twitch-gui

  echo '######### install Chatty'
  apt install default-jre

  CHATTY_URL=https://github.com/chatty/chatty/releases
  CHATTY_REL='0.11'
  CHATTY_DEF="Chatty_${CHATTY_REL}.zip"
  CHATTY_SRC='Chatty_*.zip'
  CHATTY_DRV=$(download_driver $CHATTY_URL $CHATTY_URL/download/v$CHATTY_REL/$CHATTY_DEF $CHATTY_SRC)

  unzip $CHATTY_DRV -d /opt/chatty
fi

#####################################################################
# Diverse
#####################################################################

#####################################################################
######### Atom
# https://linuxhint.com/install_atom_text_editor_debian_10/
if [[ ! -z "$DO_ATOM" ]]; then
  echo '######### install Atom IDE'
  ATOM_URL=https://github.com/atom/atom/releases
  ATOM_REL='v1.46.0'
  ATOM_DEF="atom-amd64.deb"
  ATOM_SRC='atom_*.deb'
  ATOM_DRV=$(download_driver $ATOM_URL $ATOM_URL/download/$ATOM_REL/$ATOM_DEF $ATOM_SRC)

  dpkg -i $ATOM_DRV

  atom --version
fi

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
#  CONKY_DEF="conky-manager-v2.4-amd64.deb"
#  CONKY_SRC='conky-manager-*-amd64.deb'
#  CONKY_DRV=$(download_driver $CONKY_URL $CONKY_URL/download/$CONKY_REL/$CONKY_DEF $CONKY_SRC)

#  CONKY_FONT_URL=http://mxrepo.com/mx/repo/pool/main/m/mx-conky/
#  CONKY_FONT_REL='20.4'
#  CONKY_FONT_DEF="mx-conky_20.4_amd64.deb"
#  CONKY_FONT_SRC='mx-conky_*_amd64.deb'
#  CONKY_FONT_DRV=$(download_driver $CONKY_FONT_URL $CONKY_FONT_URL/$CONKY_FONT_DEF $CONKY_FONT_SRC)
#  dpkg -i $CONKY_FONT_DRV

#  CONKY_URL=http://mxrepo.com/mx/repo/pool/main/c/conky-manager/
#  CONKY_REL='2.7'
#  CONKY_DEF="conky-manager_2.7+dfsg1-3mx19+2_amd64.deb"
#  CONKY_SRC='conky-manager_*+dfsg1-3mx19+2_amd64.deb'
#  CONKY_DRV=$(download_driver $CONKY_URL $CONKY_URL/$CONKY_DEF $CONKY_SRC)
#  dpkg -i $CONKY_DRV

#  CONKY_BUILDS="http://ppa.launchpad.net/tomtomtom/conky-manager/ubuntu"
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
######### better text editor
# https://www.sublimetext.com/
if [[ ! -z "$DO_SUBLIME" ]]; then
  echo '######### install Sublime editor'

  wget -nv https://download.sublimetext.com/sublimehq-pub.gpg -O - | apt-key add -
  echo "deb https://download.sublimetext.com/ apt/stable/" | tee $SOURCES_DIR/sublime.list > /dev/null
  apt update

  apt install sublime-text
fi

#####################################################################
######### nice text editor
# http://uvviewsoft.com/cudatext/
if [[ ! -z "$DO_CUDA_TEXT" ]]; then
  echo '######### install CudaText editor'
  CUDA_URL=https://www.fosshub.com/CudaText.html
  CUDA_DEF='cudatext_1.98.0.0-1_gtk2_amd64.deb'
  CUDA_SRC='cudatext_*_gtk2_amd64.deb'
  CUDA_DEB=$(download_driver $CUDA_URL '' $CUDA_SRC)

  echo "execute 'sudo dpkg -i $CUDA_DEB'"
  dpkg -i $CUDA_DEB

  DESKTOP_CUDA="Desktop/cudatext.desktop"
  cat <<- EOT | sudo -u $SUDO_USER tee $DESKTOP_CUDA > /dev/null
	[Desktop Entry]
	Version=1.0
	Name=Cuda Text
	Comment=a cross-platform text editor, written in Lazarus.
	Exec=cudatext
	Icon=cudatext-512.png
	Terminal=false
	Type=Application
	Categories=Utility;Application;Editor;
	EOT
  chmod +x $DESKTOP_CUDA

  PHYLIB=$(find /usr -name 'libpython3.*so*' 2>/dev/null | head -1)

  CUDA_SETTING=".config/cudatext/settings"
  sudo -u $SUDO_USER mkdir -p "$CUDA_SETTING"

  cat <<- EOT | sudo -u $SUDO_USER tee "$CUDA_SETTING/user.json" > /dev/null
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
######### nice icon sets
# https://snwh.org/moka
if [[ ! -z "$DO_MOKA" ]]; then
  echo '######### install Moka'
  LAUNCHMAD_LIBS=https://launchpadlibrarian.net

  sudo -u $SUDO_USER wget -P Downloads -nv $LAUNCHMAD_LIBS/425937281/moka-icon-theme_5.4.523-201905300105~daily~ubuntu18.04.1_all.deb -O moka-icon-theme_5.4.523.deb
  sudo -u $SUDO_USER wget -P Downloads -nv $LAUNCHMAD_LIBS/375793783/faba-icon-theme_4.3.317-201806241721~daily~ubuntu18.04.1_all.deb -O faba-icon-theme_4.3.317.deb
# sudo -u $SUDO_USER wget -P Downloads -nv $LAUNCHMAD_LIBS/373757993/faba-mono-icons_4.4.102-201604301531~daily~ubuntu18.04.1_all.deb -O faba-mono-icons_4.4.102.deb

  dpkg -i Downloads/moka-icon-theme_5.4.523.deb
  dpkg -i Downloads/faba-icon-theme_4.3.317.deb
fi

#####################################################################
######### nice shell extension
# https://ohmyz.sh
if [[ ! -z "$DO_OHMYZ" ]]; then
  echo '######### install OHMYZ shell extension'
  apt install git
  apt install zsh
  apt install curl

  sudo -u $SUDO_USER bash -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  sudo -u $SUDO_USER sed -i '0,/ZSH_THEME="[^"]*"/s//ZSH_THEME="robbyrussell"/' .zshrc		 # ZSH_THEME="robbyrussell"
  sudo -u $SUDO_USER sort .bash_history | uniq | awk '{print ": :0:;"$0}' >> .zsh_history

  logout_now
fi

#####################################################################
######### Password Safe
# https://howtoinstall.co/en/debian/stretch/passwordsafe-common
if [[ ! -z "$DO_PASSWORD_SAFE" ]]; then
  echo '######### install Password Safe'

  apt install passwordsafe
fi

#####################################################################
######### Samba
# https://devconnected.com/how-to-install-samba-on-debian-10-buster/

SAMBA_CONF='/etc/samba/smb.conf'
SAMBA_SHARE='/home/samba'

function create_smb_user() {
  SMB_USER=$1
  echo "create a samba user '$SMB_USER' with working directory at '$SAMBA_SHARE'"
  useradd -M -d $SAMBA_SHARE/$SMB_USER -s /usr/sbin/nologin -G sambashare $SMB_USER
  mkdir -p $SAMBA_SHARE/$SMB_USER
  smbpasswd -a $SMB_USER
  smbpasswd -e $SMB_USER
  chown $SMB_USER:sambashare $SAMBA_SHARE/$SMB_USER
  chmod 2770 $SAMBA_SHARE/smbadmin
}

function create_smb_user_config() {
  SMB_USER=$1
  if ! grep -E -q "[$SMB_USER]" $SAMBA_CONF ; then
    cat <<- EOT | tee -a $SAMBA_CONF > /dev/null
		[$SMB_USER]
		  path = $SAMBA_SHARE/$SMB_USER
		  read only = no
		  browseable = $2
		  force create mode = 0660
		  force directory mode = 2770
		  valid users = @$SMB_USER @sambashare
		EOT
  fi
}

if [[ ! -z "$DO_SAMBA" ]]; then
  echo '######### install Samba Server'
  # groups: user sudo netdev cdrom
  apt install samba
#  apt install smbclient cifs-utils
  apt install ufw

  mkdir -p $SAMBA_SHARE
  chmod 777 $SAMBA_SHARE
  chgrp sambashare $SAMBA_SHARE

  if ! grep -E -q "[Docs]" $SAMBA_CONF ; then
    cat <<- EOT | tee -a $SAMBA_CONF > /dev/null
		[Docs]
		  path = $SAMBA_SHARE
		  writable = yes
		  guest ok = yes
		  guest only = yes
		  create mode = 0777
		  directory mode = 0777
		EOT
  fi

  create_smb_user $SUDO_USER
  create_smb_user smbadmin

  create_smb_user_config $SUDO_USER no
  create_smb_user_config smbadmin   yes

  nano $SAMBA_CONF

  testparm
  if [[ "$?" == "0" ]]; then
    systemctl restart smbd nmbd
    systemctl status  smbd nmbd
  else
    echo "something was going wrong :("
    exit 1
  fi

  ufw allow 'Samba'
  ufw status

  samba -V
  smbclient -L localhost

  # smbclient //192.168.122.52/$SUDO_USER -U $SUDO_USER
fi

#####################################################################
######### Access Windows Share
FSTAB='/etc/fstab'

if [[ ! -z "$DO_CIFS" ]]; then
  echo '######### install Access Windows Share'
  apt install cifs-utils

  # my old windows disks
  mkdir -p /mnt/work_c
  mkdir -p /mnt/work_d
  mkdir -p /mnt/work_e

  # I use the same name
  WINDOWS_USER=$SUDO_USER       # change this to your windows user name
  WINDOWS_DOMAIN='work.local'	# change this to your windows domain

  echo -n "type your windows password for $SUDO_USER:"
  read -s WINDOWS_PW
  echo

  WIN_CREDENTIALS='/etc/win-credentials'
  cat <<- EOT | tee $WIN_CREDENTIALS > /dev/null
	username=$WINDOWS_USER
	password=$WINDOWS_PW
	domain=$WINDOWS_DOMAIN
	EOT
  chown root: $WIN_CREDENTIALS
  chmod 600 $WIN_CREDENTIALS

  USER_UID=$(sudo -u $SUDO_USER id -u $SUDO_USER)
  USER_GID=$(sudo -u $SUDO_USER id -g $SUDO_USER)
  WIN_OPTIONS="uid=$USER_UID,gid=$USER_GID,forceuid,forcegid,dir_mode=0755,file_mode=0644"

  mount -t cifs -o credentials=$WIN_CREDENTIALS,$WIN_OPTIONS //$WINDOWS_DOMAIN/c /mnt/work_c
  mount -t cifs -o credentials=$WIN_CREDENTIALS,$WIN_OPTIONS //$WINDOWS_DOMAIN/d /mnt/work_d
  mount -t cifs -o credentials=$WIN_CREDENTIALS,$WIN_OPTIONS //$WINDOWS_DOMAIN/e /mnt/work_e

  if ! grep -E -q "//WORK" $FSTAB ; then
    if [[ ! -f "$FSTAB.old" ]]; then
      cp $FSTAB $FSTAB.old
    fi
    cat <<- EOT | tee -a $FSTAB > /dev/null
		//$WINDOWS_DOMAIN/c  /mnt/work_c  cifs  credentials=$WIN_CREDENTIALS,$WIN_OPTIONS 0 0
		//$WINDOWS_DOMAIN/d  /mnt/work_d  cifs  credentials=$WIN_CREDENTIALS,$WIN_OPTIONS 0 0
		//$WINDOWS_DOMAIN/e  /mnt/work_e  cifs  credentials=$WIN_CREDENTIALS,$WIN_OPTIONS 0 0
		EOT
  fi

  df -h
fi

#####################################################################
######### XScreensaver
if [[ ! -z "$DO_SCREENSAVER" ]]; then
  echo '######### install XScreensaver'
  apt install xscreensaver xscreensaver-gl-extra xscreensaver-data-extra
fi

#####################################################################
######### GParted
if [[ ! -z "$DO_GPARTED" ]]; then
  echo '######### install GParted'
  apt install gparted
fi

#####################################################################
######### GPicview image viewer
if [[ ! -z "$DO_GPIC" ]]; then
  echo '######### install GPicview'
  apt install gpicview
fi

#####################################################################
######### Viewnior image viewer
if [[ ! -z "$DO_VIEWNIOR" ]]; then
  echo '######### install Viewnior'
  apt install viewnior
fi

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
  if ! grep -E -q "$AUTO_DIR" $AUTO_MASTER ; then
    if [[ ! -f "$AUTO_MASTER.old" ]]; then
      cp $AUTO_MASTER $AUTO_MASTER.old
    fi
    echo "$AUTO_DIR $AUTO_CONF --timeout=60 --ghost" | tee -a $AUTO_MASTER > /dev/null
  fi

  blkid -o list
  AUTO_BACKUP_UUID=$(blkid | grep "ext2" | grep "/dev/sd" | sed 's/.*\sUUID="\([^"]*\).*/\1/')
  echo "usb backup uuid=$AUTO_BACKUP_UUID"
  if [[ ! -z "$AUTO_BACKUP_UUID" ]]; then
    echo "backup  -fstype=ext2,sync,rw,user,noauto  :/dev/disk/by-uuid/$AUTO_BACKUP_UUID" | tee $AUTO_CONF > /dev/null
    if ! grep -E -q "$AUTO_BACKUP_UUID" $FSTAB ; then
      echo "UUID=$AUTO_BACKUP_UUID $AUTO_DIR noauto,rw 0 0" | tee -a $FSTAB > /dev/null
    fi
  fi

  systemctl reload autofs
  echo
  echo "edit your '/etc/rsnapshot.conf'"
fi

#####################################################################
if [[ ! -z "$DO_TEST" ]]; then
  echo "nothing here for now"
fi
