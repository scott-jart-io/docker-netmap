#!/bin/sh
netmap/build-apps/bridge/bridge -i netmap:veth1 2>> /tmp/bridge.log &
bridge_pid=$!
sleep 5
echo 'hello from netmap!' | socat - tcp4:10.200.1.1:5555
kill $bridge_pid
wait

