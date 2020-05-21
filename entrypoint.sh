#!/bin/bash

echo "Kernel: $(/linux/linux --version)"
echo
echo "Configuration: MEM=$MEM"
echo "Command: $*"

#start sshd
/etc/init.d/ssh start >> /tmp/setup.log 2>&1

# verify TMPDIR configuration
if [ $(stat --file-system --format=%T $TMPDIR) != tmpfs ]; then
    echo "For better performance, consider mounting a tmpfs on $TMPDIR like this: \`docker run --tmpfs $TMPDIR:rw,nosuid,nodev,exec,size=8g\`"
fi

# start uml in the background
echo 'starting uml'
/kernel.sh >> /tmp/kernel.log 2>&1 &

echo -n 'waiting for sshd'
for i in {1..60}; do
	if ssh -o StrictHostKeyChecking=no -p 8022 root@127.0.0.1 true 2>/dev/null >/dev/null; then
		echo ''
		echo "running command: $(sh -c "echo $*")"
		stty sane 2> /dev/null
		sh -c "$*"
		echo "halting uml"
		ssh -o StrictHostKeyChecking=no -p 8022 root@127.0.0.1 /sbin/halt -f
		wait # wait for kernel to exit
		exit 0
	fi
	sleep 1
	echo -n '.'
done

echo "timeout waiting for sshd"
echo "----- setup log:"
cat /tmp/setup.log
echo "----- kernel log:"
cat /tmp/kernel.log
exit 1

