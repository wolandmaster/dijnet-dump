FROM debian:9.13
ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update && apt-get install -y wget xxd libxml2-utils

COPY dijnet-dump.sh dijnet-dump.conf /work/
WORKDIR /work
