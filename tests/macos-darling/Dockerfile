FROM ubuntu:18.04 as builder

ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update && apt-get install -y \
    cmake clang bison flex libfuse-dev libudev-dev pkg-config git linux-headers-$(uname -r) \
    gcc-multilib libcap2-bin libc6-dev-i386 libcairo2-dev libgl1-mesa-dev libglu1-mesa-dev \
    libtiff5-dev libfreetype6-dev libelf-dev libxml2-dev libegl1-mesa-dev libfontconfig1-dev \
    libbsd-dev libxrandr-dev libxcursor-dev libgif-dev libavutil-dev libpulse-dev libssl-dev \
    libavformat-dev libavcodec-dev libavresample-dev libdbus-1-dev libxkbfile-dev

WORKDIR /work
RUN git clone --recursive https://github.com/darlinghq/darling.git

WORKDIR /work/darling/build
RUN cmake -DFULL_BUILD=OFF .. \
    && make -j $(getconf _NPROCESSORS_ONLN) install \
    && make -j $(getconf _NPROCESSORS_ONLN) lkm


FROM ubuntu:18.04

ENV DEBIAN_FRONTEND noninteractive
RUN apt-get update && apt-get install -y \
    kmod libx11-6 libxrandr2 libegl1 libgl1 xdg-user-dirs wget jq sudo
RUN mkdir -p /lib/modules/$(uname -r) \
    && ln -s /lib/modules/$(uname -r) /lib/modules/current \
    && groupadd -g 1000 darling \
    && useradd -g darling -u 1000 -s /bin/bash -d /home/darling darling \
    && echo "darling ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers

WORKDIR /lib/modules/current/extra
COPY --from=builder /usr/local /usr/local
COPY --from=builder /work/darling/src/external/lkm/*.ko ./

WORKDIR /usr/local/libexec/darling/usr/local
RUN printf '%s\n' \
      '#!/bin/bash' \
      'PRODUCT_VERSION=$(awk -F"[<>]" "/ProductVersion/ { getline; print \$3 }" \' \
      '  /usr/local/libexec/darling/System/Library/CoreServices/SystemVersion.plist)' \
      '[[ "${PRODUCT_VERSION}" == "10.14" ]] && PRODUCT_NAME="mojave"' \
      '[[ "${PRODUCT_VERSION}" == "10.15" ]] && PRODUCT_NAME="catalina"' \
      '[[ "${PRODUCT_VERSION}" == "11.0"  ]] && PRODUCT_NAME="big_sur"' \
      '[[ -z "${PRODUCT_NAME}" ]] && echo "unknown macOS version" && exit 1' \
      'while (($#)); do' \
      '  FORMULA=$(wget -qO- "https://formulae.brew.sh/api/formula/$1.json")' \
      '  jq -r ".bottle.stable.files.${PRODUCT_NAME}.url" <<<"${FORMULA}" \' \
      '  | xargs wget --show-progress --progress=bar:force -qO "$1.tar.gz"' \
      '  tar --strip-components=2 -xf "$1.tar.gz" && rm "$1.tar.gz"' \
      '  set -- "$@" $(jq -r ".dependencies | @tsv" <<<"${FORMULA}")' \
      '  shift' \
      'done' > /usr/local/bin/brew_install \
    && chmod a+x /usr/local/bin/brew_install \
    && brew_install bash libxml2 wget pv

RUN printf '%s\n' \
      '#!/bin/bash' \
      'sudo mount -t tmpfs tmpfs /home/darling' \
      'exec darling shell "$@"' > /entrypoint.sh \
    && chmod a+x /entrypoint.sh

USER darling
WORKDIR /home/darling
ENTRYPOINT ["/entrypoint.sh"]

COPY dijnet-dump.sh dijnet-dump.conf /usr/local/libexec/darling/work/
