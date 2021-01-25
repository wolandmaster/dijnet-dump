FROM alpine as builder
RUN wget -q https://archive.openwrt.org/chaos_calmer/15.05.1/x86/64/openwrt-15.05.1-x86-64-rootfs.tar.gz -O /rootfs.tar.gz
RUN mkdir /rootfs && tar xf /rootfs.tar.gz -C /rootfs

FROM scratch
COPY --from=builder /rootfs/ /
COPY tests/openwrt-15.05/libxml2-utils_2.9.2-3_x86_64.ipk /tmp/
RUN mkdir -p /var/lock && opkg update \
    && opkg install --force-overwrite coreutils-stty coreutils-cksum coreutils-sort \
    && opkg install bash xxd wget /tmp/libxml2-utils_2.9.2-3_x86_64.ipk

COPY dijnet-dump.sh dijnet-dump.conf /work/
