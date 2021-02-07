FROM ubuntu:18.04 as builder

ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update && apt-get install -y \
    build-essential git gawk wget file unzip python libncurses5-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /work
RUN git clone --branch "openwrt-19.07" https://git.openwrt.org/openwrt/openwrt.git . \
    && ./scripts/feeds update -a \
    && ./scripts/feeds install -a

COPY tests/openwrt-19.07/libxml2-utils.patch ./
RUN patch -ruN -d feeds/packages/libs/libxml2 < libxml2-utils.patch \
    && printf '%s\n' \
      'CONFIG_TARGET_x86=y' \
      'CONFIG_TARGET_x86_64=y' \
      'CONFIG_TARGET_x86_64_Generic=y' \
      'CONFIG_PACKAGE_libxml2=m' \
      'CONFIG_PACKAGE_libxml2-utils=m' \
      'CONFIG_PACKAGE_zlib=m' > .config

ENV FORCE_UNSAFE_CONFIGURE=1
RUN make -j $(getconf _NPROCESSORS_ONLN) defconfig toolchain/install
RUN make -j $(getconf _NPROCESSORS_ONLN) package/libxml2/compile

RUN wget --show-progress --progress=bar:force -qO rootfs.tar.gz \
      https://downloads.openwrt.org/releases/19.07.5/targets/x86/64/openwrt-19.07.5-x86-64-generic-rootfs.tar.gz \
    && mkdir rootfs && tar xf rootfs.tar.gz -C rootfs && rm rootfs.tar.gz


FROM scratch

COPY --from=builder /work/rootfs/ /
COPY --from=builder /work/bin/packages/x86_64/packages/libxml2-utils*.ipk /tmp/
RUN mkdir -p /var/lock && opkg update \
    && opkg install coreutils-stty \
    && opkg install bash xxd wget pv /tmp/libxml2-utils*.ipk
CMD ["/bin/sh"]

WORKDIR /tmp
COPY dijnet-dump.sh dijnet-dump.conf /work/
