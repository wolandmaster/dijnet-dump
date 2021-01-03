FROM ubuntu:16.04
ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update && apt-get install -y wget libxml2-utils

COPY dijnet-dump.sh dijnet-dump.conf /work/
WORKDIR /work
