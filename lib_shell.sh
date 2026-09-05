#!/bin/bash

# shellcheck source=/dev/null disable=SC2119,SC2120,SC2294,SC2001,SC2045,SC2184,SC2059,SC2034

# doc-top: > **General conventions**
# doc-top: > - Functions whose name starts with a single underscore (e.g. `_info`) are library functions.
# doc-top: > - Functions ending with `() {` and implementing telemetry call `_func_start` / `_func_end`; the telemetry functions themselves (`_func_start`, `_func_end`, `_log`, `_verbose_func_space`) do not for recursion reasons.
# doc-top: > - Many helpers accept their input either as arguments or via stdin (piped). When no argument is given, stdin is used.
# doc-top: > - Exit code `0` means success, non-zero means failure 
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
# doc-section: Logger & Output Helpers
# doc-order: 1
# description: Prints a message to standard error (stderr), with `echo -e` so escape sequences are interpreted.
# example: `_echoerr "message"`
# example: `_echoerr $@`
# return-inline: Always `0` (exit status of `echo`).
_echoerr() {
    echo -e "$@" >&2
}

# call: _verbose_func_space ()
# doc-section: Logger & Output Helpers
# doc-order: 2
# description: Builds the global `VERBOSE_SPACE` string by concatenating the function names stored in `FUNC_LIST`, producing an indentation/trace prefix like ` func1 > func2 >`.
# example: `_verbose_func_space` (no arguments; relies on the global `FUNC_LIST` array)
# return-inline: Always `0`. Sets the global variable `VERBOSE_SPACE`.
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
# doc-section: Logger & Output Helpers
# doc-order: 3
# description: Telemetry hook called at the entry point of every instrumented library function. Records the caller's name and a start timestamp (seconds.nanoseconds) into the global `FUNC_LIST` array. When `DEBUG` is enabled, logs the start and, if `VERBOSE` is enabled, logs each argument (`$1`, `$2`, ...) or `no args`.
# example: `_func_start "$@"` (pass through the calling function's arguments)
# return-inline: Always `0`. Side effect: appends `caller:start_time` to `FUNC_LIST`, sets `VERBOSE_SPACE`.
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
# doc-section: Logger & Output Helpers
# doc-order: 4
# description: Telemetry hook called before returning from an instrumented function. Pops the last entry from `FUNC_LIST`, computes the elapsed duration in nanoseconds via `_timediff`, and, when `DEBUG` is enabled, logs an `End` (or `End - returning:<code> - in <duration>ns`) message.
# example: `_func_end` — plain end
# example: `_func_end "0"` — end reporting a return code, e.g. `_func_end "$return_code"`
# return-inline: Always `0`. Side effect: removes the last element of `FUNC_LIST`.
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
# doc-section: Logger & Output Helpers
# doc-order: 5
# description: Logs a message at the **ERROR** level with a red ✗ check prefix.
# example: `_error "message"`
# return-inline: Always `0` (relies on `_log`).
_error() {
    _log "ERROR  " "\033[0;31m" "$CHECK_KO $*"
}

# call: _warning ($1:msg)
# doc-section: Logger & Output Helpers
# doc-order: 6
# description: Logs a message at the **WARNING** level with a yellow ▲ prefix.
# example: `_warning "message"`
# return-inline: Always `0`.
_warning() {
    _log "WARNING" "\033[0;33m" "$CHECK_WARN $*"
}

# call: _success ($1:msg)
# doc-section: Logger & Output Helpers
# doc-order: 7
# description: Logs a message at the **SUCCESS** level with a green ✓ prefix.
# example: `_success "message"`
# return-inline: Always `0`.
_success() {
    _log "SUCCESS" "\033[0;32m" "$CHECK_SUCCESS $*"
}

# call: _info ($1:msg)
# doc-section: Logger & Output Helpers
# doc-order: 8
# description: Logs a message at the **INFO** level with a blue ★ prefix.
# example: `_info "message"`
# return-inline: Always `0`.
_info() {
    _log "INFO   " "\033[0;34m" "$CHECK_INFO $*"
}

# call: _debug ($1:msg)
# doc-section: Logger & Output Helpers
# doc-order: 9
# description: Logs a message at the **DEBUG** level (no colored prefix). Output is suppressed unless the global `DEBUG` variable is `true`.
# example: `_debug "message"`
# return-inline: Always `0`.
_debug() {
    _log "DEBUG  " "" "$*"
}

# call: _verbose ($1:msg)
# doc-section: Logger & Output Helpers
# doc-order: 10
# description: Logs a message at the **VERBOSE** level (no colored prefix). Output is suppressed unless the global `VERBOSE` variable is `true`.
# example: `_verbose "message"`
# return-inline: Always `0`.
_verbose() {
    _log "VERBOSE" "" "$*"
}

# call: _verbose_file ($1:file)
# doc-section: Logger & Output Helpers
# doc-order: 11
# description: Dumps the content of a file to stderr between `--- dump file start ---` / `--- dump file end ---` markers. The markers are always logged at VERBOSE level; the actual file content is only printed when `$VERBOSE` is `true`.
# example: `_verbose_file "/path/to/file"`
# example: `$1` — path of the file to dump
# return: `0` — file exists (dumped when `VERBOSE=true`)
# return: `1` — file does not exist (logs `can verbose $1, not exist`)
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
# doc-section: Logger & Output Helpers
# doc-order: 12
# description: Core logger used by `_error`, `_warning`, `_success`, `_info`, `_debug`, `_verbose`. Formats the message with level, color, date, and function trace (`VERBOSE_SPACE`), and prints to stderr. Suppresses DEBUG/VERBOSE messages when the corresponding flags are off.
# example: `_log "<level>" "<color-ansi>" "<message>"`
# param: `$1` — level string, e.g. `ERROR  `, `WARNING`, `INFO   `
# param: `$2` — ANSI color code, e.g. `\033[0;31m`
# param: `$3` — message
# return-inline: Always `0`.
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
# doc-section: Validation Primitives
# doc-order: 13
# description: Checks whether the first argument is a non-empty string (presence check).
# example: `_exist "$var"` — true if `$var` is non-empty
# return: `0` — argument is non-empty
# return: `1` — argument is empty/not present
_exist () {
    if [[ -z "$1" ]] ; then return 1; else return 0; fi
}

# call: _fileexist ($1:file)
# doc-section: Validation Primitives
# doc-order: 14
# description: Checks whether the file or path given as `$1` exists on disk.
# example: `_fileexist "/path/to/file"`
# return: `0` — path exists
# return: `1` — path does not exist
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
# doc-section: Validation Primitives
# doc-order: 15
# description: Same existence check as `_fileexist` but designed for NFS/remote files: it uses `timeout 1 stat -t "$1"` so a hanging filesystem answers within 1 second instead of blocking.
# example: `_remotefileexist "/path/to/remote/file"`
# example: `$1` — path to check
# return: `0` — path exists (stat returned `0`)
# return: `1` — path does not exist, or the check timed out after 1 second (stat returned `124`)
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
# doc-section: Validation Primitives
# doc-order: 16
# description: Checks whether a shell function with the given name is defined.
# example: `_func_exist "_func_exist"`
# example: `$1` — function name to look up
# return: `0` — a function with that name exists (`type -t` returns `function`)
# return: `1` — no such function (or `$1` empty)
_func_exist() {
  [ "$(type -t "$1")" == 'function' ]
}

# call: _installed ($1:binary)
# doc-section: Validation Primitives
# doc-order: 17
# description: Checks whether a command/binary is available in `PATH`.
# example: `_installed "curl"`
# return: `0` — command found
# return: `1` — command not found
_installed () {
    if type "$1" 2> /dev/null 1>/dev/null ; then return 0; else return 1; fi
}

# call: _working_dir ()
# doc-section: Working Directory Helpers
# doc-order: 18
# description: Prints the basename of the current working directory.
# example: `_working_dir` (no arguments)
# return-inline: Always `0`. Outputs the directory basename on stdout.
_working_dir () {
    basename "$PWD"
}

# call: _working_dir_count_file ($1:pattern)
# doc-section: Working Directory Helpers
# doc-order: 19
# description: Counts files in the current directory (depth 1). With an argument, counts only files matching the given name pattern.
# example: `_working_dir_count_file` — count all files
# example: `_working_dir_count_file "*.conf"` — count files matching pattern
# return-inline: Always `0`. Outputs the file count on stdout.
_working_dir_count_file () {
    if _exist "$1" ; then
        find "." -maxdepth 1 -type f -name "$@" | wc -l | xargs
    else
        find "." -maxdepth 1 -type f | wc -l | xargs
    fi
}

# call: _working_dir_count_dir ($1:pattern)
# doc-section: Working Directory Helpers
# doc-order: 20
# description: Counts directories in the current directory (depth 1). With an argument, counts only directories matching the given name pattern.
# example: `_working_dir_count_dir` — count all directories
# example: `_working_dir_count_dir "build*"` — count directories matching pattern
# return-inline: Always `0`. Outputs the directory count on stdout.
_working_dir_count_dir () {
    if _exist "$1" ; then
        find "." -maxdepth 1 -type d -name "$@" | $GREP "./" | wc -l | xargs
    else
        find "." -maxdepth 1 -type d | $GREP "./" | wc -l | xargs
    fi
}

# call: _working_dir_list_dir_by_creation_date ()
# doc-section: Working Directory Helpers
# doc-order: 21
# description: Lists directories in the current directory (depth 1) sorted by their creation date.
# example: `_working_dir_list_dir_by_creation_date` (no arguments)
# return-inline: Always `0`. Outputs one directory path per line, sorted by creation time.
_working_dir_list_dir_by_creation_date () {
    # shellcheck disable=1001
    find "." -maxdepth 1 -type d -exec stat --format="%w %n" {} + | sort -n | $GREP "/" | cut -d\/ -f2-42
}

# call: _tmp_file ()
# doc-section: Temporary Files & Random Generation
# doc-order: 22
# description: Prints a pseudo-random temporary file path under `/tmp` based on the current script name and the calling function name.
# example: `_tmp_file` (no arguments; must be called from inside a function)
# return: `0` — success; prints the temp path on stdout
# return: `1` — called outside a function (logs `we'r not in a function, weird`)
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
# doc-section: Process Options & Orchestrator Helpers
# doc-order: 26
# description: Parses the command-line arguments with `getopt` (short options from `_getopt_short`, long options from `_getopt_long`), sets the matching global flags (`VERBOSE`, `DEBUG`, `DRY_RUN`, `DEFAULT`, `FORCE`, `YUBIKEY`, `LIB`, `ACTION`), and dispatches the `--help`, `--list-libs`, `--bats`, `--shellcheck`, and `--kcov` actions.
# example: `_process_opts "$@"`
# return: `0` — options parsed and the requested action succeeded
# return: `1` — bad/missing argument, or one of the dispatched actions failed
# doc-intro: > These functions implement the orchestrator's CLI parsing, usage display, and library loading. They rely on the runtime globals `$MY_GIT_DIR`, `$LIB`, `$CUR_NAME`, `$OPTS`, and the per-lib `GETOPT_SHORT_<LIB>` variables set up by `my_warp.sh`.
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
    local __doc=false

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
                --doc )              __doc=true          ; export ACTION=true ; shift ;;
                --list-libs )        __list_libs=true    ; export ACTION=true ; shift ;;

                -- )             shift ; break ;;
                *)               shift ;;
            esac
        done
    fi

    if $__help ; then
        _usage ; __return=$?
    else
        if $__list_libs  ; then if ! _get_installed_libs  ; then _error "something went wrong when listing installed libs" ; _func_end "1" ; return 1 ;fi ; fi
        if $__bats       ; then if ! _bats "$@"           ; then _error "something went wrong in bats" ; _func_end "1" ; return 1 ;fi ; fi
        if $__shellcheck ; then if ! _shellcheck "$@"     ; then _error "something went wrong in shellcheck" ; _func_end "1" ; return 1 ;fi ; fi
        if $__kcov       ; then if ! _kcov "$@"           ; then _error "something went wrong in kcov" ; _func_end "1" ; return 1 ;fi ; fi
        if $__doc        ; then if ! _doc "$@"            ; then _error "something went wrong in doc" ; _func_end "1" ; return 1 ;fi ; fi
    fi

    _func_end "$__return" ; return $__return
}

# call: _getopt_short ()
# doc-section: Process Options & Orchestrator Helpers
# doc-order: 27
# description: Builds the short option string for `getopt` by concatenating the `GETOPT_SHORT_<LIB>` variable of every installed library (e.g. `GETOPT_SHORT_SHELL=h,v,d,b,s,k`), joined with commas.
# example: `_getopt_short` (no arguments; requires `MY_GIT_DIR` and `_get_installed_libs`)
# return-inline: Always `0`. Outputs the short option list on stdout (e.g. `h,v,d,b,s,k`).
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
# doc-section: Process Options & Orchestrator Helpers
# doc-order: 28
# description: Builds the long option string for `getopt` from the `# usage` comment lines of every installed library plus the built-in options (`debug,verbose,help,list-libs,bats,shellcheck,kcov,dry-run,default,force,yubikey`, the `lib:` placeholder, and each library name).
# example: `_getopt_long` (no arguments; requires `MY_GIT_DIR` and `_get_installed_libs`)
# return-inline: Always `0`. Outputs the long option list on stdout.
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

    echo -n "debug,verbose,help,list-libs,bats,shellcheck,kcov,doc,dry-run,default,force,yubikey,$__result""lib:" | sed -e 's/ /:,/g'

    _func_end "0" ; return 0
}

####################################################################################################
############################################## USAGES ##############################################
####################################################################################################
# call: _usage ()
# doc-section: Process Options & Orchestrator Helpers
# doc-order: 29
# description: Prints the orchestrator usage. Without `$LIB`, prints the generic help; with `$LIB` set, calls the optional `_usage_$LIB` function and lists every `# usage` line of the library as `$CUR_NAME --lib $LIB <command>`.
# example: `_usage`
# example: `_usage` with `$LIB` set (e.g. via `./my_warp.sh --lib shell -h`)
# return: `0` — usage displayed
# return: `1` — `$LIB` is set but `$MY_GIT_DIR/$LIB/lib_$LIB.sh` does not exist (`No such LIB`)
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
        echo "  * Bats subset (regex filter)         => $CUR_NAME -b --lib lib_name '<regex>'"
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
# doc-section: Process Options & Orchestrator Helpers
# doc-order: 30
# description: Sources `lib_shell.sh` (itself) and then every installed library `$MY_GIT_DIR/<lib>/lib_<lib>.sh` found by `_get_installed_libs`.
# example: `_load_libs` (no arguments; requires `MY_GIT_DIR`)
# return-inline: Always `0` (unless a `source` fails). Not telemetry-instrumented.
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
# doc-section: Process Options & Orchestrator Helpers
# doc-order: 31
# description: Sources a single library `$MY_GIT_DIR/$1/lib_$1.sh`.
# example: `_load_lib "shell"`
# example: `$1` — library name
# return: `0` — library sourced successfully
# return: `10` (`ERROR_ARGV`) — `$1` empty (`LIB EMPTY`) or `$MY_GIT_DIR/$1/lib_$1.sh` does not exist
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
# doc-section: Process Options & Orchestrator Helpers
# doc-order: 32
# description: Sources a configuration file. If a `my_<basename>` variant exists next to it (e.g. `my_my_warp.conf`), that one is sourced instead of the original.
# example: `_load_conf "/path/to/conf/file"`
# example: `$1` — path of the configuration file
# return: `0` — configuration sourced
# return: `10` (`ERROR_ARGV`) — `$1` empty (`CONF EMPTY`) or the file does not exist
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
# doc-section: Process Options & Orchestrator Helpers
# doc-order: 33
# description: Lists the names of all installed libraries, i.e. every directory under `$MY_GIT_DIR` that contains a matching `lib_<dir>.sh` file.
# example: `_get_installed_libs` (no arguments; requires `MY_GIT_DIR`)
# return-inline: Always `0`. Outputs the space-separated list of library names on stdout (trailing space removed).
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
# doc-section: Temporary Files & Random Generation
# doc-order: 23
# description: Generates a random alphanumeric string (uppercase letters and digits, excluding `I`, `O`, `S`) from `/dev/urandom`.
# example: `_gen_rand` — default: blocks of `4`, separator `-`, max `29` chars
# example: `_gen_rand 8` — 8-char blocks
# example: `_gen_rand 8 "."` — 8-char blocks joined with `.`
# example: `_gen_rand 8 "." 12` — truncated to 12 chars
# example: `$1` — block width (default `4`)
# example: `$2` — block separator (default `-`)
# example: `$3` — maximum output length (default `29`)
# return-inline: Always `0`. Outputs the random string on stdout.
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
# doc-section: Temporary Files & Random Generation
# doc-order: 24
# description: Generates a random numeric PIN from `/dev/urandom`.
# example: `_gen_pin` — default length `6`
# example: `_gen_pin 8` — 8-digit PIN
# example: `$1` — length (default `6`)
# return-inline: Always `0`. Outputs the PIN on stdout.
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
# doc-section: Temporary Files & Random Generation
# doc-order: 25
# description: Generates a UUID using the `uuidgen` command.
# example: `_gen_uuid` (no arguments; requires `uuidgen` installed)
# return: `0` — success; outputs the UUID on stdout
# return: `10` (`ERROR_ARGV`) — `uuidgen` not installed
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
# doc-section: Time Management
# doc-order: 34
# description: Prints the current local date/time formatted as `YYYY-MM-DD HH:MM:SS`.
# example: `_date` (no arguments)
# return-inline: Always `0`. Outputs the date string on stdout.
_date () {
    printf '%(%Y-%m-%d %H:%M:%S)T\n' -1
}

# call: _iso_date ()
# doc-section: Time Management
# doc-order: 35
# description: Prints the current UTC date/time in ISO 8601 format with milliseconds (`YYYY-MM-DDTHH:MM:SS.mmmZ`).
# example: `_iso_date` (no arguments)
# return-inline: Always `0`. Outputs the ISO date string on stdout.
_iso_date () {
    date -u +"%Y-%m-%dT%H:%M:%S.%3NZ"
}

# call: _timediff ($1:start) ($2:end)
# doc-section: Time Management
# doc-order: 36
# description: Computes the duration between two timestamps in `seconds.nanoseconds` format and prints it as `<seconds>s<nanoseconds>` with full nanosecond precision (no rounding), e.g. `12s345678901`.
# example: `_timediff "start" "end"`
# param: `$1` — start timestamp, e.g. `1712345678.123456789`
# param: `$2` — end timestamp, same format
# return: `0` — success; outputs the duration on stdout
# return: `1` — start or end time empty, or either timestamp not in `seconds.nanoseconds` format (`invalid timestamp, expected seconds.nanoseconds`)
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
# doc-section: Time Management
# doc-order: 37
# description: Converts an epoch timestamp (milliseconds) to a UTC date string `YYYY-MM-DD HH:MM:SS`. The input must be a non-empty numeric string of at least 4 digits (e.g. `1000` → `1970-01-01 00:00:01`).
# example: `_epoch_2_date "1712345678123"` (epoch in milliseconds)
# return: `0` — success; outputs the UTC date on stdout
# return: `1` — argument empty (`DATE EMPTY`), non-numeric input (`epoch not numeric`), or input shorter than 4 digits (`epoch too short`)
_epoch_2_date () {
# always return UTC date
    if ! _exist "$1"; then _error "DATE EMPTY"; return 1 ; fi
    if ! _is_numeric "$1"; then _error "epoch not numeric"; return 1 ; fi
    if [ "${#1}" -lt 4 ]; then _error "epoch too short"; return 1 ; fi

    date -u -d "@${1%???}.${1: -3}" +"%Y-%m-%d %H:%M:%S"
}

# call: _date_2_epoch ($1:date)
# doc-section: Time Management
# doc-order: 38
# description: Converts a date string to a UTC epoch timestamp in **milliseconds** (`%s%3N`).
# example: `_date_2_epoch "2024-04-05 12:34:56"`
# return: `0` — success; outputs the epoch milliseconds on stdout
# return: `1` — argument empty
_date_2_epoch () {
# always return UTC epoch
    if ! _exist "$1"; then _error "DATE EMPTY"; return 1 ; fi

    date -d "$1" +"%s%3N"
}

####################################################################################################
######################################## ARRAY MANAGEMENT ##########################################
####################################################################################################
# call: _array_print ($1:array)
# doc-section: Array Management
# doc-order: 39
# description: Prints all elements of an array, one per line, prefixed with their index (`[0]:value`).
# example: `_array_print "my_array"` — `$1` is the array name
# return: `0` — success
# return: `1` — array name empty
# doc-intro: > Arrays are passed by **name** (nameref), not by value. They must exist in the caller's scope.
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
# doc-section: Array Management
# doc-order: 40
# description: Prints the element of an array at a given index.
# example: `_array_print_index "my_array" "2"` — `$1` array name, `$2` index
# return: `0` — success; outputs the element on stdout
# return: `1` — array name or index empty
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
# doc-section: Array Management
# doc-order: 41
# description: Appends an element to an array.
# example: `_array_add "my_array" "new_element"` — `$1` array name, `$2` element
# return: `0` — success
# return: `1` — array name or element empty
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
# doc-section: Array Management
# doc-order: 42
# description: Removes the last element of an array.
# example: `_array_remove_last "my_array"` — `$1` array name
# return: `0` — success
# return: `1` — array name empty
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
# doc-section: Array Management
# doc-order: 43
# description: Removes the element at a given index and re-indexes the array (holes are compacted).
# example: `_array_remove_index "my_array" "2"` — `$1` array name, `$2` index
# return: `0` — success
# return: `1` — array name or index empty
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
# doc-section: Array Management
# doc-order: 44
# description: Prints the number of elements in an array.
# example: `_array_count_elt "my_array"` — `$1` array name
# return: `0` — success; outputs the element count on stdout
# return: `1` — no argument given
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
# doc-section: YAML & JSON Management
# doc-order: 45
# description: Converts JSON input to YAML using `yq`.
# example: `_json_2_yaml "$json"`
# example: `echo "$json" | _json_2_yaml`
# return: `0` — success; outputs YAML on stdout
# return: `10` (`ERROR_ARGV`) — `yq` not installed
# return: `1` — unsupported `yq` version (needs v4) or `yq` conversion error
# doc-intro: > JSON helpers require `jq`; YAML helpers require `yq` (version 4). Unless stated otherwise, input is the JSON/YAML text (argument or stdin) and the converted output is printed on stdout.
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
# doc-section: YAML & JSON Management
# doc-order: 46
# description: Converts YAML input to JSON using `yq`.
# example: `_yaml_2_yaml "$yaml"`
# example: `echo "$yaml" | _yaml_2_json`
# return: `0` — success; outputs JSON on stdout
# return: `10` (`ERROR_ARGV`) — `yq` not installed
# return: `1` — unsupported `yq` version (needs v4) or `yq` conversion error
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
# doc-section: YAML & JSON Management
# doc-order: 47
# description: Adds a key/value pair into a JSON document at a given path. The value is inserted as a raw JSON literal (object, array, number, boolean, or quoted string), so `$4` must be valid JSON.
# example: `_json_add_key_with_value "$json" "path" "key" "value"`
# param: `$1` — JSON input
# param: `$2` — target path, e.g. `foo` or empty for root (keys are never prefixed with a leading dot)
# param: `$3` — key to add
# param: `$4` — value to set as a JSON literal, e.g. `{"a":1}`, `true`, `1`, or `"text"`
# return: `0` — success; outputs the modified JSON on stdout
# return: `10` (`ERROR_ARGV`) — missing JSON/key/value, or `jq` not installed
# return: `1` — `jq` processing error
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
# doc-section: YAML & JSON Management
# doc-order: 48
# description: Appends a value to an array inside a JSON document (creates the array path if needed).
# example: `_json_add_value_in_array "$json" "path" "array" "value"`
# param: `$1` — JSON input
# param: `$2` — optional parent path prefix (if empty, `$3` is used directly); keys are never prefixed with a leading dot
# param: `$3` — array key/path
# param: `$4` — value to append (string, or `{...}` JSON object)
# return: `0` — success; outputs the modified JSON on stdout
# return: `10` (`ERROR_ARGV`) — missing JSON/array/value, or `jq` not installed
# return: `1` — `jq` processing error
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
# doc-section: YAML & JSON Management
# doc-order: 49
# description: Removes a key (or path) from a JSON document.
# example: `_json_remove_key "$json" "foo.bar"`
# param: `$1` — JSON input
# param: `$2` — key/path to delete, e.g. `foo` (never prefixed with a leading dot)
# return: `0` — success; outputs the modified JSON on stdout
# return: `10` (`ERROR_ARGV`) — missing JSON/key, or `jq` not installed
# return: `1` — `jq` processing error
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
# doc-section: YAML & JSON Management
# doc-order: 50
# description: Replaces the value of an existing key in a JSON document.
# example: `_json_replace_key_with_value "$json" "foo" "new_value"`
# param: `$1` — JSON input
# param: `$2` — key/path whose value to replace (never prefixed with a leading dot)
# param: `$3` — new value (string)
# return: `0` — success; outputs the modified JSON on stdout
# return: `10` (`ERROR_ARGV`) — missing JSON/key/value, or `jq` not installed
# return: `1` — `jq` processing error
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
# doc-section: YAML & JSON Management
# doc-order: 51
# description: Extracts the value of a key (or path) from a JSON document and prints it without quotes (`jq -r`). The key is resolved via `getpath`, so keys containing special characters are supported.
# example: `_json_get_value_from_key "$json" "foo.bar"`
# param: `$1` — JSON input
# param: `$2` — key/path to read (never prefixed with a leading dot)
# return: `0` — key found and value not `null`; outputs the raw value on stdout (a JSON string equal to `"null"` is a valid value and returns `0`)
# return: `10` (`ERROR_ARGV`) — missing JSON/key, or `jq` not installed
# return: `1` — key resolves to JSON `null`/missing
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
# doc-section: YAML & JSON Management
# doc-order: 52
# description: Iterates the elements of an array at a given path and prints the value of a key for every matching element, one per line (`jq -r`). An optional `(match-key, match-value)` pair restricts the iteration to elements where `.[match-key] == match-value`; pass both empty to match all elements. The array path is resolved via `getpath`, so keys containing special characters are supported.
# example: `_json_get_value_from_array "$json" "content.sections" "dashboardId" "child-123" "name"` — prints the `name` of every section whose `dashboardId` equals `child-123`.
# example: `_json_get_value_from_array "$json" "content.sections" "" "" "name"` — prints the `name` of every section.
# param: `$1` — JSON input
# param: `$2` — array path to read (never prefixed with a leading dot)
# param: `$3` — match key (empty to match all)
# param: `$4` — match value (empty to match all)
# param: `$5` — key whose value is printed for each matching element
# return: `0` — success; outputs the key values on stdout (no output when the array is empty or no element matches)
# return: `10` (`ERROR_ARGV`) — missing JSON/array path/return key, or `jq` not installed
# return: `1` — `jq` processing error
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
# doc-section: String Management
# doc-order: 53
# description: Converts the input string to uppercase.
# example: `_upper "hello world"`
# example: `echo "hello world" | _upper`
# return-inline: Always `0`. Outputs the uppercased string on stdout.
# next 4 func can be use like _upper "hello word" or echo "hello world" | _upper
_upper() {
    local __input=${*:-$(</dev/stdin)}
    local LC_ALL=C

    printf '%s\n' "${__input^^}"
}

# call: _lower ($1:str)
# doc-section: String Management
# doc-order: 54
# description: Converts the input string to lowercase.
# example: `_lower "HELLO WORLD"`
# example: `echo "HELLO WORLD" | _lower`
# return-inline: Always `0`. Outputs the lowercased string on stdout.
_lower() {
    local __input=${*:-$(</dev/stdin)}
    local LC_ALL=C

    printf '%s\n' "${__input,,}"
}

# call: _remove_french ($1:str)
# doc-section: String Management
# doc-order: 55
# description: Removes all French accentuation from the input string, replacing each accented letter with its unaccented base letter (`è`/`È` → `e`/`E`, `à`/`À` → `a`/`A`, `ç`/`Ç` → `c`/`C`, ...). Covers `à â ä é è ê ë î ï ô ö ù û ü ÿ ç` and their uppercase forms. Non-accented characters (including ligatures like `œ`/`æ`) are left unchanged.
# example: `_remove_french "Crème Brûlée"`
# example: `echo "déjà vu" | _remove_french`
# return-inline: Always `0`. Outputs the accent-free string on stdout.
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
# doc-section: String Management
# doc-order: 56
# description: Removes the last character of the input string.
# example: `_remove_last_car "hello"`
# example: `echo "hello" | _remove_last_car`
# return-inline: Always `0`. Outputs the truncated string on stdout.
_remove_last_car() {
    local __input=${*:-$(</dev/stdin)}

    printf '%s\n' "${__input%?}"
}

# call: _is_ascii ($1:str)
# doc-section: String Management
# doc-order: 57
# description: Checks whether the given string contains only printable ASCII characters (0x20–0x7E).
# example: `_is_ascii "some-string"`
# return: `0` — string is printable ASCII
# return: `1` — string contains non-ASCII or non-printable characters
_is_ascii() {
    local LC_ALL=C

    [[ "$1" =~ ^[[:print:]]*$ ]]
}

# call: _is_numeric ($1:str)
# doc-section: String Management
# doc-order: 58
# description: Checks whether the given string contains only digits (0–9).
# example: `_is_numeric "123"`
# return: `0` — string is numeric
# return: `1` — string is empty or contains non-digit characters
_is_numeric() {
    local LC_ALL=C

    [[ "$1" =~ ^[0-9]+$ ]]
}

# call: _startswith ($1:str) ($2:substr)
# doc-section: String Management
# doc-order: 59
# description: Checks whether a string starts with a given prefix. Pure-bash implementation (no subprocess), so it works regardless of the current `IFS` setting.
# example: `_startswith "hello world" "hello"`
# param: `$1` — string to test
# param: `$2` — prefix to look for
# return: `0` — string starts with the prefix
# return: `1` — otherwise (or prefix not found)
_startswith() {
    local __str="$1"
    local __sub="$2"

    [[ "$__str" == "$__sub"* ]]
}

# call: _contains ($1:str) ($2:regex)
# doc-section: String Management
# doc-order: 60
# description: Checks whether the first string contains a substring or regex pattern given as `$2` (tested with `[[ $1 =~ $2 ]]`).
# example: `_contains "hello world" "world"`
# example: `$1` — string to search in
# example: `$2` — substring or extended regular expression to look for
# return: `0` — match found
# return: `1` — no match (or `$2` empty)
_contains () {
    if [[ $1 =~ $2 ]]; then return 0; else return 1; fi
}

####################################################################################################
############################################### GIT ################################################
####################################################################################################
# call: _git_upstream ($1:dir)
# doc-section: GIT
# doc-order: 61
# description: Echoes the upstream branch ref (e.g. `origin/main`) of the current branch in a git directory.
# example: `_git_upstream "/path/to/git/repo"`
# example: `$1` — directory of the git repository
# return: `0` — success; outputs the upstream ref on stdout
# return: `1` — no upstream configured for the branch, or not a git repository
# return: `10` (`ERROR_ARGV`) — argument empty (`DIR EMPTY`), or `git` not installed (`GIT: not found`)
_git_upstream () {
    _func_start "$@"

    # Check argv
    if ! _exist "$1"; then _error "DIR EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _installed "git"; then _error "GIT: not found"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi

    local __dir="$1"
    local __upstream
    local __return

    __upstream=$(git -C "$__dir" rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null)
    __return=$?
    if [ "$__return" -ne 0 ]; then _error "UPSTREAM: no upstream configured for branch in $__dir" ; _func_end "1" ; return 1 ; fi

    echo "$__upstream"

    _func_end "0" ; return 0
}

# call: _git_commits_ahead ($1:dir)
# doc-section: GIT
# doc-order: 62
# description: Echoes the number of commits the current branch is ahead of its upstream (`@{u}`..HEAD) in a git directory.
# example: `_git_commits_ahead "/path/to/git/repo"`
# example: `$1` — directory of the git repository
# return: `0` — success; outputs the commit count on stdout
# return: `1` — no upstream configured for the branch, or not a git repository
# return: `10` (`ERROR_ARGV`) — argument empty (`DIR EMPTY`), or `git` not installed (`GIT: not found`)
_git_commits_ahead () {
    _func_start "$@"

    # Check argv
    if ! _exist "$1"; then _error "DIR EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _installed "git"; then _error "GIT: not found"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi

    local __dir="$1"
    local __ahead
    local __return

    __ahead=$(git -C "$__dir" rev-list --count '@{u}'..HEAD 2>/dev/null)
    __return=$?
    if [ "$__return" -ne 0 ]; then _error "UPSTREAM: no upstream configured for branch in $__dir" ; _func_end "1" ; return 1 ; fi

    echo "$__ahead" | tr -d ' '

    _func_end "0" ; return 0
}

# call: _git_staged_shortstat ($1:dir)
# doc-section: GIT
# doc-order: 63
# description: Echoes the shortstat summary of the staged diff (e.g. `2 files changed, 5 insertions(+), 1 deletion(-)`) in a git directory; empty when nothing is staged.
# example: `_git_staged_shortstat "/path/to/git/repo"`
# example: `$1` — directory of the git repository
# return: `0` — success; outputs the shortstat on stdout (possibly empty)
# return: `1` — not a git repository
# return: `10` (`ERROR_ARGV`) — argument empty (`DIR EMPTY`), or `git` not installed (`GIT: not found`)
_git_staged_shortstat () {
    _func_start "$@"

    # Check argv
    if ! _exist "$1"; then _error "DIR EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _installed "git"; then _error "GIT: not found"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi

    local __dir="$1"
    local __shortstat
    local __return

    __shortstat=$(git -C "$__dir" diff --cached --shortstat 2>/dev/null)
    __return=$?
    if [ "$__return" -ne 0 ]; then _error "GIT: not a git repository: $__dir" ; _func_end "1" ; return 1 ; fi

    echo "$__shortstat" | tr -s ' ' | sed 's/^ //'

    _func_end "0" ; return 0
}

# call: _git_staged_stat ($1:dir)
# doc-section: GIT
# doc-order: 64
# description: Echoes the full stat block of the staged diff in a git directory; empty when nothing is staged.
# example: `_git_staged_stat "/path/to/git/repo"`
# example: `$1` — directory of the git repository
# return: `0` — success; outputs the stat block on stdout (possibly empty)
# return: `1` — not a git repository
# return: `10` (`ERROR_ARGV`) — argument empty (`DIR EMPTY`), or `git` not installed (`GIT: not found`)
_git_staged_stat () {
    _func_start "$@"

    # Check argv
    if ! _exist "$1"; then _error "DIR EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _installed "git"; then _error "GIT: not found"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi

    local __dir="$1"
    local __stat
    local __return

    __stat=$(git -C "$__dir" diff --cached --stat 2>/dev/null)
    __return=$?
    if [ "$__return" -ne 0 ]; then _error "GIT: not a git repository: $__dir" ; _func_end "1" ; return 1 ; fi

    echo "$__stat"

    _func_end "0" ; return 0
}

# call: _git_is_work_tree ($1:dir)
# doc-section: GIT
# doc-order: 65
# description: Predicate that returns success when the given directory is inside a git work tree. Echoes nothing.
# example: `_git_is_work_tree "/path/to/git/repo"`
# example: `$1` — directory to test
# return: `0` — the directory is inside a git work tree
# return: `1` — not a git work tree (or not a git repository)
# return: `10` (`ERROR_ARGV`) — argument empty (`DIR EMPTY`), or `git` not installed (`GIT: not found`)
_git_is_work_tree () {
    _func_start "$@"

    # Check argv
    if ! _exist "$1"; then _error "DIR EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _installed "git"; then _error "GIT: not found"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi

    local __dir="$1"
    local __return

    git -C "$__dir" rev-parse --is-inside-work-tree >/dev/null 2>&1
    __return=$?
    if [ "$__return" -ne 0 ]; then _error "GIT: not a git work tree: $__dir" ; _func_end "1" ; return 1 ; fi

    _func_end "0" ; return 0
}

# call: _git_porcelain_status ($1:dir)
# doc-section: GIT
# doc-order: 66
# description: Echoes the porcelain status (`git status --porcelain`) of a git work tree; empty when the tree is clean.
# example: `_git_porcelain_status "/path/to/git/repo"`
# example: `$1` — directory of the git repository
# return: `0` — success; outputs the porcelain status on stdout (possibly empty)
# return: `1` — not a git work tree
# return: `10` (`ERROR_ARGV`) — argument empty (`DIR EMPTY`), or `git` not installed (`GIT: not found`)
_git_porcelain_status () {
    _func_start "$@"

    # Check argv
    if ! _exist "$1"; then _error "DIR EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _installed "git"; then _error "GIT: not found"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi

    local __dir="$1"
    local __status
    local __return

    __status=$(git -C "$__dir" status --porcelain 2>/dev/null)
    __return=$?
    if [ "$__return" -ne 0 ]; then _error "GIT: not a git work tree: $__dir" ; _func_end "1" ; return 1 ; fi

    echo "$__status"

    _func_end "0" ; return 0
}

# call: _git_diff ($1:dir) ($2:ref)
# doc-section: GIT
# doc-order: 67
# description: Echoes the raw git diff of a work tree. With `$2` set to `HEAD` it diffs the working tree against `HEAD`; with `--cached` it diffs the staged changes; with no `$2` it runs plain `git diff`.
# example: `_git_diff "/path/to/git/repo" "HEAD"`
# example: `_git_diff "/path/to/git/repo" "--cached"`
# example: `_git_diff "/path/to/git/repo"`
# example: `$1` — directory of the git repository
# example: `$2` — optional diff reference: `HEAD`, `--cached`, or empty for plain diff
# return: `0` — success; outputs the raw diff on stdout (possibly empty)
# return: `1` — not a git work tree
# return: `10` (`ERROR_ARGV`) — argument empty (`DIR EMPTY`), or `git` not installed (`GIT: not found`)
_git_diff () {
    _func_start "$@"

    # Check argv
    if ! _exist "$1"; then _error "DIR EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _installed "git"; then _error "GIT: not found"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi

    local __dir="$1"
    local __ref="$2"
    local __diff
    local __return

    if [ -n "$__ref" ]; then
        __diff=$(git -C "$__dir" diff "$__ref" 2>/dev/null)
    else
        __diff=$(git -C "$__dir" diff 2>/dev/null)
    fi
    __return=$?
    if [ "$__return" -ne 0 ]; then _error "GIT: not a git work tree: $__dir" ; _func_end "1" ; return 1 ; fi

    echo "$__diff"

    _func_end "0" ; return 0
}

# call: _git_add ($1:dir)
# doc-section: GIT
# doc-order: 68
# description: Stages all changes in a git work tree (`git add -A`). Echoes nothing.
# example: `_git_add "/path/to/git/repo"`
# example: `$1` — directory of the git repository
# return: `0` — success (all changes staged)
# return: `1` — `git add` failed in the directory
# return: `10` (`ERROR_ARGV`) — argument empty (`DIR EMPTY`), or `git` not installed (`GIT: not found`)
_git_add () {
    _func_start "$@"

    # Check argv
    if ! _exist "$1"; then _error "DIR EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _installed "git"; then _error "GIT: not found"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi

    local __dir="$1"
    local __return

    git -C "$__dir" add -A
    __return=$?
    if [ "$__return" -ne 0 ]; then _error "GIT: git add failed in $__dir" ; _func_end "1" ; return 1 ; fi

    _func_end "0" ; return 0
}

# call: _git_commit ($1:dir) ($2:message)
# doc-section: GIT
# doc-order: 69
# description: Commits the staged changes in a git work tree with the given message (`git commit -m`). Echoes the commit output (combined stdout+stderr).
# example: `_git_commit "/path/to/git/repo" "commit message"`
# example: `$1` — directory of the git repository
# example: `$2` — commit message
# return: `0` — success; outputs the commit output on stdout
# return: `1` — `git commit` failed in the directory
# return: `10` (`ERROR_ARGV`) — argument empty (`DIR EMPTY` / `MESSAGE EMPTY`), or `git` not installed (`GIT: not found`)
_git_commit () {
    _func_start "$@"

    # Check argv
    if ! _exist "$1"; then _error "DIR EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _exist "$2"; then _error "MESSAGE EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _installed "git"; then _error "GIT: not found"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi

    local __dir="$1"
    local __message="$2"
    local __result
    local __return

    __result=$(git -C "$__dir" commit -m "$__message" 2>&1)
    __return=$?

    echo "$__result"

    if [ "$__return" -ne 0 ]; then _error "GIT: git commit failed in $__dir" ; _func_end "1" ; return 1 ; fi

    _func_end "0" ; return 0
}

####################################################################################################
############################################### URL ################################################
####################################################################################################
#
#
# usage: _curl --method ($1) --url ($2) --header ($3) --header-data ($4) --data ($5)
# doc-section: URL & HTTP
# doc-order: 70
# description: Wrapper around `curl` performing a request with the given HTTP method, URL, optional headers, and optional data. Prints the response body on stdout. Detects HTTP error status responses (`400`, `401`, `403`, `404`, `500`, `502`, `503`, `504`) appended by `--write-out` and reports the matching error.
# example: `_curl "GET" "https://api.example.com/resource"`
# example: `_curl "GET" "https://api.example.com/resource" "Authorization: Bearer x"`
# example: `_curl "POST" "https://api.example.com/resource" "Content-Type: application/json" "X-Custom: 1" '{"key":"value"}'`
# param: `$1` — HTTP method: `POST`, `PUT`, `DELETE`, or `GET`
# param: `$2` — URL (must be ASCII)
# param: `$3` — optional header
# param: `$4` — optional second header
# param: `$5` — optional request body (`-d`)
# return: `0` — success; outputs the response body on stdout
# return: `10` (`ERROR_ARGV`) — missing method/URL, non-ASCII URL, `curl` not installed, or wrong method
# return: `1` — HTTP error status detected in the response: `400 Bad Request`, `401 Unauthorized`, `403 Forbidden`, `404 Not Found`, `500 Internal Server Error`, `502 Bad Gateway`, `503 Service Unavailable`, `504 Gateway Time-out`
# return: `3` — curl "URL malformed" error
# return: `5` — curl "could not resolve proxy" error
# return: `6` — curl "could not resolve host" (DNS) error
# return: `7` — curl "failed to connect to host" error
# return: `23` — curl write error
# return: `26` — curl read error
# return: `35` — curl SSL connect error
# return: `47` — curl "too many redirects" error
# return: other — any other curl error code
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

    # Intercept HTTP error status codes (the status code is appended by --write-out)
    if [ "$__return" == "0" ]; then
        case $__http_code in
            400 ) _debug "$__resp"; _error "400 Bad Request" ; _func_end "1" ; return 1 ;;
            401 ) _debug "$__resp"; _error "401 Unauthorized" ; _func_end "1" ; return 1 ;;
            403 ) _debug "$__resp"; _error "403 Forbidden" ; _func_end "1" ; return 1 ;;
            404 ) _debug "$__resp"; _error "404 Not Found" ; _func_end "1" ; return 1 ;;
            500 ) _debug "$__resp"; _error "500 Internal Server Error" ; _func_end "1" ; return 1 ;;
            502 ) _debug "$__resp"; _error "502 Bad Gateway" ; _func_end "1" ; return 1 ;;
            503 ) _debug "$__resp"; _error "503 Service Unavailable" ; _func_end "1" ; return 1 ;;
            504 ) _debug "$__resp"; _error "504 Gateway Time-out" ; _func_end "1" ; return 1 ;;
        esac
    fi

    case $__return in
        0 )  echo "$__body" ; _func_end "0" ; return 0 ;; # no _shellcheck
        3 )  _error "Wrong URL:$2" ; _func_end "$__return" ; return $__return ;;
        5 )  _error "Proxy error for _curl" ; _func_end "$__return" ; return $__return ;;
        6 )  _error "DNS error for _curl" ; _func_end "$__return" ; return $__return ;;
        7 )  _error "Connection error for _curl" ; _func_end "$__return" ; return $__return ;;
        23 ) _error "Write error for _curl" ; _func_end "$__return" ; return $__return ;;
        26 ) _error "Read error for _curl" ; _func_end "$__return" ; return $__return ;;
        35 ) _error "SSL error for _curl" ; _func_end "$__return" ; return $__return ;;
        47 ) _error "Too many redirects for _curl" ; _func_end "$__return" ; return $__return ;;
        * )  _error "Something went wrong in _curl. Return code:$__return Response:$__resp" ; _func_end "$__return" ; return $__return ;;
    esac
}

# call: _encode_url ($1:url)
# doc-section: URL & HTTP
# doc-order: 71
# description: Percent-encodes a URL/string using `jq -Rr @uri`.
# example: `_encode_url "https://example.com/a b&c"`
# example: `echo "a b&c" | _encode_url`
# return: `0` — success; outputs the encoded string on stdout
# return: `10` (`ERROR_ARGV`) — empty input or `jq` not installed
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
# doc-section: URL & HTTP
# doc-order: 72
# description: Percent-decodes a URL-encoded string (handles `%XX` and `+` as space). Recursive implementation.
# example: `_decode_url "a%20b%26c"`
# example: `$1` (and following args) — the encoded string
# return: `0` — success; outputs the decoded string on stdout
# return: `10` (`ERROR_ARGV`) — empty input
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
# doc-section: Network Management
# doc-order: 73
# description: Validates that the argument is a well-formed IPv4 address (no leading zeros, each octet ≤ 255).
# example: `_valid_ipv4 "192.168.1.1"`
# return: `0` — valid IPv4
# return: `10` (`ERROR_ARGV`) — no argument given
# return: `1` — invalid format, leading zero, or octet > 255
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
# doc-section: Network Management
# doc-order: 74
# description: Validates a network in CIDR notation, e.g. `192.168.1.0/24` (valid IP + numeric mask ≤ 32).
# example: `_valid_network "192.168.1.0/24"`
# return: `0` — valid network
# return: `10` (`ERROR_ARGV`) — no argument given
# return: `1` — invalid IP, missing mask, non-numeric mask, or mask > 32
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
# doc-section: Network Management
# doc-order: 75
# description: Converts a dotted-quad IPv4 address to its 32-bit integer representation.
# example: `_ip2int "192.168.1.1"`
# return: `0` — success; outputs the integer on stdout
# return: `10` (`ERROR_ARGV`) — missing/invalid IP
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
# doc-section: Network Management
# doc-order: 76
# description: Converts a 32-bit integer (0–4294967295) to a dotted-quad IPv4 address. Out-of-range, negative, or non-numeric input is rejected.
# example: `_int2ip "3232235777"`
# return: `0` — success; outputs the IP on stdout
# return: `10` (`ERROR_ARGV`) — argument empty (`INT EMPTY`), non-numeric input (`int not numeric`), or integer greater than `4294967295` (`int too large`)
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
# doc-section: Network Management
# doc-order: 77
# description: Converts a CIDR prefix length to a netmask, e.g. `24` → `255.255.255.0`.
# example: `_netmask "24"`
# return: `0` — success; outputs the netmask on stdout
# return: `10` (`ERROR_ARGV`) — missing mask, non-numeric mask (`mask not numeric`), or mask > 32
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
# doc-section: Network Management
# doc-order: 78
# description: Computes the broadcast address of a network given an IP and a CIDR mask, e.g. `192.0.2.0 24` → `192.0.2.255`.
# example: `_broadcast "192.0.2.0" "24"` — `$1` IP, `$2` mask
# return: `0` — success; outputs the broadcast address on stdout
# return: `10` (`ERROR_ARGV`) — missing IP/mask, invalid IP, non-numeric mask (`mask not numeric`), or mask > 32
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
# doc-section: Network Management
# doc-order: 79
# description: Computes the network address given an IP and a CIDR mask, e.g. `192.0.2.10 24` → `192.0.2.0`.
# example: `_network "192.0.2.10" "24"` — `$1` IP, `$2` mask
# return: `0` — success; outputs the network address on stdout
# return: `10` (`ERROR_ARGV`) — missing IP/mask, invalid IP, non-numeric mask (`mask not numeric`), or mask > 32
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
# doc-section: Architecture Detection
# doc-order: 81
# description: Returns success when the current machine architecture is `armv7l` (typical Raspberry Pi), failure otherwise.
# example: `_raspberry` (no arguments)
# return: `0` — architecture is `armv7l`
# return: `1` — otherwise
_raspberry () {
    if [ "$(_os_arch)" = "armv7l" ]; then return 0; else return 1; fi
}

# call: _x86_64 ()
# doc-section: Architecture Detection
# doc-order: 82
# description: Returns success when the current machine architecture is `x86_64`, failure otherwise.
# example: `_x86_64` (no arguments)
# return: `0` — architecture is `x86_64`
# return: `1` — otherwise
_x86_64 () {
    if [ "$(_os_arch)" = "x86_64" ]; then return 0; else return 1; fi
}

# call: _os_arch ()
# doc-section: Architecture Detection
# doc-order: 80
# description: Prints the machine hardware name (`uname -m`), e.g. `x86_64`, `armv7l`.
# example: `_os_arch` (no arguments)
# return-inline: Always `0`. Outputs the architecture on stdout.
_os_arch () {
    _func_start "$@"

    uname -m

    _func_end "0" ; return 0
}

####################################################################################################
######################################### INTERACTIVE ASK ##########################################
####################################################################################################
# call: _ask_yes_or_no ($1:question) ($2:default)
# doc-section: Interactive Ask Helpers
# doc-order: 83
# description: Asks a yes/no question. With `$2` set, the prompt shows `[Y/n]` or `[y/N]` and an empty answer uses that default. When `WHIPTAIL=true`, the question is displayed with `whiptail` instead of a text prompt. Prints `y` or `n`.
# example: `_ask_yes_or_no "Do you agree?"`
# example: `_ask_yes_or_no "Do you agree?" "y"` — default answer `y`
# example: `$1` — question text
# example: `$2` — optional default (`y` or `n`)
# return: `0` — answered (or default used); outputs `y`/`n` on stdout
# return: `10` (`ERROR_ARGV`) — question empty, invalid default, or `whiptail` not installed
# return: loops with a warning until a valid `Y`/`N` (or accepted default) is entered
# doc-intro: > These helpers prompt the user on the terminal. When the global `DEFAULT` is `true`, they skip the prompt and return the provided default value instead. They rely on `_valid_ipv4` / `_valid_network` for input validation.
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
# doc-section: Interactive Ask Helpers
# doc-order: 85
# description: Asks for an IPv4 address and validates it with `_valid_ipv4` (loop until valid). An empty answer uses the optional default `$2`.
# example: `_ask_ip "Server IP?"`
# example: `_ask_ip "Server IP?" "192.168.1.1"` — default IP
# example: `$1` — question text
# example: `$2` — optional default IP
# return: `0` — answered (or default used); outputs the IP on stdout
# return: `1` — invalid default while `DEFAULT=true` (logs `default value is not a valid ip address`)
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
# doc-section: Interactive Ask Helpers
# doc-order: 86
# description: Asks for a network in CIDR notation and validates it with `_valid_network` (loop until valid). An empty answer uses the optional default `$2`.
# example: `_ask_network "VPN network?"`
# example: `_ask_network "VPN network?" "192.168.1.0/24"` — default network
# example: `$1` — question text
# example: `$2` — optional default network
# return: `0` — answered (or default used); outputs the network on stdout
# return: `1` — invalid default while `DEFAULT=true` (logs `default value is not a valid network`)
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
# doc-section: Interactive Ask Helpers
# doc-order: 84
# description: Asks a free-text question and prints the answer. An empty answer falls back to the optional default `$2`.
# example: `_ask_string "Project name?"`
# example: `_ask_string "Project name?" "myproject"` — default `myproject`
# example: `$1` — question text
# example: `$2` — optional default value
# return: `0` — answered (or default used); outputs the string on stdout
# return: `10` (`ERROR_ARGV`) — question empty, or default empty while `DEFAULT=true`
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
# doc-section: Tests & CI
# doc-order: 89
# description: Runs ShellCheck on the target library files and then applies the project's custom lint rules (each function must have exactly one `# usage:`/`# call:` line and 1–2 `# description:` lines directly above its definition; `_error` must be followed by `return`/`exit` >0; use `$GREP` not raw `grep`; `_func_end` must take an argument and be followed by `return`/`exit`; `_func_end "1"` requires an `_error` on the same line; `return 0` is only allowed immediately before a closing `}` (the end of a function/block), so a `_func_end "0" ; return 0` directly followed by the function's closing brace is fine even when the file continues with top-level code after that brace; use `_curl` not raw `curl`; no `docker` piped to another command; `$?` must be tested with an `_error`; every `return` in a function that calls `_func_start` must be on the same line as `_func_end` — stack-balance rule). Comment lines and lines exempted with `# no _shellcheck` are skipped. Prints `no error found with shellcheck in ...` on success.
# example: `_shellcheck "file1.sh" "file2.sh"` — check the given files
# example: `_shellcheck` — check all `*.sh` files under `$MY_GIT_DIR/$LIB` (requires `$LIB` set and `$MY_GIT_DIR/$LIB/lib_$LIB.sh` to exist)
# return: `0` — ShellCheck and all custom lint checks pass
# return: `10` (`ERROR_ARGV`) — `shellcheck` not installed
# return: `1` — lib file not found, ShellCheck errors, or a custom lint rule violation
# doc-intro: > These functions are the orchestrator's testing/CI entry points. They rely on the runtime globals `$LIB`, `$MY_GIT_DIR`, `$GREP`, and `$DRY_RUN` set by `my_warp.sh`.
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
                else if ($0 ~ /^# description:/) { d++ }
                else { next }
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
            function analyze(fname,   i, close_lines) {
                # A closing brace ends a function (or block): `return 0` directly
                # followed by `}` is a normal success return, even when the file
                # continues with top-level code after that brace.
                for (i = 1; i <= line_count; i++) {
                    if (lines[i] ~ /^[[:space:]]*\}/) { close_lines[i] = 1 }
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

# call: _bats ($1:filter)
# doc-section: Tests & CI
# doc-order: 90
# description: Runs the BATS test suite (`bats/tests.bats`) of the library `$LIB` with verbose output. When an optional `$1` regex filter is given, only the tests whose name matches that regex are run (forwarded verbatim to `bats --filter <regex>`): a single test can be selected with a unique substring or an anchored `^exact name$`, several tests with an alternation such as `'name1|name2'`. A filter that matches no test still exits `0` (bats semantics), so verify the pattern if nothing ran.
# example: `_bats` — run the whole suite; requires `$LIB` set and `$MY_GIT_DIR/$LIB/bats/tests.bats` to exist
# example: `_bats "_load_lib"` — run only the tests whose name contains `_load_lib`
# example: `_bats "^_load_lib => true$"` — run exactly one test
# example: `_bats "alpha one|beta two"` — run several tests
# example: `$1` — optional filter regex matched against the `@test` names
# return: `0` — BATS tests passed (a no-match filter also returns `0`)
# return: `10` (`ERROR_ARGV`) — `$LIB` empty, lib file not found, or more than one argument given (only one filter regex is supported)
# return: `1` — `bats` not installed or tests failed
_bats () {
    _func_start "$@"

    # Check argv
    if ! _exist "$LIB"; then _error "no LIB found"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi

    if _exist "$LIB" && ! _fileexist "$MY_GIT_DIR/$LIB/lib_$LIB.sh"; then _error "lib file not found" ;  _usage; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi

    if _exist "$2"; then _error "too many arguments: only one filter regex is supported" ; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi

    if _installed "bats"; then
        local __bats_args=(--verbose-run)
        if _exist "$1"; then __bats_args+=(--filter "$1"); fi
        __bats_args+=("$MY_GIT_DIR/$LIB/bats/tests.bats")

        cd "$MY_GIT_DIR/$LIB" || { _error "cannot cd to $MY_GIT_DIR/$LIB"; _func_end "1" ; return 1 ; }
        if bats "${__bats_args[@]}" ; then # --show-output-of-passing-tests
            _verbose "no error found"; cd - > /dev/null || { _error "cannot cd back"; _func_end "1" ; return 1 ; } ; _func_end "0" ; return 0
        else
            _error "something went wrong with bats"; cd - || { _error "cannot cd back"; _func_end "1" ; return 1 ; } ; _func_end "1" ; return 1
        fi
    else
        _error "bats not found" ; _func_end "1" ; return 1
    fi
}

# call: _kcov ($1:mode)
# doc-section: Tests & CI
# doc-order: 91
# description: Measures test code coverage of the library `$LIB` using `kcov`, prints per-file coverage percentages (from `coverage.json`), and uploads the `cobertura.xml` report to Codecov when `codecov`, `$CODECOV_TOKEN`, and `$GITHUB_USERNAME` are available. Does nothing (dry-run) when `$DRY_RUN` is `true`. When the argument `AI` is passed, the temporary report directory is **not** removed; instead the full path of `cobertura.xml` is logged with `_info`.
# example: `_kcov` — requires `$LIB` set and `kcov` installed; cleans up the temporary report
# example: `_kcov AI` — same as above, but keeps the report and prints its full path via `_info`
# example: `$1` — optional; when set to `AI`, keeps the `cobertura.xml` report
# return: `0` — success (dry-run included; upload return code is not checked — see TODO in source)
# return: `10` (`ERROR_ARGV`) — `$LIB` empty, `kcov` not installed, or `jq` not installed
# return: `1` — `_tmp_file` failed
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
# doc-section: Tests & CI
# doc-order: 92
# description: Summarizes the coverage report produced by `_kcov`: locates the `cobertura.xml` file inside the given kcov temporary/report directory and prints, for each file present in the report, the line numbers that are **not covered** (i.e. with `hits="0"`). The file list is discovered from the report itself (e.g. `lib_shell.sh` + `my_warp.sh` for the shell lib, `lib_tempo_shell.sh` for the tempo_shell lib). Output is one line per file as `file:line1,line2,...`; a file with every line covered prints `file:` followed by an empty list.
# example: `_kcov_resume "$__tmp"` — where `$__tmp` is the temporary directory used by `_kcov` (or any directory containing a `cobertura.xml`)
# example: `$1` — directory containing the kcov report (`cobertura.xml`); may be the `_kcov` temp dir or the kept report dir
# return: `0` — success; outputs the uncovered line numbers per file on stdout
# return: `10` (`ERROR_ARGV`) — directory argument empty or directory does not exist
# return: `1` — no `cobertura.xml` found inside the directory
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

# call: _doc ($1:filename)
# description: Generates the markdown function reference of lib_$LIB.sh into the given filename.
_doc () {
    _func_start "$@"

    # Check argv
    if ! _exist "$1"; then _error "FILENAME EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _exist "$LIB"; then _error "LIB EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _fileexist "$MY_GIT_DIR/$LIB/lib_$LIB.sh"; then _error "LIB FILE NOT FOUND: $MY_GIT_DIR/$LIB/lib_$LIB.sh"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi

    local __filename="$1"
    local __libfile="$MY_GIT_DIR/$LIB/lib_$LIB.sh"
    local __libname
    local __tmp

    __libname=${__libfile##*/}

    if ! __tmp=$(_tmp_file) ; then _error "TMP: cannot create a temp file" ; _func_end "1" ; return 1 ; fi

    if $GREP -q '^# doc-section:' "$__libfile"; then
        # documented mode: the lib carries `# doc-section:` / `# doc-order:` /
        # `# description:` / `# example:` / `# param:` / `# return-inline:` /
        # `# return:` markers plus optional `# doc-top:` / `# doc-bottom:` and
        # `# doc-intro:` markers; rebuild functions.md-style markdown from them.
        if ! awk -v __libname="$__libname" '
            BEGIN {
                print "# `" __libname "` — Function Reference"
                print ""
                print "This document describes every function defined in `" __libname "`."
                ntop = 0
                nbot = 0
                nverb = 0
                norder = 0
                # pending function
                porder = ""
                psec = ""
                pdesc = ""
                nu = 0
                rk = ""
                nr = 0
                # marker prefixes built without the literal word "return" so the
                # shell source does not trip the stack-balance lint rule
                rtag = "# ret" "urn:"
                rtagi = "# ret" "urn-inline:"
            }
            /^# doc-top:/ {
                x = $0
                sub(/^# doc-top:[[:space:]]*/, "", x)
                top[++ntop] = x
                next
            }
            /^# doc-bottom:/ {
                x = $0
                sub(/^# doc-bottom:[[:space:]]*/, "", x)
                bot[++nbot] = x
                next
            }
            /^# doc-verbatim:/ {
                x = $0
                sub(/^# doc-verbatim: ?/, "", x)
                verb[++nverb] = x
                next
            }
            /^# doc-intro:/ {
                x = $0
                sub(/^# doc-intro:[[:space:]]*/, "", x)
                if (psec != "") intro[psec] = (intro[psec] == "" ? x : intro[psec] "\n" x)
                next
            }
            /^# doc-section:/ {
                x = $0
                sub(/^# doc-section:[[:space:]]*/, "", x)
                psec = x
                next
            }
            /^# doc-order:/ {
                x = $0
                sub(/^# doc-order:[[:space:]]*/, "", x)
                porder = x + 0
                if (porder > norder) norder = porder
                next
            }
            /^# description:/ {
                x = $0
                sub(/^# description:[[:space:]]*/, "", x)
                pdesc = x
                next
            }
            /^# example:/ {
                x = $0
                sub(/^# example:[[:space:]]*/, "", x)
                nu++
                uind[porder, nu] = 3
                utxt[porder, nu] = x
                next
            }
            /^# param:/ {
                x = $0
                sub(/^# param:[[:space:]]*/, "", x)
                nu++
                uind[porder, nu] = 5
                utxt[porder, nu] = x
                next
            }
            $0 ~ "^" rtagi {
                x = $0
                sub("^" rtagi "[[:space:]]*", "", x)
                rk = "inline"
                rtxt[porder, 1] = x
                nr = 1
                next
            }
            $0 ~ "^" rtag {
                x = $0
                sub("^" rtag "[[:space:]]*", "", x)
                if (rk != "list") rk = "list"
                nr++
                rtxt[porder, nr] = x
                next
            }
            /^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*[[:space:]]*\(\)[[:space:]]*\{/ {
                if (porder != "") {
                    nm = $0
                    sub(/^[[:space:]]*/, "", nm)
                    sub(/[[:space:]]*\(.*/, "", nm)
                    name[porder] = nm
                    sec[porder] = psec
                    desc[porder] = pdesc
                    ucnt[porder] = nu
                    if (rk != "") rkind[porder] = rk; else rkind[porder] = "none"
                    rcnt[porder] = nr
                }
                porder = ""
                psec = ""
                pdesc = ""
                nu = 0
                rk = ""
                nr = 0
                next
            }
            {
                next
            }
            END {
                print ""
                for (t = 1; t <= ntop; t++) print top[t]
                print ""
                print "---"
                print ""
                for (v = 1; v <= nverb; v++) print verb[v]
                prevsec = ""
                first = 1
                for (o = 1; o <= norder; o++) {
                    if (name[o] == "") continue
                    s = sec[o]
                    if (s != prevsec) {
                        if (!first) {
                            print "---"
                            print ""
                        }
                        first = 0
                        print "## " s
                        print ""
                        if (intro[s] != "") {
                            n = split(intro[s], ilines, "\n")
                            for (i = 1; i <= n; i++) print ilines[i]
                            print ""
                        }
                        prevsec = s
                    }
                    print "### `" name[o] "`"
                    print "1. **Description:** " desc[o]
                    print "2. **Usage:**"
                    for (u = 1; u <= ucnt[o]; u++) {
                        if (uind[o, u] == 5) printf "     - %s\n", utxt[o, u]
                        else printf "   - %s\n", utxt[o, u]
                    }
                    if (rkind[o] == "inline") {
                        print "3. **Returns:** " rtxt[o, 1]
                    } else if (rkind[o] == "list") {
                        print "3. **Returns:**"
                        for (r = 1; r <= rcnt[o]; r++) printf "   - %s\n", rtxt[o, r]
                    } else {
                        print "3. **Returns:**"
                    }
                    # separator blank after the entry: needed between entries and
                    # before a doc-bottom block, but not after the very last entry
                    more = 0
                    for (r = o + 1; r <= norder; r++) if (name[r] != "") more = 1
                    if (more || nbot > 0) print ""
                }
                for (b = 1; b <= nbot; b++) print bot[b]
            }
        ' "$__libfile" > "$__tmp"; then
            _error "PARSE: something went wrong while parsing $__libfile"; _func_end "1" ; return 1
        fi
    else
        # generic mode: derive the doc from the `# usage:`/`# call:` and
        # `# description:` headers grouped under the section banners of the file.
        if ! awk -v __libname="$__libname" '
            BEGIN {
                print "# `" __libname "` — Function Reference"
                print ""
                print "This document describes every function defined in `" __libname "`."
                print ""
                print "> Auto-generated from the `# call:` / `# usage:` / `# description:` headers of `" __libname "` by `_doc`. Edit the source comments, then regenerate."
                print ""
                print "---"
                print ""
                cursec = ""
                emitted = ""
                nb = 0
            }
            {
                if ($0 ~ /^[[:space:]]*#/) {
                    b = $0
                    if (b ~ /^#+[[:space:]]*[^#]/ && b ~ /#[[:space:]]*$/) {
                        sub(/^#+[[:space:]]*/, "", b)
                        sub(/[[:space:]]*#+[[:space:]]*$/, "", b)
                        cursec = b
                        nb = 0
                    } else {
                        nb++
                        buf[nb] = $0
                    }
                    next
                }
                if ($0 ~ /^[[:space:]]*[A-Za-z_][A-Za-z0-9_]*[[:space:]]*\(\)[[:space:]]*\{/) {
                    name = $0
                    sub(/^[[:space:]]*/, "", name)
                    sub(/[[:space:]]*\(.*/, "", name)
                    usage = ""
                    call = ""
                    desc = ""
                    for (i = 1; i <= nb; i++) {
                        x = buf[i]
                        if (x ~ /^[[:space:]]*#[[:space:]]*usage:/) {
                            sub(/^[[:space:]]*#[[:space:]]*usage:[[:space:]]*/, "", x)
                            usage = x
                        } else if (x ~ /^[[:space:]]*#[[:space:]]*call:/) {
                            sub(/^[[:space:]]*#[[:space:]]*call:[[:space:]]*/, "", x)
                            call = x
                        } else if (x ~ /^[[:space:]]*#[[:space:]]*description:/) {
                            sub(/^[[:space:]]*#[[:space:]]*description:[[:space:]]*/, "", x)
                            desc = desc x " "
                        }
                    }
                    sig = usage
                    if (sig == "") sig = call
                    if (sig == "") sig = name
                    sub(/[[:space:]]+$/, "", desc)
                    if (cursec != "" && cursec != emitted) {
                        if (emitted != "") {
                            print "---"
                            print ""
                        }
                        print "## " cursec
                        print ""
                        emitted = cursec
                    }
                    print "### `" name "`"
                    print "1. **Description:** " desc
                    print "2. **Usage:**"
                    print "   - `" sig "`"
                    print "3. **Returns:** "
                    print ""
                    nb = 0
                    next
                }
                nb = 0
            }
        ' "$__libfile" > "$__tmp"; then
            _error "PARSE: something went wrong while parsing $__libfile"; _func_end "1" ; return 1
        fi
    fi

    if ! mv -f "$__tmp" "$__filename"; then
        _error "FILE: cannot write $__filename"; _func_end "1" ; return 1
    fi

    _success "documentation generated in $__filename"

    _func_end "0" ; return 0
}

####################################################################################################
############################################ DISPLAY ###############################################
####################################################################################################
# call: _showU8Variation ($1:selector) ($2:codepoint)
# doc-section: Display Helpers
# doc-order: 87
# description: Displays a UTF-8 table showing how characters render in the terminal using variation selectors. The first argument selects the variation selector (1–26); the remaining arguments are hex code points (e.g. `24` for the table of `0x2400`-based glyphs). When no hex code point is given, the table defaults to `26` (U+2600 Miscellaneous Symbols).
# example: `_showU8Variation 24 24`
# example: `_showU8Variation 7` — selector only; defaults to code point `26`
# example: `$1` — variation selector number (1–256; values 1–16 map to U+FE00–U+FE0F, 17–256 to U+E0100–U+E01EF)
# example: `$@` — hex code point arguments
# return: `0` — table printed to stdout (exit status of the last `printf`)
# return: `1` — `$1` empty (`VARIATION SELECTOR EMPTY`), not numeric (`VARIATION SELECTOR not numeric`), or outside 1–256 (`VARIATION SELECTOR must be between 1 and 256`)
# return: Not telemetry-instrumented.
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
# doc-section: Display Helpers
# doc-order: 88
# description: Prints a matrix of ANSI escape codes combining background, text, and mode attributes so the user can see how every `\e[<bg>;<mode>;<color>m` combination renders. With an argument, that text is used as the sample instead of the escape sequence itself.
# example: `_show_color_code`
# example: `_show_color_code "sample"` — print `sample` with each combination
# return-inline: Always `0` (exit status of the last `printf`). Prints the color matrix to stdout. Not telemetry-instrumented.
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
# doc-section: Demo
# doc-order: 93
# description: Demo function that prints `Hello world` and exercises all logger levels (`_success`, `_verbose`, `_info`, `_warning`, `_error`).
# example: `_hello_world` (no arguments)
# return-inline: Always `0`. Outputs `Hello world` on stdout and log lines on stderr.
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
# doc-bottom: ---
# doc-bottom:
# doc-bottom: ## Global Variables Reference
# doc-bottom:
# doc-bottom: | Variable | Type | Purpose |
# doc-bottom: |----------|------|---------|
# doc-bottom: | `CHECK_KO` | string (ANSI) | Red ✗ prefix used by error logs |
# doc-bottom: | `CHECK_WARN` | string (ANSI) | Yellow ▲ prefix used by warning logs |
# doc-bottom: | `CHECK_SUCCESS` | string (ANSI) | Green ✓ prefix used by success logs |
# doc-bottom: | `CHECK_INFO` | string (ANSI) | Blue ★ prefix used by info logs |
# doc-bottom: | `ERROR_ARGV` | integer | Exit code (`10`) used for argument/validation errors |
# doc-bottom: | `GREP` / `EGREP` | string | Preconfigured `grep --text` binary path |
# doc-bottom: | `VERBOSE_SPACE` | string | Function-trace indentation prefix built by `_verbose_func_space` |
# doc-bottom: | `FUNC_LIST` | array | Telemetry stack of `function:start_time` entries |
# doc-bottom: | `VERBOSE` / `DEBUG` | boolean | Enable verbose / debug logging (consumed by `_log`, `_func_start`, `_func_end`) |
# doc-bottom: | `DRY_RUN` | boolean | When `true`, `_kcov` skips the real coverage run |
# doc-bottom: | `DEFAULT` | boolean | When `true`, the `_ask_*` helpers return the provided default without prompting |
# doc-bottom: | `FORCE` | boolean | When `true`, bypasses the cache (used by `_check_cache_or_force` in the `tempo_shell` feature library) |
# doc-bottom: | `YUBIKEY` | boolean | Enables YubiKey integrations in the `tempo_shell` feature library |
# doc-bottom: | `LIB` | string | Currently selected library name (`_process_opts`, `_usage`, `_load_lib`, `_shellcheck`, `_bats`, `_kcov`) |
# doc-bottom: | `MY_GIT_DIR` | string | Base directory of the local git repositories |
# doc-bottom: | `CUR_NAME` | string | Name of the running orchestrator script (`${0##*/}`), used in help/usage output |
# doc-bottom: | `OPTS` | string | Normalized option string produced by `getopt` in `_process_opts` |
# doc-bottom: | `ACTION` | boolean | Set to `true` when `--help`, `--bats`, `--shellcheck`, `--kcov` or `--list-libs` was requested |
# doc-bottom: | `GETOPT_SHORT_<LIB>` | string | Per-library short option list consumed by `_getopt_short` (e.g. `GETOPT_SHORT_SHELL=h,v,d,b,s,k`) |

