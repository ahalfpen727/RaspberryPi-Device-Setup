# RaspberryPi-Device-Setup
scripts and resources to setup Raspberry Pis (0,2,3,A,B+) for network auditing

# Start Bluetooth
```
systemctl enable bluetooth
service bluetooth start
systemctl enable hciuart
systemctl start hciuart.service
```
# Simplified Configuration of Raspberry Pi's Running Kali
```
apt install whiptail parted lua5.1 alsa-utils psmisc
wget -O /usr/local/bin/kalipi-config https://raw.githubusercontent.com/Re4son/RPi-Tweaks/master/kalipi-config/kalipi-config
chmod 755 /usr/local/bin/kalipi-config
```
# Enable Autologin on Re4son
```
cd /usr/local/src/re4son-kernel_4*
sudo ./re4son-pi-tft-setup -a pi
```
# To change it back, just run:
```
cd /usr/local/src/re4son-kernel_4*
sudo ./re4son-pi-tft-setup -a disable
```
# Install and Configure Snort
```
sudo bash
apt install apache2 apache2-doc autoconf automake bison ca-certificates ethtool flex g++ gcc libapache2-mod-php libcrypt-ssleay-perl default-libmysqlclient-dev libnet1 libnet1-dev libpcre3 libpcre3-dev libpcap-dev libphp-adodb libssl-dev libtool libwww-perl make default-mysql-client mysql-common default-mysql-server php-cli php-gd php-mysql php-pear sysstatcd /usr/local/src
wget https://libdnet.googlecode.com/files/libdnet-1.12.tgz
wget https://www.snort.org/downloads/snort/daq-2.0.6.tar.gz
wget https://www.snort.org/downloads/snort/snort-2.9.8.2.tar.gz
tar xvfvz libdnet-1.12.tgz
cd libdnet-1.12
./configure "CFLAGS=-fPIC"
make && make install && make check
ln -s /usr/local/lib/libdnet.1.0.1 /usr/lib/libdnet.1

cd /usr/local/src
tar xvfz daq-2.0.6.tar.gz
cd daq-2.0.6
./configure
make && make install

cd /usr/local/src && wget --no-check-certificate https://www.snort.org/documents/185 -O snort.conf
tar xvfz snort-2.9.8.2.tar.gz
cd snort-2.9.8.2
./configure --enable-sourcefire; make; sudo make install

mkdir /usr/local/etc/snort /usr/local/etc/snort/rules /var/log/snort /var/log/barnyard2 /usr/local/lib/snort_dynamicrules
touch /usr/local/etc/snort/rules/white_list.rules /usr/local/etc/snort/rules/black_list.rules /usr/local/etc/snort/sid-msg.map

groupadd snort && useradd -g snort snort

cp /usr/local/src/snort-2.9.8.2/etc/*.conf* /usr/local/etc/snort
cp /usr/local/src/snort-2.9.8.2/etc/*.map /usr/local/etc/snort
cp /usr/local/src/snort.conf /usr/local/etc/snort
mkdir /var/log/snort
chown snort:snort /var/log/snort
```
# Change these snort config variables in ...
```
nano /usr/local/etc/snort/snort.conf
var RULE_PATH ../rules
var SO_RULE_PATH ../so_rules
var PREPROC_RULE_PATH ../preproc_rules
var WHITE_LIST_PATH ../rules
var BLACK_LIST_PATH ../rules
```
# TO
```
var RULE_PATH rules
var SO_RULE_PATH so_rules
var PREPROC_RULE_PATH preproc_rules
var WHITE_LIST_PATH rules
var BLACK_LIST_PATH rules
```
# delete or comment out all of the “include $RULE_PATH” lines except “local.rules”
```
vi /usr/local/etc/snort/rules/local.rules
```
# Enter a simple rule like this for testing:
```
alert icmp any any -> $HOME_NET any (msg:"ICMP test"; sid:10000001; rev:1;)
```
# test snort.
```
/usr/local/bin/snort -A console -q -u snort -g snort -c /usr/local/etc/snort/snort.conf -i eth0
```
