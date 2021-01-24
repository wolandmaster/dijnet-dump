#!/usr/bin/env bash
# dijnet.hu invoice downloader tester [https://github.com/wolandmaster/dijnet-dump]
# Copyright (c) 2016-2021 Sandor Balazsi and others
# This software may be distributed under the terms of the Apache 2.0 license

banner() {
  TITLE="# $@ #"; EDGE=$(sed 's/./#/g' <<<"${TITLE}")
  echo -e "\n${EDGE}\n${TITLE}\n${EDGE}\n"
}

absolute_path() {
  pushd . &>/dev/null && cd "$(dirname "$1")" && pwd -P && popd &>/dev/null
}

set -e; cd "$(absolute_path "$0")"
trap '[[ $? == 0 ]] && echo "Overall result: SUCCESS" || echo "Overall result: FAILED"' EXIT
read -r ROWS COLUMNS < <(stty size)

TARGETS="$@"; [[ -z "${TARGETS}" ]] && TARGETS="tests/*"
LAST_CHECKSUM=""
for TARGET in $(ls -d ${TARGETS} 2>/dev/null); do
  banner "${TARGET:6}"
  docker build --file ${TARGET}/Dockerfile --tag dijnet-dump:${TARGET:6} .
  CHECKSUM=$(docker run --tty --interactive --privileged dijnet-dump:${TARGET:6} bash -c '
    export LANG=C LC_ALL=C \
    && mkdir /tmp/invoices \
    && cd /tmp/invoices \
    && stty columns '"${COLUMNS}"' \
    && /work/dijnet-dump.sh \
    && find . -type f -exec wc -c {} \; | tee /dev/tty | grep -v "dijnet-dump.log" \
     | sort -k2 | sed -E "s/^[[:space:]]*//" | cksum | awk "{print \"CHECKSUM:\", \$1}"
  ' | tee /dev/tty | awk '/CHECKSUM:/ {print $NF}')

  if [[ -z "${LAST_CHECKSUM}" || "${CHECKSUM}" == "${LAST_CHECKSUM}" ]]; then
    LAST_CHECKSUM="${CHECKSUM}"
  else
    echo "Test result checksum mismatch!" >&2
    exit 1
  fi
done

