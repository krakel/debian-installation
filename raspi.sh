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
  ssl       Apache 2 SSL Certificate
  lets      Apache 2 SSL Certificate with LetsEncrypt
  bind      bind9 dns service
  maria     database configuration
  next      next cloud
  git       git server'
}

declare -A SELECT=(
	[apache]=DO_APACHE
	[bind]=DO_BIND
	[flash]=DO_FLASH
	[git]=DO_GIT
	[lets]=DO_LETS_ENCRYPT
	[maria]=DO_MARIA
	[next]=DO_NEXT_CLOUD
	[ohmyz]=DO_OHMYZ
	[src]=DO_SOURCE
	[ssd]=DO_SSD
	[ssh]=DO_SSH
	[ssl]=DO_SSL
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

THIS_NAME=rasp1
THIS_IP=192.168.2.10
THIS_DEF=192.168.2.1
THIS_DOMAIN=at-home

MY_DOMAIN=imhaus.ddns.net

SUDO_USER=$(logname)
HOME_USER="/home/$SUDO_USER"

cd $HOME_USER

if [[ $(id -u) != 0 ]]; then
	 echo
	 echo 'Ups, I am not root!'
	 exit 1
fi

#####################################################################
## some functions
#####################################################################
function logoutNow() {
	echo
	echo -n 'You need to logout now!'
	read
	exit
}

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

function addSudoComplete() {
	if ! grep -F -q 'complete -cf sudo' $1 ; then
		cat <<- 'EOT' | sudo -u $SUDO_USER tee -a $1 > /dev/null
			if [ "$PS1" ]; then
			  complete -cf sudo
			fi
		EOT
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

	usermod -aG sudo $NEW_USER
	sed -i "s/^SUDO_USER .*/$NEW_USER ALL=(ALL:ALL) ALL/" /etc/sudoers

	sudo -u $NEW_USER cp -rf /home/$SUDO_USER/* /home/$NEW_USER

#	deluser $SUDO_USER sudo
	echo "execute: userdel --remove $SUDO_USER"

	logoutNow
fi

#####################################################################
#####################################################################
if [[ ! -z "$DO_FLASH" ]]; then
	EEPROM=/etc/default/rpi-eeprom-update
	BOOT_LDR=/lib/firmware/raspberrypi/bootloader/stable

	apt install rpi-eeprom

	if [[ ! -f "$EEPROM.old" ]]; then
		mv "$EEPROM" "$EEPROM.old"
	fi
	echo 'FIRMWARE_RELEASE_STATUS="stable"' > $EEPROM

	vcgencmd bootloader_version
	vcgencmd bootloader_config
	echo

	ls -al $BOOT_LDR

	BOOT_DRV=$(ls -t $BOOT_LDR/pieeprom*.bin 2>/dev/null | tail -1)
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

	if [[ ! -f "$SSH_CONF.old" ]]; then
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

		#AllowGroups ssh
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
	#sed -i "s/^.?ignoreip.*/ignoreip 127.0.0.1/32 192.168.2.16/28" $F2B_CONF
	#systemctl restart fail2ban

	#ufw status numbered
	#ufw allow $SSH_PORT
	#ufw enable

	#iptables
#	iptables -F
#	iptables -X
#	iptablex -P INPUT   DROP
#	iptablex -P OUTPUT  DROP
#	iptablex -P FORWARD DROP
#	iptables -A INPUT  -i lo -j ACCEPT
#	iptables -A OUTPUT -i lo -j ACCEPT
	iptables -A INPUT -p tcp -m tcp --dport 22           -m state --state NEW -m recent --set    --name SSH --mask 255.255.255.255 --rsource
	iptables -A INPUT -p tcp -m tcp --dport 22 -j DROP   -m state --state NEW -m recent --update --name SSH --mask 255.255.255.255 --rsource --seconds 600 --hitcount 5 --rttl
	iptables -A INPUT -p tcp -m tcp --dport 22 -j ACCEPT
	iptables -A INPUT -p tcp -m tcp --dport 22 -j REJECT -s 101.251.197.238/32 --reject-with icmp-host-prohibited
	iptables -A INPUT -p tcp -m tcp --dport 22 -j REJECT -s 118.0.0.0/8        --reject-with icmp-host-prohibited
	iptables -A INPUT -p tcp -m tcp --dport 22 -j REJECT -s 119.0.0.0/9        --reject-with icmp-host-prohibited

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
	insertPathFkts     '.profile'
	insertGenPasswdFkt '.profile'
	addSudoComplete    '.profile'

	dpkg-reconfigure tzdata

	apt install ntp
	systemctl enable ntp
	systemctl start  ntp
fi

#####################################################################
#####################################################################
ETH0=$(ip addr | grep MULTICAST | head -1 | cut -d ' ' -f 2 | cut -d ':' -f 1)

if [[ ! -z "$DO_BIND" ]]; then
	function netCreateStatic() {
		local thePort=$1

		cat <<- EOT > "/etc/network/interfaces.d/$thePort"
			auto $thePort

			# The primary network interface
			iface $thePort inet static
			  address         $THIS_IP
			  broadcast       192.168.2.255
			  netmask         255.255.255.0
			  gateway         $THIS_DEF
			  dns-nameservers 127.0.0.1
			  dns-search      $THIS_NAME.$THIS_DOMAIN
		EOT
	}

	netCreateStatic $ETH0

	systemctl stop    dhcpcd
	systemctl disable dhcpcd

	if [[ ! -f "/etc/hostname.old" ]]; then
		mv "/etc/hostname" "/etc/hostname.old"
	fi
	echo "$THIS_NAME" > /etc/hostname

	systemctl restart systemd-hostnamed
	#/etc/init.d/hostname.sh restart		# old !!!

	HOST_FILE='/etc/hosts'
	if ! grep -F -q "$THIS_NAME.$THIS_DOMAIN" $HOST_FILE ; then
		sed -i 's|^127.0.0.1|d' $HOST_FILE
		echo "127.0.0.1 $THIS_NAME.$THIS_DOMAIN $THIS_NAME localhost" >> $HOST_FILE
	fi

	if [[ ! -f "/etc/host.conf.old" ]]; then
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
	cat <<- 'EOT' > '/etc/bind/named.conf.options'
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
		  192.168.2.0/24; // 192.168.2.0 - 192.168.2.255
		};
	EOT

	cat <<- EOT > '/etc/bind/named.conf.local'
		zone "$THIS_DOMAIN" {
		  type master;
		  file "/etc/bind/db.raspi";
		  allow-transfer { acl_trusted_transfer; };
		};

		zone "2.168.192.in-addr.arpa" {
		  notify no;
		  type master;
		  file "/etc/bind/rev.raspi";
		};
	EOT

	cat <<- EOT > '/etc/bind/db.raspi'
		$TTL 3D
		@ IN SOA $THIS_DOMAIN. postmaster.$THIS_DOMAIN. (
		  0000000001      ;serial
		  3H              ;refresh
		  15M             ;retry
		  1W              ;expiry
		  1D )            ;minimum

		@ IN NS $THIS_NAME.$THIS_DOMAIN.
		  IN A  $THIS_IP
		$THIS_NAME IN A $THIS_IP
		game       IN A 192.168.2.20
		router     IN A $THIS_DEF
	EOT

	cat <<- EOT > '/etc/bind/rev.raspi'
		$TTL 3D
		@ IN SOA $THIS_DOMAIN. postmaster.$THIS_DOMAIN. (
		  0000000001      ;serial
		  3H              ;refresh
		  15M             ;retry
		  1W              ;expiry
		  1H )            ;negative caching

		@ IN NS $THIS_NAME.$THIS_DOMAIN.

		10 IN PTR $THIS_NAME.$THIS_DOMAIN.
		20 IN PTR game.$THIS_DOMAIN.
		1  IN PTR router.$THIS_DOMAIN.
	EOT

	chown bind:bind *.raspi

	NAMED_CONF='/etc/bind/named.conf'
	if ! grep -F -q 'logging {' $NAMED_CONF ; then
		cat <<- 'EOT' >> $NAMED_CONF

			logging {
			  channel query.log {
			    file "/var/lib/bind/bind_query.log" versions 3 size 5m;
			    // set the severity to dynamic to see the debug messages
			    severity dynamic;
			    print-time yes;
			  };
			  category queries {
			    query.log;
			  };
			};
		EOT
	fi
	sed -i 's|^include "/etc/bind/named.conf.options";|#include "/etc/bind/named.conf.options";|' $NAMED_CONF
	sed -i 's|^include "/etc/bind/named.conf.local";|#include "/etc/bind/named.conf.local";|'     $NAMED_CONF

	systemctl enable  bind9
	systemctl restart bind9

	echo 'finished installation of Bind9'
fi

#####################################################################
#####################################################################
WWW_DIR='/var/www/html'

if [[ ! -z "$DO_APACHE" ]]; then

	apt install apache2
	apt install php libapache2-mod-php

	mv "$WWW_DIR/index.html" "$WWW_DIR/index.old"
	echo "<?php phpinfo(); ?>" > "$WWW_DIR/index.php"

	systemctl enable apache2
	systemctl start  apache2

	echo 'finished installation of apache2'
fi

#####################################################################
#####################################################################
if [[ ! -z "$DO_SSL" ]]; then
	SSL_CONF='/etc/apache2/ownssl'
	SSL_DEF='/etc/apache2/sites-available/default-ssl.conf'
	SSL_OLD='/etc/apache2/sites-old'

	mkdir -p $SSL_CONF
	openssl genrsa -out "$SSL_CONF/apachessl.pem"
	openssl req -new -key "$SSL_CONF/apachessl.pem" -out "$SSL_CONF/apachessl.csr" -sha512 -subj "/C=DE/ST=Bayern/OU=Private/CN=$THIS_IP"
	openssl x509 -days 365 -req -in "$SSL_CONF/apachessl.csr" -signkey "$SSL_CONF/apachessl.pem" -out "$SSL_CONF/apachessl.crt" -sha512

	mkdir -p $SSL_OLD
	if [[ ! -f "$SSL_OLD/default-ssl.conf" ]]; then
		cp "$SSL_DEF" "$SSL_OLD"
	fi

	sed -i "s|\s*#SSLEngine .*|		SSLEngine on|" $SSL_DEF
	sed -i "s|\s*SSLEngine .*|		SSLEngine on|"    $SSL_DEF
	sed -i "s|\s*SSLCertificateFile .*|		SSLCertificateFile    $SSL_CONF/apachessl.crt|"    $SSL_DEF
	sed -i "s|\s*SSLCertificateKeyFile .*|		SSLCertificateKeyFile $SSL_CONF/apachessl.pem|" $SSL_DEF

	a2enmod ssl
	a2ensite default-ssl

	systemctl restart apache2
	echo 'enabled ssl for apache2'
fi

#####################################################################
#####################################################################
if [[ ! -z "$DO_LETS_ENCRYPT" ]]; then
	apt install certbot
	apt install python3-pip

	echo 'add the txt records to your dns provider'
	certbot certonly --manual --preferred-challenge dns -d "*.$MY_DOMAIN" -d "$MY_DOMAIN"

	python3 -m pip install --use-feature=2020-resolver --upgrade pip
	python3 -m pip install --use-feature=2020-resolver setuptools
	python3 -m pip install --use-feature=2020-resolver acme==1.8.0  # <-- need update
	python3 -m pip install --use-feature=2020-resolver certbot-dns-nsone


	echo "open https://my.nsone.net and create a account"
	echo "add a zone with your domain $MY_DOMAIN"
	echo "create a new API key LetsEncryptKey"
	echo "deactivate all options except 'manage zone' and 'view zone'"
	echo "copy the API key"
	echo
	read -p "enter your api key:" -s API_KEY
	if [[ -z "$API_KEY" ]]; then
		echo "missing api key!!!"
		exit
	fi

	API_KEY_FILE='/root/api.key'
	echo "dns_nsone_api_key = $API_KEY" > $API_KEY_FILE
	chmod 600 $API_KEY_FILE

	certbot certonly --renew-by-default --dns-nsone --dns-nsone-credentials $API_KEY_FILE -d "*.$MY_DOMAIN" -d "$MY_DOMAIN" # --dry-run
#	certbot renew --quiet # --dry-run

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

	echo "you need your root password"
	echo "Change the root password?              -> no"
	echo "Remove anonymous user?                 -> yes"
	echo "Disallow root login remotely?          -> yes"
	echo "Remove test database and access to it? -> yes"
	echo "Reload privilege tables now?           -> yes"
	mysql_secure_installation

	#echo "You need a phpmyadmin password!"
	#continueNow
	#apt install phpmyadmin <-- not supported by debian anymore
	#echo ""                                    >> /etc/apache2/apache2.conf
	#echo "Include /etc/phpmyadmin/apache.conf" >> /etc/apache2/apache2.conf

	ADMINER_DIR='/etc/adminer'
	apt install adminer
	mkdir -p $ADMINER_DIR
	echo 'Alias /adminer /usr/share/adminer/adminer' | tee /etc/adminer/adminer.conf > /dev/null
	ln -s $ADMINER_DIR/adminer.conf /etc/apache2/conf-available/adminer.conf

	a2enconf adminer
	systemctl restart apache2
	echo 'finished installation of Maria DB'
fi

#####################################################################
#####################################################################
if [[ ! -z "$DO_NEXT_CLOUD" ]]; then
	apt install php-xml php-cli php-cgi php-mbstring php-gd php-curl php-zip

	systemctl restart apache2

	NEXT_DATA='nextdb'
	NEXT_USER='nextuser'
	NEXT_TEMP='/tmp/script.sql'

	echo -n "type your $NEXT_DATA password for $NEXT_USER:"
	read -s NEXT_PW
	echo

	cat <<- EOT > $NEXT_TEMP
		CREATE DATABASE $NEXT_DATA;
		CREATE USER '$NEXT_USER'@'localhost' IDENTIFIED BY '$NEXT_PW';
		GRANT ALL ON $NEXT_DATA.* TO '$NEXT_USER'@'localhost';
		FLUSH PRIVILEGES;
	EOT

	mysql -u root -p < $NEXT_TEMP

	if [[ ! -f "Downloads/nextcloud.zip" ]]; then
		sudo -u $SUDO_USER wget -P Downloads -O nextcloud.zip "https://download.nextcloud.com/server/releases/latest.zip"
	fi
	sudo -u $SUDO_USER unzip Downloads/nextcloud.zip -d $HOME_USER
	mv $HOME_USER/nextcloud $WWW_DIR
	chown -R www-data:www-data $WWW_DIR/nextcloud
	echo 'finished installation of next cloud'
fi

#####################################################################
#####################################################################
######### nice shell extension
# https://ohmyz.sh
if [[ ! -z "$DO_OHMYZ" ]]; then
	echo '######### install OHMYZ shell extension'
	apt install zsh
	apt install curl

	sudo -u $SUDO_USER bash -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
	sudo -u $SUDO_USER sed -i '0,/ZSH_THEME="[^"]*"/s//ZSH_THEME="robbyrussell"/' .zshrc     # ZSH_THEME="robbyrussell"
	sudo -u $SUDO_USER sort .bash_history | uniq | awk '{print ": :0:;"$0}' >> .zsh_history

	logoutNow
fi

#####################################################################
#####################################################################
######### Git
if [[ ! -z "$DO_GIT" ]]; then
	echo '######### install git server'
	apt install git

	sudo -u $SUDO_USER mkdir -p $HOME_USER/git
	cd $HOME_USER/git
	sudo -u $SUDO_USER git init --bare test

	# git remote add origin [email protected]:/home/git/repositories/test
	# git push origin master
	# git clone [email protected]Server-IP:/home/git/repositories/test
fi

#####################################################################
#####################################################################
if [[ ! -z "$DO_RESCUE" ]]; then
	echo '######### rescue a broken raspi'
	mkdir -p /rescue
	lsblk

	mount /dev/sda2 /rescue
	mount /dev/sda1 /rescue/boot

	mount -t proc   proc /rescue/proc
	mount -t sysfs  sys  /rescue/sys
	mount -o bind   /dev /rescue/dev
	mount -t devpts pts  /rescue/dev/pts

	chroot /rescue

	######################################

	#exit
	#umount /rescue/dev/pts
	#umount /rescue/dev
	#umount /rescue/sys
	#umount /rescue/proc
	
	#umount /rescue/boot
	#umount /rescue
fi

#####################################################################
#####################################################################
if [[ ! -z "$DO_TEST" ]]; then
	echo 'nothing here for now'
fi
