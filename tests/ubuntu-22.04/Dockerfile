FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y \
      wget xxd libxml2-utils \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /tmp
COPY dijnet-dump.sh dijnet-dump.conf /work/
