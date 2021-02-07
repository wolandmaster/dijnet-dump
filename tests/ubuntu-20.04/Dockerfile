FROM ubuntu:20.04

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y \
    wget xxd libxml2-utils pv locales \
    && rm -rf /var/lib/apt/lists/*

RUN sed -i '/hu_HU.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
ENV LANG=hu_HU.UTF-8 LC_ALL=hu_HU.UTF-8 LANGUAGE=hu_HU:hu

WORKDIR /tmp
COPY dijnet-dump.sh dijnet-dump.conf /work/
