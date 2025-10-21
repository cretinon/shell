#!/usr/bin/env bats

# global var
VERBOSE=false
DEBUG=false
FUNC_LIST=()
unset LIB
GIT_DIR="${HOME}/git"
CUR_NAME=${FUNCNAME[0]}

# load our shell functions and all libs
source $GIT_DIR/shell/lib_shell.sh
_load_libs

@test "_func_exist => true" {
  if _func_exist "_func_exist"; then result=true; else result=false;fi
  ($result)
}

@test "_func_exist => false" {
  if _func_exist "_func_not_exist"; then result=false; else result=true;fi
  ($result)
}

@test "_start_with => true" {
  if _startswith "-toto" "-" ; then result=true; else result=false;fi
  ($result)
}

@test "_start_with => false" {
  if _startswith "-toto" "*" ; then result=false; else result=true;fi
   ($result)
}

@test "_upper" {
  result="$(_upper azerty)"
  [ "$result" = "AZERTY" ]
}

@test "_upper pipe" {
  result="$(echo azerty | _upper)"
  [ "$result" = "AZERTY" ]
}
