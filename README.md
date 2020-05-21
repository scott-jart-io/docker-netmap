# docker-netmap
Dockerfile and scripts to build an Ubuntu 20.04-based, [netmap](http://info.iet.unipi.it/~luigi/netmap/)-capable Docker image.

Derived from the wonderful [diuid](https://github.com/weber-software/diuid).

Build:
```
git clone https://github.com/scott-jart-io/docker-netmap.git
cd docker-netmap
make
```
Run:
```
docker run --rm -it io.jart.focal-netmap:1.0
```
A shell will launch in a [User-mode Linux](http://user-mode-linux.sourceforge.net/) environment configured with netmap and [veth](http://man7.org/linux/man-pages/man4/veth.4.html) drivers. The environment will have a pre-configured veth pair with veth2 in the primary [network namespace](http://man7.org/linux/man-pages/man8/ip-netns.8.html) and its peer, veth1, in network namespace `veth1-ns`.

This setup is designed to make it easy to experiment with netmap without needing to install netmap in your local environment, set up a [VirtualBox](https://www.virtualbox.org/) or [Vagrant](https://www.vagrantup.com/) , or similar.

It is not designed to show off netmap's high performance as the setup itself is quite inefficient.

An incredibly simple demonstration script is provided that runs a netmap bridge (using the `bridge` app) between the nic and host (sw) queues of `veth1` from within the `veth1-ns` namespace, and uses [`socat`](https://linux.die.net/man/1/socat) to send a line of text through the bridge to `veth2` in the primary namespace.

Demo:
```
./bridge-test.sh
```
Result:
```
waiting for connection... (about 5s)
hello from netmap!
```

Exciting, right?