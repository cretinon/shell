#!/usr/bin/env bats

# global var
VERBOSE=false
DEBUG=false
FUNC_LIST=()
unset LIB
GIT_DIR="${HOME}/project/git"
CUR_NAME=${FUNCNAME[0]}

# load our shell functions and all libs
source $GIT_DIR/shell/lib_shell.sh
_load_libs

@test "_getopt_short" {
  run _getopt_short
  [ "$output" = "h,v,d,b" ]
}

@test "_getopt_long" {
  run _getopt_long
  [ "$output" = "ansible:,shell:,storm:,debug,verbose,help,list-libs,bats,data:,directory:,file:,header:,header-data:,method:,network:,passphrase:,remove-src:,url:,category:,customer:,dashboardid:,destdir:,exclude:,filter:,force:,metric:,scope_name:,scope_techno:,scope_type:,scope_uuid:,tagid:,techno:,toolbox:,type:,lib:" ]
}

@test "_get_installed_libs" {
  run _get_installed_libs
  [ "$output" = "ansible shell storm" ]
}

@test "_x86_64" {
  if _x86_64; then result=true; else result=false;fi
  ($result)
}

@test "_raspberry" {
  if ! _raspberry; then result=true; else result=false;fi
  ($result)
}

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
  result="$(_upper azerty*é)"
  [ "$result" = "AZERTY*é" ]
}

@test "_upper pipe" {
  result="$(echo azerty*é | _upper)"
  [ "$result" = "AZERTY*é" ]
}

@test "_lower" {
  result="$(_lower AZERTY*é)"
  [ "$result" = "azerty*é" ]
}

@test "_lower pipe" {
  result="$(echo AZERTY*é | _lower)"
  [ "$result" = "azerty*é" ]
}

@test "_curl GET good url" {
  result=$(_curl "GET" "https://www.gnupg.org/"  |md5sum)
  [ "$result" = "c49a6f9cd6991ff92c8e7a5e11377175  -" ]
}

@test "_curl GET wrong url" {
  run _curl "GET" "https://www.gnupgdsdss.org/"
  expected=$(echo -e "$CHECK_KO DNS error for curl")
  [ "$output" = "$expected" ]
}

@test "_curl GET good url with header" {
  run _curl "GET" "https://reqbin.com/echo" "User-Agent:"
  echo $output > /tmp/titi
  result=$(_curl "GET" "https://reqbin.com/echo" "User-Agent:" |md5sum)
#  [ "$result" = "2b50b1818834b647a843cc1861dfe430  -" ]
}
