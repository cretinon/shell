#!/bin/bash

# shellcheck source=/dev/null disable=SC2119,SC2120,SC2294,SC2001,SC2045,SC2184

export GETOPT_SHORT_SHELL=h,v,d,b,s,k

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
    local __kcov=false

    __short=$(_getopt_short)
    __long=$(_getopt_long)

    OPTS=$(getopt --options "$__short" --long "$__long" --name "$0" -- "$@" 2>/dev/null) || (_error "Bad or missing argument.\n\nTry '$CUR_NAME --help' for more informations\n" ; return 1)

    if _notstartswith "$1" '-'; then
        _error "Bad or missing argument.\n\nTry '$CUR_NAME --help' for more informations\n" ; return 1
    else
        eval set -- "$OPTS"

        while true ; do
            case "$1" in
                -v | --verbose )     VERBOSE=true                             ; shift ;;
                -d | --debug )       DEBUG=true                               ; shift ;;
                --dry-run )          DRY_RUN=true                             ; shift ;;
                --lib )              LIB="$2"                                 ; shift ; shift ;;

                -h | --help )        __help=true         ; export ACTION=true ; shift ;;
                -b | --bats )        __bats=true         ; export ACTION=true ; shift ;;
                -s | --shellcheck )  __shellcheck=true   ; export ACTION=true ; shift ;;
                -k | --kcov )        __kcov=true         ; export ACTION=true ; shift ;;
                --list-libs )        __list_libs=true    ; export ACTION=true ; shift ;;

                -- )             shift ; break ;;
                *)               shift ;;
            esac
        done
    fi

    if $__help ; then
        _usage ; __return=$?
    else
        if $__list_libs  ; then if ! _get_installed_libs ; then _error "something went wrong when listing installed libs" ; _func_end "1" ; return 1 ;fi ; fi
        if $__bats       ; then if ! _bats               ; then _error "something went wrong in bats" ; _func_end "1" ; return 1 ;fi ; fi
        if $__shellcheck ; then if ! _shellcheck "$@"    ; then _error "something went wrong in shellcheck" ; _func_end "1" ; return 1 ;fi ; fi
        if $__kcov       ; then if ! _kcov               ; then _error "something went wrong in kcov" ; _func_end "1" ; return 1 ;fi ; fi
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

    _func_end "0" ; return 0 # no _shellcheck
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

    echo -n "debug,verbose,help,list-libs,bats,shellcheck,kcov,dry-run,$__result""lib:" | sed -e 's/ /:,/g'

    _func_end "0" ; return 0 # no _shellcheck
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
        fi
        $GREP "^# usage" "$MY_GIT_DIR/$LIB/lib_$LIB.sh" | cut -d_ -f2-99 \
            | sed -e "s/(\$1)//" | sed -e "s/(\$2)//" | sed -e "s/(\$3)//" | sed -e "s/(\$4)//" \
            | sed -e "s/(\$5)//" | sed -e "s/(\$6)//" | sed -e "s/(\$7)//" | sed -e "s/(\$8)//" \
            | sed -e "s/(\$9)//" | sed -e "s/(\$10)//" | while read -r __line
        do
            echo "$CUR_NAME --lib $LIB $__line"
        done | sort -u
    else
        echo "Usage :"
        echo "  * This help                          => $CUR_NAME -h | --help"
        echo "  * Verbose                            => $CUR_NAME -v | --verbose"
        echo "  * Debug                              => $CUR_NAME -d | --debug"
        echo "  * Dry run                            => $CUR_NAME --dry-run"
        echo "  * List avaliable libs                => $CUR_NAME --list-libs"
        echo "  * Use any lib                        => $CUR_NAME --lib lib_name"
        echo "  * Bash Automated Testing System      => $CUR_NAME -b | --bats --lib lib_name"
        echo "  * Shell Syntax Checking              => $CUR_NAME -s | --shellcheck --lib lib_name"
        echo "  * Code coverage                      => $CUR_NAME -k | --kcov --lib lib_name"
    fi

    _func_end "0" ; return 0 # no _shellcheck
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

    _func_end "0" ; return 0 # no _shellcheck
}

_load_lib () {
    _func_start

    if _notexist "$1" ;then _error "LIB EMPTY" ; _func_end "1" ; return 1 ; fi
    if _filenotexist "$MY_GIT_DIR/$1/lib_$1.sh" ;then _error "$MY_GIT_DIR/$1/lib_$1.sh not exist, not sourcing" ;_func_end "1" ; return 1 ; fi

    _verbose "Loading $MY_GIT_DIR/$1/lib_$1.sh"
    source  "$MY_GIT_DIR"/"$1"/lib_"$1".sh

    _func_end "0" ;  return 0 # no _shellcheck
}

_load_conf () {
    _func_start

    if _notexist "$1"; then _error "CONF EMPTY"; _func_end "1" ; return 1 ; fi
    if _filenotexist "$1"; then _error "$1 not exist, not sourcing (did you git pull ?)" ; _func_end "1" ; return 1 ; fi

    local __basename
    local __my_basename
    local __my_conf_file

    __basename=$(basename "$1" | sed -e "s/\./\\\./")
    __my_basename="my_"$__basename
    __my_conf_file=$(echo "$1" | sed -e "s/$__basename/$__my_basename/")

    if _fileexist "$__my_conf_file"; then
        _verbose "Sourcing MY CONF:$__my_conf_file"
        source "$__my_conf_file"
    else
        _verbose "Sourcing:$1"
        source "$1"
    fi

    _func_end "0" ; return 0 # no _shellcheck
}

_get_installed_libs () {
    _func_start

    local __lib_dir

    for __lib_dir in $(ls "$MY_GIT_DIR"); do
        if _fileexist "$MY_GIT_DIR"/"$__lib_dir"/lib_"$__lib_dir".sh ; then
            echo -n "$__lib_dir "
        fi
    done | _remove_last_car

    _func_end "0" ; return 0 # no _shellcheck
}

####################################################################################################
######################################### DEBUG MANAGEMENT #########################################
####################################################################################################
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
    local __date
    local __msg="Start"
    local __start

    __start=$(date +"%s.%N")

    _array_add FUNC_LIST "${FUNCNAME[1]}:$__start"
    _verbose_func_space

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
    local __nb
    local __start
    local __end
    local __duration

    __nb=$(_array_count_elt FUNC_LIST)
    __nb=$((__nb-1))
    __start=$(echo "$__nb ${FUNC_LIST[$__nb]}" | cut -d: -f2)
    __end=$(date +"%s.%N")
    __duration=$(_timediff "$__start" "$__end")

    if _notexist "$1"; then
        __msg="End"
    else
        __msg="End - returning:$1 - in $__duration""s"
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
######################################## NETWORK MANAGEMENT ########################################
####################################################################################################
_ipv4() {

    local __ip="$1"
    local __i

    [[ "$__ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] ||  return 1

    for __i in ${__ip//./ }; do
        [[ "${#__i}" -gt 1 && "${__i:0:1}" == 0 ]] && return 1
        [[ "$__i" -gt 255 ]] && return 1
    done

    return 0 ; # no _shellcheck
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

    _func_end "0" ; return 0 # no _shellcheck # TODO use not_installed
}

#
# usage: _iptables_show
#
_iptables_show () {
    _func_start

    if ! _installed "iptables"; then _error "iptables not found"; func_end "1" ; return 1 ; fi

    local __return

    iptables -vL -t filter
    iptables -vL -t nat
    iptables -vL -t mangle
    iptables -vL -t raw
    iptables -vL -t security
    __return=$?

    _func_end "$__return" ; return $__return
}

#
# usage: _iptables_save
#
_iptables_save () {
    _func_start

    if ! _installed "iptables"; then _error "iptables not found"; func_end "1" ; return 1 ; fi

    local __return

    iptables-save -c > /etc/iptables-save
    __return=$?

    _func_end "$__return" ; return $__return
}

#
# usage: _iptables_restore
#
_iptables_restore () {
    _func_start

    if ! _installed "iptables"; then _error "iptables not found"; func_end "1" ; return 1 ; fi

    local __return

    iptables-restore -c < /etc/iptables-save
    __return=$?

    _func_end "$__return" ; return $__return
}

#
# usage: _iptables_flush
#
_iptables_flush () {
    _func_start

    if _installed "docker"; then _error "Running on host with docker installed is not supported"; func_end "1" ; return 1 ; fi
    if ! _installed "iptables"; then _error "iptables not found"; func_end "1" ; return 1 ; fi

    local __return

    iptables -F
    iptables -X
    iptables -t nat -F
    iptables -t nat -X
    iptables -t mangle -F
    iptables -t mangle -X
    iptables -P INPUT ACCEPT
    iptables -P OUTPUT ACCEPT
    iptables -P FORWARD ACCEPT
    iptables -Z
    __return=$?

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
######################################### TIME MANAGEMENT ##########################################
####################################################################################################
_date () {
    date '+%Y-%m-%d %H:%M:%S'
}

_timediff() {
    if _notexist "$1"; then _error "start time EMPTY"; return 1 ; fi
    if _notexist "$2"; then _error "end time EMPTY"; return 1 ; fi

    local __start_time
    local __end_time
    local __start_s
    local __start_nanos
    local __end_s
    local __end_nanos

    __start_time=$1
    __end_time=$2

    __start_s=${__start_time%.*}
    __start_nanos=${__start_time#*.}
    __end_s=${__end_time%.*}
    __end_nanos=${__end_time#*.}

    if [ "$__end_nanos" -lt "$__start_nanos" ];then
        __end_s=$(( 10#$__end_s - 1 ))
        __end_nanos=$(( 10#$__end_nanos + 10**9 ))
    fi

    time=$(( 10#$__end_s - 10#$__start_s )).$(( (10#$__end_nanos - 10#$__start_nanos)/10**6 ))

    echo $time
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

    for __file in $(find "$1" -type f | $GREP "\.gpg" ); do
        if ! _decrypt_file "$__file" "$2" "$3"; then _error "something went wrong when decrypt file" ; _func_end "1" ; return 1 ; fi
    done

    _func_end "0" ; return 0 # no _shellcheck
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

    for __file in $(find "$1" -type f | $GREP -v "\.gpg" ); do
        if ! _encrypt_file "$__file" "$2" "$3"; then _error "something went wrong when encrypt file" ; _func_end "1" ; return 1 ; fi
    done

    _func_end "0" ; return 0 # no _shellcheck
}

####################################################################################################
########################################### TESTS & CI #############################################
####################################################################################################
_shellcheck () {
    _func_start

    local __files

    if _notexist "$LIB" ; then
        __files="$*"
    else
        if _exist "$LIB" && _filenotexist "$MY_GIT_DIR/$LIB/lib_$LIB.sh" ;then _error "lib file not found" ; _usage; _func_end "1" ; return 1 ; fi
        __files=$(find "$MY_GIT_DIR"/"$LIB"/ -type f | $GREP -v "entry" | $GREP "\.sh" | tr '\n' ' '  )
    fi

    if ! _installed "shellcheck"; then _error "shelcheck not found" , _func_end "1" ; return 1 ; fi

    # shellcheck disable=SC2086
    if shellcheck $__files ; then
        if $GREP --line-number "_error" $__files | $GREP -v "return" | $GREP -v "no _shellcheck"; then
            _error "_error must be followed by return >0" ; _func_end "1" ; return 1
        fi
        if $GREP --line-number "grep" $__files | $GREP -v "no _shellcheck"; then # no _shellcheck
            _error "grep is not allowed, use \$GREP instead" ; _func_end "1" ; return 1 # no _shellcheck
        fi
        if $GREP --line-number "_func_end" $__files | $GREP -v '_func_end "' | $GREP -v "no _shellcheck" ; then  # no _shellcheck
            _error "_func_end must have an arg then followed by return" ; _func_end "1" ; return 1
        fi
        if $GREP --line-number "_func_end" $__files | $GREP -v "return" | $GREP -v "exit" | $GREP -v "no _shellcheck" ; then  # no _shellcheck
            _error "_func_end must be followed by return" ; _func_end "1" ; return 1
        fi
        if $GREP --line-number "_func_end \"1\"" $__files | $GREP -v "_error" | $GREP -v "no _shellcheck" ; then  # no _shellcheck
            _error "must have an _error message if we return 1" ; _func_end "1" ; return 1
        fi
        if $GREP --line-number "return 0" $__files | $GREP -v "return 1" | $GREP -v "no _shellcheck" ; then  # no _shellcheck
            _error "returning 0 is may be a bad idea" ; _func_end "1" ; return 1
        fi
        if $GREP --line-number "curl" $__files | $GREP -v "_curl" | $GREP -v "no _shellcheck" ; then  # no _shellcheck
            _error "do not use curl but _curl instead" ; _func_end "1" ; return 1
        fi
        if $GREP --line-number -w "docker" $__files | $GREP "|" | $GREP -v "no _shellcheck" ; then  # no _shellcheck
            _error "can't test docker return is used with a pipe" ; _func_end "1" ; return 1
        fi
        echo "no error found with shellcheck in $__files";
    else
        _error "something went wrong with shellcheck"; _func_end "1" ; return 1
    fi
}

_bats () {
    _func_start

    if _notexist "$LIB"; then _error "no LIB found"; _func_end "1" ; return 1 ; fi

    if _exist "$LIB" && _filenotexist "$MY_GIT_DIR/$LIB/lib_$LIB.sh"; then _error "lib file not found" ;  _usage; _func_end "1" ; return 1 ; fi

    if _installed "bats"; then
        cd "$MY_GIT_DIR/$LIB" || return 1
        if bats --verbose-run "$MY_GIT_DIR/$LIB/bats/tests.bats" ; then # --show-output-of-passing-tests
            _verbose "no error found"; cd - > /dev/null || return 1 ; _func_end "0" ; return 0 # no _shellcheck
        else
            _error "something went wrong with bats"; cd - || return 1 ; _func_end "1" ; return 1
        fi
    else
        _error "bats not found" ; _func_end "1" ; return 1
    fi
}

_kcov () {
    _func_start

    if _notexist "$LIB"; then _error "no LIB found"; _func_end "1" ; return 1 ; fi
    if _notinstalled "kcov"; then _error "kcov not found"; _func_end "1" ; return 1 ; fi

    local __tmp
    local __upload=true

    if _notinstalled "codecov"; then _warning "codecov not found, no uploading"; __upload=false ; fi
    if _notexist "$CODECOV_TOKEN"; then _warning "no CODECOV_TOKEN found, no uploading"; __upload=false ; fi
    if _notexist "$GITHUB_USERNAME"; then _warning "no GITHUB_USERNAME found, no uploading"; __upload=false ; fi

    if ! __tmp=$(_tmp_file) ; then _error "something went wrong in _tmp_file"; _func_end "1" ; return 1 ; fi

    _debug "tmp dir:$__tmp"

    if ! $DRY_RUN ; then
        kcov --exclude-path="$MY_GIT_DIR/$LIB/.git/,$MY_GIT_DIR/$LIB/README.md,/usr/,$MY_GIT_DIR/$LIB/.codecov.yml,$MY_GIT_DIR/$LIB/.pre-commit-config.yaml" --include-path="$MY_GIT_DIR/$LIB" "$__tmp" "$MY_GIT_DIR/shell/my_warp.sh" --lib "$LIB" -b

        < "$__tmp/my_warp.sh/coverage.json" jq -r ".files | .[]" | jq -r '.file + " " + .percent_covered'

        if $__upload ; then
            codecov --codecov-yml-path .codecov.yml upload-coverage --report-type coverage --git-service github -r "$GITHUB_USERNAME/$LIB" -t "$CODECOV_TOKEN" --file "$__tmp/my_warp.sh/cobertura.xml"
        fi

        rm -rf "$__tmp"

    else
        _debug "doing nothing in dry run"
    fi

    _func_end "0" ; return 0 # no _shellcheck # TODO check codecov return
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
    if _notinstalled "curl"; then _error "curl not found"; _func_end "1" ; return 1 ; fi # no _shellcheck

    _verbose "METHOD:$1"
    _verbose "URL:$2"

    local __resp
    local __return

    case $1 in
        POST | PUT | DELETE | GET )
            if _notexist "$3"; then
                _verbose "HEADER EMPTY"
                __resp=$(curl -s -k -X "$1" --location "$2") # no _shellcheck
                __return=$?
            else
                if _notexist "$4"; then
                    _verbose "HEADER DATA EMPTY"
                    __resp=$(curl -s -k -X "$1" --location "$2" -H "$3") # no _shellcheck
                    __return=$?
                else
                    if _notexist "$5"; then
                        _verbose "NEXT HEADER:$4"
                        __resp=$(curl -s -k -X "$1" --location "$2" -H "$3" -H "$4") # no _shellcheck
                        __return=$?
                    else
                        _verbose "HEADER DATA:$4"
                        _verbose "DATA:$5"
                        __resp=$(curl -s -k -X "$1" --location "$2" -H "$3" -H "$4" -d "$5") # no _shellcheck
                        __return=$?
                    fi
                fi
            fi
            ;;
        * ) _error "Wrong METHOD send to curl" ; _func_end "1" ; return 1 ;; # no _shellcheck
    esac

    case $__return in
        0 ) if echo "$__resp" | $GREP "Unauthorized" > /dev/null; then _debug "$__resp"; _error "TOKEN invalid"; _func_end "1" ; return 1 ; else echo "$__resp" ; _func_end ; return 0 ; fi ;;
        3 ) _error "Wrong URL:$2" ; _func_end "$__return" ; return $__return ;;
        6 ) _error "DNS error for _curl" ; _func_end "$__return" ; return $__return ;;
        * ) _error "Something went wrong in _curl. Return code:$? Response:$__resp" ; _func_end "$__return" ; return $__return ;;
    esac
}

_encode_url () {
    _func_start

    if _notexist "$1"; then _error "URL EMPTY"; _func_end "1" ; return 1 ; fi
    if _notinstalled "jq"; then _error "jq not installed" ; _func_end "1" ; return 1 ; fi

    echo "$1" | jq -sRr @uri

    _func_end "0" ; return 0 # no _shellcheck
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

    _func_end "0" ; return 0 # no _shellcheck
}

####################################################################################################
############################################## ADMIN ###############################################
####################################################################################################
#
# usage: _service_list
#
_service_list () {
    _func_start

    local __return
    local __result

    __result=$(systemctl list-units --type=service --all --no-pager 2>&1)
    __return=$?

    if echo "$__result" | $GREP "System has not been booted with systemd as init system" ; then _warning "we'r in CI or container, no systemd" ; __return=0 ; else echo "$__result" ; fi

    _func_end "$__return" ; return $__return
}

#
# usage: _service_search --service ($1)
#
_service_search () {
    _func_start

    if _notexist "$1"; then _error "SERVICE EMPTY"; _func_end "1" ; return 1 ; fi

    local __return
    local __result

    __result=$(_service_list 2>&1)
    __return=$?

    if echo "$__result" | $GREP "we'r in CI or container, no systemd" ; then _warning "we'r in CI or container, no systemd" ; __return=0 ; else echo "$__result" | $GREP -i "$1" ; __return=$? ; fi


    _func_end "$__return" ; return $__return
}

####################################################################################################
######################################### INTERACTIVE ASK ##########################################
####################################################################################################
_ask_yes_or_no () {
    _func_start

    if _notexist "$1"; then _error "QUESTION EMPTY"; _func_end "1" ; return 1 ; fi

    local __answer="none"

    while true ; do
        read -r -p "$1 (y/N) " __answer
        case $__answer in
            [Yy] ) echo "y" ; _func_end "0" ; return 0 ;; # no _shellcheck
            [Nn] ) echo "n" ; _func_end "0" ; return 0 ;; # no _shellcheck
            "" )   echo "n" ; _func_end "0" ; return 0 ;; # no _shellcheck
            * ) echo "Please answer Y or N";;
        esac
    done

    _func_end "0" ; return 0 # no _shellcheck
}

_ask_ip () {
    _func_start

    if _notexist "$1"; then _error "QUESTION EMPTY"; _func_end "1" ; return 1 ; fi

    local __answer="none"

    while true ; do
        read -r -p "$1 " __answer
        if _ipv4 "$__answer"; then echo "$__answer" ; _func_end "0" ; return 0 ; fi # no _shellcheck
        echo "$__answer is not a valid ip address"
    done

    _func_end "0" ; return 0 # no _shellcheck
}

_ask_string () {
    _func_start

    if _notexist "$1"; then _error "QUESTION EMPTY"; _func_end "1" ; return 1 ; fi

    local __answer="none"

    read -r -p "$1 " __answer
    echo "$__answer"

    _func_end "0" ; return 0 # no _shellcheck
}

####################################################################################################
######################################### EVERYTHING ELSE ##########################################
####################################################################################################
_gen_rand () {
    _func_start

    tr -dc A-Za-z0-9 </dev/urandom | head -c 13

    _func_end "0" ; return 0 # no _shellcheck
}

_tmp_file () {
    _func_start

    local __rand

    __rand=$(_gen_rand)

    if _exist "${FUNCNAME[1]}" ; then
        echo "/tmp/$(basename "$0")${FUNCNAME[1]}.$__rand"
    else
        _error "we'r not in a function, weird" ; _func_end "1" ; return 1
    fi

    _func_end "0" ; return 0 # no _shellcheck
}

_os_arch () {
    _func_start

    uname -m

    _func_end "0" ; return 0 # no _shellcheck
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
    _error "Hello world" # no _shellcheck

    _func_end "0" ; return 0 # no _shellcheck
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
    local __service

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
            --service )        __service=$2      ; shift ; shift         ;;
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
            iptables_show)     _iptables_show                                                    ; __return=$? ; break ;;
            iptables_save)     _iptables_save                                                    ; __return=$? ; break ;;
            iptables_restore)  _iptables_restore                                                 ; __return=$? ; break ;;
            iptables_flush)    _iptables_flush                                                   ; __return=$? ; break ;;
            service_list)      _service_list                                                     ; __return=$? ; break ;;
            service_search)    _service_search    "$__service"                                   ; __return=$? ; break ;;
            -- ) shift ;;
            *) _error "command $1 not found" ; __return=1 ; break ;;
        esac
    done

    _func_end "$__return" ; return "$__return"
}
