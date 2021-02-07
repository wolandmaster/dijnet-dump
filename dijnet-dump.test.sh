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

set -e; export LANG=C LC_ALL=C; cd "$(absolute_path "$0")"
trap '[[ $? == 0 ]] && echo "Overall result: SUCCESS" || echo "Overall result: FAILED"' EXIT
read -r ROWS COLS < <(stty size)

TARGETS="$@"; [[ -z "${TARGETS}" ]] && TARGETS="tests/*"
LAST_CHECKSUM=""
for TARGET in $(ls -d ${TARGETS} 2>/dev/null); do
  banner "${TARGET:6}"
  docker build --file ${TARGET}/Dockerfile --tag dijnet-dump:${TARGET:6} .
  docker container rm --force "dijnet-dump_${TARGET:6}" &>/dev/null | true
  CMD="stty columns ${COLS}; mkdir invoices; cd invoices"
  CMD="${CMD}; /work/dijnet-dump.sh; echo ====; find . -type f -exec wc -c {} \;"
  docker run --tty --interactive --privileged \
	     --name "dijnet-dump_${TARGET:6}" "dijnet-dump:${TARGET:6}" bash -ec "${CMD}"
  CHECKSUM=$(docker logs "dijnet-dump_${TARGET:6}" | sed '1,/^====/d' \
  | grep -v "dijnet-dump.log" | sort -k2 | sed -E "s/^[[:space:]]*//" | cksum | cut -d" " -f1)
  echo "CHECKSUM: ${CHECKSUM}"
  docker container rm --force "dijnet-dump_${TARGET:6}" &>/dev/null

  if [[ -z "${LAST_CHECKSUM}" || "${CHECKSUM}" == "${LAST_CHECKSUM}" ]]; then
    LAST_CHECKSUM="${CHECKSUM}"
  else
    echo "Test result checksum mismatch!" >&2
    exit 1
  fi
done

