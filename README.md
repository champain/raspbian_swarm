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

## Missing packages, to be updated
sudo apt-get install build-essential libssl-dev libffi-dev python-dev python-setuptools python-cffi ssh-pass


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

```bash
docker service create \
        --no-resolve-image \
        --detach=False \
        --name registry \
        --constraint node.role==manager \
        --publish 5000:5000/tcp \
        armbuild/registry:latest
```


## Build and push the image
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

Now that the binary exists, it can be distributed up to the Docker repo of choice
using the `Dockerfile` in the build dir which looks like this

```
FROM resin/rpi-raspbian
COPY mols2 /
CMD /mols2 10 100
```
The above last line can be edited to provide different parameters to `/mols2`.


From there, it's all a matter of building an image with a tag, and pushing
it to the repo of choice. Docker Hub has been used in this example

```bash
docker login
#Enter credentials here

docker image build -t latin_squares:10.100 .
docker tag latin_squares:10.100 champain/latin_squares:10.100
docker push champain/latin_squares:10.100
```
