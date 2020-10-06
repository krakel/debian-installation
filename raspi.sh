#!/bin/bash

function helpMsg() {
  echo 'Usage:
  su root
  raspi [commands]*

Commands:
  help      this help
  test      only script tests

  src       update raspian (use this first)

  flash     update firmware
  ssd       update ssd
  user      create new user

  ohmyz     ohmyz shell extension
  ssh       ssh configuration
  tools     some tools
  wlan      wlan configuration

  apache    Apache 2 configuration
  bind      bind9 dns service
  maria     database configuration
  next      next cloud
'
}

declare -A SELECT=(
	[apache]=DO_APACHE
	[bind]=DO_BIND
	[flash]=DO_FLASH
	[maria]=DO_MARIA
	[next]=DO_NEXT_CLOUD
	[ohmyz]=DO_OHMYZ
	[src]=DO_SOURCE
	[ssd]=DO_SSD
	[ssh]=DO_SSH
	[test]=DO_TEST
	[tools]=DO_TOOLS
	[user]=DO_USER
	[wlan]=DO_WLAN
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

RASP_NAME=rasp1
SOURCES_DIR=/etc/apt/sources.list.d
SUDO_USER=$(logname)
HOME_USER=/home/$SUDO_USER
cd $HOME_USER

function logoutNow() {
	echo
	echo -n 'You need to logout now!'
	read
	exit
}

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

function powerOFF() {
	continueNow 'You NEED to poweroff now!'
	systemctl poweroff
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


function insertGenPasswdFkt() {
	if ! grep -F -q 'genpasswd()' $1 ; then
		cat <<- 'EOT' | sudo -u $SUDO_USER tee -a $1 > /dev/null

		genpasswd() {
		  local l=$1
		  if [ "$l" == "" ] && l=20 ; then
		    tr -dc A-Za-z0-9_ < /dev/urandom | head -c ${l} | xargs
		  fi
		}
		EOT
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
#####################################################################
if [[ ! -z "$DO_SOURCE" ]]; then
	apt update
	apt full-upgrade

	apt install net-tools
	apt install apt-transport-https
	apt install wget
	apt autoremove

	update-ca-certificates --fresh
	sudo -u $SUDO_USER mkdir -p $HOME_USER/Downloads

#	https://www.raspberrypi.org/forums/viewforum.php?f=29&269769
	rpi-update

	rebootNow
fi


#####################################################################
#####################################################################
if [[ ! -z "$DO_SSD" ]]; then
	MOUNT_SSD='/mnt/ssd'

	lsblk

	mkdir -p $MOUNT_SSD
	mount /dev/sda2 $MOUNT_SSD
	mkdir -p $MOUNT_SSD/boot
	mount /dev/sda1 $MOUNT_SSD/boot

	cp /boot/*.dat $MOUNT_SSD
	cp /boot/*.elf $MOUNT_SSD

	powerOFF
fi

#####################################################################
#####################################################################
if [[ ! -z "$DO_USER" ]]; then
	echo -n "type the name of the new user:"
	read -s NEW_USER
	echo

	adduser $NEW_USER

	su - root -c bash -c "/sbin/usermod -aG sudo $NEW_USER"
	sed -i "s/^SUDO_USER .*/$NEW_USER ALL=(ALL:ALL) ALL/" /etc/sudoers

	sudo -u $NEW_USER cp -rf /home/$SUDO_USER/* /home/$NEW_USER

	deluser $SUDO_USER sudo
	echo "execute: userdel --remove $SUDO_USER"

	logoutNow
fi

#####################################################################
#####################################################################
if [[ ! -z "$DO_FLASH" ]]; then
	EEPROM=/etc/default/rpi-eeprom-update
	BOOT_LDR=/lib/fimrware/raspberrypi/bootloader/stable

	apt install rpi-eeprom

	if [[ ! -f "$EEPROM.old" ]];
		mv "$EEPROM" "$EEPROM.old"
	fi
	echo 'FIRMWARE_RELEASE_STATUS="stable"' > $EEPROM

	vcgencmd bootloader_version
	vcgencmd bootloader_config
	echo

	ls -al $BOOT_LDR

	BOOT_DRV=$(ls -t "$BOOT_LDR/pieeprom*.bin" 2>/dev/null | head -1)
	if [[ -f "$BOOT_DRV" ]]; then
		continueNow "Do you want to install the firmware '$BOOT_DRV' now?"
		rpi-eeprom-update -d -f "$BOOT_DRV"
		raspi-config

		rebootNow
	fi
fi

#####################################################################
#####################################################################
if [[ ! -z "$DO_SSH" ]]; then
	SSH_CONF='/etc/ssh/sshd_config'
	SSH_PORT=22
	SSH_USER="$HOME_USER/.ssh"
	SSH_AUTH=$SSH_USER/authorized_keys

	usermod -aG ssh $SUDO_USER

	sudo -u $SUDO_USER mkdir -p $SSH_USER
	sudo -u $SUDO_USER touch $SSH_AUTH

	chmod 700 $SSH_USER
	chown $SUDO_USER:ssh $SSH_AUTH
	chmod 660 $SSH_AUTH

	if [[ ! -f "$SSH_USER/id_raspi.pub" ]]; then
		sudo -u $SUDO_USER ssh-keygen -b 4096 -f $SSH_USER/id_raspi
	fi
	sudo -u $SUDO_USER cat $SSH_USER/id_raspi.pub >> $SSH_AUTH

	if [[ ! -f "$SSH_CONF.old" ]];
		mv "$SSH_CONF" "$SSH_CONF.old"
	fi

	cat <<- EOT > $SSH_CONF
	Port $SSH_PORT
	AddressFamily any
	Protocol 2

	HostKey /etc/ssh/ssh_host_ed25519_key
	HostKey /etc/ssh/ssh_host_rsa_key

	UsePrivilegeSeparation yes

	SyslogFacility AUTH
	LogLevel VERBOSE

	LoginGraceTime 30
	PermitRootLogin no
	StrictModes yes

	AuthenticationMethods publickey
	AuthorizedKeysFile %h/.ssh/authorized_keys
	PubkeyAuthentication yes

	ChallengeResponseAuthentication no
	HostbasedAuthentication no
	PasswordAuthentication no
	PermitEmptyPasswords no

	ClientAliveCountMax 3
	ClientAliveInterval 3600
	MaxAuthTries 3
	MaxStartups 3:50:6
	PrintLastLog yes
	PrintMotd no
	TCPKeepAlive yes
	X11Forwarding no
	X11DisplayOffset 10

	#Banner /etc/issue.net
	AcceptEnv LANG LC_*
	Subsystem sftp /usr/lib/ssh/sftp-server -f AUTHPRIV -l INFO
	UsePAM yes

	AllowGroups ssh
	AllowUsers $SUDO_USER
	Compression delayed

	Ciphers chacha20-poly1305@openssh.com,aes256-gcm@openssh.com,aes128-gcm@openssh.com,aes256-ctr
	HostKeyAlgorithms rsa-sha2-512,ssh-rsa,ssh-dss
	KexAlgorithms curve25519-sha256@libssh.org,diffie-hellman-group-exchange-sha256
	MACs hmac-sha2-512-etm@openssh.com,hmac-sha2-256-etm@openssh.com,hmac-sha2-512,hmac-sha2-256,umac-128-etm@openssh.com
	EOT

	#F2B_CONF=/etc/fail2ban/jail.local
	#apt install fail2ban
	#cp /etc/fail2ban/jail.conf $F2B_CONF
	#sed -i "s/^.?ignoreip.*/ignoreip 127.0.0.1/32 192.168.0.16/28" $F2B_CONF
	#systemctl restart fail2ban

	#ufw status numbered
	#ufw allow $SSH_PORT
	#ufw enable

	#iptables
	iptables -A INPUT -p tcp -m tcp --dport 22 -m state --state NEW -m recent --set --name SSH --mask 255.255.255.255 --rsource
	iptables -A INPUT -p tcp -m tcp --dport 22 -m state --state NEW -m recent --update --seconds 600 --hitcount 5 --rttl --name SSH --mask 255.255.255.255 --rsource -j DROP
	iptables -A INPUT -p tcp -m tcp --dport 22 -j ACCEPT
	iptables -A INPUT -s 101.251.197.238/32 -p tcp -m tcp --dport 22 -j REJECT --reject-with icmp-host-prohibited
	iptables -A INPUT -s 118.0.0.0/8        -p tcp -m tcp --dport 22 -j REJECT --reject-with icmp-host-prohibited
	iptables -A INPUT -s 119.0.0.0/9        -p tcp -m tcp --dport 22 -j REJECT --reject-with icmp-host-prohibited

	RULES_DST="/etc/iptables.rules"
	RULES_BIN="/etc/network/if-pre-up.d/network.sh"
	iptables-save > $RULES_DST

	cat <<- EOT > $RULES_BIN
	#!/bin/sh
	/sbin/iptables-restore < $RULES_DST
	EOT

	chmod +x $RULES_BIN
fi

#####################################################################
#####################################################################
if [[ ! -z "$DO_WLAN" ]]; then
	WPA_CONF='wpa-supplicant.conf'

	cat <<- 'EOT' > $WPA_CONF
	country=DE
	ctrl_interface=DIR=/var/run/wpa_supplicant GROUP=netdev
	update_config=1
	network={
     ssid="Pfotenweg";
     psk="bigmom86";
     key_mgmt=WPA-PSK
	}
	EOT

fi

#####################################################################
#####################################################################
if [[ ! -z "$DO_TOOLS" ]]; then
	insertPathFkts     '.bashrc'
	insertGenPasswdFkt '.bashrc'
fi

#####################################################################
#####################################################################
ETH0=$(ip addr | grep MULTICAST | head -1 | cut -d ' ' -f 2 | cut -d ':' -f 1)

if [[ ! -z "$DO_BIND" ]]; then
	function kvmCreateStatic() {
		local thePort=$1

		cat <<- 'EOT' > "/etc/network/interfaces.d/$thePort"
		# Configure bridge and give it a static ip
		iface $thePort inet static
		  address         192.168.0.10
		  broadcast       192.168.0.255
		  netmask         255.255.255.0
		  gateway         192.168.0.1
		  dns-nameservers 192.168.0.1
		  dns-search      192.168.0.1
		EOT
	}

	kvmCreateStatic $ETH0

	if [[ ! -f "/etc/hostname.old" ]];
		mv "/etc/hostname" "/etc/hostname.old"
	fi
	echo "$RASP_NAME" > /etc/hostname

	systemctl restart systemd-hostnamed
	#/etc/init.d/hostname.sh restart		# old !!!

	if ! grep -F -q "$RASP_NAME.local" /etc/hosts ; then
		echo "127.0.0.1 $RASP_NAME.local $RASP_NAME" >> /etc/hosts
	fi

	if [[ ! -f "/etc/host.conf.old" ]];
		mv "/etc/host.conf" "/etc/host.conf.old"
	fi
	echo 'order hosts,bind' > /etc/host.conf

	apt install bind9
	apt install bind9utils
	apt install dnsutils

	mkdir -p /var/cache/bind
	mkdir -p /var/log/named

	# 217.0.43.161
	# 217.0.43.177
	cat <<- 'EOT' >> '/etc/bind/named.conf.options'
	options {
	  directory "/var/cache/bind";
	  recursion yes;
	  allow-query { "acl_trusted_clients"; };
	  forwarders {
	    46.182.19.48;
	    84.200.69.80;
	    217.237.150.205;
	  };
	  dnssec-validation auto;
	  auth-nxdomain no;    # conform to RFC1035
	  listen-on-v6 { any; };
	};

	acl "acl_trusted_transfer" {
	  none;
	};

	acl "acl_trusted_clients" {
	  // localhost (RFC 3330) - Loopback-Device addresses
	  127.0.0.0/8;    // 127.0.0.0 - 127.255.255.255

	  // Private Network (RFC 1918) - LAN, WLAN etc.
	  192.168.0.0/24; // 192.168.0.0 - 192.168.0.255
	};
	EOT

	cat <<- 'EOT' >> '/etc/bind/named.conf.local'
	zone "local" {
	  type master;
	  file "/etc/bind/db.raspi";
	  allow-transfer { acl_trusted_transfer; };
	};

	zone "0.168.192.in-addr.arpa" {
	  notify no;
	  type master;
	  file "/etc/bind/rev.raspi";
	};
	EOT

	cat <<- 'EOT' > '/etc/bind/db.raspi'
	$TTL 3D
	@ IN SOA local. postmaster.local. (
	  0000000001      ;serial
	  3H              ;refresh
	  15M             ;retry
	  1W              ;expiry
	  1D )            ;minimum

	@ IN NS $RASP_NAME.local.
	  IN A  192.168.0.10
	$RASP_NAME IN A 192.168.0.10
	game       IN A 192.168.0.20
	work       IN A 192.168.0.30
	router     IN A 192.168.0.1
	EOT

	cat <<- 'EOT' > '/etc/bind/rev.raspi'
	$TTL 3D
	@ IN SOA local. postmaster.local. (
	  0000000001      ;serial
	  3H              ;refresh
	  15M             ;retry
	  1W              ;expiry
	  1H )            ;negative caching

	@ IN NS $RASP_NAME.local.

	10 IN PTR $RASP_NAME.local.
	20 IN PTR game.local.
	30 IN PTR work.local.
	1  IN PTR router.local.
	EOT

	chown bind:bind *.raspi

	cat <<- 'EOT' >> '/etc/bind/named.conf'

	logging {
	  channel query.log {
	    file "/var/lib/bind/bind_query.log" version 3 size 5m;
	    // set the severity to dynamic to see the debug messages
	    serverity dynamic;
	    print-time yes;
	  };
	  category queries {
	    query.log;
	  };
	};
	EOT

	systemctl enable  bind9
	systemctl restart bind9
fi

#####################################################################
#####################################################################
WWW_DIR='/var/www/html'

if [[ ! -z "$DO_APACHE" ]]; then

	apt install apache2
	apt install php libapache2-mod-php

	mv "$WWW_DIR/index.html" "$WWW_DIR/index.old"
	echo "<? phpinfo(); ?>" > "$WWW_DIR/index.php"

	systemctl enable apache2
fi

#####################################################################
#####################################################################
if [[ ! -z "$DO_MARIA" ]]; then
	if ! apt -qq list mariadb-server 2>/dev/null | grep installed ; then
		apt install mariadb-server
		apt install mariadb-client
		apt install php-mysql

		rebootNow
	fi

	echo "You need a phpmyadmin password!"
	continueNow

	apt install phpmyadmin

	echo "you need your root password"
	echo "Change the root password?              -> no"
	echo "Remove anonymous user?                 -> yes"
	echo "Disallow root login remotely?          -> yes"
	echo "Remove test database and access to it? -> no"
	echo "Reload privilege tables now?           -> yes"
	mysql_secure_installation

	echo ""                                    >> /etc/apache2/apache2.conf
	echo "Include /etc/phpmyadmin/apache.conf" >> /etc/apache2/apache2.conf

	systemctl restart apache2
fi

#####################################################################
#####################################################################
if [[ ! -z "$DO_NEXT_CLOUD" ]]; then
	apt install php-xml php-cli php-cgi php-mbstring php-gd php-curl php-zip

	systemctl restart apache2

	NEXT_DATA='nextdb'
	NEXT_USER='nextuser'
	NEXT_TEMP='/tmp/script.sql'

	echo -n "type your $NEXT_DATA db password for $NEXT_USER:"
	read -s NEXT_PW
	echo

	cat <<- EOT > $NEXT_TEMP
	CREATE DATABASE $NEXT_DATA;
	CREATE USER '$NEXT_USER'@'localhost' IDENTIFIED BY '$NEXT_PW';
	GRANT ALL ON $NEXT_DATA.* TO '$NEXT_USER'@'localhost';
	FLUSH PRIVILEGES;
	EOT

	mysql -u root -p < $NEXT_TEMP

	sudo -u $SUDO_USER wget -P Downloads "https://download.nextcloud.com/server/releases/latest.zip"
	sudo -u $SUDO_USER unzip Downloads/latest.zip -d $HOME_USER/nextcloud
	mv $HOME_USER/nextcloud $WWW_DIR
	chown -R www-data:www-data $WWW_DIR/nextcloud
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

	insertPathFkts     '.zshrc'
	insertGenPasswdFkt '.zshrc'

	logoutNow
fi

#####################################################################
#####################################################################
if [[ ! -z "$DO_TEST" ]]; then
	echo 'nothing here for now'
fi
