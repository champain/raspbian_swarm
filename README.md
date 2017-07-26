# Raspberry PI swarm
For starters, used dnsmasq on a vagrant machine to provision an IP
on the first machine.

# Net booting
Dunno if this is a good idea since all the pis
are going to attempt to boot their root fs off of
the master, and not their own SD card... for now.

Docs exist [here](https://github.com/raspberrypi/documentation/blob/master/hardware/raspberrypi/bootmodes/netboot_server_easy.md)
for ways to easily netboot some things

## Changes to net booting
I had a USB drive. We'll try to make that
the nfs mount point.

sudo systemctl stop dhcpcd.service
sudo systemctl disable dhcpcd.service
sudo /etc/init.d/networking restart
hostnamectl set-hostname mymachine
