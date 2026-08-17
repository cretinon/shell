#!/bin/bash

# shellcheck source=/dev/null disable=SC2119,SC2120,SC2294,SC2001,SC2045,SC2184,SC2059,SC2034

GETOPT_SHORT_SHELL=h,v,d,b,s,k


ERROR_ARGV=10

GREP="/usr/bin/grep --text" # no _shellcheck
EGREP="/usr/bin/grep --text" # no _shellcheck

####################################################################################################
############################################ SIMPLE TEST ###########################################
####################################################################################################

_notstartswith() {
    if _startswith "$1" "$2"; then return 1; else return 0; fi
}

_notexist () {
    if [[ -z "$1" ]] ; then return 0; else return 1; fi
}

_notinstalled () {
    if type "$1" 2> /dev/null 1>/dev/null ; then return 1; else return 0; fi
}

_filenotexist () {
    if [ -e "$1" ]; then return 1; else return 0; fi
}

_workingdir_isnot () {
    if [ "a$PWD" = "a$1" ]; then return 1; else return 0; fi
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
        0) if "$3" ; then _verbose "Removing :" "$1"; rm -rf "$1" ; fi ; _func_end "$__return" ; return $__return ;;
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
        0) if "$3" ; then _verbose "Removing :" "$1"; rm -rf "$1" ; fi ; _func_end "$__return" ; return $__return ;;
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
# usage: _opentofu_install
#
_opentofu_install () {
    _func_start "$@"

    # Check OS (must be Debian 13)
    if [ -f /etc/os-release ]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        if [ "$ID" != "debian" ] || [ "$VERSION_ID" != "13" ]; then
            _error "This function only supports Debian 13. Detected ID=$ID, VERSION_ID=$VERSION_ID" ; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV
        fi
    else
        _error "Cannot determine OS, /etc/os-release is missing." ; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV
    fi

    # Check privileges (must be root)
    if [ "$(_id)" -ne "0" ]; then
        _error "must be root" ; _func_end "$ERROR_ARGV" ; return $ERROR_ARGV
    fi

    _info "Installing OpenTofu prerequisites..."
    apt-get update
    apt-get install -y apt-transport-https ca-certificates curl gnupg # no _shellcheck

    _info "Adding OpenTofu GPG keys..."
    install -m 0755 -d /etc/apt/keyrings
    _curl "GET" "https://get.opentofu.org/opentofu.asc" | gpg --dearmor | tee /etc/apt/keyrings/opentofu.gpg >/dev/null
    _curl "GET" "https://packages.opentofu.org/opentofu/tofu/gpgkey" | gpg --dearmor | tee /etc/apt/keyrings/opentofu-archive-keyring.gpg >/dev/null

    _info "Adding OpenTofu APT repositories..."
    echo "deb [signed-by=/etc/apt/keyrings/opentofu.gpg,/etc/apt/keyrings/opentofu-archive-keyring.gpg] https://packages.opentofu.org/opentofu/tofu/any/ any main" | tee /etc/apt/sources.list.d/opentofu.list >/dev/null
    echo "deb-src [signed-by=/etc/apt/keyrings/opentofu.gpg,/etc/apt/keyrings/opentofu-archive-keyring.gpg] https://packages.opentofu.org/opentofu/tofu/any/ any main" | tee -a /etc/apt/sources.list.d/opentofu.list >/dev/null

    _info "Updating package lists and installing OpenTofu (tofu)..."
    apt-get update
    if apt-get install -y tofu; then
        _success "OpenTofu installed successfully!" ; _func_end "0" ; return 0 # no _shellcheck
    else
        _error "Failed to install tofu package" ; _func_end "1" ; return 1
    fi
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
            opentofu_install)  _opentofu_install                                                 ; __return=$? ; break ;;
            -- ) shift ;;
            *) _error "command $1 not found" ; __return=1 ; break ;;
        esac
    done

    _func_end "$__return" ; return "$__return"
}
