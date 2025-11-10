#!/bin/bash

# shellcheck source=/dev/null disable=SC2119,SC2120,SC2294,SC2001,SC2045,SC2184

export GETOPT_SHORT_SHELL=h,v,d,b,s

export CHECK_OK="[\033[0;32m✓\033[0m]"
export CHECK_KO="[\033[0;31m✗\033[0m]"
export CHECK_WARN="[\033[0;33m🌟\033[0m]"
export CHECK_INFO="[i]"

export GREP="/usr/bin/grep --text" # no _shellcheck
export EGREP="/usr/bin/grep --text" # no _shellcheck

####################################################################################################
########################################### PROCESS OPTS ###########################################
####################################################################################################
_process_opts () {
    _func_start

    local __short
    local __long
    local __action
    local __return=0
    local __help=false
    local __bats=false
    local __shellcheck=false
    local __list_libs=false

    __short=$(_getopt_short)
    __long=$(_getopt_long)

    OPTS=$(getopt --options "$__short" --long "$__long" --name "$0" -- "$@" 2>/dev/null) || (_error "Bad or missing argument.\n\nTry '$CUR_NAME --help' for more informations\n" ; return 1)

    if _notstartswith "$1" '-'; then
        _error "Bad or missing argument.\n\nTry '$CUR_NAME --help' for more informations\n" ; return 1
    else
        eval set -- "$OPTS"

        while true ; do
            case "$1" in
                -v | --verbose )     VERBOSE=true ; shift ;;
                -d | --debug )       DEBUG=true ; shift ;;
                --lib )              LIB="$2" ; shift ; shift ;;

                -h | --help )        __help=true ; export ACTION=true ; shift ;;
                -b | --bats )        __bats=true ; export ACTION=true ; shift ;;
                -s | --shellcheck )  __shellcheck=true ; export ACTION=true ; shift ;;
                --list-libs )        __list_libs=true ; export ACTION=true ; shift ;;

                -- )             shift ; break ;;
                *)               shift ;;
            esac
        done
    fi

    if $__help ; then
        _usage ; __return=$?
    else
        if $__bats ; then if ! _bats ; then _error "something went wrong in bats" ; _func_end "1" ; return 1 ;fi ; fi
        if $__list_libs ; then if ! _get_installed_libs ; then _error "something went wrong when listing installed libs" ; _func_end "1" ; return 1 ;fi ; fi
        if $__shellcheck ; then if ! _shellcheck ; then _error "something went wrong in shellcheck" ; _func_end "1" ; return 1 ;fi ; fi
    fi

    _func_end "$__return" ; return $__return
}

_getopt_short () { # no _shellcheck
    _func_start

    local __lib
    local __tmp
    local __libs

    __libs=$(_get_installed_libs | _upper)

    for __lib in $__libs ; do
        __tmp=GETOPT_SHORT_$__lib
        if _exist "${!__tmp}"; then echo -n "${!__tmp}," ; fi
    done | _remove_last_car

    _func_end "0" ; return 0
}

_getopt_long () { # no _shellcheck
    _func_start

    local __line
    local __word
    local __opt
    local __result

    __result=$(for __lib in $(_get_installed_libs); do
                   $GREP "^# usage" "$MY_GIT_DIR"/"$__lib"/lib_"$__lib".sh | cut -d: -f2-99 | cut -d_ -f2-99 \
                       | sed -e "s/(\$1)//" | sed -e "s/(\$2)//" | sed -e "s/(\$3)//" \
                       | sed -e "s/(\$4)//" | sed -e "s/(\$5)//" | sed -e "s/(\$6)//" |\
                       while read -r __line; do
                           for __word in $__line; do
                               echo "$__word:,"
                           done
                       done | sort -u |$GREP "^--" | sed -e 's/--//g' | while read -r __line; do
                       echo -n "$__line"
                   done
               done)

    for __lib in $(_get_installed_libs); do
        echo -n "$__lib:,"
    done

    echo -n "debug,verbose,help,list-libs,bats,shellcheck,$__result""lib:" | sed -e 's/ /:,/g'

    _func_end "0" ; return 0
}

####################################################################################################
############################################## USAGES ##############################################
####################################################################################################
_usage () {
    _func_start

    local __line

    if _exist "$LIB" && _filenotexist "$MY_GIT_DIR/$LIB/lib_$LIB.sh" ;then
        _error "No such LIB:$LIB\n\nTry '$CUR_NAME -h' for more informations\n"; _func_end "1" ; return 1
    fi

    if _exist "$LIB"; then
        if _func_exist "_usage_$LIB"; then
            _usage_"$LIB"
        else
            $GREP "^# usage" "$MY_GIT_DIR/$LIB/lib_$LIB.sh" | cut -d_ -f2-99 \
                | sed -e "s/(\$1)//" | sed -e "s/(\$2)//" | sed -e "s/(\$3)//" | sed -e "s/(\$4)//" \
                | sed -e "s/(\$5)//" | sed -e "s/(\$6)//" | sed -e "s/(\$7)//" | sed -e "s/(\$8)//" \
                | sed -e "s/(\$9)//" | sed -e "s/(\$10)//" | while read -r __line
            do
                echo "$CUR_NAME --lib $LIB $__line"
            done | sort -u
        fi
    else
        echo "Usage :"
        echo "* This help                          => $CUR_NAME -h | --help"
        echo "* Verbose                            => $CUR_NAME -v | --verbose"
        echo "* Debug                              => $CUR_NAME -d | --debug"
        echo "* Bats                               => $CUR_NAME -b | --bats"
        echo "* Use any lib                        => $CUR_NAME --lib lib_name"
        echo "* List avaliable libs                => $CUR_NAME --list-libs"
    fi
    _func_end "0" ; return 0
}

####################################################################################################
######################################### LOAD LIBS & CONF #########################################
####################################################################################################
_load_libs () {
    _func_start

    local __lib

    for __lib in $(_get_installed_libs); do
        _verbose "Loading:$MY_GIT_DIR/$__lib/lib_$__lib.sh"
        source  "$MY_GIT_DIR"/"$__lib"/lib_"$__lib".sh
    done

    _func_end "0" ; return 0
}

_load_lib () {
    _func_start

    if _notexist "$1" ;then _error "LIB EMPTY" ; _func_end "1" ; return 1 ; fi
    if _filenotexist "$MY_GIT_DIR/$1/lib_$1.sh" ;then _error "$MY_GIT_DIR/$1/lib_$1.sh not exist, not sourcing" ;_func_end "1" ; return 1 ; fi

    _verbose "Loading $MY_GIT_DIR/$1/lib_$1.sh"
    source  "$MY_GIT_DIR"/"$1"/lib_"$1".sh

    _func_end "0" ;  return 0
}

_load_conf () {
    _func_start

    if _notexist "$1"; then _error "CONF EMPTY"; _func_end "1" ; return 1 ; fi
    if _filenotexist "$1"; then _error "$1 not exist, not sourcing" ; _func_end "1" ; return 1 ; fi

    _verbose "Sourcing:$1"
    source "$1"

    _func_end "0" ; return 0
}

_get_installed_libs () {
    _func_start

    local __lib_dir

    for __lib_dir in $(ls "$MY_GIT_DIR"); do
        if _fileexist "$MY_GIT_DIR"/"$__lib_dir"/lib_"$__lib_dir".sh ; then
            echo -n "$__lib_dir "
        fi
    done | _remove_last_car

    _func_end "0" ; return 0
}

####################################################################################################
######################################### DEBUG MANAGEMENT #########################################
####################################################################################################
_date () {
    date '+%Y-%m-%d %H:%M:%S'
}

_verbose_func_space () {
    local __i
    local __func_list
    local __oldIFS=$IFS

    IFS=''
    VERBOSE_SPACE=""
    for (( i=0; i<${#FUNC_LIST[@]}; i++ )); do
        VERBOSE_SPACE="$VERBOSE_SPACE ${FUNC_LIST[$i]} >"
    done
    IFS=$__oldIFS
}

_func_start () {
    _array_add FUNC_LIST "${FUNCNAME[1]}"
    _verbose_func_space

    local __date
    local __msg="Start"

    __date=$(_date)

    if $VERBOSE; then
        if $DEBUG; then
            __msg="[$$] -- VERBOSE -- $__date -- $VERBOSE_SPACE $__msg"
            echo -e "$__msg" >&2
        fi
    fi
}

_func_end () { # no _shellcheck
    _verbose_func_space

    local __date
    local __msg

    if _notexist "$1"; then
        __msg="End"
    else
        __msg="End - returning:$1"
    fi

    __date=$(_date)

    if $VERBOSE; then
        if $DEBUG; then
            __msg="[$$] -- VERBOSE -- $__date -- $VERBOSE_SPACE $__msg"
            echo -e "$__msg" >&2
        fi
    fi

    _array_remove_last FUNC_LIST
}

_echoerr() {
    echo -e "$@"
}

_error () { # no _shellcheck
    local __date
    local __msg

    __date=$(_date)

    if $DEBUG; then
        __msg="[$$] -- \033[0;31mERROR\033[0m ---- $__date -- $VERBOSE_SPACE $CHECK_KO $*"
    else
        __msg="$CHECK_KO $*"
    fi

    _echoerr "$__msg" >&2
}

_warning () {
    local __date
    local __msg

    __date=$(_date)

    if $DEBUG; then
        __msg="[$$] -- \033[0;33mWARNING\033[0m -- $__date -- $VERBOSE_SPACE $CHECK_WARN $*"
    else
        __msg="$CHECK_WARN $*"
    fi

    _echoerr "$__msg" >&2
}

_debug () {
    local __date
    local __msg

    __date=$(_date)

    if $DEBUG; then
        __msg="[$$] -- DEBUG ---- $__date -- $VERBOSE_SPACE $CHECK_INFO $*"
        _echoerr "$__msg" >&2
    fi
}

_verbose () {
    local __date
    local __msg

    __date=$(_date)

    if $VERBOSE; then
        if $DEBUG; then
            __msg="[$$] -- VERBOSE -- $__date -- $VERBOSE_SPACE $*"
        else
            __msg="$*"
        fi

        echo -e "$__msg" >&2
    fi
}

_verbose_file () {
    local __date

    __date=$(_date)

    if $VERBOSE; then _echoerr "[$$] -- DEBUG --  $__date -- $VERBOSE_SPACE ---- dump file start ---- " "[$*]"; fi
    if $VERBOSE; then cat "$1"; fi
    if $VERBOSE; then _echoerr "[$$] -- DEBUG --  $__date -- $VERBOSE_SPACE ---- dump file end ---- " "[$*]"; fi
}

####################################################################################################
############################################ SIMPLE TEST ###########################################
####################################################################################################
_func_exist() {
  [ "$(type -t "$1")" == 'function' ]
}

_startswith() {
    local __str="$1"
    local __sub="$2"

    echo "$__str" | $GREP "^$__sub" >/dev/null 2>&1
}

_notstartswith() {
    if _startswith "$1" "$2"; then return 1; else return 0; fi
}

_exist () {
    if [ "a$1" = "a" ]; then return 1; else return 0; fi
}

_notexist () {
    if [ "a$1" = "a" ]; then return 0; else return 1; fi
}

_installed () {
    if type "$1" 2> /dev/null 1>/dev/null ; then return 0; else return 1; fi
}

_notinstalled () {
    if type "$1" 2> /dev/null 1>/dev/null ; then return 1; else return 0; fi
}

_fileexist () {
    if [ -e "$1" ]; then return 0; else return 1; fi
}

_filenotexist () {
    if [ -e "$1" ]; then return 1; else return 0; fi
}

_workingdir_isnot () {
    if [ "a$PWD" = "a$1" ]; then return 1; else return 0; fi
}

_raspberry () {
    if [ "$(_os_arch)" = "armv7l" ]; then return 0; else return 1; fi
}

_x86_64 () {
    if [ "$(_os_arch)" = "x86_64" ]; then return 0; else return 1; fi
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

####################################################################################################
######################################## ARRAY MANAGEMENT ##########################################
####################################################################################################
_array_print () {
    if _notexist "$1"; then _error "ARRAY EMPTY"; return 1 ; fi

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
    if _notexist "$1"; then _error "ARRAY EMPTY"; return 1 ; fi
    if _notexist "$2"; then _error "INDEX EMPTY"; return 1 ; fi

    local __oldIFS=$IFS

    IFS=''
    declare -n __array
    __array="$1"

    echo "${__array[$2]}"

    IFS=$__oldIFS
}

_array_add () {
    if _notexist "$1"; then _error "ARRAY EMPTY"; return 1 ; fi
    if _notexist "$2"; then _error "ELEMENT EMPTY"; return 1 ; fi

    local __oldIFS=$IFS

    IFS=''
    declare -n __array
    __array="$1"

    __array+=("$2")

    IFS=$__oldIFS
}

_array_remove_last () {
    if _notexist "$1"; then _error "ARRAY EMPTY"; return 1 ; fi

    local __oldIFS=$IFS

    IFS=''

    unset "$1"[-1]

    IFS=$__oldIFS
}

_array_remove_index () {
    if _notexist "$1"; then _error "ARRAY EMPTY"; return 1 ; fi
    if _notexist "$2"; then _error "INDEX EMPTY"; return 1 ; fi

    local __oldIFS=$IFS

    IFS=''
    declare -n __array
    __array="$1"

    unset "$1"["$2"]

    __array=("${__array[@]}")

    IFS=$__oldIFS
}

_array_count_elt () {
    if _notexist "$@"; then _error "ARRAY EMPTY"; return 1 ; fi

    local __oldIFS=$IFS

    IFS=''
    declare -n __array
    __array="$1"

    echo ${#__array[@]}

    IFS=$__oldIFS
}

####################################################################################################
############################################## CRYPT ###############################################
####################################################################################################
#
# usage: _decrypt_file --file ($1) --passphrase ($2) --remove-src ($3)
#
_decrypt_file () {
    _func_start

    if _notexist "$1"; then _error "FILE EMPTY"; _func_end "1" ; return 1 ; fi
    if _notexist "$2"; then _error "PASSPHRASE EMPTY"; _func_end "1" ; return 1 ; fi
    if _notexist "$3"; then _error "REMOVE-SRC EMPTY"; _func_end "1" ; return 1 ; fi
    if _filenotexist "$1"; then _error "FILE NOT EXIST:$1"; _func_end "1" ; return 1 ; fi
    if _notinstalled "gpg" ; then _error "gpg not found"; _func_end "1" ; return 1 ; fi

    local __return

    _verbose "decrypting :$1"
    gpg --batch --passphrase "$2" "$1" 2> /dev/null
    __return=$?

    case $__return in
        0) if $3 ; then _verbose "Removing :" "$1"; rm -rf "$1" ; fi ; _func_end "$__return" ; return $__return ;;
        2) _error "destfile already exist" ; _func_end "$__return" ; return $__return ;;
        *) _error "something went wrong $__return"; _func_end "$__return" ; return $__return ;;
    esac
}

#
# usage: _decrypt_directory --directory ($1) --passphrase ($2) --remove-src ($3)
#
_decrypt_directory () {
    _func_start

    if _notexist "$1"; then _error "DIRECTORY EMPTY"; _func_end "1" ; return 1 ; fi
    if _notexist "$2"; then _error "PASSPHRASE EMPTY"; _func_end "1" ; return 1 ; fi
    if _notexist "$3"; then _error "REMOVE-SRC EMPTY"; _func_end "1" ; return 1 ; fi
    if _filenotexist "$1"; then _error "DIRECTORY NOT EXIST:$1"; _func_end "1" ; return 1 ; fi
    if _notinstalled "gpg" ; then _error "gpg not found"; _func_end "1" ; return 1 ; fi

    local __file

    for __file in $(find "$1" -type f | $GREP ".gpg" ); do
        if ! _decrypt_file "$__file" "$2" "$3"; then _func_end "1" ; return 1 ; fi
    done

    _func_end "0" ; return 0
}

#
# usage: _encrypt_file --file ($1) --passphrase ($2) --remove-src ($3)
#
_encrypt_file () {
    _func_start

    if _notexist "$1"; then _error "FILE EMPTY"; _func_end "1" ; return 1 ; fi
    if _notexist "$2"; then _error "PASSPHRASE EMPTY"; _func_end "1" ; return 1 ; fi
    if _notexist "$3"; then _error "REMOVE-SRC EMPTY"; _func_end "1" ; return 1 ; fi
    if _filenotexist "$1"; then _error "FILE NOT EXIST:$1"; _func_end "1" ; return 1 ; fi
    if _notinstalled "gpg" ; then _error "gpg not found"; _func_end "1" ; return 1 ; fi

    local __return

    _verbose "encrypting :$1"
    gpg -c --cipher-algo AES256 --compress-algo 1 --batch --passphrase "$2" "$1" 2> /dev/null
    __return=$?

    case $__return in
        0) if $3 ; then _verbose "Removing :" "$1"; rm -rf "$1" ; fi ; _func_end "$__return" ; return $__return ;;
        2) _error "destfile already exist" ; _func_end "$__return" ; return $__return ;;
        *) _error "something went wrong $__return" ; _func_end "$__return"; return $__return ;;
    esac
}

#
# usage: _encrypt_directory --directory ($1) --passphrase ($2) --remove-src ($3)
#
_encrypt_directory () {
    _func_start

    if _notexist "$1"; then _error "DIRECTORY EMPTY"; _func_end "1" ; return 1 ; fi
    if _notexist "$2"; then _error "PASSPHRASE EMPTY"; _func_end "1" ; return 1 ; fi
    if _notexist "$3"; then _error "REMOVE-SRC EMPTY"; _func_end "1" ; return 1 ; fi
    if _filenotexist "$1"; then _error "DIRECTORY NOT EXIST:$1"; _func_end "1" ; return 1 ; fi
    if _notinstalled "gpg" ; then _error "gpg not found"; _func_end "1" ; return 1 ; fi

    local __file

    for __file in $(find "$1" -type f | $GREP -v ".gpg" ); do
        if ! _encrypt_file "$__file" "$2" "$3"; then _func_end "1" ; return 1 ; fi
    done

    _func_end "0" ; return 0
}

####################################################################################################
########################################### TESTS & CI #############################################
####################################################################################################
_shellcheck () {
    _func_start

    if _notexist "$LIB" ;then _error "LIB EMPTY" ; _func_end "1" ; return 1 ; fi

    if _exist "$LIB" && _filenotexist "$MY_GIT_DIR/$LIB/lib_$LIB.sh" ;then
        _usage; _func_end "1" ; return 1
    fi

    if _installed "shellcheck"; then
        if shellcheck "$MY_GIT_DIR"/"$LIB"/*.sh ; then
            if $GREP --line-number "_error" "$MY_GIT_DIR"/"$LIB"/*.sh  | $GREP -v "return" | $GREP -v "no _shellcheck"; then
                _error "_error must be followed by return >0" ; _func_end "1" ; return 1
            fi
            if $GREP --line-number "grep" "$MY_GIT_DIR"/"$LIB"/*.sh | $GREP -v "no _shellcheck"; then # no _shellcheck
                _error "grep is not allowed, use \$GREP instead" ; _func_end "1" ; return 1 # no _shellcheck
            fi
            if $GREP --line-number "_func_end" "$MY_GIT_DIR"/"$LIB"/*.sh | $GREP -v '_func_end "' | $GREP -v "no _shellcheck" ; then  # no _shellcheck
                _error "_func_end must have an arg then followed by return" ; _func_end "1" ; return 1
            fi
            if $GREP --line-number "_func_end" "$MY_GIT_DIR"/"$LIB"/*.sh | $GREP -v "return" | $GREP -v "exit" | $GREP -v "no _shellcheck" ; then  # no _shellcheck
                _error "_func_end must be followed by return" ; _func_end "1" ; return 1
            fi
            echo "no error found with shellcheck";
        else
            _error "something went wrong with shellcheck"; _func_end "1" ; return 1
        fi
    else
        _error "shellcheck not found" ; _func_end "1" ; return 1
    fi
}

_bats () {
    _func_start

    if _exist "$LIB" && _filenotexist "$MY_GIT_DIR/$LIB/lib_$LIB.sh" ;then
        _usage; _func_end "1" ; return 1
    fi

    if _installed "bats"; then
        if bats --verbose-run --show-output-of-passing-tests "$MY_GIT_DIR/$LIB/bats/tests.bats" ; then
            _verbose "no error found"; _func_end "0" ; return 0
        else
            _error "something went wrong with bats"; _func_end "1" ; return 1
        fi
    else
        _error "bats not found" ; _func_end "1" ; return 1
    fi
}

####################################################################################################
############################################### URL ################################################
####################################################################################################
#
# usage: _curl --method ($1) --url ($2) --header ($3) --header-data ($4) --data ($5)
#
_curl () {
    _func_start

    if _notexist "$1"; then _error "METHOD EMPTY"; _func_end "1" ; return 1 ; fi
    if _notexist "$2"; then _error "URL EMPTY"; _func_end "1" ; return 1 ; fi

    _verbose "METHOD:$1"
    _verbose "URL:$2"

    local __resp
    local __return

    case $1 in
        POST | PUT | DELETE | GET )
            if _notexist "$3"; then
                _verbose "HEADER EMPTY"
                __resp=$(curl -s -k -X "$1" --location "$2")
                __return=$?
            else
                if _notexist "$4"; then
                    _verbose "HEADER DATA EMPTY"
                    __resp=$(curl -s -k -X "$1" --location "$2" -H "$3")
                    __return=$?
                else
                    if _notexist "$5"; then
                        _verbose "NEXT HEADER:$4"
                        __resp=$(curl -s -k -X "$1" --location "$2" -H "$3" -H "$4")
                        __return=$?
                    else
                        _verbose "HEADER DATA:$4"
                        _verbose "DATA:$5"
                        __resp=$(curl -s -k -X "$1" --location "$2" -H "$3" -H "$4" -d "$5")
                        __return=$?
                    fi
                fi
            fi
            ;;
        * ) _error "Wrong METHOD send to curl" ; _func_end "1" ; return 1 ;;
    esac

    case $__return in
        0 ) if echo "$__resp" | $GREP "Unauthorized" > /dev/null; then _debug "$__resp"; _error "TOKEN invalid"; _func_end "1" ; return 1 ; else echo "$__resp" ; _func_end ; return 0 ; fi ;;
        3 ) _error "Wrong URL:$2" ; _func_end "$__return" ; return $__return ;;
        6 ) _error "DNS error for curl" ; _func_end "$__return" ; return $__return ;;
        * ) _error "Something went wrong in curl. Return code:$? Response:$__resp" ; _func_end "$__return" ; return $__return ;;
    esac
}

_encode_url () {
    _func_start

    if _notexist "$1"; then _error "URL EMPTY"; _func_end "1" ; return 1 ; fi
    if _notinstalled "jq"; then _error "jq not installed" ; _func_end "1" ; return 1 ; fi

    echo "$1" | jq -sRr @uri

    _func_end "0" ; return 0
}

_decode_url () {
    _func_start

    if _notexist "$1"; then _error "URL EMPTY"; _func_end "1" ; return 1 ; fi

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

    _func_end "0" ; return 0
}

####################################################################################################
######################################### EVERYTHING ELSE ##########################################
####################################################################################################
_tmp_file () {
    _func_start

    if _exist "${FUNCNAME[1]}" ; then
        if _exist "$1"; then echo "/tmp/$(basename "$0")${FUNCNAME[1]}.$1" ;else echo "/tmp/$(basename "$0")${FUNCNAME[1]}"; fi
    else
        if _exist "$1"; then echo "/tmp/$(basename "$0")_$(tr -dc A-Za-z0-9 </dev/urandom | head -c 13).$1" ;else echo "/tmp/$(basename "$0")_$(tr -dc A-Za-z0-9 </dev/urandom | head -c 13)"; fi
    fi

    _func_end "0" ; return 0
}

_os_arch () {
    _func_start

    uname -m

    _func_end "0" ; return 0
}

#
# usage: _host_up_show --network ($1)(192.168.1.0/24)
#
_host_up_show () {
    _func_start

    if _notexist "$1"; then _error "NETWORK EMPTY"; _func_end "1" ; return 1 ; fi

    _verbose "NETWORK:$1"

    local __line
    local __name

    if _installed "nmap"; then
        nmap -v -sn -n "$1" -oG - | $GREP Up | awk '{print $2}' | while read -r __line
        do
           if _installed "dig"; then
               __name=$(dig -x "$__line" | $GREP -v ^\; | $GREP PTR | awk  '{print $5}' | _remove_last_car)
               echo "$__line $__name"
           else
               echo "$__line"
           fi
        done | sort -u
    else
        _error "nmap not installed" ; _func_end "1" ; return 1 ;
    fi

    _func_end "0" ; return 0
}

#
# usage: _hello_world
#
_hello_world () {
    _func_start

    local __tmp

    echo "Hello world"

    _verbose "Hello world"
    _warning "Hello world"
    _error "Hello world" # return 1

    __tmp=$(_tmp_file "label")
    echo "$__tmp"

    _func_end "0" ; return 0
}

####################################################################################################
############################################# PROCESS ##############################################
####################################################################################################
_process_lib_shell () {
    _func_start

    eval set -- "$@"

    local __file
    local __directory
    local __passphrase
    local __remove_src=false
    local __url
    local __method
    local __header
    local __header_data
    local __data
    local __network
    local __return

    while true ; do
        case "$1" in
            --file )           __file=$2         ; shift ; shift         ;;
            --directory )      __directory=$2    ; shift ; shift         ;;
            --passphrase )     __passphrase=$2   ; shift ; shift         ;;
            --remove-src )     __remove_src=$2   ; shift ; shift         ;;
            --method )         __method=$2       ; shift ; shift         ;;
            --url )            __url=$2          ; shift ; shift         ;;
            --header )         __header=$2       ; shift ; shift         ;;
            --header-data )    __header_data=$2  ; shift ; shift         ;;
            --data )           __data=$2         ; shift ; shift         ;;
            --network )        __network=$2      ; shift ; shift         ;;
            -- )                                   shift ;        break  ;;
            *)                                     shift                 ;;
        esac
    done

    while true ; do
        case "$1" in
            hello_world)       _hello_world                                                      ; __return=$? ; break ;;
            curl)              _curl "$__method" "$__url" "$__header" "$__header_data" "$__data" ; __return=$? ; break ;;
            decrypt_file)      _decrypt_file      "$__file"       "$__passphrase" "$__remove_src"; __return=$? ; break ;;
            encrypt_file)      _encrypt_file      "$__file"       "$__passphrase" "$__remove_src"; __return=$? ; break ;;
            decrypt_directory) _decrypt_directory "$__directory"  "$__passphrase" "$__remove_src"; __return=$? ; break ;;
            encrypt_directory) _encrypt_directory "$__directory"  "$__passphrase" "$__remove_src"; __return=$? ; break ;;
            host_up_show)      _host_up_show      "$__network"                                   ; __return=$? ; break ;;
            -- ) shift ;;
            *) _error "command $1 not found" ; __return=1 ; break ;;
        esac
    done

    _func_end "$__return" ; return "$__return"
}
