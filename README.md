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

Other useful Commands
``` 
Run these proc directory commands to uncover other hardware information.

    cat /proc/meminfo displays details about the Raspberry Pi’s memory.
    cat /proc/partitions reveals the size and number of partitions on your SD card or HDD.
    cat /proc/version shows you which version of the Pi you are using.

Check the current Linux versions

Use these commands to assess what your Raspberry Pi might be capable of. It doesn’t end there. Find further information using the vcgencmd series of commands:

    vcgencmd measure_temp reveals the CPU temperature (vital if you’re concerned about airflow).
    vcgencmd get_mem arm && vcgencmd get_mem gpu will reveal the memory split between the CPU and GPU, which can be adjusted in the config screen.
    free -o -h will display the available system memory.
    top d1 checks the load on your CPU, displaying details for all cores.
    df -h is a great way to quickly check the free disk space on your Raspberry Pi.

How much free space does your Raspberry Pi's SD card have?

    uptime is a simple command that displays the Raspberry Pi’s load average.

3 Commands to Check Connected Devices

Just as you can list the contents of a directory with a single command, Linux lets you list devices connected to your computer.

    ls /dev/sda* displays a list of partitions on the SD card. For a Raspberry Pi with a HDD attached, substitute sda* with hda*.
    lsusb displays all attached USB devices. This is crucial for connecting a hard disk drive or other USB hardware that requires configuration.

Use lsusb to learn about USB devices connected to the Raspberry Pi

If the item is listed here, you should be able to set it up.

    lsblk is another list command you can use. This displays information about all attached block devices (storage that reads and writes in blocks)
```