#!/bin/bash
# dump all dijnet.hu invoices to the actual folder
#
# required dependency:
# - libxml2-utils
#
# optional dependency:
# - pv (if you want a nice progress bar)

if ! which xmllint &>/dev/null; then
  echo "Dependency missing! Please install xmllint:"
  echo "- debian/ubuntu: apt-get install libxml2-utils"
  echo "- cygwin: setup-x86_64 -qP libxml2"
  exit 1
fi

SCRIPT=$(basename $0)
DIJNET_BASE_URL="https://www.dijnet.hu/ekonto"
#[ -z "${PASS}" ] && read -s -p "password: " PASS && echo

COOKIES=$(mktemp)
trap "rm ${COOKIES}" EXIT
trap 'PREV_COMMAND="${THIS_COMMAND}"; THIS_COMMAND="${BASH_COMMAND}"' DEBUG

## arg flags ------------------------------------------------------------------
P_USER="0"                 #     -u   |  --user
P_PASSWORD="0"             #     -p   |  --password
P_DEFAULT_DATE="0"         #
P_START_DATE="0"           #     -sd  |  --start_date
P_END_DATE="0"             #     -ed  |  --end_date
P_TODAY="0"                #     -t   |  --today
P_1_MONTH="0"              #     -1m  |  --last-1-month
P_6_MONTHS="0"             #     -6m  |  --last-6-months
P_1_YEAR="0"               #     -1y  |  --last-1-year

# CONSTANTS ###################################################################
## ANSI/VT100 Control sequences -----------------------------------------------
CEND='\033[0m'

CDEFAULT='\e[39m'   #Default
CBLACK='\e[30m'     #Black
CRED='\e[31m'       #Red
CGREEN='\e[32m'     #Green
CYELLOW='\e[33m'    #Yellow
CBLUE='\e[34m'      #Blue
CMAGENTA='\e[35m'   #Magenta
CCYAN='\e[36m'      #Cyan
CGRAY='\e[37m'      #Light gray
CDGRAY='\e[90m'     #Dark gray
CRED='\e[91m'       #Light red
CLGREEN='\e[92m'    #Light green
CLYELLOW='\e[93m'   #Light yellow
CLBLUE='\e[94m'     #Light blue
CLMAGENTA='\e[95m'  #Light magenta
CLCYAN='\e[96m'     #Light cyan
CWHITE='\e[97m'     #White

CBOLD='\e[1m'       #Bold
CDIM='\e[2m'        #Dim
CUNDERLINE='\e[4m'  #Underlined
CBLINK='\e[5m'      #Blink
CINVERTED='\e[7m'   #inverted
CHIDDEN='\e[8m'     #Hidden

#------------------------------------------------------------------------------
# no param
#------------------------------------------------------------------------------
die() {
  [ -z "$1" ] && echo "ERROR: command's exit code not zero: ${PREV_COMMAND}" >&2 || echo -e "ERROR: $1" >&2
  kill $$
  exit 1
}

#------------------------------------------------------------------------------
# no param
#------------------------------------------------------------------------------
xpath() {
  xmllint --html --xpath "$1" - 2>/dev/null
}

dijnet() {
  URL_POSTFIX="$1"
  POST_DATA="$2"
  wget \
    --quiet \
    --output-document=- \
    --load-cookies "${COOKIES}" \
    --save-cookies "${COOKIES}" \
    --keep-session-cookies \
    --post-data "${POST_DATA}" \
    ${DIJNET_BASE_URL}/${URL_POSTFIX}
}

#------------------------------------------------------------------------------
# no param
#------------------------------------------------------------------------------
progress() {
  if which pv &>/dev/null; then
    pv -N "total: ${INVOICE_COUNT}, current" -W -b -w 120 -p -l -t -e -s ${INVOICE_COUNT} >/dev/null
  else
    xargs -I{} printf "\033[2K\r total: ${INVOICE_COUNT}, current: {}"
    echo
  fi
}

#------------------------------------------------------------------------------
# no param
#------------------------------------------------------------------------------
function show_config(){
    echo -e "${CLYELLOW}Current settings${CEND}"
    echo -ne "Arguments: \033[94m[${CEND}"
    if [ "1" == ${P_USER} ]; then       echo -ne "${CLGREEN}${CBOLD}u${CEND}${CLBLUE}|${CEND}"; else  echo -ne "u${CLBLUE}|${CEND}"; fi
    if [ "1" == ${P_PASSWORD} ]; then   echo -ne "${CLGREEN}${CBOLD}p${CEND}${CLBLUE}|${CEND}"; else  echo -ne "p${CLBLUE}|${CEND}"; fi
    if [ "1" == ${P_START_DATE} ]; then echo -ne "${CLGREEN}${CBOLD}sd${CEND}${CLBLUE}|${CEND}"; else echo -ne "sd${CLBLUE}|${CEND}"; fi
    if [ "1" == ${P_END_DATE} ]; then   echo -ne "${CLGREEN}${CBOLD}ed${CEND}${CLBLUE}|${CEND}"; else echo -ne "ed${CLBLUE}|${CEND}"; fi
    if [ "1" == ${P_TODAY} ]; then      echo -ne "${CLGREEN}${CBOLD}t${CEND}${CLBLUE}|${CEND}"; else  echo -ne "t${CLBLUE}|${CEND}"; fi
    if [ "1" == ${P_1_MONTH} ]; then    echo -ne "${CLGREEN}${CBOLD}1m${CEND}${CLBLUE}|${CEND}"; else echo -ne "1m${CLBLUE}|${CEND}"; fi
    if [ "1" == ${P_6_MONTHS} ]; then   echo -ne "${CLGREEN}${CBOLD}6m${CEND}${CLBLUE}|${CEND}"; else echo -ne "6m${CLBLUE}|${CEND}"; fi
    if [ "1" == ${P_1_YEAR} ]; then     echo -e  "${CLGREEN}${CBOLD}1y${CEND}${CLBLUE}]${CEND}"; else echo -e  "1y${CLBLUE}]${CEND}"; fi

    echo -e "${CLYELLOW}Configuration${CEND}"
    echo -e "USERNAME          : ${USER}"
    if [ "1" == ${P_DEFAULT_DATE} ]; then echo -e "DEFAULT DATE mode : yes"; fi
    echo -e "START_DATE        : ${START_DATE}"
    echo -e "END_DATE          : ${END_DATE}"
}

#------------------------------------------------------------------------------
# no param
#------------------------------------------------------------------------------
function help(){
    printf "Usage: $0 [options]\n\n \
OPTIONS:\n \
  -u <username>    | --user <username>\n \
  -p <password>    | --password <password>\n \
  -P               | --read-password\n \
  -sd <yyyy.mm.dd> | --start-date <yyyy.mm.dd>\n \
  -ed <yyyy.mm.dd> | --end-date <yyyy.mm.dd>\n \
  -t               | --today\n \
  -1m              | --last-1-month\n \
  -6m              | --last-6-months\n \
  -1y              | --last-1-year\n \
  -h               | --help\n"
}

###############################################################################
#  MAIN  ######################################################################
###############################################################################

# PARAMETERS CHECKING
while [[ ${1:-} ]]
do
    case "${1}" in
        --user | -u)
            P_USER="1"
            USER=$2
            shift
            shift
            ;;
        --password | -p)
            P_PASSWORD="1"
            PASS=$2
            shift
            shift
            ;;
        --read-password | -P)
            P_PASSWORD="1"
            read -s -p "Enter your password: " PASS && echo
            shift
            ;;
        --start-date | -sd)
            P_START_DATE="1"
            START_DATE=$2
            shift
            shift
            ;;
        --end-date | -ed)
            P_END_DATE="1"
            END_DATE=$2
            shift
            shift
            ;;
        --today | -t)
            P_TODAY="1"
            shift
            ;;
        --last-1-month | -1m)
            P_1_MONTH="1"
            shift
            ;;
        --last-6-months | -6m)
            P_6_MONTHS="1"
            shift
            ;;
        --last-1-year | -1y)
            P_1_YEAR="1"
            shift
            ;;
        --help | -h)
            help
            exit 1
            ;;
        *)
            echo "Unknown parameter: ${1}" >&2
            exit 1
            ;;
    esac
done

# PROCESS COMMAND LINE ARGUMENTS
if ! which pv &>/dev/null; then
  echo "hint: install \"pv\" package for a nice progress bar"
fi

echo -e "Process command line arguments..."

## Login data checking
if [ "0" == ${P_USER} ] || [ "0" == ${P_PASSWORD} ]; then
    echo -e "${CRED}ERROR: user/password data missing${CEND}"; exit 1;
fi

## Is default mode necessary?
if  [ "0" == ${P_END_DATE} ] && [ "0" == ${P_START_DATE} ] && \
    [ "0" == ${P_1_MONTH} ]  && [ "0" == ${P_6_MONTHS} ] && [ "0" == ${P_1_YEAR} ] && [ "0" == ${P_TODAY} ] ; then P_DEFAULT_DATE="1"; P_1_MONTH=1;fi

## Date parameter checking -- logically
if [ "1" == ${P_END_DATE} ] && [ "0" == ${P_START_DATE} ]; then
    echo -e "${CRED}ERROR: '--start_date' parameter missing{CEND}"; exit 1;
fi

## Calculating END_DATE
if [ "0" == ${P_END_DATE} ]; then END_DATE=$(date +%Y.%m.%d); fi

if [[ ${END_DATE} < ${START_DATE} ]]; then
    echo -e "${CRED}ERROR: '--end_date' is less than '--start_date'${CEND}"; exit 1;
fi

## 'DATE' is above all
if ( [ "1" == ${P_END_DATE} ] || [ "1" == ${P_START_DATE} ] ) && \
   ( [ "1" == ${P_1_MONTH} ] || [ "1" == ${P_6_MONTHS} ] || [ "1" == ${P_1_YEAR} ] || [ "1" == ${P_TODAY} ] ); then
        if [ "1" == ${P_TODAY} ]; then  echo -e "${CLYELLOW}WARNING: '--today' parameter is dropped${CEND}";P_TODAY="0"; fi;
        if [ "1" == ${P_1_MONTH} ]; then  echo -e "${CLYELLOW}WARNING: '--last-1-month' parameter is dropped${CEND}";P_1_MONTH="0"; fi;
        if [ "1" == ${P_6_MONTHS} ]; then echo -e "${CLYELLOW}WARNING: '--last-6-months' parameter is dropped${CEND}";P_6_MONTHS="0"; fi;
        if [ "1" == ${P_1_YEAR} ]; then   echo -e "${CLYELLOW}WARNING: '--last-1-year' parameter is dropped${CEND}";P_1_YEAR="0"; fi;
fi

## Choosing the closest date
date_flags=$((${P_TODAY}+${P_1_MONTH}+${P_6_MONTHS}+${P_1_YEAR}))
if ( [ ${date_flags} -gt "1" ] ); then
    FLAG="0"
    if [ "1" == ${P_TODAY} ]; then  FLAG="1"; fi;

    if [ "1" == ${FLAG} ] && [ "1" == ${P_1_MONTH} ]; then
        echo -e "${CLYELLOW}WARNING: '--last-1-month' parameter is dropped${CEND}";P_1_MONTH="0";
    else
        if [ "1" == ${P_1_MONTH} ]; then FLAG="1"; fi
    fi;

    if [ "1" == ${FLAG} ] && [ "1" == ${P_6_MONTHS} ]; then
        echo -e "${CLYELLOW}WARNING: '--last-6-months' parameter is dropped${CEND}";P_6_MONTHS="0";
    else
        if [ "1" == ${P_6_MONTHS} ]; then FLAG="1"; fi
    fi

    if [ "1" == ${FLAG} ] && [ "1" == ${P_1_YEAR} ]; then
        echo -e "${CLYELLOW}WARNING: '--last-1-year' parameter is dropped${CEND}";P_1_YEAR="0";
    else
        if [ "1" == ${P_1_YEAR} ]; then FLAG="1"; fi
    fi;
fi

## Date parameter checking -- format
REGEX_DATE="^[0-9]{4}\.[-0-9]{2}\.[0-9]{2}$"
if [ "1" == ${P_START_DATE} ]; then
    if [[ ! ${START_DATE} =~ ${REGEX_DATE} ]]; then echo -e "${CRED}ERROR: invalid '--start_date' (${START_DATE})${CEND}"; exit 1; fi
fi

if [ "1" == ${P_END_DATE} ]; then
    if [[ ! $END_DATE =~ ${REGEXP_DATE} ]]; then echo -e "${CRED}ERROR: invalid '--end_date' (${END_DATE})${CEND}"; exit 1; fi
fi

## Calculating START DATE parameter
if [ "1" == ${P_TODAY} ]; then  START_DATE=$(date +%Y.%m.%d); fi;
if [ "1" == ${P_1_MONTH} ]; then  START_DATE=$(date -d "-1 months" +%Y.%m.%d); fi;
if [ "1" == ${P_6_MONTHS} ]; then START_DATE=$(date -d "-6 months" +%Y.%m.%d); fi;
if [ "1" == ${P_1_YEAR} ]; then   START_DATE=$(date -d "-1 years" +%Y.%m.%d); fi;

# PRINTING CONFIGURATION INFO
show_config

# LOGIN
printf "Login... "
LOGIN=$(dijnet "login/login_check_password" "vfw_form=login_check_password&username=${USER}&password=${PASS}" \
      | iconv -f iso8859-2 -t utf-8)
if ! echo "${LOGIN}" | grep -q --ignore-case "Bejelentkez&eacute;si n&eacute;v: <strong>${USER}"; then
  LOGIN_ERROR=$(echo "${LOGIN}" | xpath '//strong[contains(@class, "out-error-message")]/text()')
  die "login failed (${LOGIN_ERROR})"
fi
echo OK

# GRABBING DATA
printf "Query data of the registered providers... "

## DATA in UTF-8 CODING
UTF8_DATA=$(dijnet 'control/szamla_search' | iconv -f iso8859-2 -t utf-8 | grep -o "{\"aliasnev\":\"[^\"]*\",\"szlaszolgnev\":\"[^\"]*\",\"regszolgid\":[^,]*,\"ugyfelazon\":\"[^\"]*\",\"statusgrp\":[^,]*,\"szolgid\":[^,]*,\"alias\":\"[^\"]*\"}")
readarray -t UTF8_ALIASES < <(grep -o "\"alias\":\"[^\"]*\"" <<< ${UTF8_DATA} | sed 's/\"//g' | awk -F":" '{ print $2 }')
readarray -t UTF8_PROVIDERS < <(grep -o "\"szlaszolgnev\":\"[^\"]*\"" <<< ${UTF8_DATA} | sed 's/\"//g' | awk -F":" '{ print $2 }')
readarray -t UTF8_CUSTOMER_REG_IDS < <(grep -o "\"regszolgid\":[^,]*" <<< ${UTF8_DATA} | sed 's/\"//g' | awk -F":" '{ print $2 }')

## PROVIDERS in ISO8859-2 CODEING for HTTP POST
readarray -t PROVIDERS < <(dijnet "control/szamla_search" | perl -lne '/sopts.add\(.(.+?).\)/ and print $1')
echo OK

## Some helper array, variable
SIZE=${#UTF8_ALIASES[@]}

### Calculating max length of UTF8_ALIASES
ALL_IN_ONE_ALIASES=""
ALIASES_MAX_LEN=0
for x in ${UTF8_ALIASES[@]}; do
        ALL_IN_ONE_ALIASES="${ALL_IN_ONE_ALIASES}\n$x"
        strlength=`printf "%s" "$x" | wc -m`
        if [ ${strlength} -gt ${ALIASES_MAX_LEN} ]; then ALIASES_MAX_LEN=${#x}; fi
done

### Existance of the item in UTF8_PROVIDERS (More appearence means subdirectory is needed in the TARGET_PATH calculation)
readarray -t PROVIDERS_OCCUR < <(for x in ${UTF8_ALIASES[@]}; do grep -o ${x} <<<${ALL_IN_ONE_ALIASES} | wc -l;done)

## Structure of DATA
#    var ropts = [
#      {"aliasnev":"Haller-D�jbeszed�-v�z-g�z-csat (530133175)","szlaszolgnev":"NKM Energia - f�ldg�z",             "regszolgid":167473339,"ugyfelazon":"530133175",   "statusgrp":40,"szolgid":200,"alias":"Haller-D�jbeszed�-v�z-g�z-csat"},
#      {"aliasnev":"Szirmos-D�jbeszed�-NHKV kuka (544560237)",  "szlaszolgnev":"DFaktorh�z Zrt.",                   "regszolgid":633932725,"ugyfelazon":"544560237",   "statusgrp":40,"szolgid":200,"alias":"Szirmos-D�jbeszed�-NHKV kuka"},
#      {"aliasnev":"Haller-D�jbeszed�-v�z-g�z-csat (530133175)","szlaszolgnev":"J�V��R�S",                          "regszolgid":167473339,"ugyfelazon":"530133175",   "statusgrp":40,"szolgid":200,"alias":"Haller-D�jbeszed�-v�z-g�z-csat"},
#      {"aliasnev":"Haller-D�jbeszed�-v�z-g�z-csat (530133175)","szlaszolgnev":"FCSM Zrt.",                         "regszolgid":167473339,"ugyfelazon":"530133175",   "statusgrp":40,"szolgid":200,"alias":"Haller-D�jbeszed�-v�z-g�z-csat"},
#      {"aliasnev":"Szirmos-d�jbeszed�-v�zm�vek (544734313)",   "szlaszolgnev":"FV Zrt.",                           "regszolgid":644309792,"ugyfelazon":"544734313",   "statusgrp":40,"szolgid":200,"alias":"Szirmos-d�jbeszed�-v�zm�vek"},
#      {"aliasnev":"Szirmos-D�jbeszed�-NHKV kuka (544560237)",  "szlaszolgnev":"NHKV Zrt.",                         "regszolgid":633932725,"ugyfelazon":"544560237",   "statusgrp":40,"szolgid":200,"alias":"Szirmos-D�jbeszed�-NHKV kuka"},
#      {"aliasnev":"Haller-upc (0024893117)",                   "szlaszolgnev":"UPC",                               "regszolgid":120973071,"ugyfelazon":"0024893117",  "statusgrp":40,"szolgid":210,"alias":"Haller-upc"},
#      {"aliasnev":"Haller-Telekom-vezet�kes (100539503)",      "szlaszolgnev":"Telekom otthoni, Telekom-�sszevont","regszolgid":254955142,"ugyfelazon":"100539503",   "statusgrp":40,"szolgid":610,"alias":"Haller-Telekom-vezet�kes"},
#      {"aliasnev":"Szirmos-NKM f�ldg�z (000010854104)",        "szlaszolgnev":"NKM Energia - f�ldg�z",             "regszolgid":633932937,"ugyfelazon":"000010854104","statusgrp":40,"szolgid":250,"alias":"Szirmos-NKM f�ldg�z"},
#      {"aliasnev":"Haller-D�jbeszed�-v�z-g�z-csat (530133175)","szlaszolgnev":"FV Zrt.",                           "regszolgid":167473339,"ugyfelazon":"530133175",   "statusgrp":40,"szolgid":200,"alias":"Haller-D�jbeszed�-v�z-g�z-csat"},
#      {"aliasnev":"Haller-f�t�v (30280114)",                   "szlaszolgnev":"F�t�v Zrt.",                        "regszolgid":116265690,"ugyfelazon":"30280114",    "statusgrp":40,"szolgid":260,"alias":"Haller-f�t�v"},
#      {"aliasnev":"Haller-D�jbeszed�-v�z-g�z-csat (530133175)","szlaszolgnev":"DFaktorh�z Zrt.",                   "regszolgid":167473339,"ugyfelazon":"530133175",   "statusgrp":40,"szolgid":200,"alias":"Haller-D�jbeszed�-v�z-g�z-csat"},
#      {"aliasnev":"Telekom-mobil (10303985)",                  "szlaszolgnev":"Telekom mobil",                     "regszolgid":254955141,"ugyfelazon":"10303985",    "statusgrp":40,"szolgid":630,"alias":"Telekom-mobil"},
#      {"aliasnev":"Debrecen-upc (0031354905)",                 "szlaszolgnev":"UPC",                               "regszolgid":571265547,"ugyfelazon":"0031354905",  "statusgrp":40,"szolgid":210,"alias":"Debrecen-upc"}
#    ];

## Query parameters for HTTP POST
#    dijnet control/szamla_search_submit POST Data
#    button_search_form =
#    datumig            = yyyy.mm.dd
#    datumtol           = yyyy.mm.dd
#    regszolgid         =
#    szlaszolgnev       =
#    vfw_coll           = szamla_search_params
#    vfw_form           = szamla_search_submit

# DOWNLOADING
printf "Download invoices...\n"
LAST=$(( ${SIZE}-1 ))
for IDX in $(seq 0 ${LAST}); do
  INVOICES=$(dijnet "control/szamla_search_submit" "datumig=${END_DATE}&datumtol=${START_DATE}&vfw_form=szamla_search_submit&vfw_coll=szamla_search_params&szlaszolgnev=${PROVIDERS[${IDX}]}&regszolgid=${UTF8_CUSTOMER_REG_IDS[${IDX}]}" \
           | xpath '//table[contains(@class, "szamla_table")]/tbody/tr/td[1]/@onclick' \
           | sed 's/onclick="xt_cell_click(this,.//g;s/.)"//g;s/\&amp;/\&/g;s/\/ekonto\/control\///g')
  INVOICE_COUNT=$(echo "${INVOICES}" | wc -w)
  INVOICE_INDEX=1
  strlengthc=`printf "%s" "${UTF8_ALIASES[${IDX}]}" | wc -c` # in bytes (it can be bigger because of utf-8 coding)
  strlengthm=`printf "%s" "${UTF8_ALIASES[${IDX}]}" | wc -m` # in chars

  printf "${CLYELLOW}%-$(( strlength=${ALIASES_MAX_LEN}+${strlengthc}-${strlengthm} ))s -- ${CLCYAN}%3s invoices ${CLGREEN}-- ${UTF8_PROVIDERS[${IDX}]}\033[0m\n" ${UTF8_ALIASES[${IDX}]} ${INVOICE_COUNT} ${note}
  for INVOICE in ${INVOICES}; do
    dijnet "control/${INVOICE}" | iconv -f iso8859-2 -t utf-8 | grep -q 'href="szamla_letolt"' || die
    INVOICE_DOWNLOAD=$(dijnet "control/szamla_letolt")
    INVOICE_NUMBER=$(echo "${INVOICE_DOWNLOAD}" | xpath '//label[@class="title_next_s"]/text()' | sed 's/\//_/g;s/ //g')
    INVOICE_NUMBER=$(awk -F"-" '{ print $2 }'<<< ${INVOICE_NUMBER})"-"$(awk -F"-" '{ print $1 }'<<< ${INVOICE_NUMBER})
    if [ ${PROVIDERS_OCCUR[${IDX}]} -gt 1 ]; then
      TARGET_FOLDER=$(echo "dijnet-invoices/${UTF8_ALIASES[${IDX}]}/${UTF8_PROVIDERS[${IDX}]}/${INVOICE_NUMBER}" | sed 's/ \+/_/g;s/\.\//\//g')
    else
      TARGET_FOLDER=$(echo "dijnet-invoices/${UTF8_ALIASES[${IDX}]}/${INVOICE_NUMBER}" | sed 's/ \+/_/g;s/\.\//\//g')
    fi
    mkdir -p "${TARGET_FOLDER}" || die "not able to create folder: ${TARGET_FOLDER}"
    echo "${INVOICE_INDEX}"
    DOWNLOAD_LINKS=$(echo "${INVOICE_DOWNLOAD}" | xpath '//a[contains(@class, "xt_link__download")]/@href' | sed 's/href="\([^"]*\)"/\1 /g')
    for DOWNLOAD_LINK in ${DOWNLOAD_LINKS}; do
      echo "${DOWNLOAD_LINK}" | egrep -qi "adobe|e-szigno" && continue
      wget --quiet --load-cookies "${COOKIES}" --content-disposition --no-clobber \
           --directory-prefix "${TARGET_FOLDER}" "${DIJNET_BASE_URL}/control/${DOWNLOAD_LINK}"
    done
    dijnet "control/szamla_list" &>/dev/null
    ((INVOICE_INDEX++))
  done | progress
done
