#!/bin/bash

# shellcheck source=/dev/null

_main () {
    _func_start

    local __return=0

    if ! _process_opts "$@"; then _error "Process exited abnormally" ; _func_end "1" ; return 1 ; fi
    if ! $ACTION ; then
        if ! _exist "$LIB" ; then _error "B" ; _func_end "1" ; return 1 ; fi
        if ! _func_exist _process_lib_"$LIB"; then _error "no such lib:$LIB" ; _func_end "1" ; return 1 ; fi
        _process_lib_"$LIB" "$OPTS"
        __return=$? ; if [ $__return -ne 0 ] ; then _error "something went wrong while processing LIB $LIB"; _func_end "$__return" ; return $__return ; fi
    fi

    _func_end "$__return" ; return $__return
}

if [ -e "${HOME}/conf/my_warp.conf" ]; then
    source "${HOME}/conf/my_warp.conf"

    export VERBOSE=false
    export DEBUG=false
    export DRY_RUN=false
    export DEFAULT=false
    export FORCE=false
    export FUNC_LIST=("my_warp.sh")
    unset LIB
    export MY_GIT_DIR
    export CUR_NAME="${0##*/}"
    export ACTION=false

    # load our shell functions and all libs
    if [ -e "$MY_GIT_DIR/shell/lib_shell.sh" ]; then
        source "$MY_GIT_DIR"/shell/lib_shell.sh
        _load_libs

        _main "$@"
    else
        echo "$MY_GIT_DIR/shell/lib_shell.sh does not exist"
    fi
else
    echo "${HOME}/conf/my_warp.conf does not exist"
fi
