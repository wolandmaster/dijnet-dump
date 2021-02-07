FROM fedora:33

RUN dnf -y update && dnf -y install wget vim-common findutils pv \
    && dnf clean all

WORKDIR /tmp
COPY dijnet-dump.sh dijnet-dump.conf /work/
