FROM alpine as builder

WORKDIR /work
RUN wget -qO rootfs.tar.gz \
    https://archive.openwrt.org/chaos_calmer/15.05.1/x86/64/openwrt-15.05.1-x86-64-rootfs.tar.gz \
    && mkdir rootfs && tar xf rootfs.tar.gz -C rootfs && rm rootfs.tar.gz \
    && sed -i 's/downloads.openwrt.org/archive.openwrt.org/g' rootfs/etc/opkg/distfeeds.conf


FROM scratch

COPY --from=builder /work/rootfs/ /
COPY tests/openwrt-15.05/libxml2-utils_2.9.2-3_x86_64.ipk /tmp/
RUN mkdir -p /var/lock && opkg update \
    && opkg install coreutils-stty \
    && opkg install bash wget xxd /tmp/libxml2-utils_2.9.2-3_x86_64.ipk

WORKDIR /tmp
COPY dijnet-dump.sh dijnet-dump.conf /work/
