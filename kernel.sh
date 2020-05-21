#!/bin/bash
exec /linux/linux rootfstype=hostfs rw eth0=slirp,,slirp-fullbolt mem=$MEM init=/init.sh
