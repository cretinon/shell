#!/bin/bash

# shellcheck source=/dev/null disable=SC2119,SC2120,SC2294,SC2001,SC2045,SC2184,SC2059,SC2034

GETOPT_SHORT_SHELL=h,v,d,b,s,k


CHECK_KO="[\033[0;31m✗\033[0m]"
CHECK_WARN="[\033[0;33m▲︋\033[0m]"
CHECK_SUCCESS="[\033[0;32m✓\033[0m]"
CHECK_INFO="[\033[0;34m★\033[0m]"

ERROR_ARGV=10

GREP="/usr/bin/grep --text"
EGREP="/usr/bin/grep --text"


####################################################################################################
########################################### STACK TRACE ############################################
####################################################################################################
# call: _echoerr ($1:msg)
# description: Prints a message to stderr.
_echoerr() {
    echo -e "$@" >&2
}

# call: _verbose_func_space ()
# description: Builds the verbose function-call space string from FUNC_LIST.
_verbose_func_space () {
    local __i
    local __oldIFS=$IFS
    local __msg

    IFS=''
    VERBOSE_SPACE=""
    for (( __i=0; __i<${#FUNC_LIST[@]}; __i++ )); do
        __msg="${FUNC_LIST[$__i]%%:*}"
        VERBOSE_SPACE="$VERBOSE_SPACE $__msg >"
    done
    IFS=$__oldIFS
}

# call: _func_start ($@:args)
# description: Starts function telemetry and logs the entry.
_func_start () {
    local __msg="Start"
    local __start
    local __i=0
    local LC_ALL=C # EPOCHREALTIME uses a locale-dependent decimal separator

    __start=$EPOCHREALTIME

    _array_add FUNC_LIST "${FUNCNAME[1]}:$__start"
    if $DEBUG || $VERBOSE; then _verbose_func_space ; fi

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

# call: _func_end ($1:code)
# description: Ends function telemetry and logs the exit.
_func_end () {
    if $DEBUG || $VERBOSE; then _verbose_func_space ; fi

    local __date
    local __msg
    local __nb
    local __start
    local __end
    local __duration
    local LC_ALL=C # EPOCHREALTIME uses a locale-dependent decimal separator

    __nb=$(_array_count_elt FUNC_LIST)
    __nb=$((__nb-1))
    __start=${FUNC_LIST[$__nb]#*:}
    __end=$EPOCHREALTIME
    __duration=$(_timediff "$__start" "$__end")

    if ! _exist "$1"; then
        __msg="End"
    else
        __msg="End - returning:$1 - in $__duration""ns"
    fi

    __date=$(_date)

    if $DEBUG; then
        _debug "$__msg"
    fi

    _array_remove_last FUNC_LIST
}

# call: _error ($1:msg)
# description: Logs an ERROR-level message.
_error() {
    _log "ERROR  " "\033[0;31m" "$CHECK_KO $*"
}

# call: _warning ($1:msg)
# description: Logs a WARNING-level message.
_warning() {
    _log "WARNING" "\033[0;33m" "$CHECK_WARN $*"
}

# call: _success ($1:msg)
# description: Logs a SUCCESS-level message.
_success() {
    _log "SUCCESS" "\033[0;32m" "$CHECK_SUCCESS $*"
}

# call: _info ($1:msg)
# description: Logs an INFO-level message.
_info() {
    _log "INFO   " "\033[0;34m" "$CHECK_INFO $*"
}

# call: _debug ($1:msg)
# description: Logs a DEBUG-level message.
_debug() {
    _log "DEBUG  " "" "$*"
}

# call: _verbose ($1:msg)
# description: Logs a VERBOSE-level message.
_verbose() {
    _log "VERBOSE" "" "$*"
}

# call: _verbose_file ($1:file)
# description: Dumps a file content to stderr with verbose logging.
_verbose_file () {
    local __date

    if ! _fileexist "$1"
    then
        _error "can verbose $1, not exist" ; return 1
    else
        _verbose "--- dump file start --- $1"
        if $VERBOSE; then cat "$1" >&2; fi
        _verbose "--- dump file end   --- $1"
    fi
}

# call: _log ($1:level) ($2:color) ($3:message)
# description: Core logger used by all log levels.
_log () {

    local __level="$1" __color="$2" __message="$3"
    local __date

    if [[ "$__level" == "DEBUG  " && $DEBUG != true ]];   then return ; fi
    if [[ "$__level" == "VERBOSE" && $VERBOSE != true ]]; then return ; fi

    if ! $DEBUG && ! $VERBOSE; then
        _echoerr "$__message"
        return
    fi

    __date=$(_date)

    if $DEBUG; then
        _verbose_func_space
        _echoerr "[$$] -- ${__color}${__level}\033[0m -- $__date -- $VERBOSE_SPACE $__message"
    else
        _echoerr "[$$] -- VERBOSE -- $__date -- $__message"
    fi
}


####################################################################################################
#################################### CORE VALIDATION PRIMITIVE #####################################
####################################################################################################
# call: _exist ($1:arg)
# description: Checks that an argument or variable is non-empty.
_exist () {
    if [[ -z "$1" ]] ; then return 1; else return 0; fi
}

# call: _fileexist ($1:file)
# description: Checks that a file exists.
_fileexist () {
    _func_start "$@"

    if [ -e "$1" ]; then
        _debug "$1 already exist"
        _func_end "0" ; return 0 # no _shellcheck
    else
        _func_end "1" ; _verbose "file $1 does not exist" ; return 1 # no _shellcheck
    fi
}

# call: _remotefileexist ($1:path)
# description: Checks that a remote (NFS) file exists.
_remotefileexist () {
    _func_start "$@"

    timeout 1 stat -t "$1" > /dev/null 2>/dev/null

    case "$?" in
        0)
            _verbose "$1 exist"
            _func_end "0" ; return 0 # no _shellcheck
        ;;
        124)
            _func_end "1" ; _error "$1 Timeout" ; return 1
        ;;
        *)
            _func_end "1" ; _error "$1 not exist" ; return 1
        ;;
    esac
}

# call: _func_exist ($1:function)
# description: Checks that a function is defined.
_func_exist() {
  [ "$(type -t "$1")" == 'function' ]
}

# call: _installed ($1:binary)
# description: Checks that a binary is installed.
_installed () {
    if type "$1" 2> /dev/null 1>/dev/null ; then return 0; else return 1; fi
}

# call: _working_dir ()
# description: Prints the basename of the current directory.
_working_dir () {
    basename "$PWD"
}

# call: _working_dir_count_file ($1:pattern)
# description: Counts files in the current directory.
_working_dir_count_file () {
    if _exist "$1" ; then
        find "." -maxdepth 1 -type f -name "$@" | wc -l | xargs
    else
        find "." -maxdepth 1 -type f | wc -l | xargs
    fi
}

# call: _working_dir_count_dir ($1:pattern)
# description: Counts directories in the current directory.
_working_dir_count_dir () {
    if _exist "$1" ; then
        find "." -maxdepth 1 -type d -name "$@" | $GREP "./" | wc -l | xargs
    else
        find "." -maxdepth 1 -type d | $GREP "./" | wc -l | xargs
    fi
}

# call: _working_dir_list_dir_by_creation_date ()
# description: Lists directories in the current directory by creation date.
_working_dir_list_dir_by_creation_date () {
    # shellcheck disable=1001
    find "." -maxdepth 1 -type d -exec stat --format="%w %n" {} + | sort -n | $GREP "/" | cut -d\/ -f2-42
}

# call: _tmp_file ()
# description: Generates a unique temporary file path.
_tmp_file () {
    _func_start "$@"

    # Check argv
    local __rand

    __rand=$(_gen_rand)

    if _exist "${FUNCNAME[1]}" ; then
        echo "/tmp/${0##*/}${FUNCNAME[1]}.$__rand"
    else
        _error "we'r not in a function, weird" ; _func_end "1" ; return 1
    fi

    _func_end "0" ; return 0
}

####################################################################################################
########################################### PROCESS OPTS ###########################################
####################################################################################################
# call: _process_opts ($@:args)
# description: Parses the CLI options and routes to the requested action.
_process_opts () {
    _func_start "$@"

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

    OPTS=$(getopt --options "$__short" --long "$__long" --name "$0" -- "$@" 2>/dev/null) || (_error "Bad or missing argument.\n\nTry '$CUR_NAME --help' for more informations\n" ; _func_end "1" ; return 1)

    if ! _startswith "$1" '-'; then
        _error "Bad or missing argument.\n\nTry '$CUR_NAME --help' for more informations\n" ; _func_end "1" ; return 1
    else
        eval set -- "$OPTS"

        while true ; do
            case "$1" in
                -v | --verbose )     VERBOSE=true                             ; shift ;;
                -d | --debug )       DEBUG=true                               ; shift ;;
                --dry-run )          DRY_RUN=true                             ; shift ;;
                --default )          DEFAULT=true                             ; shift ;;
                --force )            FORCE=true                               ; shift ;;
                --yubikey )          YUBIKEY=true                             ; shift ;;
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
        if $__kcov       ; then if ! _kcov "$@"           ; then _error "something went wrong in kcov" ; _func_end "1" ; return 1 ;fi ; fi
    fi

    _func_end "$__return" ; return $__return
}

# call: _getopt_short ()
# description: Builds the short option string from the installed libs.
_getopt_short () {
    _func_start "$@"

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

# call: _getopt_long ()
# description: Builds the long option string from the lib usage lines.
_getopt_long () {
    _func_start "$@"

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

    echo -n "debug,verbose,help,list-libs,bats,shellcheck,kcov,dry-run,default,force,yubikey,$__result""lib:" | sed -e 's/ /:,/g'

    _func_end "0" ; return 0
}

####################################################################################################
############################################## USAGES ##############################################
####################################################################################################
# call: _usage ()
# description: Displays the CLI help and usage.
_usage () {
    _func_start "$@"

    # Check argv
    if _exist "$LIB" && ! _fileexist "$MY_GIT_DIR/$LIB/lib_$LIB.sh" ; then _error "No such LIB:$LIB\n\nTry '$CUR_NAME -h' for more informations\n"; _func_end "1" ; return 1 ; fi

    local __line

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
        echo "  * Select default values when asked   => $CUR_NAME --default"
        echo "  * Force action                       => $CUR_NAME --force"
        echo "  * Use a Yubikey                      => $CUR_NAME --yubikey"
        echo "  * List avaliable libs                => $CUR_NAME --list-libs"
        echo "  * Use any lib                        => $CUR_NAME --lib lib_name"
        echo "  * Bash Automated Testing System      => $CUR_NAME -b | --bats --lib lib_name"
        echo "  * Shell Syntax Checking              => $CUR_NAME -s | --shellcheck --lib lib_name"
        echo "  * Code coverage                      => $CUR_NAME -k | --kcov --lib lib_name"
        echo "  * Code coverage keep report (AI)     => $CUR_NAME -k AI --lib lib_name"
    fi

    _func_end "0" ; return 0
}

####################################################################################################
######################################### LOAD LIBS & CONF #########################################
####################################################################################################
# call: _load_libs ()
# description: Sources lib_shell.sh and every installed library.
_load_libs () {
#    _func_start "$@"

    local __lib

    source "$MY_GIT_DIR/shell/lib_shell.sh"

    for __lib in $(_get_installed_libs); do
        _verbose "Loading:$MY_GIT_DIR/$__lib/lib_$__lib.sh"
        source  "$MY_GIT_DIR"/"$__lib"/lib_"$__lib".sh
    done

#    _func_end "0" ; return 0
}

# call: _load_lib ($1:lib)
# description: Sources a single library file.
_load_lib () {
    _func_start "$@"

    # Check argv
    if ! _exist "$1" ;then _error "LIB EMPTY" ; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _fileexist "$MY_GIT_DIR/$1/lib_$1.sh" ;then _error "$MY_GIT_DIR/$1/lib_$1.sh not exist, not sourcing" ; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi

    _verbose "Loading $MY_GIT_DIR/$1/lib_$1.sh"
    source  "$MY_GIT_DIR"/"$1"/lib_"$1".sh

    _func_end "0" ;  return 0
}

# call: _load_conf ($1:file)
# description: Sources a user or my configuration file.
_load_conf () {
    _func_start "$@"

    # Check argv
    if ! _exist "$1"; then _error "CONF EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _fileexist "$1"; then _error "$1 not exist, not sourcing (did you git pull ?)" ; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi

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

    _func_end "0" ; return 0
}

# call: _get_installed_libs ()
# description: Lists the installed libraries.
_get_installed_libs () {
    _func_start "$@"

    local __lib_dir

    for __lib_dir in $(ls "$MY_GIT_DIR"); do
        if _fileexist "$MY_GIT_DIR"/"$__lib_dir"/lib_"$__lib_dir".sh ; then
            echo -n "$__lib_dir "
        fi
    done | _remove_last_car

    _func_end "0" ; return 0
}

####################################################################################################
########################################### RAND & UUID ############################################
####################################################################################################
# call: _gen_rand ($1:length) ($2:separator) ($3:max)
# description: Generates a random alphanumeric string.
_gen_rand () {
    _func_start "$@"

    local __rand

    __rand=$(LC_ALL=C tr -dc "A-Z0-9" < /dev/urandom | \
       tr -d "IOS" | \
       fold  -w  "${1:-4}" | \
       paste -sd "${2:--}" - | \
       head  -c  "${3:-29}")

    echo "$__rand"

    _func_end "0" ; return 0
}

# call: _gen_pin ($1:length)
# description: Generates a random numeric PIN.
_gen_pin () {
    _func_start "$@"

    local __pin

    __pin=$(LC_ALL=C tr -dc "0-9" < /dev/urandom | \
       fold  -w  "${1:-6}" | \
       head  -c  "${1:-6}")

    echo "$__pin"

    _func_end "0" ; return 0
}

# call: _gen_uuid ()
# description: Generates a UUID.
_gen_uuid () {
    _func_start "$@"

    if ! _installed "uuidgen" ; then _error "uuidgen not found"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi

    uuidgen

    _func_end "0" ; return 0
}

####################################################################################################
######################################### TIME MANAGEMENT ##########################################
####################################################################################################
# call: _date ()
# description: Prints the current date and time.
_date () {
    printf '%(%Y-%m-%d %H:%M:%S)T\n' -1
}

# call: _iso_date ()
# description: Prints the current UTC date in ISO format.
_iso_date () {
    date -u +"%Y-%m-%dT%H:%M:%S.%3NZ"
}

# call: _timediff ($1:start) ($2:end)
# description: Computes the difference between two timestamps.
_timediff() {
    if ! _exist "$1"; then _error "start time EMPTY"; return 1 ; fi
    if ! _exist "$2"; then _error "end time EMPTY"; return 1 ; fi
    if ! [[ "$1" =~ ^[0-9]+\.[0-9]+$ ]] || ! [[ "$2" =~ ^[0-9]+\.[0-9]+$ ]]; then
        _error "invalid timestamp, expected seconds.nanoseconds"; return 1
    fi

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

    # Strip leading zeros safely (avoid octal interpretation)
    __start_s=${__start_s#"${__start_s%%[1-9]*}"}
    __start_nanos=${__start_nanos#"${__start_nanos%%[1-9]*}"}
    __end_s=${__end_s#"${__end_s%%[1-9]*}"}
    __end_nanos=${__end_nanos#"${__end_nanos%%[1-9]*}"}

    # Default to 0 if empty after stripping
    __start_s=${__start_s:-0}
    __start_nanos=${__start_nanos:-0}
    __end_s=${__end_s:-0}
    __end_nanos=${__end_nanos:-0}

    if [ "$__end_nanos" -lt "$__start_nanos" ];then
        __end_s=$(( "$__end_s" - 1 ))
        __end_nanos=$(( "$__end_nanos" + 10**9 ))
    fi

    __time=$(( "$__end_s" - "$__start_s" ))s$(( "$__end_nanos" - "$__start_nanos" ))

    echo $__time
}

# call: _epoch_2_date ($1:epoch)
# description: Converts an epoch timestamp to a UTC date.
_epoch_2_date () {
# always return UTC date
    if ! _exist "$1"; then _error "DATE EMPTY"; return 1 ; fi
    if ! _is_numeric "$1"; then _error "epoch not numeric"; return 1 ; fi
    if [ "${#1}" -lt 4 ]; then _error "epoch too short"; return 1 ; fi

    date -u -d "@${1%???}.${1: -3}" +"%Y-%m-%d %H:%M:%S"
}

# call: _date_2_epoch ($1:date)
# description: Converts a date to an epoch timestamp.
_date_2_epoch () {
# always return UTC epoch
    if ! _exist "$1"; then _error "DATE EMPTY"; return 1 ; fi

    date -d "$1" +"%s%3N"
}

####################################################################################################
######################################## ARRAY MANAGEMENT ##########################################
####################################################################################################
# call: _array_print ($1:array)
# description: Prints array elements with their index.
# we can't add _func_start "$@" && _func_end in array management ... infinite loop
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

# call: _array_print_index ($1:array) ($2:index)
# description: Prints one element of an array.
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

# call: _array_add ($1:array) ($2:element)
# description: Appends an element to an array.
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

# call: _array_remove_last ($1:array)
# description: Removes the last element of an array.
_array_remove_last () {
    if ! _exist "$1"; then _error "ARRAY EMPTY"; return 1 ; fi

    local __oldIFS=$IFS

    IFS=''
    declare -n __array
    __array="$1"

    if [ "${#__array[@]}" -gt 0 ]; then
        unset "$1"[-1]
    fi

    IFS=$__oldIFS
}

# call: _array_remove_index ($1:array) ($2:index)
# description: Removes an element at a given index.
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

# call: _array_count_elt ($1:array)
# description: Counts the elements of an array.
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
# call: _json_2_yaml ($1:json)
# description: Converts JSON input to YAML using yq.
# we need to IFS='' before doing smthing like __my_var=$(cat $file) ; echo $__my_var | _json_2_yaml
_json_2_yaml () {
    _func_start "$@"

    # Check argv
    if ! _installed "yq"; then _error "yq not found"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi

    local __input=${*:-$(</dev/stdin)}
    local __return
    local __yq_version

    __yq_version=$(yq --version | sed -e 's/yq (https:\/\/github.com\/mikefarah\/yq\/) version v//' | sed -e 's/yq version //' | sed -e 's/yq //' | cut -d. -f1)
    if ! _is_numeric "$__yq_version" || [ "$__yq_version" -ne 4 ]; then _error "yq $__yq_version not supported, need version >= 4"; _func_end "1" ; return 1 ; fi

    echo "$__input" | yq -p json
    __return=$? ; if [ $__return -ne 0 ] ; then _error "something went wrong with yq"; _func_end "$__return" ; return $__return ; fi

    _func_end "$__return" ; return $__return
}

# call: _yaml_2_json ($1:yaml)
# description: Converts YAML input to JSON using yq.
_yaml_2_json () {
    _func_start "$@"

    # Check argv
    if ! _installed "yq"; then _error "yq not found"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi

    local __input=${*:-$(</dev/stdin)}
    local __return
    local __yq_version

    __yq_version=$(yq --version | sed -e 's/yq (https:\/\/github.com\/mikefarah\/yq\/) version v//' | sed -e 's/yq version //' | sed -e 's/yq //' | cut -d. -f1)
    if ! _is_numeric "$__yq_version" || [ "$__yq_version" -ne 4 ]; then _error "yq $__yq_version not supported, need version >= 4"; _func_end "1" ; return 1 ; fi

    echo "$__input" | yq -o json
    __return=$? ; if [ $__return -ne 0 ] ; then _error "something went wrong with yq"; _func_end "$__return" ; return $__return ; fi

    _func_end "$__return" ; return $__return
}

# call: _json_add_key_with_value ($1:json) ($2:path) ($3:key) ($4:value)
# description: Adds a key with a value to JSON.
_json_add_key_with_value () {
    _func_start "$@"

    # Check argv
    if ! _exist "$1"; then _error "JSON EMPTY" ; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _exist "$3"; then _error "KEY EMPTY" ; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _exist "$4"; then _error "VALUE EMPTY" ; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _installed "jq"; then _error "jq not found" ; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi

    local __return

    # if _startswith "$4" "{"; then
    #     _debug "adding $4 to $3"
    #     echo "$1" | jq '.'"$2"' += {"'"$3"'":'"$4"'}'
    # else
    #     _debug "adding $4 to $3"
    #     echo "$1" | jq '.'"$2"' += {"'"$3"'":"'"$4"'"}'
    # fi

    _debug "adding $4 to $3"
    echo "$1" | jq '.'"$2"' += {"'"$3"'":'"$4"'}'

    __return=$? ; if [ $__return -ne 0 ] ; then _error "something went wrong with jq"; _func_end "$__return" ; return $__return ; fi

    _func_end "$__return" ; return $__return
}

# call: _json_add_value_in_array ($1:json) ($2:path) ($3:array) ($4:value)
# description: Adds a value inside a JSON array.
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

# call: _json_remove_key ($1:json) ($2:key)
# description: Removes a key from JSON.
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

# call: _json_replace_key_with_value ($1:json) ($2:key) ($3:value)
# description: Replaces a key value in JSON.
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

# call: _json_get_value_from_key ($1:json) ($2:key)
# description: Gets a value from a JSON key path.
_json_get_value_from_key () {
    _func_start "$@"

    # Check argv
    if ! _exist "$1"; then _error "JSON EMPTY" ; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _exist "$2"; then _error "KEY EMPTY" ; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _installed "jq"; then _error "jq not found"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi

    local __return
    local __result
    # shellcheck disable=SC2016 # $p is jq's --arg variable, not a bash expansion
    local __filter='getpath(($p | split(".")))'

    __result=$(echo "$1" | jq -r --arg p "$2" "$__filter" 2>/dev/null)

    # distinguish a JSON null / missing value (ret 1) from any non-null value,
    # including the literal string "null" (ret 0)
    if echo "$1" | jq -e --arg p "$2" "$__filter"' != null' >/dev/null 2>&1; then
        __return=0
    else
        __return=1
    fi

    _debug "$2:$__result"
    echo "$__result"

    _func_end "$__return" ; return $__return
}

# call: _json_get_value_from_array ($1:json) ($2:path) ($3:match-key) ($4:match-value) ($5:return-key)
# description: Gets a value from a JSON array path.
_json_get_value_from_array () {
    _func_start "$@"

    # Check argv
    if ! _exist "$1"; then _error "JSON EMPTY" ; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _exist "$2"; then _error "ARRAY PATH EMPTY" ; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _exist "$5"; then _error "RETURN KEY EMPTY" ; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _installed "jq"; then _error "jq not found" ; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi

    local __return
    local __filter
    # shellcheck disable=SC2016 # $p/$mk/$mv/$rk are jq --arg variables, not bash expansions
    if _exist "$3" && _exist "$4"; then
        __filter='getpath(($p | split(".")))[]? | select(.[$mk] == $mv) | .[$rk]'
    else
        __filter='getpath(($p | split(".")))[]? | .[$rk]'
    fi

    echo "$1" | jq -r --arg p "$2" --arg mk "$3" --arg mv "$4" --arg rk "$5" "$__filter"
    __return=$? ; if [ $__return -ne 0 ] ; then _error "something went wrong with jq"; _func_end "$__return" ; return $__return ; fi

    _func_end "$__return" ; return $__return
}

####################################################################################################
######################################## STRING MANAGEMENT #########################################
####################################################################################################
# call: _upper ($1:str)
# description: Converts input to uppercase.
# next 4 func can be use like _upper "hello word" or echo "hello world" | _upper
_upper() {
    local __input=${*:-$(</dev/stdin)}
    local LC_ALL=C

    printf '%s\n' "${__input^^}"
}

# call: _lower ($1:str)
# description: Converts input to lowercase.
_lower() {
    local __input=${*:-$(</dev/stdin)}
    local LC_ALL=C

    printf '%s\n' "${__input,,}"
}

# call: _remove_french ($1:str)
# description: Removes French accents from the input.
_remove_french() {
    local __input=${*:-$(</dev/stdin)}
    local LC_ALL=C

    __input=${__input//à/a}
    __input=${__input//â/a}
    __input=${__input//ä/a}
    __input=${__input//é/e}
    __input=${__input//è/e}
    __input=${__input//ê/e}
    __input=${__input//ë/e}
    __input=${__input//î/i}
    __input=${__input//ï/i}
    __input=${__input//ô/o}
    __input=${__input//ö/o}
    __input=${__input//ù/u}
    __input=${__input//û/u}
    __input=${__input//ü/u}
    __input=${__input//ÿ/y}
    __input=${__input//ç/c}
    __input=${__input//À/A}
    __input=${__input//Â/A}
    __input=${__input//Ä/A}
    __input=${__input//É/E}
    __input=${__input//È/E}
    __input=${__input//Ê/E}
    __input=${__input//Ë/E}
    __input=${__input//Î/I}
    __input=${__input//Ï/I}
    __input=${__input//Ô/O}
    __input=${__input//Ö/O}
    __input=${__input//Ù/U}
    __input=${__input//Û/U}
    __input=${__input//Ü/U}
    __input=${__input//Ÿ/Y}
    __input=${__input//Ç/C}

    printf '%s\n' "$__input"
}

# call: _remove_last_car ($1:str)
# description: Removes the last character of the input.
_remove_last_car() {
    local __input=${*:-$(</dev/stdin)}

    printf '%s\n' "${__input%?}"
}

# call: _is_ascii ($1:str)
# description: Checks that the input is ASCII.
_is_ascii() {
    local LC_ALL=C

    [[ "$1" =~ ^[[:print:]]*$ ]]
}

# call: _is_numeric ($1:str)
# description: Checks that the input is numeric.
_is_numeric() {
    local LC_ALL=C

    [[ "$1" =~ ^[0-9]+$ ]]
}

# call: _startswith ($1:str) ($2:substr)
# description: Checks that a string starts with a substring.
_startswith() {
    local __str="$1"
    local __sub="$2"

    [[ "$__str" == "$__sub"* ]]
}

# call: _contains ($1:str) ($2:regex)
# description: Checks that a string matches a regex.
_contains () {
    if [[ $1 =~ $2 ]]; then return 0; else return 1; fi
}

####################################################################################################
############################################### URL ################################################
####################################################################################################
#
# usage: _curl --method ($1) --url ($2) --header ($3) --header-data ($4) --data ($5)
# description: Performs an HTTP request with curl and prints the response body.
#
_curl () {
    _func_start "$@"

    # Check argv
    if ! _exist "$1"; then _error "METHOD EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _exist "$2"; then _error "URL EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _is_ascii "$2"; then _error "URL is non ASCII !!!"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _installed "curl"; then _error "curl not found"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi

    _debug "METHOD:$1"
    _debug "URL:$2"

    local __resp
    local __return
    local __http_code
    local __body

    case $1 in
        POST | PUT | DELETE | GET )
            if ! _exist "$3"; then
                __resp=$(curl -s -k -X "$1" --location "$2" --write-out $'\n%{http_code}') # no _shellcheck
                __return=$?
            else
                if ! _exist "$4"; then
                    __resp=$(curl -s -k -X "$1" --location "$2" -H "$3" --write-out $'\n%{http_code}') # no _shellcheck
                    __return=$?
                else
                    if ! _exist "$5"; then
                        __resp=$(curl -s -k -X "$1" --location "$2" -H "$3" -H "$4" --write-out $'\n%{http_code}') # no _shellcheck
                        __return=$?
                    else
                        __resp=$(curl -s -k -X "$1" --location "$2" -H "$3" -H "$4" -d "$5" --write-out $'\n%{http_code}') # no _shellcheck
                        __return=$?
                    fi
                fi
            fi
            ;;
        * ) _error "Wrong METHOD send to curl" ; _func_end "1" ; return 1 ;;
    esac

    # The HTTP status code is appended to the response body by --write-out (as a last line)
    __http_code="${__resp##*$'\n'}"
    __body="${__resp%$'\n'*}"

    # Intercept HTTP 504 (Gateway Time-out)
    if [[ "$__return" == "0" && "$__http_code" == "504" ]]; then _debug "$__resp"; _error "504 Gateway Time-out"; _func_end "1" ; return 1 ; fi

    case $__return in
        0 )  if echo "$__body" | $GREP "Unauthorized" > /dev/null; then _debug "$__body"; _error "TOKEN invalid"; _func_end "1" ; return 1 ; else echo "$__body" ; _func_end "0" ; return 0 ; fi ;;
        3 )  _error "Wrong URL:$2" ; _func_end "$__return" ; return $__return ;;
        6 )  _error "DNS error for _curl" ; _func_end "$__return" ; return $__return ;;
        35 ) _error "SSL error for _curl" ; _func_end "$__return" ; return $__return ;;
        * )  _error "Something went wrong in _curl. Return code:$__return Response:$__resp" ; _func_end "$__return" ; return $__return ;;
    esac
}

# call: _encode_url ($1:url)
# description: URL-encodes an input string.
_encode_url () {
    _func_start "$@"

    local __input=${*:-$(</dev/stdin)}

    # Check argv
    if ! _exist "$__input"; then _error "URL EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _installed "jq"; then _error "jq not installed" ; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi

    echo "$__input" | jq -Rr @uri # was jq -sRr but added a %A0 at the end of strig

    _func_end "0" ; return 0
}

# call: _decode_url ($1:url)
# description: URL-decodes an input string.
_decode_url () {
    _func_start "$@"

    # Check argv
    if ! _exist "$1"; then _error "URL EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi

    local __strg
    local j

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
        * ) _func_end "0" ; return 0 ;; # no _shellcheck
    esac
    if [ -n "${__strg}" ] ; then _decode_url "${__strg}"; fi

    _func_end "0" ; return 0
}

####################################################################################################
######################################## NETWORK MANAGEMENT ########################################
####################################################################################################
# call: _valid_ipv4 ($1:ip)
# description: Validates an IPv4 address.
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

    _func_end "0" ; return 0 ;
}

# call: _valid_network ($1:network)
# description: Validates a network address (IP/mask).
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
    if ! _is_numeric "$__mask"; then _error "mask not numeric" ; _func_end "1" ; return 1 ; fi
    if [ "$__mask" -gt 32 ]; then _error "mask > 32" ; _func_end "1" ; return 1 ; fi

    _func_end "0" ; return 0 ;
}

# call: _ip2int ($1:ip)
# description: Converts an IPv4 address to an integer.
_ip2int() {
    _func_start "$@"

    # Check argv
    if ! _exist "$1"; then _error "IP EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _valid_ipv4 "$1"; then _error "not a valid ip address" ; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi

    _debug "what is $1 in int ?"

    local a b c d
    { IFS=. read -r a b c d; } <<< "$1"
    echo $(((((((a << 8) | b) << 8) | c) << 8) | d))

    _func_end "0" ; return 0
}

# call: _int2ip ($1:int)
# description: Converts an integer to an IPv4 address.
_int2ip() {
    _func_start "$@"

    # Check argv
    if ! _exist "$1"; then _error "INT EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _is_numeric "$1"; then _error "int not numeric"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if [ "$1" -gt 4294967295 ]; then _error "int too large"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi

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

    _func_end "0" ; return 0
}

# call: _netmask ($1:mask)
# description: Computes the netmask of a CIDR mask.
_netmask() {
    # Example: netmask 24 => 255.255.255.0
    _func_start "$@"

    # Check argv
    if ! _exist "$1"; then _error "MASK EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _is_numeric "$1"; then _error "mask not numeric"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if [ "$1" -gt 32 ]; then _error "mask > 32" ; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi

    _debug "what is $1 mask ?"

    local __mask=$(((0xffffffff << (32 - "$1")) & 0xffffffff))
    _int2ip $__mask

    _func_end "0" ; return 0
}

# call: _broadcast ($1:ip) ($2:mask)
# description: Computes the broadcast address of a network.
_broadcast() {
    # Example: broadcast 192.0.2.0 24 => 192.0.2.255
    _func_start "$@"

    # Check argv
    if ! _exist "$1"; then _error "IP EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _exist "$2"; then _error "MASK EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _valid_ipv4 "$1"; then _error "not a valid ip address" ; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _is_numeric "$2"; then _error "mask not numeric"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if [ "$2" -gt 32 ]; then _error "mask > 32" ; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi

    _debug "what is $1 $2 broadcast ?"

    local __addr
    local __mask

    __addr=$(_ip2int "$1")
    __mask=$((0xffffffff << (32 -"$2")))

    _int2ip $(( (__addr | ~__mask) & 0xffffffff ))

    _func_end "0" ; return 0
}

# call: _network ($1:ip) ($2:mask)
# description: Computes the network address of a network.
_network() {
    # Example: network 192.0.2.0 24 => 192.0.2.0
    _func_start "$@"

    # Check argv
    if ! _exist "$1"; then _error "NETWORK EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _exist "$2"; then _error "MASK EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _valid_ipv4 "$1"; then _error "not a valid ip address" ; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _is_numeric "$2"; then _error "mask not numeric"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if [ "$2" -gt 32 ]; then _error "mask > 32" ; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi

    _debug "what is $1 $2 network ?"

    local __addr
    local __mask

    __addr=$(_ip2int "$1")
    __mask=$((0xffffffff << (32 -"$2")))

    _int2ip $((__addr & __mask))

    _func_end "0" ; return 0
}

####################################################################################################
############################################## ARCH ################################################
####################################################################################################
# call: _raspberry ()
# description: Checks that the architecture is armv7l.
_raspberry () {
    if [ "$(_os_arch)" = "armv7l" ]; then return 0; else return 1; fi
}

# call: _x86_64 ()
# description: Checks that the architecture is x86_64.
_x86_64 () {
    if [ "$(_os_arch)" = "x86_64" ]; then return 0; else return 1; fi
}

# call: _os_arch ()
# description: Prints the machine architecture.
_os_arch () {
    _func_start "$@"

    uname -m

    _func_end "0" ; return 0
}

####################################################################################################
######################################### INTERACTIVE ASK ##########################################
####################################################################################################
# call: _ask_yes_or_no ($1:question) ($2:default)
# description: Asks a yes/no question interactively.
_ask_yes_or_no () {
    _func_start "$@"

    # Check argv
    if ! _exist "$1"; then _error "QUESTION EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _exist "$DEFAULT"; then DEFAULT=false ; fi
    if ! _exist "$WHIPTAIL"; then WHIPTAIL=false ; fi

    local __answer="none"
    local __msg
    local __heigh

    if $DEFAULT ; then
        _debug "not asking because of --default"
        if _exist "$2" ; then
            if [ "a$2" != "ay" ] && [ "a$2" != "an" ] ; then _error "default value is not a valid y/n" ; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
            echo "$2"; _func_end "0" ; return 0 # no _shellcheck
        else
            _error "default value is empty" ; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV
        fi
    else
        if $WHIPTAIL ; then
            if ! _installed "whiptail"; then _error "whiptail not found"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi

            __heigh=$(echo "$1" | wc -l)
            __heigh=$(("$__heigh" + 7))

            if whiptail --yesno "$1" "$__heigh" 120; then
                echo "y"
            else
                echo "n"
            fi
        else
            while true ; do
                if _exist "$2" ; then
                    case $2 in
                        y) __msg="$1 [Y/n] ? " ;;
                        n) __msg="$1 [y/N] ? " ;;
                        *) _error "default value is not valid y/n" ; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ;;
                    esac

                    read -r -p "$__msg" __answer
                else
                    read -r -p "$1 [y/n] ? " __answer
                fi

                case $__answer in
                    [Yy] ) echo "y" ; _func_end "0" ; return 0 ;; # no _shellcheck
                    [Nn] ) echo "n" ; _func_end "0" ; return 0 ;; # no _shellcheck
                    "" )   if _exist "$2"; then
                               if [ "a$2" != "ay" ] && [ "a$2" != "an" ] ; then _error "default value is not valid y/n" ; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
                               echo "$2" ; _func_end "0" ; return 0 # no _shellcheck
                           else
                               _warning "Please answer Y or N"
                           fi ;;

                    * ) _warning "Please answer Y or N";;
                esac
            done
        fi
    fi

    _func_end "0" ; return 0
}

# call: _ask_ip ($1:question) ($2:default)
# description: Asks for an IPv4 address interactively.
_ask_ip () {
    _func_start "$@"

    # Check argv
    if ! _exist "$1"; then _error "QUESTION EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi

    local __answer="none"

    if $DEFAULT ;then
        _debug "not asking because of --default"
        if _exist "$2" ; then
            if ! _valid_ipv4 "$2"; then _error "default value is not a valid ip address" ; _func_end "1" ; return 1 ; fi
            echo "$2"; _func_end "0" ; return 0 # no _shellcheck
        else
            _error "default value is empty" ; _func_end "1" ; return 1
        fi
    else
        while true ; do
            if _exist "$2" ; then read -r -p "$1 [$2] ? " __answer ; else read -r -p "$1 ? " __answer ; fi
            if [ "a$__answer" == "a" ]; then
                if _exist "$2"; then
                    if _valid_ipv4 "$2"; then
                        echo "$2"; _func_end "0" ; return 0 # no _shellcheck
                    else
                        _error "default value is not a valid ip address" ; _func_end "1" ; return 1
                    fi
                fi
            fi
            if _valid_ipv4 "$__answer"; then echo "$__answer" ; _func_end "0" ; return 0 ; fi # no _shellcheck
            _warning "$__answer is not a valid ip address"
        done
    fi
}

# call: _ask_network ($1:question) ($2:default)
# description: Asks for a network address interactively.
_ask_network () {
    _func_start "$@"

    # Check argv
    if ! _exist "$1"; then _error "QUESTION EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi

    local __answer="none"

    if $DEFAULT ;then
        _debug "not asking because of --default"
        if _exist "$2" ; then
            if ! _valid_network "$2"; then _error "default value is not a valid network" ; _func_end "1" ; return 1 ; fi
            echo "$2"; _func_end "0" ; return 0 # no _shellcheck
        else
            _error "default value is empty" ; _func_end "1" ; return 1
        fi
    else
        while true ; do
            if _exist "$2" ; then read -r -p "$1 [$2] ? " __answer ; else read -r -p "$1 ? " __answer ; fi
            if [ "a$__answer" == "a" ]; then
                if _exist "$2"; then
                    if _valid_network "$2"; then
                        echo "$2"; _func_end "0" ; return 0 # no _shellcheck
                    else
                        _error "default value is not a valid network" ; _func_end "1" ; return 1
                    fi
                fi
            fi
            if _valid_network "$__answer"; then echo "$__answer" ; _func_end "0" ; return 0 ; fi # no _shellcheck
            _warning "$__answer is not a valid network"
        done
    fi
}

# call: _ask_string ($1:question) ($2:default)
# description: Asks for a free-form string interactively.
_ask_string () {
    _func_start "$@"

    # Check argv
    if ! _exist "$1"; then _error "QUESTION EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi

    local __answer="none"

    if $DEFAULT ;then
        _debug "not asking because of --default"
        if _exist "$2" ; then
            echo "$2"; _func_end "0" ; return 0 # no _shellcheck
        else
            _error "default value is empty" ; _func_end "1" ; return 1
        fi
    else
        while true; do
            if _exist "$2" ; then read -r -p "$1 [$2] ? " __answer ; else read -r -p "$1 ? " __answer ; fi
            if [ "a$__answer" == "a" ]; then if _exist "$2"; then echo "$2"; _func_end "0" ; return 0 ; fi ; fi # no _shellcheck
            if [ "a$__answer" != "a" ]; then echo "$__answer"; _func_end "0"; return 0 ;  fi # no _shellcheck
            _warning "$1 can't be empty"
        done
    fi
}

####################################################################################################
########################################### TESTS & CI #############################################
####################################################################################################
# call: _shellcheck ($1:files)
# description: Runs shellcheck on target files and enforces the project lint rules.
_shellcheck () {
    _func_start "$@"

    # Check argv
    local __files

    if ! _exist "$LIB" ; then
        __files="$*"
    else
        if _exist "$LIB" && ! _fileexist "$MY_GIT_DIR/$LIB/lib_$LIB.sh" ;then _error "lib file not found" ; _usage; _func_end "1" ; return 1 ; fi
        __files=$(find "$MY_GIT_DIR"/"$LIB"/ -type f | $GREP -v "entry" | $GREP "\.sh$" | tr '\n' ' '  )
    fi

    if ! _installed "shellcheck"; then _error "shelcheck not found" ; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi

    # shellcheck disable=SC2086
    if shellcheck $__files ; then
        if awk '
            FNR == 1 { b=0; d=0; u=0 }
            /^[[:space:]]*$/ { b=0; d=0; u=0; next }
            /^#!/ { next }
            /^# shellcheck/ { next }
            /^#/ {
                if ($0 ~ /^#+$/) { b++ }
                else if ($0 ~ /^#+[[:space:]]*[A-Za-z0-9&_ -]*[[:space:]]*#+$/) { b++ }
                else if ($0 ~ /^# usage:/ || $0 ~ /^# call:/) { u++ }
                else { d++ }
                next
            }
            /^[a-zA-Z_][a-zA-Z0-9_]* *\(\)/ {
                if (d < 1 || d > 2) { print FILENAME":"FNR": " $1 " missing short description (1 to 2 lines)"; bad=1 }
                if (u != 1) { print FILENAME":"FNR": " $1 " must have exactly 1 usage or call line"; bad=1 }
                b=0; d=0; u=0
                next
            }
            { b=0; d=0; u=0 }
            END { if (bad) exit 0; else exit 1 }
        ' $__files; then
            _error "each function must have a short description (1 to 2 lines) and exactly 1 usage or call line" ; _func_end "1" ; return 1
        fi
        if $GREP --line-number -E "(^|[^_a-zA-Z0-9])_error([[:space:]]|$)" $__files | $GREP -v "return" | $GREP -v "exit" | $GREP -v "no _shellcheck" | $GREP -v -E "^([^:]*:)?[0-9]*:[[:space:]]*#"; then
            _error "_error must be followed by return or exit >0" ; _func_end "1" ; return 1
        fi
        if $GREP --line-number -E "(^|[|;&()[:space:]])grep([[:space:]]|$)" $__files | $GREP -v -E "^([^:]*:)?[0-9]*:[[:space:]]*#"; then
            _error "grep is not allowed, use \$GREP instead" ; _func_end "1" ; return 1
        fi
        if $GREP --line-number -E "(^|[^_a-zA-Z0-9])_func_end([[:space:]][^_(]|$)" $__files | $GREP -v '_func_end "' | $GREP -v "no _shellcheck" | $GREP -v -E "^([^:]*:)?[0-9]*:[[:space:]]*#" ; then
            _error "_func_end must have an arg then followed by return" ; _func_end "1" ; return 1
        fi
        if $GREP --line-number -E "(^|[^_a-zA-Z0-9])_func_end([[:space:]][^_(]|$)" $__files | $GREP -v "return" | $GREP -v "exit" | $GREP -v "no _shellcheck" | $GREP -v -E "^([^:]*:)?[0-9]*:[[:space:]]*#" ; then
            _error "_func_end must be followed by return" ; _func_end "1" ; return 1
        fi
        if $GREP --line-number "_func_end \"1\"" $__files | $GREP -v "_error" | $GREP -v "no _shellcheck" | $GREP -v -E "^([^:]*:)?[0-9]*:[[:space:]]*#" ; then
            _error "must have an _error message if we return 1" ; _func_end "1" ; return 1
        fi
        if awk '
            FNR == 1 && NR > 1 { analyze(prev_file); delete lines; line_count = 0 }
            { lines[++line_count] = $0; prev_file = FILENAME }
            function analyze(fname,   i, j, close_lines) {
                for (i = 1; i <= line_count; i++) {
                    if (lines[i] ~ /^[[:space:]]*\}/) {
                        j = i + 1
                        while (j <= line_count && (lines[j] ~ /^[[:space:]]*$/ || lines[j] ~ /^[[:space:]]*#/)) { j++ }
                        if (j > line_count || lines[j] ~ /^[a-zA-Z_][a-zA-Z0-9_]* *\(\)/) { close_lines[i] = 1 }
                    }
                }
                for (i = 1; i <= line_count; i++) {
                    if (lines[i] ~ /return 0/ && lines[i] !~ /return 1/ && lines[i] !~ /no _shellcheck/ && lines[i] !~ /^[[:space:]]*#/ && !close_lines[i+1]) {
                        print fname":"i": " lines[i]; found = 1
                    }
                }
            }
            END { if (line_count > 0) analyze(prev_file); if (found) exit 0; else exit 1 }
        ' $__files; then
            _error "returning 0 is may be a bad idea" ; _func_end "1" ; return 1
        fi
        if $GREP --line-number -E "(^|[|;&()[:space:]])curl([[:space:]]|$)" $__files | $GREP -v "_curl" | $GREP -v "no _shellcheck" | $GREP -v -E "^([^:]*:)?[0-9]*:[[:space:]]*#"; then
            _error "do not use curl but _curl instead" ; _func_end "1" ; return 1
        fi
        if $GREP --line-number -E "docker[[:space:]]" $__files | $GREP "|" | $GREP -v "no _shellcheck" | $GREP -v -E "^([^:]*:)?[0-9]*:[[:space:]]*#" ; then
            _error "can't test docker return is used with a pipe" ; _func_end "1" ; return 1
        fi
        if $GREP --line-number -w "\$?" $__files | $GREP -v "_error" | $GREP -v "break" | $GREP -v "case" | $GREP -v "=\$?" | $GREP -v "no _shellcheck" | $GREP -v -E "^([^:]*:)?[0-9]*:[[:space:]]*#" ; then
            _error "we must test \$? and have _error if smth goes wrong" ; _func_end "1" ; return 1
        fi
        if awk '
            /^[a-zA-Z_][a-zA-Z0-9_]* *\(\)/ { fname=$0; sub(/ *\(\).*/,"",fname); gsub(/^_/,"",fname) }
            /_func_start/ && $0 !~ /^[[:space:]]*#/ { instrumented[fname]=1 }
            /(^|[^_"a-zA-Z0-9])return([^_"a-zA-Z0-9]|$)/ && !/_func_end/ && !/no _shellcheck/ && $0 !~ /^[[:space:]]*#/ && fname != "" && instrumented[fname] { print FILENAME":"FNR": "$0; found=1 }
            END { if (!found) exit 1 }
        ' $__files; then
            _error "_func_end missing before return (stack-balance rule)" ; _func_end "1" ; return 1
        fi
        echo "no error found with shellcheck in $__files";
    else
        _error "something went wrong with shellcheck"; _func_end "1" ; return 1
    fi
}

# call: _bats ()
# description: Runs the BATS test suite of the library.
_bats () {
    _func_start "$@"

    # Check argv
    if ! _exist "$LIB"; then _error "no LIB found"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi

    if _exist "$LIB" && ! _fileexist "$MY_GIT_DIR/$LIB/lib_$LIB.sh"; then _error "lib file not found" ;  _usage; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi

    if _installed "bats"; then
        cd "$MY_GIT_DIR/$LIB" || { _error "cannot cd to $MY_GIT_DIR/$LIB"; _func_end "1" ; return 1 ; }
        if bats --verbose-run "$MY_GIT_DIR/$LIB/bats/tests.bats" ; then # --show-output-of-passing-tests
            _verbose "no error found"; cd - > /dev/null || { _error "cannot cd back"; _func_end "1" ; return 1 ; } ; _func_end "0" ; return 0
        else
            _error "something went wrong with bats"; cd - || { _error "cannot cd back"; _func_end "1" ; return 1 ; } ; _func_end "1" ; return 1
        fi
    else
        _error "bats not found" ; _func_end "1" ; return 1
    fi
}

# call: _kcov ($1:mode)
# description: Measures test coverage with kcov and uploads it to codecov.
_kcov () {
    _func_start "$@"

    # Check argv
    if ! _exist "$LIB"; then _error "no LIB found"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _installed "kcov"; then _error "kcov not found"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _installed "jq"; then _error "jq not found"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi

    local __tmp
    local __upload=true
    local __keep=false

    if _exist "$1" && [ "$1" = "AI" ]; then __keep=true ; fi

    if ! _installed "codecov"; then _warning "codecov not found, no uploading"; __upload=false ; fi
    if ! _exist "$CODECOV_TOKEN"; then _warning "no CODECOV_TOKEN found, no uploading"; __upload=false ; fi
    if ! _exist "$GITHUB_USERNAME"; then _warning "no GITHUB_USERNAME found, no uploading"; __upload=false ; fi

    if ! __tmp=$(_tmp_file) ; then _error "something went wrong in _tmp_file"; _func_end "1" ; return 1 ; fi

    _debug "tmp dir:$__tmp"

    if ! $DRY_RUN ; then
        kcov --exclude-path="$MY_GIT_DIR/$LIB/.git/,$MY_GIT_DIR/$LIB/README.md,$MY_GIT_DIR/$LIB/ToDo.md,$MY_GIT_DIR/$LIB/functions.md,$MY_GIT_DIR/$LIB/AGENTS.md,/usr/,$MY_GIT_DIR/$LIB/.codecov.yml,$MY_GIT_DIR/$LIB/.pre-commit-config.yaml" --include-path="$MY_GIT_DIR/$LIB" "$__tmp" "$MY_GIT_DIR/shell/my_warp.sh" --lib "$LIB" -b 1>/dev/null 2>/dev/null

        jq -r ".files | .[]" "$__tmp/my_warp.sh/coverage.json" | jq -r '"coverage: " + .file + " " + .percent_covered + "%"' | while IFS= read -r __line
        do
            _info "$__line"
        done

        if $__upload ; then
            codecov --codecov-yml-path .codecov.yml upload-coverage --report-type coverage --git-service github -r "$GITHUB_USERNAME/$LIB" -t "$CODECOV_TOKEN" --file "$__tmp/my_warp.sh/cobertura.xml"
        fi

        if $__keep ; then
            _info "kcov report kept at:$__tmp/my_warp.sh/cobertura.xml"
            while IFS= read -r __line ; do
                _info "uncovered lines: $__line"
            done < <(_kcov_resume "$__tmp/my_warp.sh")
        else
            rm -rf "$__tmp"
        fi

    else
        _debug "doing nothing in dry run"
    fi

    _func_end "0" ; return 0 # TODO check codecov return
}

# call: _kcov_resume ($1:dir)
# description: Lists the uncovered lines from a kcov report.
_kcov_resume () {
    _func_start "$@"

    # Check argv
    if ! _exist "$1"; then _error "DIR EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _fileexist "$1"; then _error "DIR NOT FOUND"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi

    local __dir="$1"
    local __file
    local __cobertura
    local __lines

    _debug "resume dir:$__dir"

    __cobertura=$(find -L "$__dir" -name "cobertura.xml" | head -n 1)

    if ! _exist "$__cobertura"; then _error "cobertura.xml not found"; _func_end "1" ; return 1 ; fi

    awk -F'"' '/<class / && /filename=/ { print $4 }' "$__cobertura" | sort -u | while IFS= read -r __file; do
        __lines=$(awk -v file="$__file" '/<class / { in_class = ($0 ~ "filename=\"" file "\"") } in_class && /hits="0"/ { if (match($0, /number="[0-9]+"/)) print substr($0, RSTART + 8, RLENGTH - 9) }' "$__cobertura" | paste -sd ',' -)
        echo "$(basename "$__file"):$__lines"
    done

    _func_end "0" ; return 0
}

####################################################################################################
############################################ DISPLAY ###############################################
####################################################################################################
# call: _showU8Variation ($1:selector) ($2:codepoint)
# description: Shows how UTF-8 characters look in the terminal.
_showU8Variation () { # no telemetry (display helper)
    #_showU8Variation 1 26 show in right table how char looks like in term
    local __i __a __f __e __t

    # Check argv
    if ! _exist "$1"; then _error "VARIATION SELECTOR EMPTY" ; return 1 ; fi
    if ! _is_numeric "$1"; then _error "VARIATION SELECTOR not numeric" ; return 1 ; fi
    if [ "$1" -lt 1 ] || [ "$1" -gt 256 ]; then _error "VARIATION SELECTOR must be between 1 and 256" ; return 1 ; fi

    printf -v __t '%31s' ''
    __t=${__t// /-}
    printf -v __t '%s    %s  %s\n' "${__t::6}" "$__t"{,}
    printf -v __f '%%%ds%%%%b\\\\r' {40..10..-2}
    printf -v __f "$__f"
    __f=${__f// /$'\UA0'}
    printf -v __e '%%%%%%ds%%%%%%%%b\\\\U%X\\\\\\\\r' \
        $(( $1 > 16 ? $1 + 917743 : $1 + 65023 ))
    printf -v __e "$__e" {73..43..-2}
    printf -v __e "$__e"

    printf 'Show UTF8 table using: VARIATION SELECTOR-%d (U+%X)\n' "$1" \
        $(( $1 > 16 ? $1 + 917743 : $1 + 65023 ))
    shift
    if ! _exist "$1"; then
        _info "no hex code point given, defaulting to 26 (U+2600 Miscellaneous Symbols)"
        set -- 26
    fi
    for __a; do
        printf "$__e${__f}U%03Xyx\n%s" {,}{{F..A..-1},{9..0..-1}} 0x"${__a}" "$__t"
        for __i in {0..9} {A..F}; do
            (( 16#$__a == 0 )) && (( ( 16#$__i & 7 )  < 2 )) &&
            printf 'U%04Xx%68s\n' 0x"$__a$__i" '' && continue
            printf "$__e${__f}U%04Xx\n" \
               "\\U$__a$__i"{,}{{F..A..-1},{9..0..-1}} 0x"$__a$__i"
        done
    done
}

# call: _show_color_code ($1:label)
# description: Displays the terminal color codes.
_show_color_code () {
    local __mode
    local __bg
    local __color

    local __black=30
    local __red=31
    local __green=32
    local __yellow=33
    local __blue=34
    local __magenta=35
    local __cyan=36
    local __light_gray=37
    local __gray=90
    local __light_red=91
    local __light_green=92
    local __light_yellow=93
    local __light_blue=94
    local __light_magenta=95
    local __light_cyan=96
    local __whithe=97

    local __bg_black=40
    local __bg_red=41
    local __bg_green=42
    local __bg_yellow=43
    local __bg_blue=44
    local __bg_magenta=45
    local __bg_cyan=46
    local __bg_gray=47
    local __bg_light_gray=100
    local __bg_light_red=101
    local __bg_light_green=102
    local __bg_light_yellow=103
    local __bg_light_blue=104
    local __bg_light_magenta=105
    local __bg_light_cyan=106
    local __bg_whithe=107

    local __normal=0
    local __bold=1
    local __dim=2
    local __italic=3
    local __underline=4
    local __blink=5
    local __reverse=7
    local __invisible=8
    local __strikethrough=9
    local __dounle_underline=21
    local __moverline=53

    for __bg in $__normal $__bg_black $__bg_red $__bg_light_red $__bg_green $__bg_light_green $__bg_yellow $__bg_light_yellow $__bg_blue $__bg_light_blue $__bg_magenta $__bg_light_magenta $__bg_cyan $__bg_light_cyan $__bg_gray $__bg_light_gray $__bg_whithe ; do
        echo
        echo "bg color code : $__bg"
        printf 'normal\t\tbold\t\tdim\t\titalic\t\tunderline\t2 underline\tinvisible\tstrikethrough\tmoverline\tblink\t\treverse\n'
        for __color in $__black $__red $__light_red $__green $__light_green $__yellow $__light_yellow $__blue $__light_blue $__magenta $__light_magenta $__cyan $__light_cyan $__gray $__whithe; do
            for __mode in $__normal $__bold $__dim $__italic $__underline $__dounle_underline $__invisible $__strikethrough $__moverline $__blink $__reverse; do
                if [ "a$1" = "a" ] ; then
                    printf '\e[%d;%d;%dm%-12s\e[0m' "$__bg" "$__mode" "$__color" "$(printf ' \\e[%d;%d;%dm]' "$__bg" "$__mode" "$__color")" && printf '\t'
                else
                    printf '\e[%d;%d;%dm%-12s\e[0m' "$__bg" "$__mode" "$__color" "$(printf "$1")" && printf '\t'
                fi
            done
            printf '\n'
        done
    done
}

####################################################################################################
########################################### HELL WORLD #############################################
####################################################################################################
# usage: _hello_world
# description: Demo command that prints Hello world.
_hello_world () {
    _func_start "$@"

    echo "Hello world"

    _success "Hello world"
    _verbose "Hello world"
    _info "Hello world"
    _warning "Hello world"
    _error "Hello world" # no _shellcheck

    _func_end "0" ; return 0
}


####################################################################################################
############################################# PROCESS ##############################################
####################################################################################################
# call: _process_lib_shell ($@:args)
# description: Routes the orchestrator calls to the shell lib commands.
_process_lib_shell () {
    _func_start "$@"

    eval set -- "$@"

    local __method
    local __url
    local __header
    local __header_data
    local __data
    local __return

    while true; do
        case "$1" in
            --method )         __method=$2       ; shift ; shift         ;;
            --url )            __url=$2          ; shift ; shift         ;;
            --header )         __header=$2       ; shift ; shift         ;;
            --header-data )    __header_data=$2  ; shift ; shift         ;;
            --data )           __data=$2         ; shift ; shift         ;;
            -- )                                   break ;;
            *)                                     shift                 ;;
        esac
    done

    while true ; do
        case "$1" in
            hello_world)       _hello_world                                                      ; __return=$? ; break ;;
            curl)              _curl "$__method" "$__url" "$__header" "$__header_data" "$__data" ; __return=$? ; break ;;
            -- ) shift ;;
            *) _error "command $1 not found" ; __return=1 ; break ;;
        esac
    done

    _func_end "$__return" ; return "$__return"
}
