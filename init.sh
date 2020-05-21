#!/bin/bash
set -xu

mount -t proc proc /proc/
mount -t sysfs sys /sys/
mount -t tmpfs none /run
mkdir /dev/pts
mount -t devpts devpts /dev/pts
rm /dev/ptmx
ln -s /dev/pts/ptmx /dev/ptmx

rngd -r /dev/urandom

ifconfig lo up
ifconfig eth0 10.0.2.15 up
route add default dev eth0
if [ -f /root/netmap/netmap.ko ]; then
# TODO -- patched veth doesn't work
  insmod /root/netmap/netmap.ko generic_txqdisc=1 admode=2
  insmod /root/netmap/veth.ko
fi

# https://gist.github.com/dpino/6c0dca1742093346461e11aa8f608a99

IFACE="eth0"
NS="veth1-ns"
VETH="veth2"
VPEER="veth1"
VETH_ADDR="10.200.1.1"
VPEER_ADDR="10.200.1.2"

# Remove namespace if it exists.
ip netns del $NS &>/dev/null

# Create namespace
ip netns add $NS

# Create veth link.
ip link add ${VETH} type veth peer name ${VPEER}

# Add peer-1 to NS.
ip link set ${VPEER} netns $NS

# Setup IP address of ${VETH}.
ip addr add ${VETH_ADDR}/24 dev ${VETH}
ip link set ${VETH} up

# Setup IP ${VPEER}.
ip netns exec $NS ip addr add ${VPEER_ADDR}/24 dev ${VPEER}
ip netns exec $NS ip link set ${VPEER} up
ip netns exec $NS ip link set lo up
ip netns exec $NS ip route add default via ${VETH_ADDR}

# Enable IP-forwarding.
echo 1 > /proc/sys/net/ipv4/ip_forward

# Flush forward rules.
iptables -P FORWARD DROP
iptables -F FORWARD
 
# Flush nat rules.
iptables -t nat -F

# Enable masquerading of 10.200.1.0.
iptables -t nat -A POSTROUTING -s ${VPEER_ADDR}/24 -o ${IFACE} -j MASQUERADE
 
iptables -A FORWARD -i ${IFACE} -o ${VETH} -j ACCEPT
iptables -A FORWARD -o ${IFACE} -i ${VETH} -j ACCEPT

/sbin/sysctl -w net.ipv6.conf.${VETH}.disable_ipv6=1 > /dev/null
ip netns exec $NS /sbin/sysctl -w net.ipv6.conf.${VPEER}.disable_ipv6=1 > /dev/null

/sbin/ethtool -K ${VETH} tx off rx off gso off tso off gro off lro off 2> /dev/null
ip netns exec $NS /sbin/ethtool -K ${VPEER} tx off rx off gso off tso off gro off lro off 2> /dev/null

/etc/init.d/cgroupfs-mount start
/etc/init.d/ssh start

#connect to the parent docker container for reverse forwarding of the docker socket
ssh -f -N -o StrictHostKeyChecking=no \
    -R0.0.0.0:8022:127.0.0.1:22 \
    10.0.2.2

while /etc/init.d/ssh status; do
  sleep 60
done

/sbin/halt -f
