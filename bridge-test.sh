#!/bin/sh
ip netns exec veth1-ns sh -c './bridge-send.sh &'
echo 'waiting for connection... (about 5s)'
socat - tcp4-listen:5555,reuseaddr

