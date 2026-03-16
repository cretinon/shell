#!/bin/bash

# shellcheck source=/dev/null disable=SC2119,SC2120,SC2294,SC2001,SC2045,SC2184,SC2059,SC2034

GETOPT_SHORT_SHELL=h,v,d,b,s,k


ERROR_ARGV=10

GREP="/usr/bin/grep --text" # no _shellcheck
EGREP="/usr/bin/grep --text" # no _shellcheck

####################################################################################################
########################################### PROCESS OPTS ###########################################
####################################################################################################
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

    OPTS=$(getopt --options "$__short" --long "$__long" --name "$0" -- "$@" 2>/dev/null) || (_error "Bad or missing argument.\n\nTry '$CUR_NAME --help' for more informations\n" ; return 1)

    if ! _startswith "$1" '-'; then
        _error "Bad or missing argument.\n\nTry '$CUR_NAME --help' for more informations\n" ; return 1
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
        _usage ; __return=$? # no _shellcheck
    else
        if $__list_libs  ; then if ! _get_installed_libs ; then _error "something went wrong when listing installed libs" ; _func_end "1" ; return 1 ;fi ; fi
        if $__bats       ; then if ! _bats               ; then _error "something went wrong in bats" ; _func_end "1" ; return 1 ;fi ; fi
        if $__shellcheck ; then if ! _shellcheck "$@"    ; then _error "something went wrong in shellcheck" ; _func_end "1" ; return 1 ;fi ; fi
        if $__kcov       ; then if ! _kcov               ; then _error "something went wrong in kcov" ; _func_end "1" ; return 1 ;fi ; fi
    fi

    _func_end "$__return" ; return $__return
}

_getopt_short () { # no _shellcheck
    _func_start "$@"

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

    _func_end "0" ; return 0 # no _shellcheck
}

####################################################################################################
############################################## USAGES ##############################################
####################################################################################################
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
    fi

    _func_end "0" ; return 0 # no _shellcheck
}

####################################################################################################
######################################### LOAD LIBS & CONF #########################################
####################################################################################################
_load_libs () {
#    _func_start "$@"

    local __lib

    source "$MY_GIT_DIR/shell/lib_shell-base.sh"

    for __lib in $(_get_installed_libs); do
        _verbose "Loading:$MY_GIT_DIR/$__lib/lib_$__lib.sh"
        source  "$MY_GIT_DIR"/"$__lib"/lib_"$__lib".sh
    done

#    _func_end "0" ; return 0 # no _shellcheck
}

_load_lib () {
    _func_start "$@"

    # Check argv
    if ! _exist "$1" ;then _error "LIB EMPTY" ; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _fileexist "$MY_GIT_DIR/$1/lib_$1.sh" ;then _error "$MY_GIT_DIR/$1/lib_$1.sh not exist, not sourcing" ; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi

    _verbose "Loading $MY_GIT_DIR/$1/lib_$1.sh"
    source  "$MY_GIT_DIR"/"$1"/lib_"$1".sh

    _func_end "0" ;  return 0 # no _shellcheck
}

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

    _func_end "0" ; return 0 # no _shellcheck
}

_get_installed_libs () {
    _func_start "$@"

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
_verbose_file () {
    local __date

    __date=$(_date)

    _verbose_func_space

    if $VERBOSE; then _echoerr "[$$] -- DEBUG   --  $__date -- $VERBOSE_SPACE ---- dump file start ---- " "[$*]"; fi
    if $VERBOSE; then cat "$1" >&2; fi
    if $VERBOSE; then _echoerr "[$$] -- DEBUG   --  $__date -- $VERBOSE_SPACE ---- dump file end ---- " "[$*]"; fi
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

_contains () {
    if [[ $1 =~ $2 ]]; then return 0; else return 1; fi
}

_notexist () {
    if [[ -z "$1" ]] ; then return 0; else return 1; fi
}

_notinstalled () {
    if type "$1" 2> /dev/null 1>/dev/null ; then return 1; else return 0; fi
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

_filenotexist () {
    if [ -e "$1" ]; then return 1; else return 0; fi
}

# same as _fileexist for nfs files
_remotefileexist () {
    _func_start "$@"

    timeout 1 stat -t "$1" > /dev/null 2>/dev/null

    case "$?" in
        0)
            _verbose "$1 exist"
            _func_end "0" ; return 0 # no _shellcheck
        ;;
        124)
            _verbose "$1 TIMEOUT"
            _func_end "1" ; return 1 # no _shellcheck
        ;;
        *)
            _verbose "$1 not exist"
            _func_end "1" ; return 1 # no _shellcheck
        ;;
    esac
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

#
# usage: _host_up_show --network ($1)(192.168.1.0/24)
#
_host_up_show () {
    _func_start "$@"

    # Check argv
    if ! _exist "$1"; then _error "NETWORK EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _installed "nmap"; then _error "nmap not found"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _installed "dig"; then _error "dig not found"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi

    _debug "Looking for $1 alive ips"

    local __line
    local __name

    nmap -v -sn -n "$1" -oG - | $GREP Up | awk '{print $2}' | while read -r __line
    do
        __name=$(dig -x "$__line" | $GREP -v ^\; | $GREP PTR | awk  '{print $5}' | _remove_last_car)
        echo "$__line $__name"
    done | sort -u

    _func_end "0" ; return 0 # no _shellcheck
}

#
# usage: _iptables_show
#
_iptables_show () {
    _func_start "$@"

    # Check argv
    if ! _installed "iptables"; then _error "iptables not found"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi

    local __return
    local __id

#    __id=$(_id) ; if [ "$__id" -ne "0" ]; then _error "must be root"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi

    echo "===> Filter"
    iptables -vL -t filter
    echo ""
    echo "===> Nat"
    iptables -vL -t nat
    echo ""
    echo "===> Mangle"
    iptables -vL -t mangle
    echo ""
    echo "===> Raw"
    iptables -vL -t raw
    echo ""
    echo "===> Secutiry"
    iptables -vL -t security
    __return=$? ; if [ $__return -ne 0 ] ; then _error "something went wrong with iptables"; _func_end "$__return" ; return $__return ; fi

    _func_end "$__return" ; return $__return
}

#
# usage: _iptables_save
#
_iptables_save () {
    _func_start "$@"

    # Check argv
    if ! _installed "iptables"; then _error "iptables not found"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi

    local __return

    iptables-save -c > "${HOME}/iptables-save"
    __return=$? ; if [ $__return -ne 0 ] ; then _error "something went wrong with iptables"; _func_end "$__return" ; return $__return ; fi

    _func_end "$__return" ; return $__return
}

#
# usage: _iptables_restore
#
_iptables_restore () {
    _func_start "$@"

    # Check argv
    if ! _installed "iptables"; then _error "iptables not found"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi

    local __return

    iptables-restore -c < "${HOME}/iptables-save"
    __return=$? ; if [ $__return -ne 0 ] ; then _error "something went wrong with iptables"; _func_end "$__return" ; return $__return ; fi

    _func_end "$__return" ; return $__return
}

#
# usage: _iptables_flush
#
_iptables_flush () {
    _func_start "$@"

    # Check argv
    if _installed "docker"; then _error "Running on host with docker installed is not supported"; _func_end "$ERROR_ARGV" ; return 0 ; fi  # no _shellcheck
    if ! _installed "iptables"; then _error "iptables not found"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi

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
    __return=$? ; if [ $__return -ne 0 ] ; then _error "something went wrong with iptables"; _func_end "$__return" ; return $__return ; fi

    _func_end "$__return" ; return $__return
}



_showU8Variation () {
    #_showU8Variation 1 26 show in right table how char looks like in term
    local __i __a __f __e __t

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
############################################## CRYPT ###############################################
####################################################################################################
_pass_2_pin () {
    _func_start "$@"

    # Check argv
    if ! _exist "$1"; then _error "pass EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi

    local __pass
    local __i

    __pass=$(echo "$1" | _lower)

    for (( __i = 0; __i < ${#__pass}; ++__i)); do echo -n $(($(printf "%d\n" \'"${__pass:$__i:1}") - 96)) ; done ; echo

    _func_end "0" ; return 0 # no _shellcheck
}

_keepassxc_create_database () {
    _func_start "$@"

    # Check argv
    if ! _exist "$1"; then _error "PASS EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _exist "$2"; then _error "DATABASE EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if _fileexist "$2"; then _error "DATABASE $2 already exist"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _installed "keepassxc-cli" ; then _error "keepassxc-cli not found"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi

    local __result
    local __yubikey_opt

    if $YUBIKEY; then __yubikey_opt="db-create" ; else __yubikey_opt="db-create" ; fi
    # shellcheck disable=2086
    __result=$(echo -e "$1\n$1" | keepassxc-cli $__yubikey_opt -p "$2" 2>/dev/null)

    _verbose "$__result"
    _success "create keepass database \"$2\""
    _func_end "0" ; return 0 # no _shellcheck
}

_keepassxc_read () {
    _func_start "$@"

    # Check argv
    if ! _exist "$1"; then _error "PASS EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _exist "$2"; then _error "DATABASE EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _exist "$3"; then _error "ENTRY EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _fileexist "$2"; then _error "DATABASE $2 not found"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _installed "keepassxc-cli" ; then _error "keepassxc-cli not found"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi

    local __result
    local __yubikey_opt

    if $YUBIKEY; then __yubikey_opt="show -y 2:$(ykman list -s)" ; else __yubikey_opt="show" ; fi
    # shellcheck disable=2086
    __result=$(echo "$1" | keepassxc-cli $__yubikey_opt -s "$2" "$3" 2>/dev/null)

    if ! _exist "$__result" ; then _error "something went wong in _keepassxc_read"; _func_end "1" ; return 1 ; fi

    echo "$__result"

    _func_end "0" ; return 0 # no _shellcheck
}

_keepassxc_read_password () {
    _func_start "$@"

    # Check argv
    local __result
    local __return

    __result=$(_keepassxc_read "$1" "$2" "$3")
    __return=$? ; if [ $__return -ne 0 ] ; then _error "something went wong in _keepassxc_read_password"; _func_end "$__return" ; return $__return ; fi

    __result=$(echo "$__result" | $GREP -w "Password:" | cut -d\  -f2-99)

    echo "$__result"

    _func_end "0" ; return 0 # no _shellcheck
}

_keepassxc_read_username () {
    _func_start "$@"

    # Check argv
    local __result
    local __return

    __result=$(_keepassxc_read "$1" "$2" "$3")
    __return=$? ; if [ $__return -ne 0 ] ; then _error "something went wong in _keepassxc_read_username"; _func_end "$__return" ; return $__return ; fi

    echo "$__result" | $GREP -w "UserName:" | cut -d\  -f2-99

    _func_end "0" ; return 0 # no _shellcheck
}

_keepassxc_list_attachments () {
    _func_start "$@"

    # Check argv
    if ! _exist "$1"; then _error "PASS EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _exist "$2"; then _error "DATABASE EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _exist "$3"; then _error "ENTRY EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _fileexist "$2"; then _error "DATABASE $2 not found"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _installed "keepassxc-cli" ; then _error "keepassxc-cli not found"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi

    local __result
    local __line
    local __yubikey_opt

    if $YUBIKEY; then __yubikey_opt="show -y 2:$(ykman list -s)" ; else __yubikey_opt="show" ; fi
    # shellcheck disable=2086
    __result=$(echo "$1" | keepassxc-cli $__yubikey_opt --show-attachments -a Tags "$2" "$3" 2>/dev/null)

    if ! _exist "$__result" ; then _error "something went wong in _keepassxc_read"; _func_end "1" ; return 1 ; fi

    echo "$__result" | $GREP -v -w "Attachments:" | awk '{print $1}' | while read -r __line; do
        if [ "a$__line" != "a" ] ; then echo "$__line"; fi
    done

    _func_end "0" ; return 0 # no _shellcheck
}

_keepassxc_restore_attachment () {
    _func_start "$@"

    # Check argv
    if ! _exist "$1"; then _error "PASS EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _exist "$2"; then _error "DATABASE EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _exist "$3"; then _error "ENTRY EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _exist "$4"; then _error "ATTACHMENT EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _exist "$5"; then _error "DEST EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _fileexist "$2"; then _error "DATABASE $2 not found"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _installed "keepassxc-cli" ; then _error "keepassxc-cli not found"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi

    local __result
    local __return
    local __line
    local __yubikey_opt

    if $YUBIKEY; then __yubikey_opt="attachment-export -y 2:$(ykman list -s)" ; else __yubikey_opt="attachment-export" ; fi
    # shellcheck disable=2086
    __result=$(echo "$1" | keepassxc-cli $__yubikey_opt "$2" "$3" "$4" "$5" 2>&1)
    __return=$? ; if [ $__return -ne 0 ] ; then _error "unable to restore $4"; _func_end "$__return" ; return $__return ; fi

    __result=$(echo "$__result" | $GREP -v "Enter password")
    _verbose "$__result"

    _func_end "$__return" ; return $__return # no _shellcheck
}

_keepassxc_add_attachment () {
    _func_start "$@"

    # Check argv
    if ! _exist "$1"; then _error "PASS EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _exist "$2"; then _error "DATABASE EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _exist "$3"; then _error "ENTRY EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _exist "$4"; then _error "ATTACHMENT EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _exist "$5"; then _error "SRC EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _fileexist "$2"; then _error "DATABASE $2 not found"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _installed "keepassxc-cli" ; then _error "keepassxc-cli not found"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi

    local __result
    local __return
    local __line
    local __yubikey_opt

    if $YUBIKEY; then __yubikey_opt="attachment-import -y 2:$(ykman list -s)" ; else __yubikey_opt="attachment-import" ; fi
    # shellcheck disable=2086
    __result=$(echo "$1" | keepassxc-cli $__yubikey_opt "$2" "$3" "$4" "$5" 2>&1)
    __return=$? ; if [ $__return -ne 0 ] ; then _error "unable to add $4"; _func_end "$__return" ; return $__return ; fi

    __result=$(echo "$__result" | $GREP -v "Enter password")
    _verbose "$__result"

    _func_end "$__return" ; return $__return # no _shellcheck
}

_keepassxc_add_group () {
    _func_start "$@"

    # Check argv
    if ! _exist "$1"; then _error "PASS EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _exist "$2"; then _error "DATABASE EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _exist "$3"; then _error "ENTRY EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _fileexist "$2"; then _error "DATABASE $2 not found"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _installed "keepassxc-cli" ; then _error "keepassxc-cli not found"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi

    local __result
    local __return
    local __line
    local __yubikey_opt

    if $YUBIKEY; then __yubikey_opt="mkdir -y 2:$(ykman list -s)" ; else __yubikey_opt="mkdir" ; fi
    # shellcheck disable=2086
    __result=$(echo "$1" | keepassxc-cli $__yubikey_opt "$2" "$3" 2>&1)
    __return=$? ; if [ $__return -ne 0 ] ; then _error "unable to add $3 as group"; _func_end "$__return" ; return $__return ; fi

    __result=$(echo "$__result" | $GREP -v "Enter password")
    _verbose "$__result"
    _success "add group \"$3\""
    _func_end "$__return" ; return $__return # no _shellcheck
}

_keepassxc_add_entry () {
    _func_start "$@"

    # Check argv
    if ! _exist "$1"; then _error "PASS EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _exist "$2"; then _error "DATABASE EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _exist "$3"; then _error "ENTRY EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _fileexist "$2"; then _error "DATABASE $2 not found"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _installed "keepassxc-cli" ; then _error "keepassxc-cli not found"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi

    local __result
    local __return
    local __line
    local __yubikey_opt

    if $YUBIKEY; then __yubikey_opt="add -y 2:$(ykman list -s)" ; else __yubikey_opt="add" ; fi
    # shellcheck disable=2086
    __result=$(echo "$1" | keepassxc-cli $__yubikey_opt "$2" "$3" 2>&1)
    __return=$? ; if [ $__return -ne 0 ] ; then _error "unable to add $3 as entry"; _func_end "$__return" ; return $__return ; fi

    __result=$(echo "$__result" | $GREP -v "Enter password")
    _verbose "$__result"
    _success "add entry \"$3\""
    _func_end "$__return" ; return $__return # no _shellcheck
}

_keepassxc_change_username () {
    _func_start "$@"

    # Check argv
    if ! _exist "$1"; then _error "PASS EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _exist "$2"; then _error "DATABASE EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _exist "$3"; then _error "ENTRY EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _exist "$4"; then _error "ENTRY_USER EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _fileexist "$2"; then _error "DATABASE $2 not found"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _installed "keepassxc-cli" ; then _error "keepassxc-cli not found"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi

    local __result
    local __return
    local __line
    local __yubikey_opt

    if $YUBIKEY; then __yubikey_opt="edit -y 2:$(ykman list -s)" ; else __yubikey_opt="edit" ; fi
    # shellcheck disable=2086
    __result=$(echo -e "$1" | keepassxc-cli $__yubikey_opt "$2" "$3" -u "$4" 2>&1)
    __return=$? ; if [ $__return -ne 0 ] ; then _error "unable to change username for $3"; _func_end "$__return" ; return $__return ; fi

    __result=$(echo "$__result" | $GREP -v "Enter password")
    _verbose "$__result"
    _success "change username of \"$3\" to \"$4\""
    _func_end "$__return" ; return $__return # no _shellcheck
}

_keepassxc_change_password () {
    _func_start "$@"

    # Check argv
    if ! _exist "$1"; then _error "PASS EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _exist "$2"; then _error "DATABASE EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _exist "$3"; then _error "ENTRY EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _exist "$4"; then _error "ENTRY_PASS EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _fileexist "$2"; then _error "DATABASE $2 not found"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _installed "keepassxc-cli" ; then _error "keepassxc-cli not found"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi

    local __result
    local __return
    local __line
    local __yubikey_opt

    if $YUBIKEY; then __yubikey_opt="edit -y 2:$(ykman list -s)" ; else __yubikey_opt="edit" ; fi
    # shellcheck disable=2086
    __result=$(echo -e "$1\n$4" | keepassxc-cli $__yubikey_opt "$2" "$3" -p 2>&1)
    __return=$? ; if [ $__return -ne 0 ] ; then _error "unable to change password for $3"; _func_end "$__return" ; return $__return ; fi

    __result=$(echo "$__result" | $GREP -v "Enter password")
    _verbose "$__result"
    _success "change password of \"$3\" to \"***\""
    _func_end "$__return" ; return $__return # no _shellcheck
}

_gpg_yubikey_reset () {
    _func_start "$@"

    # Check argv
    if ! _installed "ykman" ; then _error "ykman not found"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi

    echo "y" | ykman openpgp reset 2>/dev/null 1>/dev/null

    _func_end "0" ; return 0 # no _shellcheck
}

_gpg_yubikey_change_admin_pin () {
    _func_start "$@"

    # Check argv
    if ! _exist "$1"; then _error "NEW PIN EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _installed "ykman" ; then _error "ykman not found"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi

    local __old_pin
    __old_pin="${2:-12345678}"

    echo -e "admin\npasswd\n3\n$__old_pin\n$1\n$1\nq\nquit\n" | gpg --command-fd=0 --pinentry-mode=loopback --edit-card 2>/dev/null 1>/dev/null

    _func_end "0" ; return 0 # no _shellcheck
}

_gpg_yubikey_change_user_pin () {
    _func_start "$@"

    # Check argv
    if ! _exist "$1"; then _error "NEW PIN EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _installed "ykman" ; then _error "ykman not found"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi

    local __old_pin
    __old_pin="${2:-123456}"

    echo -e "admin\npasswd\n1\n$__old_pin\n$1\n$1\nq\nquit\n" | gpg --command-fd=0 --pinentry-mode=loopback --edit-card 2>/dev/null 1>/dev/null

    _func_end "0" ; return 0 # no _shellcheck
}

_gpg_yubikey_set_retries () {
    _func_start "$@"

    # Check argv
    if ! _exist "$1"; then _error "ADMIN PIN EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _installed "ykman" ; then _error "ykman not found"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi

    local __retries
    __retries="${2:-5}"

    echo "$1" | ykman openpgp access set-retries -f "$__retries" "$__retries" "$__retries"

    _func_end "0" ; return 0 # no _shellcheck
}

_gpg_restore_keys_from_keepass () {
    _func_start "$@"

    # Check argv
    if ! _exist "$1"; then _error "keepassxc password EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _exist "$2"; then _error "keepassxc database EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _installed "gpg" ; then _error "ykman not found"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi

    # Declare local var
    local __line
    local __attachments
    local __fp
    local __entry
    local __dest_dir
    local __return

    # Set local var
    __return="1"
    __dest_dir="${HOME}/.gnupg"
    __entry="keys"
    __attachments=$(_keepassxc_list_attachments "$1" "$2" "$__entry") ; __return=$? ; if [ $__return -ne 0 ] ; then _error "unable to list attachments"; _func_end "$__return" ; return $__return ; fi
    __fp=$(echo "$__attachments" | cut -d- -f1 | sort -u)

    echo "$__attachments" | while read -r __line; do
        if ! _keepassxc_restore_attachment "$1" "$2" "$__entry" "$__line" "$__dest_dir/$__line" ; then _error "unable to restore attachment"; _func_end "$__return" ; return $__return ; fi
        gpg --import "$__dest_dir/$__line" 2>/dev/null 1>/dev/null ; __return=$? ; if [ $__return -ne 0 ] ; then _error "gpg import fails"; _func_end "$__return" ; return $__return ; fi
    done

    echo -e "5\ny\n" | gpg --command-fd 0 --no-tty --batch --expert --edit-key "$__fp" trust 2> /dev/null 1> /dev/null

    _func_end "0" ; return 0 # no _shellcheck
}

_gpg_transfert_keys_to_yubikey () {
    _func_start "$@"

    # Check argv
    if ! _exist "$1"; then _error "keepassxc password EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _exist "$2"; then _error "keepassxc database EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _installed "gpg" ; then _error "gpg not found"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi

    local __return
    local __admin_pin
#    local __passphrase
#    local __passphrase_entry
    local __identity
    local __entry
    local __key_id

    __passphrase_entry="gpg passphrase"
    __entry="key"

    # because we'r unable to put key to yubikey if we'v changed amin pin before, we have to do everything with default pin, then change it
    __admin_pin="12345678"

    #    __passphrase=$(_keepassxc_read_password "$1" "$2" "$__passphrase_entry")
    #    __return=$? ; if [ $__return -ne 0 ] ; then _error "unable to read passphrase from $2"; _func_end "$__return" ; return $__return ; fi

    __identity=$(_keepassxc_read_username "$1" "$2" "$__entry")
    __key_id=$(gpg -k --with-colons "$__identity" | awk -F: '/^pub:/ { print $5; exit }')

    echo -e "key 1\nkeytocard\n1\n$__admin_pin\n$__admin_pin\nsave" | gpg --batch --command-fd=0 --pinentry-mode=loopback --edit-key "$__key_id" 2>/dev/null 1>/dev/null
    echo -e "key 2\nkeytocard\n2\n$__admin_pin\nsave" | gpg --batch --command-fd=0 --pinentry-mode=loopback --edit-key "$__key_id" 2>/dev/null 1>/dev/null
    echo -e "key 3\nkeytocard\n3\n$__admin_pin\nsave" | gpg --batch --command-fd=0 --pinentry-mode=loopback --edit-key "$__key_id" 2>/dev/null 1>/dev/null

    echo -e "admin\nlogin\n$__identity" | gpg --batch --command-fd=0 --pinentry-mode=loopback --edit-card 2>/dev/null 1>/dev/null

    gpg -K

    _func_end "0" ; return 0 # no _shellcheck
}

secret () {
    output="${1}".$(date +%s).enc
    __key_id=$(gpg -k --with-colons | awk -F: '/^pub:/ { print $5; exit }')

    echo "$__key_id"

    gpg --encrypt --armor --output "${output}" -r "$__key_id" "${1}" && echo "${1} -> ${output}"
}

_gpg_yubikey_init_from_keepass () {
    _func_start "$@"

    # Check argv
    if ! _exist "$1"; then _error "keepassxc password EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _exist "$2"; then _error "keepassxc database EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if _fileexist "${HOME}/.gnupg" ; then _error "can't restore on existing ${HOME}/.gnupg, please back it up and remove it"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi

    # Declare local var
    local __return
    local __result
    local __admin_pin_entry
    local __user_pin_entry
    local __admin_pin
    local __user_pin
    local __retries

    # Set local var
    __admin_pin_entry="admin pin"
    __user_pin_entry="user pin"
    __retries="5"
    __admin_pin=$(_keepassxc_read_password "$1" "$2" "$__admin_pin_entry") ; __return=$? ; if [ $__return -ne 0 ] ; then _error "unable to read gpg admin pin from $2"; _func_end "$__return" ; return $__return ; fi
    __user_pin=$(_keepassxc_read_password "$1" "$2" "$__user_pin_entry")   ; __return=$? ; if [ $__return -ne 0 ] ; then _error "unable to read gpg user pin from $2"; _func_end "$__return" ; return $__return ; fi

    # Do what need to be done
    ln -s "${HOME}/git/rc/scdaemon.conf" "${HOME}/.gnupg/scdaemon.conf"
    ln -s "${HOME}/git/rc/gpg.conf" "${HOME}/.gnupg/gpg.conf"
    __result=$(gpg -k 2>/dev/null 1>/dev/null) ; __return=$? ; if [ $__return -ne 0 ] ; then _error "unable to init keyring $__result"; _func_end "$__return" ; return $__return ; fi

    # Reload scdaemon
    gpg-connect-agent "SCD KILLSCD" "SCD BYE" /bye 2>/dev/null 1>/dev/null
    gpg-connect-agent learn /bye 2>/dev/null 1>/dev/null

    __return="1"
    if ! _gpg_yubikey_reset                                     ; then _error "unable to reset yubikey"; _func_end "$__return" ; return $__return ; fi
    if ! _gpg_restore_keys_from_keepass "$1" "$2"               ; then _error "unable to restore keys from keepass"; _func_end "$__return" ; return $__return ; fi
    if ! _gpg_transfert_keys_to_yubikey "$1" "$2"               ; then _error "unable to transfert keys to yubikey"; _func_end "$__return" ; return $__return ; fi
    if ! _gpg_yubikey_change_admin_pin "$__admin_pin"           ; then _error "unable to change admin pin"; _func_end "$__return" ; return $__return ; fi
    if ! _gpg_yubikey_change_user_pin "$__user_pin"             ; then _error "unable to change user pin"; _func_end "$__return" ; return $__return ; fi
    if ! _gpg_yubikey_set_retries "$__admin_pin" "$__retries"   ; then _error "unable to set retries"; _func_end "$__return" ; return $__return ; fi
    __return="0"

    # Show result and exit
    _func_end "$__return" ; return $__return
}

_gpg_init_keepass () {
    _func_start "$@"

    # Check arg
    if ! _exist "$1"; then _error "keepassxc password EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _exist "$2"; then _error "keepassxc database EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi

    # Declare local var
    local __yubikey_toggle
    local __group
    local __entry_keys
    local __identity
    local __passphrase
    local __pin_admin
    local __pin_user
    local __return

    # Set local var
    __yubikey_toggle=$YUBIKEY
    __group="gpg"
    __entry_keys="keys"
    __entry_pin_admin="admin pin"
    __entry_pin_user="user pin"
    __identity="Jacques CRETINON <jacques@cretinon.fr>"
    __passphrase=$(_gen_rand "5" "-" "47")
    __pin_admin=$(_gen_pin "8")
    __pin_user=$(_gen_pin "6")

    # Do what need to be done
    __return="1"
    YUBIKEY=false
    if ! _keepassxc_create_database "$1" "$2"                                          ; then _error "unable to create database"; _func_end "$__return" ; return $__return ; fi
    if ! _keepassxc_add_group "$1" "$2" "$__group"                                     ; then _error "unable to add group"      ; _func_end "$__return" ; return $__return ; fi
    if ! _keepassxc_add_entry "$1" "$2" "$__group/$__entry_keys"                       ; then _error "unable to add entry"      ; _func_end "$__return" ; return $__return ; fi
    if ! _keepassxc_change_username "$1" "$2" "$__group/$__entry_keys" "$__identity"   ; then _error "unable to change username"; _func_end "$__return" ; return $__return ; fi
    if ! _keepassxc_change_password "$1" "$2" "$__group/$__entry_keys" "$__passphrase" ; then _error "unable to change password"; _func_end "$__return" ; return $__return ; fi
    if ! _keepassxc_add_entry "$1" "$2" "$__group/$__entry_pin_admin"                  ; then _error "unable to add entry"      ; _func_end "$__return" ; return $__return ; fi
    if ! _keepassxc_change_password "$1" "$2" "$__group/admin pin" "$__pin_admin"      ; then _error "unable to change password"; _func_end "$__return" ; return $__return ; fi
    if ! _keepassxc_add_entry "$1" "$2" "$__group/$__entry_pin_user"                   ; then _error "unable to add entry"      ; _func_end "$__return" ; return $__return ; fi
    if ! _keepassxc_change_password "$1" "$2" "$__group/user pin" "$__pin_user"        ; then _error "unable to change password"; _func_end "$__return" ; return $__return ; fi
    YUBIKEY=$__yubikey_toggle
    __return="0"

    # Show result and exit
    _success "init keepass ok"
    _func_end "$__return" ; return $__return
}

_gnupg () {
    _func_start "$@"

    # Check argv
    if ! _exist "$1"; then _error "keepassxc password EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _exist "$2"; then _error "keepassxc database EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if _fileexist "${HOME}/.gnupg" ; then _error "can't create on existing ${HOME}/.gnupg, please back it up and remove it"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _installed "gpg" ; then _error "gpg not found"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! gpg --card-status 2>/dev/null 1>/dev/null ; then _error "No Yubikey found" ; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi




    local __key_type
    local __expiration
    local __passphrase
    local __key_id
    local __key_fp


    __key_type="${3:-rsa4096}"
    __expiration="${4:-53y}"
    __passphrase="$1"

    echo "$__passphrase" | gpg --batch --passphrase-fd 0 --quick-generate-key "$__identity" "$__key_type" cert never

    __key_id=$(gpg -k --with-colons "$__identity" | awk -F: '/^pub:/ { print $5; exit }')
    __key_fp=$(gpg -k --with-colons "$__identity" |  awk -F: '/^fpr:/ { print $10; exit }')

    printf "\nKey ID/Fingerprint: %20s/%s\n\n" "$__key_id" "$__key_fp"

    echo "$__passphrase" | gpg --batch --pinentry-mode=loopback --passphrase-fd 0 --quick-add-key "$__key_fp" "$__key_type" sign "$__expiration"
    echo "$__passphrase" | gpg --batch --pinentry-mode=loopback --passphrase-fd 0 --quick-add-key "$__key_fp" "$__key_type" encrypt "$__expiration"
    echo "$__passphrase" | gpg --batch --pinentry-mode=loopback --passphrase-fd 0 --quick-add-key "$__key_fp" "$__key_type" auth "$__expiration"

    gpg -K

    echo "$__passphrase" | gpg --output "${HOME}/.gnupg/$__key_id"-Certify.key --batch --pinentry-mode=loopback --passphrase-fd 0 --armor --export-secret-keys "$__key_id"
    echo "$__passphrase" | gpg --output "${HOME}/.gnupg/$__key_id"-Subkeys.key --batch --pinentry-mode=loopback --passphrase-fd 0 --armor --export-secret-subkeys "$__key_id"

    gpg --output "${HOME}/.gnupg/$__key_id-$(date +%F).asc" --armor --export "$__key_id"

    _func_end "0" ; return 0 # no _shellcheck
}

#
# usage: _decrypt_file --file ($1) --passphrase ($2) --remove-src ($3)
#
_decrypt_file () {
    _func_start "$@"

    # Check argv
    if ! _exist "$1"; then _error "FILE EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _exist "$2"; then _error "PASSPHRASE EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _exist "$3"; then _error "REMOVE-SRC EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _fileexist "$1"; then _error "FILE NOT EXIST:$1"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _installed "gpg" ; then _error "gpg not found"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi

    local __return

    _verbose "decrypting :$1"
    gpg --batch --passphrase "$2" "$1" 2> /dev/null
    __return=$? # no _shellcheck

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
    _func_start "$@"

    # Check argv
    if ! _exist "$1"; then _error "DIRECTORY EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _exist "$2"; then _error "PASSPHRASE EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _exist "$3"; then _error "REMOVE-SRC EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _fileexist "$1"; then _error "DIRECTORY NOT EXIST:$1"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _installed "gpg" ; then _error "gpg not found"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi

    local __file

    for __file in $(find "$1" -type f | $GREP "\.asc" ); do
        if ! _decrypt_file "$__file" "$2" "$3"; then _error "something went wrong when decrypt file" ; _func_end "1" ; return 1 ; fi
    done

    _func_end "0" ; return 0 # no _shellcheck
}

#
# usage: _encrypt_file --file ($1) --passphrase ($2) --remove-src ($3)
#
_encrypt_file () {
    _func_start "$@"

    # Check argv
    if ! _exist "$1"; then _error "FILE EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _exist "$2"; then _error "PASSPHRASE EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _exist "$3"; then _error "REMOVE-SRC EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _fileexist "$1"; then _error "FILE NOT EXIST:$1"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _installed "gpg" ; then _error "gpg not found"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi

    local __return

    _verbose "encrypting :$1"
    gpg -c --cipher-algo AES256 --compress-algo 1 --batch --passphrase "$2" "$1" 2> /dev/null
    __return=$? # no _shellcheck

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
    _func_start "$@"

    # Check argv
    if ! _exist "$1"; then _error "DIRECTORY EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _exist "$2"; then _error "PASSPHRASE EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _exist "$3"; then _error "REMOVE-SRC EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _fileexist "$1"; then _error "DIRECTORY NOT EXIST:$1"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _installed "gpg" ; then _error "gpg not found"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi

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
    _func_start "$@"

    # Check argv
    local __files

    if ! _exist "$LIB" ; then
        __files="$*"
    else
        if _exist "$LIB" && ! _fileexist "$MY_GIT_DIR/$LIB/lib_$LIB.sh" ;then _error "lib file not found" ; _usage; _func_end "1" ; return 1 ; fi
        __files=$(find "$MY_GIT_DIR"/"$LIB"/ -type f | $GREP -v "entry" | $GREP "\.sh" | tr '\n' ' '  )
    fi

    if ! _installed "shellcheck"; then _error "shelcheck not found" , _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi

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
        if $GREP --line-number -w "\$?" $__files | $GREP -v "_error" | $GREP -v "break" | $GREP -v "no _shellcheck" ; then  # no _shellcheck
            _error "we must test \$? and have _error if smth goes wrong" ; _func_end "1" ; return 1
        fi
        echo "no error found with shellcheck in $__files";
    else
        _error "something went wrong with shellcheck"; _func_end "1" ; return 1
    fi
}

_bats () {
    _func_start "$@"

    # Check argv
    if ! _exist "$LIB"; then _error "no LIB found"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi

    if _exist "$LIB" && ! _fileexist "$MY_GIT_DIR/$LIB/lib_$LIB.sh"; then _error "lib file not found" ;  _usage; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi

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
    _func_start "$@"

    # Check argv
    if ! _exist "$LIB"; then _error "no LIB found"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _installed "kcov"; then _error "kcov not found"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi

    local __tmp
    local __upload=true

    if ! _installed "codecov"; then _warning "codecov not found, no uploading"; __upload=false ; fi
    if ! _exist "$CODECOV_TOKEN"; then _warning "no CODECOV_TOKEN found, no uploading"; __upload=false ; fi
    if ! _exist "$GITHUB_USERNAME"; then _warning "no GITHUB_USERNAME found, no uploading"; __upload=false ; fi

    if ! __tmp=$(_tmp_file) ; then _error "something went wrong in _tmp_file"; _func_end "1" ; return 1 ; fi

    _debug "tmp dir:$__tmp"

    if ! $DRY_RUN ; then
        kcov --exclude-path="$MY_GIT_DIR/$LIB/.git/,$MY_GIT_DIR/$LIB/README.md,/usr/,$MY_GIT_DIR/$LIB/.codecov.yml,$MY_GIT_DIR/$LIB/.pre-commit-config.yaml" --include-path="$MY_GIT_DIR/$LIB" "$__tmp" "$MY_GIT_DIR/shell/my_warp.sh" --lib "$LIB" -b

        jq -r ".files | .[]" "$__tmp/my_warp.sh/coverage.json" | jq -r '.file + " " + .percent_covered'

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
############################################## ADMIN ###############################################
####################################################################################################
_id () {
    _func_start "$@"

    # Declare local var

    local __return
    local __result

    __return="1"


    # Do what need to do

    __result=$(id -u)
    __return=$? ; if [ $__return -ne 0 ] ; then _error "unable to check id"; _func_end "$__return" ; return $__return ; fi


    # Show result and exit

    echo "$__result"

    _func_end "$__return" ; return $__return
}

#
# usage: _service_list
#
_service_list () {
    _func_start "$@"

    # Check argv
    local __return
    local __result

    __result=$(systemctl list-units --type=service --all --no-pager 2>&1)
    __return=$? ; if [ $__return -ne 0 ] ; then _error "unable to list services"; _func_end "$__return" ; return $__return ; fi

    if echo "$__result" | $GREP "System has not been booted with systemd as init system" ; then _warning "we'r in CI or container, no systemd" ; __return=0 ; else echo "$__result" ; fi

    _func_end "$__return" ; return $__return
}

#
# usage: _service_search --service ($1)
#
_service_search () {
    _func_start "$@"

    # Check argv
    if ! _exist "$1"; then _error "SERVICE EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi

    local __return
    local __result

    __result=$(_service_list 2>&1)
    __return=$? ; if [ $__return -ne 0 ] ; then _error "something went wrong in _service_list"; _func_end "$__return" ; return $__return ; fi

    if echo "$__result" | $GREP "we'r in CI or container, no systemd" ; then _warning "we'r in CI or container, no systemd" ; __return=0 ; else echo "$__result" | $GREP -i "$1" ; __return=$? ; fi # no _shellcheck


    _func_end "$__return" ; return $__return
}

####################################################################################################
######################################### INTERACTIVE ASK ##########################################
####################################################################################################
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
            if ! _installed "whiptail"; then _error "whiptail not found"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi # no _shellcheck

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

    _func_end "0" ; return 0 # no _shellcheck
}

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

    _func_end "0" ; return 0 # no _shellcheck
}

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

    _func_end "0" ; return 0 # no _shellcheck
}

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

    _func_end "0" ; return 0 # no _shellcheck
}

####################################################################################################
######################################### EVERYTHING ELSE ##########################################
####################################################################################################
_check_cache_or_force () {
    _func_start "$@"

    # Check argv
    if ! _exist "$1"; then _error "FILE EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi

    if "$FORCE" ; then
        _debug "FORCE getting $2"
        _func_end "1" ; return 1 # no _shellcheck
    else
        if ! _fileexist "$1" ; then
            _debug "$1 not exist, getting it"
            _func_end "1" ; return 1 # no _shellcheck
        else
            _debug "$1 exist, using cache"
            _func_end "0" ; return 0 # no _shellcheck
        fi
    fi
}


_os_arch () {
    _func_start "$@"

    uname -m

    _func_end "0" ; return 0 # no _shellcheck
}

#
# usage: _rsync --src ($1) --dst ($2) --src-list ($3) --exc-list ($4)
#
_rsync () {
    _func_start "$@"

    # Check arg
    if ! _exist "$1"; then _error "SRC EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _exist "$2"; then _error "DST EMPTY"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _remotefileexist "$1" ; then _error "SRC does not exist"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if _exist "$3"; then if ! _fileexist "$3"; then _error "SRC-LIST not found"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi ; fi
    if _exist "$4"; then if ! _fileexist "$4"; then _error "EXC-LIST not found"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi ; fi
    if ! _fileexist "$1"; then _error "SRC not found"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi
    if ! _installed "rsync" ; then _error "rsync not found"; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV ; fi

    # Declare local var
    local __return
    local __result
    local __rsync_cmd

    # Set local var
    __return="1"
    __rsync_cmd="rsync -HaRov --stats"

    # Do what need to be done
    if _exist "$3"; then __rsync_cmd="$__rsync_cmd --files-from=$3" ; fi
    if _exist "$4"; then __rsync_cmd="$__rsync_cmd --exclude-from=$4" ; fi
    echo "$__rsync_cmd $1 $2"

    __result=$($__rsync_cmd "$1" "$2")
    __return=$? ; if [ $__return -ne 0 ] ; then _error "unable to rsync"; _func_end "$__return" ; return $__return ; fi

    # Return result and exit
    echo "$__result"

    _success "rsync"
    _func_end "$__return" ; return $__return
}

#
# usage: _hello_world
#
_hello_world () {
    _func_start "$@"

    local __tmp

    echo "Hello world"

    _success "Hello world"
    _verbose "Hello world"
    _info "Hello world"
    _warning "Hello world"
    _error "Hello world" # no _shellcheck

    _func_end "0" ; return 0 # no _shellcheck
}

####################################################################################################
############################################# PROCESS ##############################################
####################################################################################################
_process_lib_shell () {
    _func_start "$@"

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
    local __src
    local __dst
    local __src_list
    local __exc_list

    while true; do
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
            --src )            __src=$2          ; shift ; shift         ;;
            --dst )            __dst=$2          ; shift ; shift         ;;
            --src-list )       __src_list=$2     ; shift ; shift         ;;
            --exc-list )       __exc_list=$2     ; shift ; shift         ;;
            -- )                                   break ;;
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
            rsync)             _rsync             "$__src" "$__dst" "$__src_list" "$__exc_list"  ; __return=$? ; break ;;
            -- ) shift ;;
            *) _error "command $1 not found" ; __return=1 ; break ;;
        esac
    done

    _func_end "$__return" ; return "$__return"
}
