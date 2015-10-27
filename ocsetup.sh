# <------------------------------ Enviroment Variables ------------------------------->
FQDN=ip of your server
ORG_NAME=organization name or ip of server
# <--------------------------------- Building --------------------------------------->

rm /etc/apt/sources.list

# ___________________________________FOR DEBIAN 8 (dont forget to comment debian 7) ____________________________________#

cat << _EOF_ > /etc/apt/sources.list
deb http://httpredir.debian.org/debian jessie main
deb-src http://httpredir.debian.org/debian jessie main

deb http://httpredir.debian.org/debian jessie-updates main
deb-src http://httpredir.debian.org/debian jessie-updates main

deb http://security.debian.org/ jessie/updates main
deb-src http://security.debian.org/ jessie/updates main
#backport
deb http://ftp.debian.org/debian jessie-backports main contrib non-free
_EOF_


# ___________________________________FOR DEBIAN 7 (dont forget to comment debian 8)____________________________________#

# cat << _EOF_ > /etc/apt/sources.list
# deb http://httpredir.debian.org/debian wheezy main
# deb-src http://httpredir.debian.org/debian wheezy main

# deb http://httpredir.debian.org/debian wheezy-updates main
# deb-src http://httpredir.debian.org/debian wheezy-updates main

# deb http://security.debian.org/ wheezy/updates main
# deb-src http://security.debian.org/ wheezy/updates main
# #backport
# deb http://ftp.debian.org/debian wheezy-backports main contrib non-free
# _EOF_


#echo "deb http://ftp.debian.org/debian jessie-backports main contrib non-free" | tee -a /etc/apt/sources.list

apt-get update
apt-get install build-essential
apt-get install libgnutls28-dev libwrap0-dev libpam0g-dev libseccomp-dev libnl-route-3-dev
apt-get install libgmp3-dev m4 gcc pkg-config make gnutls-bin libreadline-dev

# Get OCServ
wget ftp://ftp.infradead.org/pub/ocserv/ocserv-0.10.9.tar.xz
tar xvf ocserv-0.10.9.tar.xz
cd ocserv-0.10.9
./configure
make
make install

echo " ***************  make complete ***************"


# <------------------------------ Keypair Generation ------------------------------->

certtool --generate-privkey --outfile ca-key.pem 

echo "cn = $FQDN" > ca.tmpl
echo "organization = $ORG_NAME" >> ca.tmpl
echo "serial = 1" >> ca.tmpl
echo "expiration_days = 3650" >> ca.tmpl
echo "ca" >> ca.tmpl
echo "signing_key" >> ca.tmpl
echo "cert_signing_key" >> ca.tmpl
echo "crl_signing_key">> ca.tmpl

echo "*************** ca-key.pem & ca.tmpl ******************"

certtool --generate-self-signed --load-privkey ca-key.pem --template ca.tmpl --outfile ca-cert.pem

echo "cn = $FQDN" > server.tmpl
echo "organization = $ORG_NAME" >> server.tmpl
echo "expiration_days = 3650" >> server.tmpl
echo "signing_key" >> server.tmpl
echo "encryption_key" >> server.tmpl
echo "tls_www_server" >> server.tmpl

echo "********************ca-cert.pem & server.tmpl *******************"

certtool --generate-privkey --outfile server-key.pem
echo "**********  server-key.pem**************"
certtool --generate-certificate --load-privkey server-key.pem --load-ca-certificate ca-cert.pem --load-ca-privkey ca-key.pem --template server.tmpl --outfile server-cert.pem
echo "*******************server-cert.pem *******************"
echo "crl_next_update = 999" >crl.tmpl
echo "crl_number = 1">>crl.tmpl
echo "************ crl.tmpl **************"

mkdir /etc/ocserv
mkdir /etc/ocserv/ssl
cp server-cert.pem /etc/ocserv/ssl/
cp server-key.pem /etc/ocserv/ssl/

echo "************ copy cert compelete & make dir**************"


cat << _EOF_ > /etc/ocserv/ocserv.conf

auth = "plain[/etc/ocserv/ocpasswd]"


# TCP and UDP port number
tcp-port = 443
udp-port = 443

# The user the worker processes will be run as. It should be
# unique (no other services run as this user).
run-as-user = nobody
run-as-group = daemon

# socket file used for server IPC (worker-main), will be appended with .PID
# It must be accessible within the chroot environment (if any), so it is best
# specified relatively to the chroot directory.
socket-file = /var/run/ocserv-socket

server-cert = /etc/ocserv/ssl/server-cert.pem
server-key = /etc/ocserv/ssl/server-key.pem
#ca-cert = ../tests/ca.pem

# The performance cost is roughly 2% overhead at transfer time (tested on a Linux 3.17.8).
isolate-workers = true

# Limit the number of clients. Unset or set to zero for unlimited.
#max-clients = 1024
max-clients = 16

# Limit the number of identical clients (i.e., users connecting 
# multiple times). Unset or set to zero for unlimited.
max-same-clients = 2

# Keepalive in seconds
keepalive = 32400


dpd = 90

mobile-dpd = 1800

# MTU discovery (DPD must be enabled)
try-mtu-discovery = true

# The object identifier that will be used to read the user ID in the client 
# certificate. The object identifier should be part of the certificate's DN
# Useful OIDs are: 
#  CN = 2.5.4.3, UID = 0.9.2342.19200300.100.1.1
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

ipv4-network = 192.168.1.0
ipv4-netmask = 255.255.255.0

dns = 8.8.8.8
#dns = 4.2.2.4

ping-leases = false

#route = 10.10.10.0/255.255.255.0
#route = 192.168.0.0/255.255.0.0
#route = fef4:db8:1000:1001::/64
# Subsets of the routes above that will not be routed by
# the server.
#no-route = 192.168.5.0/255.255.255.0

cisco-client-compat = true

_EOF_


#confile
echo "***************** conf file maked *************************"


sysctl -w net.ipv4.ip_forward=1 && sysctl -p && iptables -I FORWARD -p tcp --tcp-flags SYN,RST SYN -j TCPMSS --clamp-mss-to-pmtu && iptables -t nat -A POSTROUTING -s 10.0.0.0/24 -o eth0 -j MASQUERADE && iptables -A FORWARD -s 10.0.0.0/24 -j ACCEPT && iptables -I INPUT -p tcp --dport 443 -j ACCEPT && iptables -I INPUT -p udp --dport 443 -j ACCEPT

echo "	now create login user as blew :"
echo "	(ocpasswd -c /etc/ocserv/ocpasswd <YOURDESIREDUSERNAME>)"
echo " ************ Every things are OK enjoy ocserv **************"
echo "	to start : ocserv -c /etc/ocserv/ocserv.conf"
