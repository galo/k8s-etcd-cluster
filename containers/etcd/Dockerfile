FROM phusion/baseimage:0.9.18

MAINTAINER Samuel Cozannet <samuel@blended.io>, http://blended.io
LABEL version="2.0.1"
LABEL app="etcd"

ADD start-etcd /etc/my_init.d/00_start-etcd
ADD k8s-hooks /opt/k8s-hooks

RUN \ 
 chmod +x /etc/my_init.d/00_start-etcd \
 && mkdir -p /etc/etcd \ 
 && touch /etc/etcd/etcd.conf \
 && chmod 0755 /opt/k8s-hooks/*.sh
 
ENV DOCKER_ETCD_VERSION 2.1.1

RUN apt-get update && apt-get install -yqq wget jq

RUN \
 cd /tmp \
 && wget https://github.com/coreos/etcd/releases/download/v${DOCKER_ETCD_VERSION}/etcd-v${DOCKER_ETCD_VERSION}-linux-amd64.tar.gz \
 && tar zxf etcd-v${DOCKER_ETCD_VERSION}-linux-amd64.tar.gz \
 && cd etcd-v${DOCKER_ETCD_VERSION}-linux-amd64 \
 && mv etcd etcdctl /usr/local/bin/ \
 && cd / \
 && rm -rf /tmp/etcd-v$DOCKER_ETCD_VERSION-linux-amd64.tar.gz /tmp/etcd-v$DOCKER_ETCD_VERSION-linux-amd64

CMD ["/sbin/my_init"]

EXPOSE 2379 2380

RUN apt-get clean && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*
