# P4wnP1 on raspberry pi zero w
# https://p4wnp1.readthedocs.io/en/latest/Getting-Started-Subfolder/Installation/

> ifconfig usb0 up
# enable static ip
> ifconfig usb0 192.168.0.1
# Important:
```
If the interface usb0 isn't configured to manual setup, it is likely that a DHCP client is running. Trying to retreive a DHCP lease would wipe the IP configuration done in step 10 (ending up with Internet connection loss at some later point). The quick and dirty way to circumvent this on Kali, is to stop the network manager service with 
```
> service network-manager stop
> iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE
> echo 1 > /proc/sys/net/ipv4/ip_forward

# ssh into pi and run the following command remotely
> route add -net default gw 169.254.241.1

> echo nameserver 8.8.8.8 > /etc/resolv.conf
> cd /home/pi
> git clone --recursive https://github.com/mame82/P4wnP1
> cd P4wnP1
> ./install.sh

> sudo update-rc.d ssh enable
> systsystemctl enable bluetooth && systemctl enable hciuart
