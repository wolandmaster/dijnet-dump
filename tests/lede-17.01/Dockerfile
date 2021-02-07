FROM alpine as builder

WORKDIR /work
RUN wget -qO rootfs.tar.gz \
    https://archive.openwrt.org/releases/17.01.7/targets/x86/64/lede-17.01.7-x86-64-generic-rootfs.tar.gz \
    && mkdir rootfs && tar xf rootfs.tar.gz -C rootfs && rm rootfs.tar.gz


FROM scratch

COPY --from=builder /work/rootfs/ /
COPY tests/lede-17.01/libxml2-utils_2.9.4-2_x86_64.ipk /tmp/
RUN mkdir -p /var/lock && opkg update \
    && opkg install coreutils-stty \
    && opkg install bash wget xxd /tmp/libxml2-utils_2.9.4-2_x86_64.ipk

WORKDIR /tmp
COPY dijnet-dump.sh dijnet-dump.conf /work/
