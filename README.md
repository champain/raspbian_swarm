# Raspberry PI swarm
This repository is designed to hold the work around a cluster of Raspberry Pis
configured to run [Docker swarm](https://docs.docker.com/engine/swarm/) in 
a way that deploys a visualizer and a slack bot that will generate
docker services designed to create Latin squares. For more information
on what Latin squares are, and why they're interesting, check out 
[this talk](https://youtu.be/VgNN8iokc54) from [Dave Bock](https://github.com/bokmann).

## Initial Setup

The default [method](https://www.raspberrypi.org/documentation/installation/installing-images/README.md) of writing the OS image
to the microSD card can be used. The only differences
are that SSH must be enabled. So the user will need to
mount the microSD card once it's been written, and touch a
file called `ssh` in the `/boot` directory.
In OS X, this booting takes place automatically once
the card is written, and can be performed as
```
touch /Volumes/boot/ssh
```

Once SSH is enabled, eject the microSD and install it
in the powered-down Pi. Do this for all of the Pis at once
for best results.

### Networking
Many attempts were made to get this to work over WiFi, but there
are really too many variables with WiFi, and we happened to have
a relatively isolated ethernet-based network to work with.
All of the Pis out of necessity should be plugged into a multiport
unmanaged switch, and that switch should be plugged into a network with
a router running DHCP. This is not too different from the vast majority
of user networks out there, including most simple home networks.

Once the Pis are connected, be sure to connect a laptop running
Avahi discovery to the switch as well.

### Powering on
Once the Pis are all connected via the switch, and have their microSD
cards installed, they are ready for power. Power them on one at a time,
and make sure that both the switch and the Pis themselves show activity
on their respective LEDs.

## Auto-discovery
All of the Pis running Raspbian come with Avahi
[enabled by default](http://elinux.org/RPi_Advanced_Setup).
I wouldn't call this type of advertisement particularly secure or
useful for production environments, but I think it works in this case.

When a Raspberry Pi comes online with Raspbian installed,
it will announce itself as `raspberrypi.local` on the network
to anything with the ability to listen for Avahi. With a laptop
running OS X, a user can simply connect the laptop to the switch
and `ssh pi@raspberrypi.local` to get
started.

## The almighty setup.sh
In this repo, the setup.sh is the next important aspect of getting
started. Before ansible can be run, this script must be run
on the Pi intended to be the master `raspberrypi.local`.

This script does several things including dependency resolution,
installing Ansible, and ansible-vault, and finally setting up
ssh keys that the master will use to connect to the hosts later.

Be sure to run this script on the master prior running any
ansible commands. After ansible is run, this command
adds the SSH keys to `ssh-agent` so that a user can
ssh from the master to any of its worker nodes, now that
Ansible has disabled password authentication for all nodes
except for the master.

## Running ansible

The first time ansible is run, the user will need to 
make sure to create the ansible-vault file, or provide
the ansible-vault credentials. Please contact the author
for credentials. Once the `setup.sh` has been run, 
and the user is in the appropriate virtualenv,
run the following command:

```
ansible-playbook -i inventory playbooks/main.yml -k --ask-vault-pass
```

Subsequent runs of the playbook will be possible without the
`-k` flag.


## Bugs!
There is a bug with the way ARM processors present themselves
to docker, so the admin needs to be careful to select
an image with the proper architecture. There is 
[discussion](https://github.com/docker/swarmkit/issues/2294)
about this on github that applies directly
to docker on Raspberry PI.

For now, the workaround appears to be to use
the flag `--no-resolve-image` along with the service creation
command.

This has the really terrible effect of not being
able to automatically deploy updates to the
docker services running, and it means that
any time docker creates a service, it will use the
latest image on the host it runs, not the latest
image from the Docker hub.

We work around that in the worst way possible -
running a cron to update images we need.


## Notes

### Here's how viz was deployed

```bash
docker service create \
        --no-resolve-image \
        --detach=False \
        --name viz \
        --publish 8080:8080/tcp \
        --constraint node.role==manager \
        --mount type=bind,src=/var/run/docker.sock,dst=/var/run/docker.sock \
        alexellis2/visualizer-arm:latest
```


### Build and push the image for the Crystal script
First you need to install Crystal on an arm machine like a Pi

```bash
echo "deb http://public.portalier.com raspbian/" > /etc/apt/sources.list.d/crystal.list
curl "http://public.portalier.com/raspbian/julien%40portalier.com-005faf9e.pub" | sudo apt-key add -
sudo apt-get update
sudo apt-get install crystal
```

Once Crystal is installed, a binary of `build/mols.cr` needs to be built
```bash
cd build
crystal build mols2.cr
```

### Docker service create command
This docker service launches the latin squares script, and accepts two arguments as parameters
0 - the order or size of the square the user would like found
1 - the full URL to the incoming webhook for slack integration.

```bash
docker service create \
--constraint node.role==worker
--limit-cpu 2.5 \
--no-resolve-image \
--name latin_squares champain/latin_squares:mols_bot \
10 https://hooks.slack.com/services/<slack token here>
```
