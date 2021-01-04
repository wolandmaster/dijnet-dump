#!/usr/bin/env bash
# dijnet.hu invoice downloader [https://github.com/wolandmaster/dijnet-dump]
# Copyright (c) 2016-2021 Sandor Balazsi and others
# This software may be distributed under the terms of the Apache 2.0 license

if ! type xmllint wget xxd &>/dev/null; then
  echo "Dependency missing! Please install them:" >&2
  echo "- debian/ubuntu: apt-get install wget xxd libxml2-utils" >&2
  echo "- fedora: dnf install wget vim-common findutils" >&2
  echo "- openwrt: opkg install bash wget xxd libxml2-utils" >&2
  exit 1
fi

die() {
  EXIT_CODE="$?" && echo -e "$@" >&2 && exit 1
}

xpath() {
  xmllint --html --xpath "$1" - 2>/dev/null
}

unaccent() {
  xxd -ps | tr -d '\n' | sed 's/\(..\)/ \1/g
    s/e1/61/g;s/c1/41/g;s/e9/65/g;s/c9/45/g;s/ed/69/g;s/cd/49/g;s/f3/6f/g;s/d3/4f/g;s/f5/6f/g
    s/d5/4f/g;s/f6/6f/g;s/d6/4f/g;s/fa/75/g;s/da/55/g;s/fb/75/g;s/db/55/g;s/fc/75/g;s/dc/55/g
    s/c3 a1/61/g;s/c3 81/41/g;s/c3 a9/65/g;s/c3 89/45/g;s/c3 ad/69/g;s/c3 8d/49/g
    s/c3 b3/6f/g;s/c3 93/4f/g;s/c3 b6/6f/g;s/c3 96/4f/g;s/c5 91/6f/g;s/c5 90/4f/g
    s/c3 ba/75/g;s/c3 9a/55/g;s/c3 bc/75/g;s/c3 9c/55/g;s/c5 b1/75/g;s/c5 b0/55/g' \
  | xxd -r -ps | sed 's/&\(.\)\(acute\|uml\|dblac\);/\1/g;s/&nbsp;/ /g'
}

dijnet() {
  URL_POSTFIX="$1"; shift; local IFS=""; POST_DATA="$*"
  wget --quiet --output-document=- --post-data "${POST_DATA}" --no-check-certificate \
       --load-cookies "${COOKIES}" --save-cookies "${COOKIES}" --keep-session-cookies \
       "${DIJNET_BASE_URL}/${URL_POSTFIX}"
}

invoice_data() {
  local IFS="|"; FILTER=$(sed 's/|/" or text()="/g' <<<"$*")
  unaccent <<<"${DOWNLOAD_PAGE}" | xpath '//label[text()="'"${FILTER}"'"]/../following-sibling::td[1]//text()'
}

download_internal_links() {
  LINKS=$(xpath '//a[contains(@class, "xt_link__download")]/@href' | sed 's/href="\([^"]*\)"/\1 /g')
  for LINK in ${LINKS}; do
    grep -q "^http" <<<"${LINK}" && continue
    wget --quiet --load-cookies "${COOKIES}" --content-disposition --no-clobber --no-check-certificate \
         --directory-prefix "${FIXED_TARGET_FOLDER}" "${DIJNET_BASE_URL}/ekonto/control/${LINK}"
  done
}

progress() {
  local PROVIDER_NAME=$(sed 's/ ()$//' <<<"${INVOICE_PROVIDER} (${INVOICE_PROVIDER_ALIAS})")
  if type pv &>/dev/null; then
    pv -N "download \"${PROVIDER_NAME}\", total: ${INVOICE_COUNT}, current" \
       -W -b -p -l -t -e -s "${INVOICE_COUNT}" >/dev/null
  else
    xargs -n 1 echo -ne "\033[2K\rdownload \"${PROVIDER_NAME}\", total: ${INVOICE_COUNT}, current:"; echo
  fi
}

set -o pipefail; export LANG=C LC_ALL=C
. "$(dirname "$(readlink -f "$0")")/dijnet-dump.conf" || die "ERROR: config file (dijnet-dump.conf) missing"
[[ "$1" == "-d" ]] && DEBUG_LOG="yes" && shift
DIJNET_USERNAME="${1:-${DIJNET_USERNAME}}"
[[ -z "${DIJNET_USERNAME}" ]] && die "usage: $(basename "$0") [-d] username"
[[ -z "${DIJNET_PASSWORD}" ]] && read -r -s -p "password: " DIJNET_PASSWORD && echo
if [[ "${DEBUG_LOG}" == "yes" ]]; then
  exec 3> >(sed 's/'"${DIJNET_USERNAME}"'/<USERNAME>/g;s/'"${DIJNET_PASSWORD}"'/********/g' >dijnet-dump.log)
  export BASH_XTRACEFD="3"
  set -x
fi

COOKIES=$(mktemp)
trap "rm ${COOKIES}" EXIT

printf "login... "
LOGIN_PAGE=$(dijnet "ekonto/login/login_check_password" \
  "vfw_form=login_check_password&username=${DIJNET_USERNAME}&password=${DIJNET_PASSWORD}")
if ! grep -qi "Bejelentkezesi nev: <strong>${DIJNET_USERNAME}</strong>" <(unaccent <<<"${LOGIN_PAGE}"); then
  LOGIN_ERROR=$(unaccent <<<"${LOGIN_PAGE}" | xpath '//div[contains(@class, "alert")]/strong/text()')
  die "\nERROR: login failed (${LOGIN_ERROR})"
fi
echo OK

printf "query service providers... "
PROVIDERS_PAGE=$(dijnet "ekonto/control/szamla_search")
grep -c "sopts.add" <<<"${PROVIDERS_PAGE}" || die "ERROR: not able to detect service providers"
type pv &>/dev/null || echo "hint: install \"pv\" package for a nice progress bar"

sed -n 's/.*var ropts\s*=\s*\[\(.*\)\];.*/\1/p' <<<"${PROVIDERS_PAGE}" | sed 's/},\s*{/}\n{/g' \
| while read -r PROVIDER_JSON; do
  declare -A PROVIDER=$(sed 's/"\([^"]\+\)":\([^,}]\+\),\?/ [\1]=\2/g;s/^{/(/;s/}$/ )/' <<<"${PROVIDER_JSON}")
  INVOICE_PROVIDER=$(unaccent <<<"${PROVIDER["szlaszolgnev"]}" | sed 's/\.$//')
  INVOICE_PROVIDER_ALIAS=$(unaccent <<<"${PROVIDER["alias"]}" | sed 's/^null$//')
  INVOICES_PAGE=$(dijnet "ekonto/control/szamla_search_submit" "vfw_form=szamla_search_submit" \
    "&vfw_coll=szamla_search_params&szlaszolgnev=${PROVIDER["szlaszolgnev"]}&regszolgid=${PROVIDER["regszolgid"]}" \
    "&datumtol=${FROM_DATE}&datumig=${TILL_DATE}")
  INVOICES=$(sed -n "s/.*clickSzamlaGTM('szamla_select', \([0-9]\+\).*/\1/p" <<<"${INVOICES_PAGE}")
  INVOICE_COUNT=$(wc -w <<<"${INVOICES}")

  for INVOICE_INDEX in ${INVOICES}; do
    INVOICE_PAGE=$(dijnet "ekonto/control/szamla_select" "vfw_coll=szamla_list&vfw_rowid=${INVOICE_INDEX}")
    grep -q 'href="szamla_letolt"' <<<"${INVOICE_PAGE}" || die "ERROR: not able to select invoice"
    DOWNLOAD_PAGE=$(dijnet "ekonto/control/szamla_letolt")
    INVOICE_NUMBER=$(invoice_data "Szamlaszam:" | sed 's/\//_/g')
    INVOICE_ISSUER_ID=$(invoice_data "Szamlakibocsatoi azonosito:")
    INVOICE_PAYMENT_DEADLINE=$(invoice_data "Fizetesi hatarido:" "Beerkezesi hatarido:")
    INVOICE_ISSUE_DATE=$(invoice_data "Kiallitas datuma:")
    INVOICE_AMOUNT=$(invoice_data "Szamla osszege:")
    INVOICE_STATUS=$(invoice_data "Szamla allapota:")
    . "$(dirname "$(readlink -f "$0")")/dijnet-dump.conf"
    FIXED_TARGET_FOLDER=$(sed 's/ \+/_/g;s/_-_/-/g;s/[.-]\+\//\//g' <<<"${TARGET_FOLDER}")
    mkdir -p "${FIXED_TARGET_FOLDER}" || die "ERROR: not able to create folder: ${FIXED_TARGET_FOLDER}"
    download_internal_links <<<"${DOWNLOAD_PAGE}"
    if grep -q 'href="szamla_info"' <<<"${INVOICE_PAGE}"; then
      INFO_PAGE=$(dijnet "ekonto/control/szamla_info") && download_internal_links <<<"${INFO_PAGE}"
    fi
    if grep -q 'href="szamla_reszletek"' <<<"${INVOICE_PAGE}"; then
      DETAILS_PAGE=$(dijnet "ekonto/control/szamla_reszletek") && download_internal_links <<<"${DETAILS_PAGE}"
    fi
    echo $((INVOICE_INDEX + 1))
    INVOICE_LIST_PAGE=$(dijnet "ekonto/control/szamla_list")
  done | progress || exit 1
done

