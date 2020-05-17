#!/bin/bash
# download dijnet.hu invoices

SCRIPT=$(basename $0)
TIMESTAMP=`date "+%Y-%m-%d %H:%M:%S"`

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
P_DEBUG="0"                #     -d   |  --debug

# CONSTANTS ###################################################################
DIJNET_BASE_URL="https://www.dijnet.hu/ekonto"
DEBUG_FOLDER="./debug_logs"
DEBUG_LOG_FILE="${DEBUG_FOLDER}/logs.txt"
REGEX_DATE="^[0-9]{4}\.[-0-9]{2}\.[0-9]{2}$"
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
function die() {
  [ -z "$1" ] && echo "ERROR: command's exit code not zero: ${PREV_COMMAND}" >&2 || echo -e "ERROR: $1" >&2
  kill $$
  exit 1
}

#------------------------------------------------------------------------------
# no param
#------------------------------------------------------------------------------
function xpath() {
  xmllint --html --xpath "$1" - 2>/dev/null
}

#------------------------------------------------------------------------------
# $1 - URL_POSTFIX
# $2 - POST_DATA
#------------------------------------------------------------------------------
function dijnet() {
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
function progress() {
  if which pv &>/dev/null; then
    pv -N "total: ${INVOICE_COUNT_PRN}, current" -W -b -w 120 -p -l -t -e -s ${INVOICE_COUNT_PRN} >/dev/null
  else
    xargs -I{} printf "\033[2K\r total: ${INVOICE_COUNT_PRN}, current: {}"
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
    if [ "1" == ${P_1_YEAR} ]; then     echo -ne "${CLGREEN}${CBOLD}1y${CEND}${CLBLUE}|${CEND}"; else echo -ne "1y${CLBLUE}|${CEND}"; fi
    if [ "1" == ${P_DEBUG} ]; then      echo -e  "${CLGREEN}${CBOLD}d${CEND}${CLBLUE}]${CEND}"; else  echo -e  "d${CLBLUE}]${CEND}"; fi

    echo -e "${CLYELLOW}Configuration${CEND}"
    echo -e "USERNAME          : ${USER}"
    if [ "1" == ${P_DEFAULT_DATE} ]; then echo -e "DEFAULT DATE mode : yes"; fi
    echo -e "START_DATE        : ${START_DATE}"
    echo -e "END_DATE          : ${END_DATE}"

    if [ "1" == ${P_DEBUG} ]; then
      echo -e "${TIMESTAMP} # Current settings" >> ${DEBUG_LOG_FILE}
      echo -e "${TIMESTAMP} # Arguments: [u |p |sd|ed|t |1m|6m|1y|d ]" >> ${DEBUG_LOG_FILE}
      if [ "1" == ${P_USER} ]; then       echo -ne "${TIMESTAMP} #            [--|"; else  echo -ne "  |"; fi >> ${DEBUG_LOG_FILE}
      if [ "1" == ${P_PASSWORD} ]; then   echo -ne "--|"; else  echo -ne "  |"; fi >> ${DEBUG_LOG_FILE}
      if [ "1" == ${P_START_DATE} ]; then echo -ne "--|"; else  echo -ne "  |"; fi >> ${DEBUG_LOG_FILE}
      if [ "1" == ${P_END_DATE} ]; then   echo -ne "--|"; else  echo -ne "  |"; fi >> ${DEBUG_LOG_FILE}
      if [ "1" == ${P_TODAY} ]; then      echo -ne "--|"; else  echo -ne "  |"; fi >> ${DEBUG_LOG_FILE}
      if [ "1" == ${P_1_MONTH} ]; then    echo -ne "--|"; else  echo -ne "  |"; fi >> ${DEBUG_LOG_FILE}
      if [ "1" == ${P_6_MONTHS} ]; then   echo -ne "--|"; else  echo -ne "  |"; fi >> ${DEBUG_LOG_FILE}
      if [ "1" == ${P_1_YEAR} ]; then     echo -ne "--|"; else  echo -ne "  |"; fi >> ${DEBUG_LOG_FILE}
      if [ "1" == ${P_DEBUG} ]; then      echo -e  "--]"; else  echo -e  "  ]"; fi >> ${DEBUG_LOG_FILE}

      echo -e "${TIMESTAMP} # USERNAME          : ${USER}" >> ${DEBUG_LOG_FILE}
      if [ "1" == ${P_DEFAULT_DATE} ]; then echo -e "${TIMESTAMP} # DEFAULT DATE mode : yes"i >> ${DEBUG_LOG_FILE}; else echo -e "${TIMESTAMP} # DEFAULT DATE mode : no" >> ${DEBUG_LOG_FILE}; fi;
      echo -e "${TIMESTAMP} # START_DATE        : ${START_DATE}" >> ${DEBUG_LOG_FILE}
      echo -e "${TIMESTAMP} # END_DATE          : ${END_DATE}" >> ${DEBUG_LOG_FILE}
    fi
}

#------------------------------------------------------------------------------
# no param
#------------------------------------------------------------------------------
function init_debug_mode(){
  mkdir -p "${DEBUG_FOLDER}" || die "not able to create folder: ${DEBUG_FOLDER}"
  # create an empty file
  > ${DEBUG_LOG_FILE}
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
  -d               | --debug\n \
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
        --debug | -d)
            P_DEBUG="1"
            init_debug_mode
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

[ ${P_DEBUG} == "1" ] && echo -e "${TIMESTAMP} # Format of the command line arguments are valid" >> ${DEBUG_LOG_FILE};


# CHECK DEPENDENT PROGRAMS
[ ${P_DEBUG} == "1" ] && echo -e "\n${TIMESTAMP} # CHECK DEPENDENT PROGRAMS ----" >> ${DEBUG_LOG_FILE};
## xmllint
[ ${P_DEBUG} == "1" ] && echo -e "${TIMESTAMP} #  * xmllint - command line XML tool (mandatory)" >> ${DEBUG_LOG_FILE};
if ! which xmllint &>/dev/null; then
  echo -e "${CRED}ERROR: \"xmllint\" program is not installed. Install the \"libxml2-utils\" package (debian/ubuntu: apt-get install libxml2-utils; cygwin: setup-x86_64 -qP libxml2).${CEND}"; exit 1;
  [ ${P_DEBUG} == "1" ] && echo -e "${TIMESTAMP} # ERROR: \"xmllint\" program is not installed. Install the \"libxml2-utils\" package (debian/ubuntu: apt-get install libxml2-utils; cygwin: setup-x86_64 -qP libxml2)." >> ${DEBUG_LOG_FILE};
fi
## pv
[ ${P_DEBUG} == "1" ] && echo -e "${TIMESTAMP} #  * pv - monitor the progress of data through a pipe (optional)" >> ${DEBUG_LOG_FILE};
if ! which pv &>/dev/null; then
  echo "hint: install \"pv\" package for a nice progress bar"
  [ ${P_DEBUG} == "1" ] && echo -e "${TIMESTAMP} # hint: install \"pv\" package for a nice progress bar" >> ${DEBUG_LOG_FILE};
fi

# PROCESS COMMAND LINE ARGUMENTS
echo -e "Process command line arguments..."
[ ${P_DEBUG} == "1" ] && echo -e "\n${TIMESTAMP} # PROCESS COMMAND LINE ARGUMENTS ----" >> ${DEBUG_LOG_FILE};

## Login data checking
[ ${P_DEBUG} == "1" ] && echo -e "${TIMESTAMP} # Login data checking" >> ${DEBUG_LOG_FILE};
if [ "0" == ${P_USER} ] || [ "0" == ${P_PASSWORD} ]; then
    [ ${P_DEBUG} == "1" ] && echo -e "${TIMESTAMP} # ERROR: user/password data missing\nExit" >> ${DEBUG_LOG_FILE};
    echo -e "${CRED}ERROR: user/password data missing${CEND}"; exit 1;
fi

## Is default mode necessary?
[ ${P_DEBUG} == "1" ] && echo -e "${TIMESTAMP} # Is default date mode? " >> ${DEBUG_LOG_FILE};
if  [ "0" == ${P_END_DATE} ] && [ "0" == ${P_START_DATE} ] && \
    [ "0" == ${P_1_MONTH} ]  && [ "0" == ${P_6_MONTHS} ] && [ "0" == ${P_1_YEAR} ] && [ "0" == ${P_TODAY} ] ; then P_DEFAULT_DATE="1"; P_1_MONTH=1;fi

## Date parameter checking -- logically
[ ${P_DEBUG} == "1" ] && echo -e "${TIMESTAMP} # Date parameter checking -- logically" >> ${DEBUG_LOG_FILE};
if [ "1" == ${P_END_DATE} ] && [ "0" == ${P_START_DATE} ]; then
    [ ${P_DEBUG} == "1" ] && echo -e "${TIMESTAMP} # ERROR: '--start_date' parameter missing\nExit" >> ${DEBUG_LOG_FILE};
    echo -e "${CRED}ERROR: '--start_date' parameter missing${CEND}"; exit 1;
fi

## Calculating END_DATE
if [ "0" == ${P_END_DATE} ]; then END_DATE=$(date +%Y.%m.%d); [ ${P_DEBUG} == "1" ] && echo -e "${TIMESTAMP} # 'END_DATE' was calculated: ${END_DATE}" >> ${DEBUG_LOG_FILE};fi;

## Date parameter checking -- format
[ ${P_DEBUG} == "1" ] && echo -e "${TIMESTAMP} # Date parameter checking -- format" >> ${DEBUG_LOG_FILE};
if [ "1" == ${P_START_DATE} ]; then
    if [[ ! ${START_DATE} =~ ${REGEX_DATE} ]]; then [ "1" == ${P_DEBUG} ] && echo -e "${TIMESTAMP} # ERROR: invalid '--start_date' (${START_DATE})\nExit" >> ${DEBUG_LOG_FILE};
                                                    echo -e "${CRED}ERROR: invalid '--start_date' (${START_DATE})${CEND}"; exit 1; fi
fi
if [ "1" == ${P_END_DATE} ]; then
    if [[ ! ${END_DATE} =~ ${REGEX_DATE} ]]; then [ "1" == ${P_DEBUG} ] && echo -e "${TIMESTAMP} # ERROR: invalid '--end_date' (${END_DATE})\nExit" >> ${DEBUG_LOG_FILE};
                                                 echo -e "${CRED}ERROR: invalid '--end_date' (${END_DATE})${CEND}"; exit 1; fi
fi
## Date parameter checking -- start_date - end_date relation
[ ${P_DEBUG} == "1" ] && echo -e "${TIMESTAMP} # Date parameter checking -- start_date - end_date relation" >> ${DEBUG_LOG_FILE};
if [[ ${END_DATE} < ${START_DATE} ]]; then
    [ ${P_DEBUG} == "1" ] && echo -e "${TIMESTAMP} # ERROR: '--end_date' parameter is less than '--start_date'\nExit" >> ${DEBUG_LOG_FILE};
    echo -e "${CRED}ERROR: '--end_date' is less than '--start_date'${CEND}"; exit 1;
fi

## Prioritize exact(yyyy.mm.dd) and generic(-1m) date formats
[ ${P_DEBUG} == "1" ] && echo -e "${TIMESTAMP} # Prioritize exact(yyyy.mm.dd) and generic(-1m) date formats" >> ${DEBUG_LOG_FILE};
if ( [ "1" == ${P_END_DATE} ] || [ "1" == ${P_START_DATE} ] ) && \
   ( [ "1" == ${P_1_MONTH} ] || [ "1" == ${P_6_MONTHS} ] || [ "1" == ${P_1_YEAR} ] || [ "1" == ${P_TODAY} ] ); then
        if [ "1" == ${P_TODAY} ]; then  echo -e "${CLYELLOW}WARNING: '--today' parameter is dropped${CEND}";P_TODAY="0";
            [ "1" == ${P_DEBUG} ] && echo -e "${TIMESTAMP} # WARNING: '--today' parameter is dropped" >> ${DEBUG_LOG_FILE};fi;

        if [ "1" == ${P_1_MONTH} ]; then  echo -e "${CLYELLOW}WARNING: '--last-1-month' parameter is dropped${CEND}";P_1_MONTH="0";
            [ "1" == ${P_DEBUG} ] && echo -e "${TIMESTAMP} # WARNING: '--last-1-month' parameter is dropped" >> ${DEBUG_LOG_FILE};fi;

        if [ "1" == ${P_6_MONTHS} ]; then echo -e "${CLYELLOW}WARNING: '--last-6-months' parameter is dropped${CEND}";P_6_MONTHS="0";
            [ "1" == ${P_DEBUG} ] && echo -e "${TIMESTAMP} # WARNING: '--last-6-months' parameter is dropped" >> ${DEBUG_LOG_FILE};fi;

        if [ "1" == ${P_1_YEAR} ]; then  echo -e "${CLYELLOW}WARNING: '--last-1-year' parameter is dropped${CEND}";P_1_YEAR="0";
            [ "1" == ${P_DEBUG} ] && echo -e "${TIMESTAMP} # WARNING: '--last-1-year' parameter is dropped" >> ${DEBUG_LOG_FILE};fi;
fi

## Choosing the closest date
[ ${P_DEBUG} == "1" ] && echo -e "${TIMESTAMP} # Choosing the closest date" >> ${DEBUG_LOG_FILE};
date_flags=$((${P_TODAY}+${P_1_MONTH}+${P_6_MONTHS}+${P_1_YEAR}))
if ( [ ${date_flags} -gt "1" ] ); then
    [ ${P_DEBUG} == "1" ] && echo -e "${TIMESTAMP} # Choosing the closest date -- logic was activated" >> ${DEBUG_LOG_FILE};
    FLAG="0"
    if [ "1" == ${P_TODAY} ]; then  FLAG="1"; fi;

    if [ "1" == ${FLAG} ] && [ "1" == ${P_1_MONTH} ]; then
        echo -e "${CLYELLOW}WARNING: '--last-1-month' parameter is dropped${CEND}";P_1_MONTH="0";
        [ "1" == ${P_DEBUG} ] && echo -e "${TIMESTAMP} # WARNING: '--last-1-month' parameter is dropped" >> ${DEBUG_LOG_FILE};
    else
        if [ "1" == ${P_1_MONTH} ]; then FLAG="1"; fi
    fi;

    if [ "1" == ${FLAG} ] && [ "1" == ${P_6_MONTHS} ]; then
        echo -e "${CLYELLOW}WARNING: '--last-6-months' parameter is dropped${CEND}";P_6_MONTHS="0";
        [ "1" == ${P_DEBUG} ] && echo -e "${TIMESTAMP} # WARNING: '--last-6-months' parameter is dropped" >> ${DEBUG_LOG_FILE};
    else
        if [ "1" == ${P_6_MONTHS} ]; then FLAG="1"; fi
    fi

    if [ "1" == ${FLAG} ] && [ "1" == ${P_1_YEAR} ]; then
        echo -e "${CLYELLOW}WARNING: '--last-1-year' parameter is dropped${CEND}";P_1_YEAR="0";
        [ "1" == ${P_DEBUG} ] && echo -e "${TIMESTAMP} # WARNING: '--last-1-year' parameter is dropped" >> ${DEBUG_LOG_FILE};
    else
        if [ "1" == ${P_1_YEAR} ]; then FLAG="1"; fi
    fi;
fi


## Calculating START DATE parameter for generic date form
[ ${P_DEBUG} == "1" ] && echo -e "${TIMESTAMP} # Calculating START DATE parameter for generic date form" >> ${DEBUG_LOG_FILE};
if [ "1" == ${P_TODAY} ]; then  START_DATE=$(date +%Y.%m.%d); fi;
if [ "1" == ${P_1_MONTH} ]; then  START_DATE=$(date -d "-1 months" +%Y.%m.%d); fi;
if [ "1" == ${P_6_MONTHS} ]; then START_DATE=$(date -d "-6 months" +%Y.%m.%d); fi;
if [ "1" == ${P_1_YEAR} ]; then   START_DATE=$(date -d "-1 years" +%Y.%m.%d); fi;

# PRINTING CONFIGURATION INFO
[ ${P_DEBUG} == "1" ] && echo -e "\n${TIMESTAMP} # PRINTING CONFIGURATION INFO ----" >> ${DEBUG_LOG_FILE};
show_config

# LOGIN TO THE SITE
[ ${P_DEBUG} == "1" ] && echo -e "\n${TIMESTAMP} # LOGIN TO THE SITE ----" >> ${DEBUG_LOG_FILE};
printf "Login attempt... "
[ ${P_DEBUG} == "1" ] && echo -e "${TIMESTAMP} # Login attempt..." >> ${DEBUG_LOG_FILE};
[ ${P_DEBUG} == "1" ] && echo -e "${TIMESTAMP} # ${DIJNET_BASE_URL}/login/login_check_password POST_DATA=vfw_form=login_check_password&username=${USER}&password=*** | iconv -f iso8859-2 -t utf-8" >> ${DEBUG_LOG_FILE};
LOGIN=$(dijnet "login/login_check_password" "vfw_form=login_check_password&username=${USER}&password=${PASS}" \
      | iconv -f iso8859-2 -t utf-8)
if ! echo "${LOGIN}" | grep -q --ignore-case "Bejelentkez&eacute;si n&eacute;v: <strong>${USER}"; then
  LOGIN_ERROR=$(echo "${LOGIN}" | xpath '//strong[contains(@class, "out-error-message")]/text()')
  [ ${P_DEBUG} == "1" ] && echo -e "${TIMESTAMP} # Login failed\nExit" >> ${DEBUG_LOG_FILE};
  die "login failed (${LOGIN_ERROR})"
fi
echo "OK"
[ ${P_DEBUG} == "1" ] && echo -e "${TIMESTAMP} # Logged in successfully" >> ${DEBUG_LOG_FILE};

# GRABBING DATA OF REGISTERED PROVIDERS
[ ${P_DEBUG} == "1" ] && echo -e "\n${TIMESTAMP} # GRABBING DATA OF REGISTERED PROVIDERS ----" >> ${DEBUG_LOG_FILE};
printf "Query data of the registered providers... "
[ ${P_DEBUG} == "1" ] && echo -e "${TIMESTAMP} # "Query data of the registered providers... >> ${DEBUG_LOG_FILE};

## Data in UTF-8 coding
[ ${P_DEBUG} == "1" ] && echo -e "${TIMESTAMP} # (UTF-8) ${DIJNET_BASE_URL}/control/szamla_search POST_DATA=" >> ${DEBUG_LOG_FILE};
UTF8_DATA=$(dijnet 'control/szamla_search' | iconv -f iso8859-2 -t utf-8 | grep -o "{\"aliasnev\":\"[^\"]*\",\"szlaszolgnev\":\"[^\"]*\",\"regszolgid\":[^,]*,\"ugyfelazon\":\"[^\"]*\",\"statusgrp\":[^,]*,\"szolgid\":[^,]*,\"alias\":\"[^\"]*\"}")
readarray -t UTF8_ALIASES < <(grep -o "\"alias\":\"[^\"]*\"" <<< ${UTF8_DATA} | sed 's/\"//g' | awk -F":" '{ print $2 }')
readarray -t UTF8_PROVIDERS < <(grep -o "\"szlaszolgnev\":\"[^\"]*\"" <<< ${UTF8_DATA} | sed 's/\"//g' | awk -F":" '{ print $2 }')
readarray -t UTF8_CUSTOMER_REG_IDS < <(grep -o "\"regszolgid\":[^,]*" <<< ${UTF8_DATA} | sed 's/\"//g' | awk -F":" '{ print $2 }')

[ ${P_DEBUG} == "1" ] && echo -e "${TIMESTAMP} # UTF8_DATA ------------------------------" >> ${DEBUG_LOG_FILE};
[ ${P_DEBUG} == "1" ] && echo -e "${UTF8_DATA}" >> ${DEBUG_LOG_FILE};
[ ${P_DEBUG} == "1" ] && echo -e "${TIMESTAMP} # UTF8_DATA ------------------------------\n" >> ${DEBUG_LOG_FILE};

[ ${P_DEBUG} == "1" ] && echo -e "${TIMESTAMP} # UTF8_ALIASES ----------------------------" >> ${DEBUG_LOG_FILE};
[ ${P_DEBUG} == "1" ] && echo -e "${UTF8_ALIASES[@]}" >> ${DEBUG_LOG_FILE};
[ ${P_DEBUG} == "1" ] && echo -e "${TIMESTAMP} # UTF8_ALIASES ----------------------------\n" >> ${DEBUG_LOG_FILE};

[ ${P_DEBUG} == "1" ] && echo -e "${TIMESTAMP} # UTF8_PROVIDERS ------------------------------" >> ${DEBUG_LOG_FILE};
[ ${P_DEBUG} == "1" ] && echo -e "${UTF8_PROVIDERS[@]}" >> ${DEBUG_LOG_FILE};
[ ${P_DEBUG} == "1" ] && echo -e "${TIMESTAMP} # UTF8_PROVIDERS ------------------------------\n" >> ${DEBUG_LOG_FILE};

[ ${P_DEBUG} == "1" ] && echo -e "${TIMESTAMP} # UTF8_CUSTOMER_REG_IDS ------------------------------" >> ${DEBUG_LOG_FILE};
[ ${P_DEBUG} == "1" ] && echo -e "${UTF8_CUSTOMER_REG_IDS[@]}" >> ${DEBUG_LOG_FILE};
[ ${P_DEBUG} == "1" ] && echo -e "${TIMESTAMP} # UTF8_CUSTOMER_REG_IDS ------------------------------\n" >> ${DEBUG_LOG_FILE};

## Providers in ISO8859-2 coding for http post
[ ${P_DEBUG} == "1" ] && echo -e "${TIMESTAMP} # "Providers in ISO8859-2 coding for http post >> ${DEBUG_LOG_FILE};
[ ${P_DEBUG} == "1" ] && echo -e "${TIMESTAMP} # (ISO8859-2) ${DIJNET_BASE_URL}/control/szamla_search POST_DATA=" >> ${DEBUG_LOG_FILE};
readarray -t PROVIDERS < <(dijnet "control/szamla_search" | perl -lne '/sopts.add\(.(.+?).\)/ and print $1')

[ ${P_DEBUG} == "1" ] && echo -e "\n${TIMESTAMP} # ISO8859-2_PROVIDERS ------------------------------" >> ${DEBUG_LOG_FILE};
[ ${P_DEBUG} == "1" ] && echo -e "${PROVIDERS[@]}" >> ${DEBUG_LOG_FILE};
[ ${P_DEBUG} == "1" ] && echo -e "${TIMESTAMP} # ISO8859-2_PROVIDERS ------------------------------\n" >> ${DEBUG_LOG_FILE};

echo OK
[ ${P_DEBUG} == "1" ] && echo -e "${TIMESTAMP} # Data are collected" >> ${DEBUG_LOG_FILE};

## Some helper array, variable
[ ${P_DEBUG} == "1" ] && echo -e "${TIMESTAMP} # Some helper array, variable" >> ${DEBUG_LOG_FILE};
SIZE=${#UTF8_ALIASES[@]}
[ ${P_DEBUG} == "1" ] && echo -e "${TIMESTAMP} # Size of UTF8_ALIASES array: ${SIZE}" >> ${DEBUG_LOG_FILE};

### Calculating max length of UTF8_ALIASES
[ ${P_DEBUG} == "1" ] && echo -e "${TIMESTAMP} # Calculating max length of UTF8_ALIASES" >> ${DEBUG_LOG_FILE};
ALL_IN_ONE_ALIASES=""
ALIASES_MAX_LEN=0
for x in ${UTF8_ALIASES[@]}; do
        ALL_IN_ONE_ALIASES="${ALL_IN_ONE_ALIASES}\n$x"
        strlength=`printf "%s" "$x" | wc -m`
        if [ ${strlength} -gt ${ALIASES_MAX_LEN} ]; then ALIASES_MAX_LEN=${#x}; fi
done
[ ${P_DEBUG} == "1" ] && echo -e "${TIMESTAMP} # Max length in the UTF8_ALIASES array: ${ALIASES_MAX_LEN}" >> ${DEBUG_LOG_FILE};

### Existance of the item in UTF8_PROVIDERS (More appearence means subdirectory is needed in the TARGET_PATH calculation)
[ ${P_DEBUG} == "1" ] && echo -e "${TIMESTAMP} # Existance of the item in UTF8_PROVIDERS (More appearence means subdirectory is needed in the TARGET_PATH calculation)" >> ${DEBUG_LOG_FILE};
readarray -t PROVIDERS_OCCUR < <(for x in ${UTF8_ALIASES[@]}; do grep -o ${x} <<<${ALL_IN_ONE_ALIASES} | wc -l;done)
[ ${P_DEBUG} == "1" ] && echo -e "\n${TIMESTAMP} # PROVIDERS_OCCUR ------------------------------" >> ${DEBUG_LOG_FILE};
[ ${P_DEBUG} == "1" ] && echo -e "${PROVIDERS_OCCUR[@]}" >> ${DEBUG_LOG_FILE};
[ ${P_DEBUG} == "1" ] && echo -e "${TIMESTAMP} # PROVIDERS_OCCUR ------------------------------" >> ${DEBUG_LOG_FILE};

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
[ ${P_DEBUG} == "1" ] && echo -e "\n${TIMESTAMP} # DOWNLOADING" >> ${DEBUG_LOG_FILE};
printf "Download invoices...\n"
[ ${P_DEBUG} == "1" ] && echo -e "${TIMESTAMP} # Downloading invoices..." >> ${DEBUG_LOG_FILE};
LAST=$(( ${SIZE}-1 ))
for IDX in $(seq 0 ${LAST}); do
  [ ${P_DEBUG} == "1" ] && echo -e "${TIMESTAMP} # ---- Query list of the invoices ---- " >> ${DEBUG_LOG_FILE};
  [ ${P_DEBUG} == "1" ] && echo -e "${TIMESTAMP} # ---- -- Provider: '${PROVIDERS[$IDX]}'" >> ${DEBUG_LOG_FILE};
  [ ${P_DEBUG} == "1" ] && echo -e "${TIMESTAMP} # ---- -- Provider: '${UTF8_CUSTOMER_REG_IDS[$IDX]}'" >> ${DEBUG_LOG_FILE};
  [ ${P_DEBUG} == "1" ] && echo -e "${TIMESTAMP} # ---- -- Date: ${START_DATE} - ${END_DATE}" >> ${DEBUG_LOG_FILE};

# This version worked until 2020.05.14
#  INVOICES_COUNT=$(dijnet "control/szamla_search_submit" "datumig=${END_DATE}&datumtol=${START_DATE}&vfw_form=szamla_search_submit&vfw_coll=szamla_search_params&szlaszolgnev=${PROVIDERS[${IDX}]}&regszolgid=${UTF8_CUSTOMER_REG_IDS[${IDX}]}" \
#           | xpath '//table[contains(@class, "szamla_table")]/tbody/tr/td[1]/@onclick'
#           | sed 's/onclick="xt_cell_click(this,.//g;s/.)"//g;s/\&amp;/\&/g;s/\/ekonto\/control\///g')

  [ ${P_DEBUG} == "1" ] && echo -e "${TIMESTAMP} # (UTF-8) ${DIJNET_BASE_URL}/control/szamla_search_submit POST_DATA=datumig=${END_DATE}&datumtol=${START_DATE}&vfw_form=szamla_search_submit&vfw_coll=szamla_search_params&regszolgid=${UTF8_CUSTOMER_REG_IDS[${IDX}]}" >> ${DEBUG_LOG_FILE};

  INVOICES_LIST_BARE=$(dijnet "control/szamla_search_submit" "datumig=${END_DATE}&datumtol=${START_DATE}&vfw_form=szamla_search_submit&vfw_coll=szamla_search_params&szlaszolgnev=${PROVIDERS[${IDX}]}&regszolgid=${UTF8_CUSTOMER_REG_IDS[${IDX}]}" )
  [ ${P_DEBUG} == "1" ] && echo -e "\n${TIMESTAMP} # INVOICES_LIST_BARE ------------------------------" >> ${DEBUG_LOG_FILE};
  [ ${P_DEBUG} == "1" ] && echo -e "${INVOICES_LIST_BARE}" >> ${DEBUG_LOG_FILE};
  [ ${P_DEBUG} == "1" ] && echo -e "${TIMESTAMP} # INVOICES_LIST_BARE ------------------------------\n" >> ${DEBUG_LOG_FILE};

  # List of invoices:
  # <table class="szamla_table" ...
  #   <tr id="r_0" ...
  #   <tr id="r_1" ...
  #   <tr id="r_2" ...
  # The number of invoices is able to determine from max of r_<number>

  # INVOICE_COUNT=$(echo "${INVOICES_LIST_BARE}" | iconv -f iso-8859-1 -t utf-8 | sed 's/[õ�áâàãäéêèëíîìïóôòõöúûùüÕ�ÁÂÀÃÄÉÊÈËÍÎÌÏÓÔÒÕÖÚÛÙÜ]//g' | sed -n 's/.*id\=\"r_\([0-9]*\)\" class\=\"\".*/\1/p' | tail -1)
  # The problematic part of the 'INVOICES_LIST_BARE' is the  ISO-8859-1 coded 'utf8:õ/iso-8859-1:�'char in the 'Díjbeszedő'. The problem is managed with 'iconv'
 INVOICE_COUNT=$(echo "${INVOICES_LIST_BARE}" | iconv -f iso-8859-1 -t utf-8 | sed -n 's/.*id\=\"r_\([0-9]*\)\" class\=\"\".*/\1/p' | tail -1)
  [ ${P_DEBUG} == "1" ] && echo -e "${TIMESTAMP} # INVOICE_COUNT: ${INVOICE_COUNT}" >> ${DEBUG_LOG_FILE};
  if [ -z "${INVOICE_COUNT}" ]; then echo "EMPTY"; INVOICE_COUNT="0"; INVOICE_COUNT_PRN="0"; else echo "NOT EMPTY"; INVOICE_COUNT_PRN=$(( ${INVOICE_COUNT} + 1 )); fi;
echo "__PASSED__"
  [ ${P_DEBUG} == "1" ] && echo -e "${TIMESTAMP} # INVOICE_COUNT: ${INVOICE_COUNT}" >> ${DEBUG_LOG_FILE};
  [ ${P_DEBUG} == "1" ] && echo -e "${TIMESTAMP} # INVOICE_COUNT_PRN: ${INVOICE_COUNT_PRN}" >> ${DEBUG_LOG_FILE};

  ## Printout about PROVIDER per INVOICES
  strlengthc=`printf "%s" "${UTF8_ALIASES[${IDX}]}" | wc -c` # in bytes (it can be bigger because of utf-8 coding)
  [ ${P_DEBUG} == "1" ] && echo -e "${TIMESTAMP} # ${UTF8_ALIASES[${IDX}]} len in bytes : ${strlengthc}" >> ${DEBUG_LOG_FILE};
  strlengthm=`printf "%s" "${UTF8_ALIASES[${IDX}]}" | wc -m` # in chars
  [ ${P_DEBUG} == "1" ] && echo -e "${TIMESTAMP} # ${UTF8_ALIASES[${IDX}]} len in chars : ${strlengthm}" >> ${DEBUG_LOG_FILE};

  printf "${CLYELLOW}%-$(( strlength=${ALIASES_MAX_LEN}+${strlengthc}-${strlengthm} ))s -- ${CLCYAN}%3s invoices ${CLGREEN}-- ${UTF8_PROVIDERS[${IDX}]}\033[0m\n" ${UTF8_ALIASES[${IDX}]} ${INVOICE_COUNT_PRN} ${note}

  if [ "0" != ${INVOICE_COUNT_PRN} ]; then
    ## Process the list of invoices
    [ ${P_DEBUG} == "1" ] && echo -e "${TIMESTAMP} # Process the list if invoices" >> ${DEBUG_LOG_FILE};
    INVOICE_INDEX=1
    for INVOICE_IDX in $(seq 0 ${INVOICE_COUNT}); do
      [ ${P_DEBUG} == "1" ] && echo -e "${TIMESTAMP} # INVOICE_IDX_: ${INVOICE_IDX}" >> ${DEBUG_LOG_FILE};

      [ ${P_DEBUG} == "1" ] && echo -e "${TIMESTAMP} # (UTF-8) ${DIJNET_BASE_URL}/control/szamla_select POST_DATA=vfw_coll=szamla_list&vfw_rowid=${INVOICE_IDX}&exp=K" >> ${DEBUG_LOG_FILE};
      INVOICE_PAGE=$(dijnet "control/szamla_select" "vfw_coll=szamla_list&vfw_rowid=${INVOICE_IDX}&exp=K")
      [ ${P_DEBUG} == "1" ] && echo -e "\n${TIMESTAMP} # INVOICE_PAGE ------------------------------" >> ${DEBUG_LOG_FILE};
      [ ${P_DEBUG} == "1" ] && echo -e "${INVOICE_PAGE}" >> ${DEBUG_LOG_FILE};
      [ ${P_DEBUG} == "1" ] && echo -e "${TIMESTAMP} # INVOICE_PAGE ------------------------------\n" >> ${DEBUG_LOG_FILE};

      [ ${P_DEBUG} == "1" ] && echo -e "${TIMESTAMP} # (UTF-8) ${DIJNET_BASE_URL}/control/szamla_letolt POST_DATA=" >> ${DEBUG_LOG_FILE};
      INVOICE_DOWNLOAD=$(dijnet "control/szamla_letolt")
      [ ${P_DEBUG} == "1" ] && echo -e "\n${TIMESTAMP} # INVOICE_DOWNLOAD ------------------------------" >> ${DEBUG_LOG_FILE};
      [ ${P_DEBUG} == "1" ] && echo -e "${INVOICE_DOWNLOAD}" >> ${DEBUG_LOG_FILE};
      [ ${P_DEBUG} == "1" ] && echo -e "${TIMESTAMP} # INVOICE_DOWNLOAD ------------------------------\n" >> ${DEBUG_LOG_FILE};

      INVOICE_NUMBER=$(echo "${INVOICE_DOWNLOAD}" | xpath '//label[@class="title_next_s"]/text()' | sed 's/\//_/g;s/ //g')
      INVOICE_NUMBER=$(awk -F"-" '{ print $2 }'<<< ${INVOICE_NUMBER})"-"$(awk -F"-" '{ print $1 }'<<< ${INVOICE_NUMBER})
      [ ${P_DEBUG} == "1" ] && echo -e "${TIMESTAMP} # INVOICE_NUMBER: ${INVOICE_NUMBER}" >> ${DEBUG_LOG_FILE};

      ### Evaulate directory structure
      if [ ${PROVIDERS_OCCUR[${IDX}]} -gt 1 ]; then
        TARGET_FOLDER=$(echo "dijnet-invoices/${UTF8_ALIASES[${IDX}]}/${UTF8_PROVIDERS[${IDX}]}/${INVOICE_NUMBER}" | sed 's/ \+/_/g;s/\.\//\//g')
      else
        TARGET_FOLDER=$(echo "dijnet-invoices/${UTF8_ALIASES[${IDX}]}/${INVOICE_NUMBER}" | sed 's/ \+/_/g;s/\.\//\//g')
      fi
      [ ${P_DEBUG} == "1" ] && echo -e "${TIMESTAMP} # Target folder for invoices: ${TARGET_FOLDER}" >> ${DEBUG_LOG_FILE};
      mkdir -p "${TARGET_FOLDER}" || die "not able to create folder: ${TARGET_FOLDER}"

      echo "${INVOICE_INDEX}"
      DOWNLOAD_LINKS=$(echo "${INVOICE_DOWNLOAD}" | xpath '//a[contains(@class, "xt_link__download")]/@href' | sed 's/href="\([^"]*\)"/\1 /g')
      for DOWNLOAD_LINK in ${DOWNLOAD_LINKS}; do
        echo "${DOWNLOAD_LINK}" | egrep -qi "adobe|e-szigno" && continue
        [ ${P_DEBUG} == "1" ] && echo -e "${TIMESTAMP} # Download file from ${DIJNET_BASE_URL}/control/${DOWNLOAD_LINK}" >> ${DEBUG_LOG_FILE};
        wget --quiet --load-cookies "${COOKIES}" --content-disposition --no-clobber \
             --directory-prefix "${TARGET_FOLDER}" "${DIJNET_BASE_URL}/control/${DOWNLOAD_LINK}"
      done
      [ ${P_DEBUG} == "1" ] && echo -e "${TIMESTAMP} # Back to the list of the invoices" >> ${DEBUG_LOG_FILE};
      [ ${P_DEBUG} == "1" ] && echo -e "${TIMESTAMP} # (UTF-8) ${DIJNET_BASE_URL}/control/szamla_list POST_DATA=" >> ${DEBUG_LOG_FILE};
      dijnet "control/szamla_list" &>/dev/null
      ((INVOICE_INDEX++))
    done | progress
  fi
done
