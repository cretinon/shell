#!/bin/bash

# shellcheck source=/dev/null

if [ -e "${HOME}/conf/my_warp.conf" ]; then
    source "${HOME}/conf/my_warp.conf"

    export VERBOSE
    export DEBUG
    export FUNC_LIST
    unset LIB
    export MY_GIT_DIR
    export CUR_NAME="${0##*/}"

    # load our shell functions and all libs
    if [ -e "$MY_GIT_DIR/shell/lib_shell.sh" ]; then
        source "$MY_GIT_DIR"/shell/lib_shell.sh
        _load_libs

        _debug "debug:$DEBUG"
        _verbose "verbose:$VERBOSE"
        _verbose "MY_GIT_DIR:$MY_GIT_DIR"

        # process options
        if _process_opts "$@" ; then
            if _exist "$LIB"; then
                if _func_exist _process_lib_"$LIB"; then
                    _process_lib_"$LIB" "$OPTS"
                else
                    _warning "_process_lib_$LIB does not exist"
                fi
            fi
        fi
    else
        echo "$MY_GIT_DIR/shell/lib_shell.sh does not exist"
    fi
else
    echo "${HOME}/conf/my_warp.conf does not exist"
fi
