FROM ubuntu:20.04
ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update && apt-get install -y wget libxml2-utils pv locales

RUN sed -i '/hu_HU.UTF-8/s/^# //g' /etc/locale.gen && locale-gen
ENV LANG hu_HU.UTF-8
ENV LC_ALL hu_HU.UTF-8
ENV LANGUAGE hu_HU:hu

COPY dijnet-dump.sh dijnet-dump.conf /work/
WORKDIR /work
