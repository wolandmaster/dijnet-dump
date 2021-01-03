FROM alpine as builder
RUN wget -q https://downloads.openwrt.org/releases/19.07.5/targets/x86/64/openwrt-19.07.5-x86-64-generic-rootfs.tar.gz -O /rootfs.tar.gz
RUN mkdir /rootfs && tar xf /rootfs.tar.gz -C /rootfs

FROM scratch
COPY --from=builder /rootfs/ /
COPY tests/openwrt-19.07/libxml2-utils_2.9.9-3_x86_64.ipk /tmp/
RUN mkdir -p /var/lock && opkg update && opkg install bash iconv wget pv /tmp/libxml2-utils_2.9.9-3_x86_64.ipk

COPY dijnet-dump.sh dijnet-dump.conf /work/
WORKDIR /work
