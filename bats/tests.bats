#!/usr/bin/env bats

# global var
VERBOSE=false
DEBUG=false
FUNC_LIST=()
unset LIB
#GIT_DIR="${HOME}/project/git"
CUR_NAME=${FUNCNAME[0]}

# load our shell functions and all libs
source $GIT_DIR/shell/lib_shell.sh
#_load_libs

setup() {
    load '/usr/lib/bats/bats-support/load'
    load '/usr/lib/bats/bats-assert/load'
}

@test "_getopt_short" {
  run _getopt_short
  [ "$output" = "h,v,d,b,s" ]
}

@test "_getopt_long" {
  run _getopt_long
  [[ "$output" = *"shell:"*"debug,verbose,help,list-libs,bats,shellcheck,"*"data:,directory:,file:,header:,header-data:,method:,network:,passphrase:,remove-src:,url:"*"lib:" ]]
}

@test "_get_installed_libs" {
  run _get_installed_libs
  [[ "$output" == *"shell"* ]]
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

####################################################################################################
######################################## STRING MANAGEMENT #########################################
####################################################################################################

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

####################################################################################################
######################################## ARRAY MANAGEMENT ##########################################
####################################################################################################

@test "_array_print" {
  local __my_array
  __my_array=(obj1 obj2 "obj 3" obj4)
  run _array_print __my_array
  assert_output "[0]:obj1
[1]:obj2
[2]:obj 3
[3]:obj4"
}

@test "_array_print_index" {
  local __my_array
  __my_array=(obj1 obj2 "obj 3" obj4)
  run _array_print_index __my_array "1"
  assert_output "obj2"
}

@test "_array_add" {
  local __my_array
  __my_array=(obj1 obj2 "obj 3" obj4)
  _array_add __my_array "obj 5"
  run _array_print __my_array
  assert_output "[0]:obj1
[1]:obj2
[2]:obj 3
[3]:obj4
[4]:obj 5"
}

@test "_array_remove_last" {
  local __my_array
  __my_array=(obj1 obj2 "obj 3" obj4)
  _array_remove_last __my_array
  run _array_print __my_array
  assert_output "[0]:obj1
[1]:obj2
[2]:obj 3"
}

@test "_array_remove_index" {
  local __my_array
  __my_array=(obj1 obj2 "obj 3" obj4)
  _array_remove_index __my_array "1"
  run _array_print __my_array
  assert_output "[0]:obj1
[1]:obj 3
[2]:obj4"
}

@test "_array_count_elt" {
  local __my_array
  __my_array=(obj1 obj2 "obj 3" obj4)
  run _array_count_elt __my_array
  assert_output "4"
}

####################################################################################################
############################################## CRYPT ###############################################
####################################################################################################

####################################################################################################
######################################### EVERYTHING ELSE ##########################################
####################################################################################################

#@test "_curl GET good url" {
#  result=$(_curl "GET" "https://www.gnupg.org/"  |md5sum)
#  [ "$result" = "c49a6f9cd6991ff92c8e7a5e11377175  -" ]
#}

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
