FROM ubuntu:16.04

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y wget libxml2-utils \
    && wget --show-progress --progress=bar:force -qO /tmp/xxd.deb \
    http://security.ubuntu.com/ubuntu/pool/main/v/vim/xxd_8.0.1453-1ubuntu1.4_amd64.deb \
    && apt-get install -y /tmp/xxd.deb \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /tmp
COPY dijnet-dump.sh dijnet-dump.conf /work/
