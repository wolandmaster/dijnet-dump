FROM ubuntu:16.04
ENV DEBIAN_FRONTEND noninteractive
ADD http://security.ubuntu.com/ubuntu/pool/main/v/vim/xxd_8.0.1453-1ubuntu1.4_amd64.deb /tmp/
RUN apt-get update && apt-get install -y wget libxml2-utils /tmp/xxd_8.0.1453-1ubuntu1.4_amd64.deb

COPY dijnet-dump.sh dijnet-dump.conf /work/
WORKDIR /work
