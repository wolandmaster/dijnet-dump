FROM alpine as builder

RUN wget -q https://archive.openwrt.org/releases/17.01.7/targets/x86/64/lede-17.01.7-x86-64-generic-rootfs.tar.gz -O /rootfs.tar.gz
RUN mkdir /rootfs && tar xf /rootfs.tar.gz -C /rootfs


FROM scratch

COPY --from=builder /rootfs/ /
COPY tests/lede-17.01/libxml2-utils_2.9.4-2_x86_64.ipk /tmp/
RUN mkdir -p /var/lock && opkg update \
    && opkg install --force-overwrite coreutils-stty coreutils-cksum coreutils-sort \
    && opkg install bash wget xxd /tmp/libxml2-utils_2.9.4-2_x86_64.ipk

COPY dijnet-dump.sh dijnet-dump.conf /work/
