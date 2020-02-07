#!bin/bash
# get and install pihole
curl -sSL https://install.pi-hole.net | bash
# install dependencies
sudo apt install -y build-essential libssl-dev libtool m4 autoconf
sudo apt install -y libev4 libyaml-dev libidn11 libuv1 libevent-core-2.0.5
# Build Stubby
git clone https://github.com/getdnsapi/getdns.git
cd getdns
git checkout develop
git submodule update --init
libtoolize -ci
autoreconf -fi
mkdir build
cd build
../configure --prefix=/usr/local --without-libidn --without-libidn2 --enable-stub-only --with-ssl --with-stubby
make
sudo make install
# configure stubby.yml
cd ../stubby
cp stubby.yml.example stubby.yml
sed -i.bak '/  - 127.0.0.1/,/  -  0::1/{/  -  0::1/ s/.*/  -  127.0.2.2@2053\
  -  0::2@2053/; t; d}' stubby.yml
sudo /usr/bin/install -Dm644 stubby.yml /etc/stubby.yml
# configure stubby.service
cd systemd
echo ' ' > ./stubby.service
sed -i '$i [Unit]' ./stubby.service
sed -i '$i Description=stubby DNS resolver' ./stubby.service
sed -i '$i Wants=network-online.target' ./stubby.service
sed -i '$i After=network-online.target' ./stubby.service
sed -i '$i [Service]' ./stubby.service
sed -i '$i ExecStart=/usr/local/bin/stubby -C /etc/stubby.yml' ./stubby.service
sed -i '$i Restart=on-abort' ./stubby.service
sed -i '$i User=root' ./stubby.service
sed -i '$i [Install]' ./stubby.service
sed -i '$i WantedBy=multi-user.target' ./stubby.service 
# install stubby service
sudo /usr/bin/install -Dm644 stubby.conf /usr/lib/tmpfiles.d/stubby.conf
sudo /usr/bin/install -Dm644 stubby.service /lib/systemd/system/stubby.service
# edit host file
sudo sed -i '/127.0.2.2/d' /etc/hosts
sudo sed -i '/0::2/d' /etc/hosts
sudo sed -i '$i 127.0.2.2     Stubby' /etc/hosts
sudo sed -i '$i 0::2          Stubby-v6' /etc/hosts 
# add path to libgetdns library and running ldconfig
sudo sed -i '$i LD_LIBRARY_PATH=/lib:/usr/lib:/usr/local/lib' /etc/environment
sudo /sbin/ldconfig -v
# enable and run stubby service
sudo systemctl enable stubby
sudo systemctl start stubby
