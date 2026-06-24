#!/bin/bash

# shellcheck source=/dev/null disable=SC2119,SC2120,SC2294,SC2001,SC2045,SC2184,SC2059,SC2034


CHECK_KO="[\033[0;31m✗\033[0m]"
CHECK_WARN="[\033[0;33m▲︋\033[0m]"
CHECK_SUCCESS="[\033[0;32m✓\033[0m]"
CHECK_INFO="[\033[0;34m★\033[0m]"

ERROR_ARGV=10

GREP="/usr/bin/grep --text" # no _shellcheck
EGREP="/usr/bin/grep --text" # no _shellcheck

_echoerr() {
    echo -e "$@" >&2
}

_verbose_func_space () {
    local __i
    local __func_list
    local __oldIFS=$IFS
    local __msg

    IFS=''
    VERBOSE_SPACE=""
    for (( i=0; i<${#FUNC_LIST[@]}; i++ )); do
        __msg=$(echo "${FUNC_LIST[$i]}" | cut -d: -f1)
        VERBOSE_SPACE="$VERBOSE_SPACE $__msg >"
    done
    IFS=$__oldIFS
}

_func_start () {
    local __msg="Start"
    local __start
    local __i=0

    __start=$(date +"%s.%N")

    _array_add FUNC_LIST "${FUNCNAME[1]}:$__start"
    _verbose_func_space

    if $DEBUG; then
        _debug "$__msg"
        if $VERBOSE; then
            if ! _exist "$1"; then _verbose "$__msg > no args" ; fi
            while _exist "$1" ; do
                __i=$(("$__i"+1))
                _verbose "$__msg > \$$__i:\"$1\"" ; shift
            done
        fi
    fi
}

_func_end () { # no _shellcheck
    _verbose_func_space

    local __date
    local __msg
    local __nb
    local __start
    local __end
    local __duration

    __nb=$(_array_count_elt FUNC_LIST)
    __nb=$((__nb-1))
    __start=$(echo "$__nb ${FUNC_LIST[$__nb]}" | cut -d: -f2)
    __end=$(date +"%s.%N")
    __duration=$(_timediff "$__start" "$__end")

    if ! _exist "$1"; then
        __msg="End"
    else
        __msg="End - returning:$1 - in $__duration""ms"
    fi

    __date=$(_date)

    if $DEBUG; then
        _debug "$__msg"
    fi

    _array_remove_last FUNC_LIST
}

_error() { # no _shellcheck
    _log "ERROR  " "\033[0;31m" "$CHECK_KO $*"
}

_warning() {
    _log "WARNING" "\033[0;33m" "$CHECK_WARN $*"
}

_success() {
    _log "SUCCESS" "\033[0;32m" "$CHECK_SUCCESS $*"
}

_info() {
    _log "INFO   " "\033[0;34m" "$CHECK_INFO $*"
}

_debug() {
    _log "DEBUG  " "" "$*"
}

_verbose() {
    _log "VERBOSE" "" "$*"
}

_log () {

    local __level="$1" __color="$2" __message="$3"
    local __date

    __date=$(_date)

    _verbose_func_space

    if [[ "$__level" == "DEBUG  " && $DEBUG != true ]];   then return ; fi
    if [[ "$__level" == "VERBOSE" && $VERBOSE != true ]]; then return ; fi

    if $DEBUG; then
        _echoerr "[$$] -- ${__color}${__level}\033[0m -- $__date -- $VERBOSE_SPACE $__message"
    else
        if $VERBOSE; then
            _echoerr "[$$] -- VERBOSE -- $__date -- $__message"
        else
            _echoerr "$__message"
        fi
    fi
}

_exist () {
    if [[ -z "$1" ]] ; then return 1; else return 0; fi
}

_fileexist () {
    _func_start "$@"

    if [ -e "$1" ]; then
        _verbose "$1 already exist"
        _func_end "0" ; return 0 # no _shellcheck
    else
        _verbose "$1 not exist"
        _func_end "1" ; return 1 # no _shellcheck
    fi
}

_installed () {
    if type "$1" 2> /dev/null 1>/dev/null ; then return 0; else return 1; fi
}

_working_dir () {
    basename "$PWD"
}

_working_dir_count_file () {
    if _exist "$1" ; then
        find "." -maxdepth 1 -type f -name "$@" | wc -l | xargs
    else
        find "." -maxdepth 1 -type f | wc -l | xargs
    fi
}

_working_dir_count_dir () {
    if _exist "$1" ; then
        find "." -maxdepth 1 -type d -name "$@" | $GREP "./" | wc -l | xargs
    else
        find "." -maxdepth 1 -type d | $GREP "./" | wc -l | xargs
    fi
}

_working_dir_list_dir_by_creation_date () {
    # shellcheck disable=1001
    find "." -maxdepth 1 -type d -exec stat --format="%w %n" {} + | sort -n | $GREP "/" | cut -d\/ -f2-42
}

_tmp_file () {
    _func_start "$@"

    # Check argv
    local __rand

    __rand=$(_gen_rand)

    if _exist "${FUNCNAME[1]}" ; then
        echo "/tmp/$(basename "$0")${FUNCNAME[1]}.$__rand"
    else
        _error "we'r not in a function, weird" ; _func_end "1" ; return 1
    fi

    _func_end "0" ; return 0 # no _shellcheck
}

####################################################################################################
########################################### RAND & UUID ############################################
####################################################################################################
_gen_rand () {
    _func_start "$@"

    local __rand

    __rand=$(LC_ALL=C tr -dc "A-Z0-9" < /dev/urandom | \
       tr -d "IOS" | \
       fold  -w  "${1:-4}" | \
       paste -sd "${2:--}" - | \
       head  -c  "${3:-29}")

    echo "$__rand"

    _func_end "0" ; return 0 # no _shellcheck
}

_gen_pin () {
    _func_start "$@"

    local __pin

    __pin=$(LC_ALL=C tr -dc "0-9" < /dev/urandom | \
       fold  -w  "${1:-6}" | \
       head  -c  "${1:-6}")

    echo "$__pin"

    _func_end "0" ; return 0 # no _shellcheck
}

_gen_uuid () {
    _func_start "$@"

    if ! _installed "uuidgen" ; then _error "uuidgen not found"; return $ERROR_ARGV ; fi

    uuidgen

    _func_end "0" ; return 0 # no _shellcheck
}

####################################################################################################
######################################### TIME MANAGEMENT ##########################################
####################################################################################################
_date () {
    date '+%Y-%m-%d %H:%M:%S'
}

_iso_date () {
    date -u +"%Y-%m-%dT%H:%M:%S.%3NZ"
}

_timediff() {
    if ! _exist "$1"; then _error "start time EMPTY"; return 1 ; fi
    if ! _exist "$2"; then _error "end time EMPTY"; return 1 ; fi

    local __start_time
    local __end_time
    local __start_s
    local __start_nanos
    local __end_s
    local __end_nanos
    local __time

    __start_time=$1
    __end_time=$2

    __start_s=${__start_time%.*}
    __start_nanos=${__start_time#*.}
    __end_s=${__end_time%.*}
    __end_nanos=${__end_time#*.}

    # Strip leading zeros safely
    __start_s=$(echo "$__start_s" | sed 's/^0\+//')
    __start_nanos=$(echo "$__start_nanos" | sed 's/^0\+//')
    __end_s=$(echo "$__end_s" | sed 's/^0\+//')
    __end_nanos=$(echo "$__end_nanos" | sed 's/^0\+//')

    # Default to 0 if empty after stripping
    __start_s=${__start_s:-0}
    __start_nanos=${__start_nanos:-0}
    __end_s=${__end_s:-0}
    __end_nanos=${__end_nanos:-0}

    if [ "$__end_nanos" -lt "$__start_nanos" ];then
        __end_s=$(( "$__end_s" - 1 ))
        __end_nanos=$(( "$__end_nanos" + 10**9 ))
    fi

    __time=$(( "$__end_s" - "$__start_s" ))s$(( ("$__end_nanos" - "$__start_nanos")/10**6 ))

    echo $__time
}

_epoch_2_date () {
# always return UTC date
    if ! _exist "$1"; then _error "DATE EMPTY"; return 1 ; fi

    date -u -d "@$(awk '{print substr($0, 0, length($0)-3) "." substr($0, length($0)-2);}' <<< "$1")" +"%Y-%m-%d %H:%M:%S"
}

_date_2_epoch () {
# always return UTC epoch
    if ! _exist "$1"; then _error "DATE EMPTY"; return 1 ; fi

    date -d "$1" +"%s%3N"
}

####################################################################################################
######################################## ARRAY MANAGEMENT ##########################################
####################################################################################################
# we can't add _func_start "$@" && _func_end in array management ... infinite loop # no _shellcheck
_array_print () {
    if ! _exist "$1"; then _error "ARRAY EMPTY"; return 1 ; fi

    local __oldIFS=$IFS
    local i

    IFS=''
    declare -n __array
    __array="$1"

    for (( i=0; i<${#__array[@]}; i++ )); do
        echo "[$i]:${__array[$i]}"
    done

    IFS=$__oldIFS
}

_array_print_index () {
    if ! _exist "$1"; then _error "ARRAY EMPTY"; return 1 ; fi
    if ! _exist "$2"; then _error "INDEX EMPTY"; return 1 ; fi

    local __oldIFS=$IFS

    IFS=''
    declare -n __array
    __array="$1"

    echo "${__array[$2]}"

    IFS=$__oldIFS
}

_array_add () {
    if ! _exist "$1"; then _error "ARRAY EMPTY"; return 1 ; fi
    if ! _exist "$2"; then _error "ELEMENT EMPTY"; return 1 ; fi

    local __oldIFS=$IFS

    IFS=''
    declare -n __array
    __array="$1"

    __array+=("$2")

    IFS=$__oldIFS
}

_array_remove_last () {
    if ! _exist "$1"; then _error "ARRAY EMPTY"; return 1 ; fi

    local __oldIFS=$IFS

    IFS=''

    unset "$1"[-1]

    IFS=$__oldIFS
}

_array_remove_index () {
    if ! _exist "$1"; then _error "ARRAY EMPTY"; return 1 ; fi
    if ! _exist "$2"; then _error "INDEX EMPTY"; return 1 ; fi

    local __oldIFS=$IFS

    IFS=''
    declare -n __array
    __array="$1"

    unset "$1"["$2"]

    __array=("${__array[@]}")

    IFS=$__oldIFS
}

_array_count_elt () {
    if ! _exist "$@"; then _error "ARRAY EMPTY"; return 1 ; fi

    local __oldIFS=$IFS

    IFS=''
    declare -n __array
    __array="$1"

    echo ${#__array[@]}

    IFS=$__oldIFS
}

####################################################################################################
########################################### YAML & JSON ############################################
####################################################################################################
# we need to IFS='' before doing smthing like __my_var=$(cat $file) ; echo $__my_var | _json_2_yaml
_json_2_yaml () {
    _func_start "$@"

    # Check argv
    if ! _installed "yq"; then _error "yq not found"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi

    local __input=${*:-$(</dev/stdin)}
    local __return
    local __yq_version

    __yq_version=$(yq --version | sed -e 's/yq (https:\/\/github.com\/mikefarah\/yq\/) version v//' | sed -e 's/yq version //' | sed -e 's/yq //' | cut -d. -f1)
    if [ "$__yq_version" -ne 4 ]; then _error "yq $__yq_version not supported, need version >= 4"; _func_end "1" ; return 1 ; fi

    echo "$__input" | yq -p json
    __return=$? ; if [ $__return -ne 0 ] ; then _error "something went wrong with yq"; _func_end "$__return" ; return $__return ; fi

    _func_end "$__return" ; return $__return
}

_yaml_2_json () {
    _func_start "$@"

    # Check argv
    if ! _installed "yq"; then _error "yq not found"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi

    local __input=${*:-$(</dev/stdin)}
    local __return
    local __yq_version

    __yq_version=$(yq --version | sed -e 's/yq (https:\/\/github.com\/mikefarah\/yq\/) version v//' | sed -e 's/yq version //' | sed -e 's/yq //' | cut -d. -f1)
    if [ "$__yq_version" -ne 4 ]; then _error "yq $__yq_version not supported, need version >= 4"; _func_end "1" ; return 1 ; fi

    echo "$__input" | yq -o json
    __return=$? ; if [ $__return -ne 0 ] ; then _error "something went wrong with yq"; _func_end "$__return" ; return $__return ; fi

    _func_end "$__return" ; return $__return
}

_json_add_key_with_value () {
    _func_start "$@"

    # Check argv
    if ! _exist "$1"; then _error "JSON EMPTY" ; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _exist "$3"; then _error "KEY EMPTY" ; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _exist "$4"; then _error "VALUE EMPTY" ; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _installed "jq"; then _error "jq not found" ; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi

    local __return

    if _startswith "$4" "{"; then
        _debug "adding $(echo "$4" | jq -c) to $3"
        echo "$1" | jq '.'"$2"' += {"'"$3"'":'"$4"'}'
    else
        _debug "adding $4 to $3"
        echo "$1" | jq '.'"$2"' += {"'"$3"'":'"$4"'}'
    fi

    __return=$? ; if [ $__return -ne 0 ] ; then _error "something went wrong with jq"; _func_end "$__return" ; return $__return ; fi

    _func_end "$__return" ; return $__return
}

_json_add_value_in_array () {
    _func_start "$@"

    # Check argv
    if ! _exist "$1"; then _error "JSON EMPTY" ; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _exist "$3"; then _error "ARRAY EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _exist "$4"; then _error "VALUE EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _installed "jq"; then _error "jq not found"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi

    local __return
    local __pa

    if ! _exist "$2"; then __pa="$3"; else __pa="$2.$3" ; fi

    if _startswith "$4" "{"; then
        _debug "adding $(echo "$4" | jq -c) to $3"
        echo "$1" | jq '.'"$__pa"'[.'"$__pa"'|length] += '"$4"''
    else
        _debug "adding $4 to $3"
        echo "$1" | jq '.'"$__pa"'[.'"$__pa"'|length] += "'"$4"'"'
    fi

    __return=$? ; if [ $__return -ne 0 ] ; then _error "something went wrong with jq"; _func_end "$__return" ; return $__return ; fi

    _func_end "$__return" ; return $__return
}

_json_remove_key () {
    _func_start "$@"

    # Check argv
    if ! _exist "$1"; then _error "JSON EMPTY" ; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _exist "$2"; then _error "KEY EMPTY" ; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _installed "jq"; then _error "jq not found"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi

    _debug "removing $2"

    local __return

    echo "$1" | jq 'del(.'"$2"')'
    __return=$? ; if [ $__return -ne 0 ] ; then _error "something went wrong with jq"; _func_end "$__return" ; return $__return ; fi

    _func_end "$__return" ; return $__return
}

_json_replace_key_with_value () {
    _func_start "$@"

    # Check argv
    if ! _exist "$1"; then _error "JSON EMPTY" ; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _exist "$2"; then _error "KEY EMPTY" ; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _exist "$3"; then _error "VALUE EMPTY" ; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _installed "jq"; then _error "jq not found"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi

    local __return

    echo "$1" | jq '.'"$2"'="'"$3"'"'
    __return=$? ; if [ $__return -ne 0 ] ; then _error "something went wrong with jq"; _func_end "$__return" ; return $__return ; fi

    _func_end "$__return" ; return $__return
}

_json_get_value_from_key () {
    _func_start "$@"

    # Check argv
    if ! _exist "$1"; then _error "JSON EMPTY" ; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _exist "$2"; then _error "KEY EMPTY" ; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _installed "jq"; then _error "jq not found"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi

    local __return
    local __result

    __result=$(echo "$1" | jq -r '.'"$2"'' 2>/dev/null)

    if [ "a$__result" == "anull" ]; then __return=1 ; else __return=0; fi

    _debug "$2:$__result"
    echo "$__result"

    _func_end "$__return" ; return $__return
}

####################################################################################################
######################################## STRING MANAGEMENT #########################################
####################################################################################################
# next 3 func can be use like _upper "hello word" or echo "hello world" | _upper
_upper() {
    local __input=${*:-$(</dev/stdin)}

    echo "$__input" | tr '[:lower:]' '[:upper:]'
}

_lower() {
    local __input=${*:-$(</dev/stdin)}

    echo "$__input" | tr '[:upper:]' '[:lower:]'
}

_remove_last_car() {
    local __input=${*:-$(</dev/stdin)}

    echo "$__input" | sed -e 's/.$//'
}

_is_ascii() {
    LC_ALL=C $GREP -q '^[ -~]*$' <<<"$1"
}

_startswith() {
    local __str="$1"
    local __sub="$2"

    echo "$__str" | $GREP "^$__sub" >/dev/null 2>&1
}

####################################################################################################
############################################### URL ################################################
####################################################################################################
#
# usage: _curl --method ($1) --url ($2) --header ($3) --header-data ($4) --data ($5)
#
_curl () {
    _func_start "$@"

    # Check argv
    if ! _exist "$1"; then _error "METHOD EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _exist "$2"; then _error "URL EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _is_ascii "$2"; then _error "URL is non ASCII !!!"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _installed "curl"; then _error "curl not found"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi # no _shellcheck

    _debug "METHOD:$1"
    _debug "URL:$2"

    local __resp
    local __return

    case $1 in
        POST | PUT | DELETE | GET )
            if ! _exist "$3"; then
                __resp=$(curl -s -k -X "$1" --location "$2") # no _shellcheck
                __return=$? # no _shellcheck
            else
                if ! _exist "$4"; then
                    __resp=$(curl -s -k -X "$1" --location "$2" -H "$3") # no _shellcheck
                    __return=$? # no _shellcheck
                else
                    if ! _exist "$5"; then
                        __resp=$(curl -s -k -X "$1" --location "$2" -H "$3" -H "$4") # no _shellcheck
                        __return=$? # no _shellcheck
                    else
                        __resp=$(curl -s -k -X "$1" --location "$2" -H "$3" -H "$4" -d "$5") # no _shellcheck
                        __return=$? # no _shellcheck
                    fi
                fi
            fi
            ;;
        * ) _error "Wrong METHOD send to curl" ; _func_end "1" ; return 1 ;; # no _shellcheck
    esac

    case $__return in
        0 )  if echo "$__resp" | $GREP "Unauthorized" > /dev/null; then _debug "$__resp"; _error "TOKEN invalid"; _func_end "1" ; return 1 ; else echo "$__resp" ; _func_end ; return 0 ; fi ;;
        3 )  _error "Wrong URL:$2" ; _func_end "$__return" ; return $__return ;;
        6 )  _error "DNS error for _curl" ; _func_end "$__return" ; return $__return ;;
        35 ) _error "SSL error for _curl" ; _func_end "$__return" ; return $__return ;;
        * )  _error "Something went wrong in _curl. Return code:$? Response:$__resp" ; _func_end "$__return" ; return $__return ;;
    esac
}

_encode_url () {
    _func_start "$@"

    local __input=${*:-$(</dev/stdin)}

    # Check argv
    if ! _exist "$__input"; then _error "URL EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _installed "jq"; then _error "jq not installed" ; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi

    echo "$__input" | jq -Rr @uri # was jq -sRr but added a %A0 at the end of strig

    _func_end "0" ; return 0 # no _shellcheck
}

_decode_url () {
    _func_start "$@"

    # Check argv
    if ! _exist "$1"; then _error "URL EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi

    local __strg

    __strg="${*}"
    printf '%s' "${__strg%%[%+]*}"
    j="${__strg#"${__strg%%[%+]*}"}"
    __strg="${j#?}"
    case "${j}" in
        "%"* )
            printf '%b' "\\0$(printf '%o' "0x${__strg%"${__strg#??}"}")"
            __strg="${__strg#??}"
            ;;
        "+"* ) printf ' ' ;;
        * ) return ;;
    esac
    if [ -n "${__strg}" ] ; then _decode_url "${__strg}"; fi

    _func_end "0" ; return 0 # no _shellcheck
}
####################################################################################################
######################################## NETWORK MANAGEMENT ########################################
####################################################################################################
_valid_ipv4() {
    _func_start "$@"

    # Check argv
    if ! _exist "$1"; then _error "IP EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi

    _debug "is $1 valid ?"

    local __ip="$1"
    local __i

    if ! [[ "$__ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] ; then  _error "bad ip format" ; _func_end "1" ; return 1 ; fi

    for __i in ${__ip//./ }; do
        if [[ "${#__i}" -gt 1 && "${__i:0:1}" == 0 ]] ; then _error "bad ip format !" ; _func_end "1" ; return 1 ; fi
        if [[ "$__i" -gt 255 ]] ; then _error "$__i > 255" ; _func_end "1" ; return 1; fi
    done

    _func_end "0" ; return 0 ; # no _shellcheck
}

_valid_network () {
    _func_start "$@"

    # Check argv
    if ! _exist "$1"; then _error "NETWORK EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi

    local __ip
    local __mask

    _debug "is $1 valid ?"

    { IFS=/ read -r __ip __mask; } <<< "$1"

    if ! _valid_ipv4 "$__ip"; then _error "not a valid ip address" ; _func_end "1" ; return 1 ; fi
    if ! _exist "$__mask"; then _error "MASK EMPTY"; _func_end "1" ; return 1 ; fi

    if [ "$__mask" -gt 32 ]; then _error "mask > 32" ; _func_end "1" ; return 1 ; fi

    _func_end "0" ; return 0 ; # no _shellcheck
}

_ip2int() {
    _func_start "$@"

    # Check argv
    if ! _exist "$1"; then _error "IP EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _valid_ipv4 "$1"; then _error "not a valid ip address" ; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi

    _debug "what is $1 in int ?"

    local a b c d
    { IFS=. read -r a b c d; } <<< "$1"
    echo $(((((((a << 8) | b) << 8) | c) << 8) | d))

    _func_end "0" ; return 0 # no _shellcheck
}

_int2ip() {
    _func_start "$@"

    # Check argv
    if ! _exist "$1"; then _error "INT EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    #    if [ "$1" -gt 4294967295 ]; then _error "int too large" ; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi

    _debug "what is $1 in ip ?"

    local __ui32="$1"
    local __ip

    __ip=$((__ui32 & 0xff))${__ip:+.}$__ip
    __ui32=$((__ui32 >> 8))

    __ip=$((__ui32 & 0xff))${__ip:+.}$__ip
    __ui32=$((__ui32 >> 8))

    __ip=$((__ui32 & 0xff))${__ip:+.}$__ip
    __ui32=$((__ui32 >> 8))

    __ip=$((__ui32 & 0xff))${__ip:+.}$__ip
    __ui32=$((__ui32 >> 8))

    echo "$__ip"

    _func_end "0" ; return 0 # no _shellcheck
}

_netmask() {
    # Example: netmask 24 => 255.255.255.0
    _func_start "$@"

    # Check argv
    if ! _exist "$1"; then _error "MASK EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if [ "$1" -gt 32 ]; then _error "mask > 32" ; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi

    _debug "what is $1 mask ?"

    local __mask=$((0xffffffff << (32 - "$1")))
    _int2ip $__mask

    _func_end "0" ; return 0 # no _shellcheck
}

_broadcast() {
    # Example: broadcast 192.0.2.0 24 => 192.0.2.255
    _func_start "$@"

    # Check argv
    if ! _exist "$1"; then _error "IP EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _exist "$2"; then _error "MASK EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _valid_ipv4 "$1"; then _error "not a valid ip address" ; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if [ "$2" -gt 32 ]; then _error "mask > 32" ; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi

    _debug "what is $1 $2 broadcast ?"

    local __addr
    local __mask

    __addr=$(_ip2int "$1")
    __mask=$((0xffffffff << (32 -"$2")))

    _int2ip $((__addr | ~__mask))

    _func_end "0" ; return 0 # no _shellcheck
}

_network() {
    # Example: network 192.0.2.0 24 => 192.0.2.0
    _func_start "$@"

    # Check argv
    if ! _exist "$1"; then _error "NETWORK EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _exist "$2"; then _error "MASK EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _valid_ipv4 "$1"; then _error "not a valid ip address" ; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if [ "$2" -gt 32 ]; then _error "mask > 32" ; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi

    _debug "what is $1 $2 network ?"

    local __addr
    local __mask

    __addr=$(_ip2int "$1")
    __mask=$((0xffffffff << (32 -"$2")))

    _int2ip $((__addr & __mask))

    _func_end "0" ; return 0 # no _shellcheck
}

_hello_world () {
    _func_start "$@"

    echo "Hello world"

    _success "Hello world"
    _verbose "Hello world"
    _info "Hello world"
    _warning "Hello world"
    _error "Hello world" # no _shellcheck

    _func_end "0" ; return 0 # no _shellcheck
}
