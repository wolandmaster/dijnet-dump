#!/usr/bin/env bash
# dump all dijnet.hu invoices to the actual folder
#
# required dependency:
# - libxml2-utils
#
# optional dependency:
# - pv (if you want a nice progress bar)

if ! which xmllint wget &>/dev/null; then
  echo "Dependency missing! Please install them:"
  echo "- debian/ubuntu: apt-get install libxml2-utils wget"
  echo "- cygwin: setup-x86_64 -qP libxml2 wget"
  exit 1
fi

die() {
  echo -e "$@" >&2 && exit 1
}

xpath() {
  xmllint --html --xpath "$1" - 2>/dev/null
}

to_utf8() {
  iconv -f iso8859-2 -t utf-8
}

unaccent() {
  sed 's/&\(.\)\(acute\|uml\);/\1/g;s/\xF5/o/g;s/&nbsp;/ /g
       s/\xc3\xa1/a/g;s/\xc3\x81/A/g;s/\xc3\xa9/e/g;s/\xc3\x89/E/g;s/\xc3\xad/i/g;s/\xc3\x8d/I/g
       s/\xc3\xb3/o/g;s/\xc3\x93/O/g;s/\xc3\xb6/o/g;s/\xc3\x96/O/g;s/\xc3\xba/u/g;s/\xc3\x9a/U/g
       s/\xc3\xbc/u/g;s/\xc3\x9c/U/g;s/\xc5\x91/o/g;s/\xc5\x90/O/g;s/\xc5\xb1/u/g;s/\xc5\xb0/U/g'
}

dijnet() {
  URL_POSTFIX="$1"; shift; local IFS=""; POST_DATA="$*"
  wget --quiet --output-document=- --post-data "${POST_DATA}" --no-check-certificate \
       --load-cookies "${COOKIES}" --save-cookies "${COOKIES}" --keep-session-cookies \
       ${DIJNET_BASE_URL}/${URL_POSTFIX}
}

invoice_data() {
  local IFS="|"; FILTER=$(sed 's/|/" or text()="/g' <<<"$*")
  xpath '//label[text()="'"${FILTER}"'"]/../following-sibling::td[1]//text()' <<<"${INVOICE_DOWNLOAD}"
}

progress() {
  if which pv &>/dev/null; then
    pv -N "download \"${INVOICE_PROVIDER}\", total: ${INVOICE_COUNT}, current" \
       -W -b -w 120 -p -l -t -e -s ${INVOICE_COUNT} >/dev/null
  else
    xargs -I{} printf "\033[2K\rdownload \"${INVOICE_PROVIDER}\", total: ${INVOICE_COUNT}, current: {}"
    echo
  fi
}

set -o pipefail; export LC_ALL=C
. "$(dirname "$(readlink -f "$0")")/dijnet-dump.conf"
DIJNET_USERNAME="${1:-${DIJNET_USERNAME}}"; DIJNET_PASSWORD="${2:-${DIJNET_PASSWORD}}"
[[ -z "${DIJNET_USERNAME}" ]] && die "usage: $(basename "$0") username <password>"
[[ -z "${DIJNET_PASSWORD}" ]] && read -s -p "password: " DIJNET_PASSWORD && echo

COOKIES=$(mktemp)
trap "rm ${COOKIES}" EXIT

printf "login... "
LOGIN=$(dijnet "ekonto/login/login_check_password" \
  "vfw_form=login_check_password&username=${DIJNET_USERNAME}&password=${DIJNET_PASSWORD}" | unaccent)
if ! grep -qi "Bejelentkezesi nev: <strong>${DIJNET_USERNAME}" <<<"${LOGIN}"; then
  LOGIN_ERROR=$(xpath '//div[contains(@class, "alert")]/strong/text()' <<<"${LOGIN}" | to_utf8)
  die "\nERROR: login failed (${LOGIN_ERROR})"
fi
echo OK

printf "query service providers... "
PROVIDERS=$(dijnet "ekonto/control/szamla_search" | sed -n "s/.*sopts.add('\([^']\+\)');/\1/p")
[[ -z "${PROVIDERS}" ]] && die "ERROR: not able to detect service providers" || wc -l <<<"${PROVIDERS}"
which pv &>/dev/null || echo "hint: install \"pv\" package for a nice progress bar"

echo "${PROVIDERS}" | while read PROVIDER; do
  INVOICE_PROVIDER=$(to_utf8 <<<"${PROVIDER}")
  INVOICES=$(dijnet "ekonto/control/szamla_search_submit" "vfw_form=szamla_search_submit" \
    "&vfw_coll=szamla_search_params&szlaszolgnev=${PROVIDER}&datumtol=${FROM_DATE}&datumig=${TILL_DATE}" \
    | sed -n "s/.*clickSzamlaGTM('szamla_select', \([0-9]\+\).*/\1/p")
  INVOICE_COUNT=$(wc -w <<<"${INVOICES}")

  for INVOICE_INDEX in ${INVOICES}; do
    dijnet "ekonto/control/szamla_select" "vfw_coll=szamla_list&vfw_rowid=${INVOICE_INDEX}" \
    | to_utf8 | grep -q 'href="szamla_letolt"' || die "ERROR: not able to select invoice"
    INVOICE_DOWNLOAD=$(dijnet "ekonto/control/szamla_letolt" | unaccent)
    INVOICE_NUMBER=$(invoice_data "Szamlaszam:" | sed 's/\//_/g')
    INVOICE_ISSUER_ID=$(invoice_data "Szamlakibocsatoi azonosito:")
    INVOICE_PAYMENT_DEADLINE=$(invoice_data "Fizetesi hatarido:" "Beerkezesi hatarido:")
    INVOICE_ISSUE_DATE=$(invoice_data "Kiallitas datuma:")
    INVOICE_AMOUNT=$(invoice_data "Szamla osszege:")
    INVOICE_STATUS=$(invoice_data "Szamla allapota:")
    . "$(dirname "$(readlink -f "$0")")/dijnet-dump.conf"
    FIXED_TARGET_FOLDER=$(sed 's/ \+/_/g;s/_-_/-/g;s/\.\//\//g' <<<"${TARGET_FOLDER}" | unaccent)
    mkdir -p "${FIXED_TARGET_FOLDER}" || die "ERROR: not able to create folder: ${FIXED_TARGET_FOLDER}"
    echo $((${INVOICE_INDEX} + 1))
    DOWNLOAD_LINKS=$(xpath '//a[contains(@class, "xt_link__download")]/@href' <<<"${INVOICE_DOWNLOAD}" \
    | sed 's/href="\([^"]*\)"/\1 /g')
    for DOWNLOAD_LINK in ${DOWNLOAD_LINKS}; do
      egrep -qi "adobe|e-szigno" <<<"${DOWNLOAD_LINK}" && continue
      wget --quiet --load-cookies "${COOKIES}" --content-disposition --no-clobber --no-check-certificate \
           --directory-prefix "${FIXED_TARGET_FOLDER}" "${DIJNET_BASE_URL}/ekonto/control/${DOWNLOAD_LINK}"
    done
    dijnet "ekonto/control/szamla_list" &>/dev/null
  done | progress || exit 1
done

