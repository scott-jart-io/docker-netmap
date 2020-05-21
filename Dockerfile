#ARG KERNEL_VERSION=4.19.123
ARG KERNEL_VERSION=5.3
ARG BASE=ubuntu:20.04

FROM $BASE AS kernel_build

RUN \
	apt-get update && \
	DEBIAN_FRONTEND=noninteractive apt-get install -y git fakeroot build-essential ncurses-dev xz-utils \
		libssl-dev bc wget flex bison libelf-dev && \
	DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends libarchive-tools

ARG KERNEL_VERSION

#RUN wget https://cdn.kernel.org/pub/linux/kernel/v4.x/linux-$KERNEL_VERSION.tar.xz && \
RUN wget https://cdn.kernel.org/pub/linux/kernel/v5.x/linux-$KERNEL_VERSION.tar.xz && \
	tar -xf linux-$KERNEL_VERSION.tar.xz

WORKDIR linux-$KERNEL_VERSION
COPY KERNEL.config .config
RUN mkdir /out
RUN make ARCH=um oldconfig && make ARCH=um prepare
RUN make ARCH=um -j `nproc`
RUN cp -f linux /out/linux
RUN cp -f drivers/net/veth.ko /out/.
RUN cp .config /KERNEL.config

RUN cd .. && \
	git clone https://github.com/luigirizzo/netmap.git && \
	cd netmap && \
	git checkout b316518f5174d13fccc1203a38dffea62e79a634 && \
	./configure --drivers=veth.c --apps=bridge --disable-ptnetmap --kernel-dir=../../linux-$KERNEL_VERSION --kernel-opts=ARCH=um && \
	make -j `nproc`
RUN cd .. && tar cfJ /out/netmap.txz netmap/*.ko netmap/build-apps

# usage: docker build -t foo --target print_config . && docker run -it --rm foo > KERNEL.config
FROM $BASE AS print_config
COPY --from=kernel_build /KERNEL.config /KERNEL.CONFIG
CMD ["cat", "/KERNEL.CONFIG"]

FROM $BASE

RUN \
	apt-get update && \
	DEBIAN_FRONTEND=noninteractive apt-get install -y wget net-tools cgroupfs-mount openssh-server psmisc \
	rng-tools apt-transport-https ca-certificates gnupg2 software-properties-common vim build-essential meson \
	ninja-build libglib2.0-dev cmake git kmod ethtool iproute2 iptables socat

RUN \
	mkdir /root/.ssh && \
	ssh-keygen -b 2048 -t rsa -f /root/.ssh/id_rsa -q -N "" && \
	cp /root/.ssh/id_rsa.pub /root/.ssh/authorized_keys

# install working slirp (ubuntu bionic package crashes)
RUN \
	wget http://ftp.us.debian.org/debian/pool/main/s/slirp/slirp_1.0.17-8_amd64.deb && \
	dpkg -i slirp_1.0.17-8_amd64.deb && \
	rm slirp_1.0.17-8_amd64.deb

WORKDIR /root

#install kernel and scripts
COPY --from=kernel_build /out/* /linux/
#install netmap build
RUN tar xf /linux/netmap.txz

#specify the of memory that the uml kernel can use 
ENV MEM 8G
ENV TMPDIR /umlshm

#it is recommended to override /umlshm with
#--tmpfs /umlshm:rw,nosuid,nodev,exec,size=8g
VOLUME /umlshm

ADD kernel.sh /kernel.sh
ADD entrypoint.sh /entrypoint.sh
ADD init.sh /init.sh
ADD bridge-send.sh .
ADD bridge-test.sh .

ARG KERNEL_VERSION

ENTRYPOINT [ "/entrypoint.sh", "ssh", "-o", "StrictHostKeyChecking=no", "-p", "8022", "root@127.0.0.1" ]

CMD [ "-tt", "/bin/bash" ]
