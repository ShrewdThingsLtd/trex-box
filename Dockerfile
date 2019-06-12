FROM phusion/baseimage
MAINTAINER erez@shrewdthings.com
ARG TREX_VER='v2.56'

RUN add-apt-repository ppa:rmescandon/yq
RUN apt-get -y update && apt-get -y install wget pciutils iproute2 build-essential jq yq ethtool
WORKDIR /opt/trex
RUN TREX_WEB_URL='http://trex-tgn.cisco.com/trex' && wget --no-cache ${TREX_WEB_URL}/release/$TREX_VER.tar.gz && tar -xzvf ./$TREX_VER.tar.gz
WORKDIR /opt/trex/$TREX_VER
COPY ./start /opt/trex/start

#######################################
########### TRex Service ##############
RUN mkdir -p /etc/service/trexd/log
RUN printf '#!/bin/sh\n\
exec 2>&1\n\
exec setsid /opt/trex/start/trex_start.sh\n\
' > /etc/service/trexd/run
RUN printf '#!/bin/sh\n\
exec chpst -ulog svlogd -tt /tmp\n\
' > /etc/service/trexd/log/run
RUN chmod +x /etc/service/trexd/run
RUN chmod +x /etc/service/trexd/log/run
#######################################
