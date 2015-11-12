FROM phusion/baseimage:latest
CMD ["/sbin/my_init"]

RUN apt-get update
ENV buildDeps "build-essential debhelper autoconf libssl-dev"
RUN apt-get install -y $buildDeps \
	libvirt-bin \
	libvirt-dev \
	python \
	qemu-kvm \
	uuid-runtime \
	wget \
    curl \
    git \
	;

RUN wget -O- http://openvswitch.org/releases/openvswitch-2.4.0.tar.gz | \
	tar -zxf - -C /tmp/
RUN cd /tmp/openvswitch-2.4.0 && \
	export DEB_BUILD_OPTIONS="parallel=$(grep -c '^processor' /proc/cpuinfo) nocheck" && \
	fakeroot debian/rules binary && \
	bash -c "dpkg -i /tmp/openvswitch-{common,pki,switch}*.deb"
RUN mkdir -p /var/run/openvswitch/

COPY ovsdb-server.run /etc/service/ovsdb-server/run
COPY ovs-vswitchd.run /etc/service/ovs-vswitchd/run
COPY libvirtd.run /etc/service/libvirtd/run
COPY bzImage.mistify initrd.mistify ifup ifdown net.sh node0.sh nodes.sh /

ENV GOLANG_VERSION 1.4.2
ENV GOLANG_DOWNLOAD_URL https://golang.org/dl/go$GOLANG_VERSION.linux-amd64.tar.gz
ENV GOLANG_DOWNLOAD_SHA1 5020af94b52b65cc9b6f11d50a67e4bae07b0aff

RUN curl -fsSL "$GOLANG_DOWNLOAD_URL" -o golang.tar.gz \
	&& echo "$GOLANG_DOWNLOAD_SHA1  golang.tar.gz" | sha1sum -c - \
	&& tar -C /usr/local -xzf golang.tar.gz \
	&& rm golang.tar.gz

ENV GOPATH /go
ENV PATH $GOPATH/bin:/usr/local/go/bin:$PATH

RUN mkdir -p "$GOPATH/src/github.com/mistifyio/" "$GOPATH/bin" && chmod -R 777 "$GOPATH"
WORKDIR $GOPATH

RUN apt-get remove -y  $buildDeps && \
	apt-get clean -y && \
	rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

ENV buildDeps ""

COPY go-test-wrapper.sh /usr/bin/

RUN chmod +x /usr/bin/go-test-wrapper.sh