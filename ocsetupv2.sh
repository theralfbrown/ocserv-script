#!/bin/bash

# ___________________________________FOR DEBIAN 8 (dont forget to comment debian 7) ____________________________________#

function debian_8(){
rm /etc/apt/sources.list
cat << _EOF_ > /etc/apt/sources.list
deb http://httpredir.debian.org/debian jessie main
deb-src http://httpredir.debian.org/debian jessie main

deb http://httpredir.debian.org/debian jessie-updates main
deb-src http://httpredir.debian.org/debian jessie-updates main

deb http://security.debian.org/ jessie/updates main
deb-src http://security.debian.org/ jessie/updates main
# backport
deb http://ftp.debian.org/debian jessie-backports main contrib non-free
_EOF_
}

# ___________________________________FOR DEBIAN 7 (dont forget to comment debian 8)____________________________________#

function debian_7(){
rm /etc/apt/sources.list
cat << _EOF_ > /etc/apt/sources.list
deb http://ftp.debian.org/debian stable main contrib non-free
deb-src http://ftp.debian.org/debian stable main contrib non-free

deb http://ftp.debian.org/debian/ wheezy-updates main contrib non-free
deb-src http://ftp.debian.org/debian/ wheezy-updates main contrib non-free

deb http://security.debian.org/ wheezy/updates main contrib non-free
deb-src http://security.debian.org/ wheezy/updates main contrib non-free

# #backport
deb http://ftp.debian.org/debian wheezy-backports main contrib non-free
_EOF_
}


# ------------------ GET AND INSTALL----------------------#
function get_essential(){
apt-get update
apt-get install build-essential
apt-get install libgnutls28-dev libwrap0-dev libpam0g-dev libseccomp-dev libnl-route-3-dev libev4 libev-dev openssl autogen
apt-get install libgmp3-dev m4 gcc pkg-config make gnutls-bin libreadline-dev curl libprotobuf-c0-dev protobuf-c-compiler
apt-get install gperf libdbus-1-dev libopts25-dev libnl-nf-3-dev libpcl1-dev libtalloc-dev liboath-dev
}

# Get OCServ
function get_oc_install(){
#oc_version_latest=$(curl -s "http://www.infradead.org/ocserv/download.html" | sed -n 's/^.*version is <b>\(.*$\)/\1/p')
wget ftp://ftp.infradead.org/pub/ocserv/ocserv-0.10.8.tar.xz
tar xvf ocserv-0.10.8.tar.xz
cd ocserv-0.10.8
./configure
make
make install
}

function certificate(){
FQDN=$(wget -qO- ipv4.icanhazip.com)
ORG_NAME=$FQDN
certtool --generate-privkey --outfile ca-key.pem 
echo "cn = $FQDN" > ca.tmpl
echo "organization = $ORG_NAME" >> ca.tmpl
echo "serial = 1" >> ca.tmpl
echo "expiration_days = 3650" >> ca.tmpl
echo "ca" >> ca.tmpl
echo "signing_key" >> ca.tmpl
echo "cert_signing_key" >> ca.tmpl
echo "crl_signing_key">> ca.tmpl
certtool --generate-self-signed --load-privkey ca-key.pem --template ca.tmpl --outfile ca-cert.pem
echo "cn = $FQDN" > server.tmpl
echo "organization = $ORG_NAME" >> server.tmpl
echo "expiration_days = 3650" >> server.tmpl
echo "signing_key" >> server.tmpl
echo "encryption_key" >> server.tmpl
echo "tls_www_server" >> server.tmpl
certtool --generate-privkey --outfile server-key.pem
echo "**********  server-key.pem**************"
certtool --generate-certificate --load-privkey server-key.pem --load-ca-certificate ca-cert.pem --load-ca-privkey ca-key.pem --template server.tmpl --outfile server-cert.pem
echo "*******************server-cert.pem *******************"
echo "crl_next_update = 999" >crl.tmpl
echo "crl_number = 1">>crl.tmpl
echo "************ crl.tmpl **************"
mkdir /etc/ocserv/
mkdir /etc/ocserv/ssl
cp server-cert.pem /etc/ocserv/ssl/
cp server-key.pem /etc/ocserv/ssl/
}


#-----------------auto conf making ---------------------------#
function conf_creation(){
cat << _EOF_ > /etc/ocserv/ocserv.conf
auth = "plain[/etc/ocserv/ocpasswd]"
tcp-port = 999
udp-port = 999
run-as-user = nobody
run-as-group = daemon
socket-file = /var/run/ocserv-socket
server-cert = /etc/ocserv/ssl/server-cert.pem
server-key = /etc/ocserv/ssl/server-key.pem
isolate-workers = true
max-clients = 16
max-same-clients = 1
keepalive = 300
dpd = 10
try-mtu-discovery = true
cert-user-oid = 0.9.2342.19200300.100.1.1
tls-priorities = "NORMAL:%SERVER_PRECEDENCE:%COMPAT:-VERS-SSL3.0"
auth-timeout = 40
# Set to zero to disable.
max-ban-score = 50
# The time (in seconds) that all score kept for a client is reset.
ban-reset-time = 300
cookie-timeout = 300
deny-roaming = false
rekey-time = 172800
rekey-method = ssl
use-occtl = true
pid-file = /var/run/ocserv.pid
device = vpns
predictable-ips = true
default-domain = example.com
ipv4-network = 10.10.10.0
ipv4-netmask = 255.255.255.0
dns = 8.8.8.8
dns = 4.2.2.4
ping-leases = false
cisco-client-compat = true
_EOF_
}

function iptable_rules(){
sysctl -w net.ipv4.ip_forward=1
sysctl -p
iptables -I FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu
iptables -t nat -A POSTROUTING -s 10.10.10.0/24 -o eth0 -j MASQUERADE
iptables -A FORWARD -s 10.10.10.0/24 -j ACCEPT
iptables -I INPUT -p tcp --dport 999 -j ACCEPT
iptables -I INPUT -p udp --dport 999 -j ACCEPT
}


function user_add(){
read -p "Enter username : " username
read -p "Enter password : " password
echo $password | ocpasswd -c /etc/ocserv/ocpasswd $username
}

function title(){
clear
echo "##############################_______OC SERVE V2 ________###################################"
}

function help_(){
echo "USAGE :"
echo "ocsetup.sh {(-i)nstall|(-u)ser|start|stop|(-s)tatus|(-h)elp}"
}

function start(){
iptable_rules
ocserv -c /etc/ocserv/ocserv.conf
}


function stop(){
/etc/init.d/ocserv stop
pkill ocserv
iptables -F
echo "OCserv STOPED"
}

function status(){
if [[ -f /run/ocserv.pid ]]; then
echo "OCserv in running"
elif [[ ! -f /run/ocserv.pid ]]; then
echo "OCserv in NOT running"
fi
}

function get_os_info(){
read -p "Enter Debian root version ( 7 or 8 ) : " os_version
}


#initsh
action=$1
[  -z $1 ] && action=help
case "$action" in
install | -i)
clear
title
get_os_info
if [[ $os_version="7" ]]; then
	debian_7
elif [[ $os_version="8" ]]; then
	debian_8
fi
get_essential
get_oc_install
certificate
clear
conf_creation
clear
title
echo "OCServ install Successfully"
    ;;
stop)
clear
title
stop
echo "OCserv NOW STOPED"
    ;;
start)
clear
title
start
echo "OCserv NOW STARTED"
    ;;
status | -s)
clear
title
status
    ;;
user | -u)
clear
title
user_add
    ;;
help | -h)
clear
help_
    ;;
*)
clear
help_
    ;;
esac
exit 0
