$script = <<SCRIPT
sudo apt-get install dnsmasq
sudo echo "interface=enp0s8\ndhcp-range=enp0s8,192.168.0.100,192.168.0.199,4h" >> /etc/dnsmasq.conf
sudo systemctl restart dnsmasq.service
SCRIPT

Vagrant.configure("2") do |config|
  config.vm.box = "ubuntu/zesty64"
  config.vm.network "public_network", ip: "192.168.0.17", bridge: "en7: Belkin USB-C LAN"
  config.vm.provision "shell", inline: $script
end
