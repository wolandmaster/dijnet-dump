FROM i386/ubuntu:18.04 as builder

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y \
    wget build-essential flex bison pkg-config gettext libx11-dev libpng-dev libjpeg-dev \
    libncurses-dev libfreetype6-dev libxml2-dev libxslt1-dev libgnutls28-dev libxrender-dev \
    && rm -rf /var/lib/apt/lists/*

ARG WINE_VERSION=5.16

WORKDIR /work/
COPY tests/cygwin-wine/winehq-48891.patch ./
RUN wget --show-progress --progress=bar:force --quiet \
    https://dl.winehq.org/wine/source/5.x/wine-${WINE_VERSION}.tar.xz \
    && tar xf wine-${WINE_VERSION}.tar.xz && rm wine-${WINE_VERSION}.tar.xz \
    && patch -p1 -d wine-${WINE_VERSION} < winehq-48891.patch

WORKDIR /work/wine-${WINE_VERSION}/build
RUN ../configure && make -j $(getconf _NPROCESSORS_ONLN) install

ARG CYGWIN_MIRROR="http://ftp.fsn.hu/pub/cygwin"
RUN printf '%s\n' \
      "#!/bin/bash" \
      "Xvfb :1 -ac -reset -terminate & sleep 2" \
      "IFS=','; DISPLAY=':1' wine /usr/local/bin/setup-x86.exe \\" \
      "  --quiet-mode \\" \
      "  --site '${CYGWIN_MIRROR}' \\" \
      "  --local-package-dir 'C:/cygwin-install' \\" \
      "  --root 'C:/cygwin' \\" \
      "  --packages \"\$*\" \\" \
      "  --wait \\" \
      "| awk '!/^AddAccessAllowedAceEx(.*) failed: 1337/ { print; fflush() }'" \
      "" > /usr/local/bin/cygwin_install \
    && chmod a+x /usr/local/bin/cygwin_install \
    && wget -nv -O /usr/local/bin/winetricks \
    https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks \
    && chmod a+x /usr/local/bin/winetricks \
    && wget -nv -O /usr/local/bin/setup-x86.exe https://cygwin.com/setup-x86.exe


FROM i386/ubuntu:18.04

ENV DEBIAN_FRONTEND=noninteractive WINEDEBUG=-all TERM=xterm CYGWIN=winsymlinks:lnk
RUN apt-get update && apt-get install -y wget xvfb \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /usr/local /usr/local
RUN winetricks nocrashdialog \
    && cygwin_install wget xxd libxml2

WORKDIR /root/.wine/drive_c/cygwin
RUN cp etc/postinstall/bash.sh.done etc/profile.d/workaround_bug_403.sh \
    && wineconsole bin/bash --login -i -c \
    "/usr/bin/update-crypto-policies; ln -sf /usr/bin/gawk /usr/bin/awk"

RUN printf '%s\n' \
      '#!/bin/bash' \
      'if [[ "$#" == 0 ]]; then' \
      '  wineconsole bin/bash.exe --login -i' \
      'else' \
      '  wineconsole bin/bash.exe --login -i -c "${*@Q} 2>&1 | tee /tmp/wineconsole.$$"' \
      '  cat tmp/wineconsole.$$' \
      'fi' > /entrypoint.sh \
    && chmod a+x /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]

COPY dijnet-dump.sh dijnet-dump.conf work/
