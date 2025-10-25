#!/usr/bin/env bats

# global var
VERBOSE=false
DEBUG=false
FUNC_LIST=()
unset LIB
#GIT_DIR="${HOME}project/git"
CUR_NAME=${FUNCNAME[0]}

# load our shell functions and all libs
source $GIT_DIR/shell/lib_shell.sh
#_load_libs

setup() {
    load '/usr/lib/bats/bats-support/load'
    load '/usr/lib/bats/bats-assert/load'
}

####################################################################################################
########################################### PROCESS OPTS ###########################################
####################################################################################################

@test "_getopt_short" {
  run _getopt_short
  [ "$output" = "h,v,d,b,s" ]
}

@test "_getopt_long" {
  run _getopt_long
  [[ "$output" = *"shell:"*"debug,verbose,help,list-libs,bats,shellcheck,"*"data:,directory:,file:,header:,header-data:,method:,network:,passphrase:,remove-src:,url:"*"lib:" ]]
}

@test "list-libs" {
  run $GIT_DIR/shell/my_warp.sh -v --list-libs
  assert_output --partial 'shell'
}

@test "shellcheck" {
  run $GIT_DIR/shell/my_warp.sh -v --lib shell -s
  assert_success
}



####################################################################################################
############################################## USAGES ##############################################
####################################################################################################

@test "usage" {
  run $GIT_DIR/shell/my_warp.sh -v -h
  assert_output "Usage :
* This help                          => my_warp.sh -h | --help
* Verbose                            => my_warp.sh -v | --verbose
* Debug                              => my_warp.sh -d | --debug
* Bats                               => my_warp.sh -b | --bats
* Use any lib                        => my_warp.sh --lib lib_name
* List avaliable libs                => my_warp.sh --list-libs"
}

@test "usage libshell" {
  run $GIT_DIR/shell/my_warp.sh -v --lib shell -h
  assert_output "my_warp.sh --lib shell curl --method  --url  --header  --header-data  --data
my_warp.sh --lib shell decrypt_directory --directory  --passphrase  --remove-src
my_warp.sh --lib shell decrypt_file --file  --passphrase  --remove-src
my_warp.sh --lib shell encrypt_directory --directory  --passphrase  --remove-src
my_warp.sh --lib shell encrypt_file --file  --passphrase  --remove-src
my_warp.sh --lib shell hello_world
my_warp.sh --lib shell host_up_show --network (192.168.1.0/24)"
}

####################################################################################################
######################################### LOAD LIBS & CONF #########################################
####################################################################################################

@test "_load_lib => true" {
  run _load_lib shell
  assert_success
}

@test "_load_lib => false" {
  run _load_lib this_lib_doesnot_exist
  assert_failure
}

@test "_load_lib => empty" {
  run _load_lib
  assert_failure
}

@test "_load_conf => true" {
  run _load_conf ${HOME}/conf/my_warp.conf

  assert_success
}

@test "_load_conf => false" {
  run _load_conf this_conf_doesnot_exist
  assert_failure
}

@test "_load_conf => empty" {
  run _load_conf
  assert_failure
}

@test "_get_installed_libs" {
  run _get_installed_libs
  [[ "$output" == *"shell"* ]]
}

####################################################################################################
######################################### DEBUG MANAGEMENT #########################################
####################################################################################################

@test "_warning" {
  run _warning "hello world"
  assert_output --partial "hello world"
}

####################################################################################################
############################################ SIMPLE TEST ###########################################
####################################################################################################

@test "_func_exist => true" {
  run _func_exist "_func_exist"
  assert_success
}

@test "_func_exist => false" {
  run _func_exist "_this_func_doesnot_exist"
  assert_failure
}

@test "_start_with => true" {
  run _startswith "-toto" "-"
  assert_success
}

@test "_start_with => false" {
  run _startswith "-toto" "*"
  assert_failure
}

@test "_notstartswith => true" {
  run _notstartswith "-toto" "*"
  assert_success
}

@test "_notstartswith => false" {
  run _notstartswith "-toto" "-"
  assert_failure
}

@test "_exist => true" {
  local this_var_exist=1
  run _exist $this_var_exist
  assert_success
}

@test "_exist => false" {
  run _exist $this_var_doesnot_exist
  assert_failure
}

@test "_notexist => true" {
  local this_var_exist=1
  run _notexist $this_var_exist
  assert_failure
}

@test "_notexist => false" {
  run _notexist $this_var_doesnot_exist
  assert_success
}

@test "_installed => true" {
  run _installed "bats"
  assert_success
}

@test "_installed => false" {
  run _installed "batse"
  assert_failure
}

@test "_notinstalled => true" {
  run _notinstalled "batse"
  assert_success
}

@test "_notinstalled => false" {
  run _notinstalled "bats"
  assert_failure
}

@test "_fileexist => true" {
  run _fileexist "$GIT_DIR/shell/lib_shell.sh"
  assert_success
}

@test "_fileexist => false" {
  run _fileexist "$GIT_DIR/shell/lib_shell.sh2"
  assert_failure
}

@test "_filenotexist => true" {
  run _filenotexist "$GIT_DIR/shell/lib_shell.sh2"
  assert_success
}

@test "_filenotexist => false" {
  run _filenotexist "$GIT_DIR/shell/lib_shell.sh"
  assert_failure
}

@test "_workingdir_isnot => true" {
  run _workingdir_isnot "/tmp"
  assert_success
}

@test "_workingdir_isnot => false" {
  run _workingdir_isnot $PWD
  assert_failure
}

@test "_raspberry" {
  run _raspberry
  assert_failure
}

@test "_x86_64" {
  run _x86_64
  assert_success
}

####################################################################################################
######################################## STRING MANAGEMENT #########################################
####################################################################################################

@test "_upper" {
  run _upper "azerty*é"
  assert_output "AZERTY*é"
}

@test "| _upper" {
  run echo $(echo "azerty*é" | _upper)
  assert_output "AZERTY*é"
}

@test "_lower" {
  run _lower "AZERTY*é"
  assert_output "azerty*é"
}

@test "| _lower" {
  run echo $(echo "AZERTY*é" | _lower)
  assert_output "azerty*é"
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

@test "_encrypt_file" {
  rm -rf /tmp/somefile.*
  echo "some text" > /tmp/somefile.txt
  run _encrypt_file /tmp/somefile.txt "changeme" false
  assert_success
}

@test "_encrypt_file => dest_file already exist" {
  echo "some text" > /tmp/somefile.txt
  run $GIT_DIR/shell/my_warp.sh -v --lib shell encrypt_file --file /tmp/somefile.txt --passphrase "changeme" --remove-src false
  assert_failure 2
}

@test "_decrypt_file" {
  rm -rf /tmp/somefile.txt
  run _decrypt_file /tmp/somefile.txt.gpg "changeme" false
  assert_success
}

@test "_decrypt_file => dest_file already exist" {
  run $GIT_DIR/shell/my_warp.sh -v --lib shell decrypt_file --file /tmp/somefile.txt.gpg --passphrase "changeme" --remove-src false
  assert_failure 2
}

@test "_encrypt_directory" {
  rm -rf /tmp/somedir
  mkdir /tmp/somedir/
  echo "some text" > /tmp/somedir/somefile1.txt
  echo "some text" > /tmp/somedir/somefile2.txt
  run _encrypt_directory /tmp/somedir "changeme" false
  assert_success
}

@test "_encrypt_directory => dest_file already exist" {
  run $GIT_DIR/shell/my_warp.sh -v --lib shell encrypt_directory --directory /tmp/somedir --passphrase "changeme" --remove-src false
  assert_failure
}

@test "_decrypt_directory" {
  rm -rf /tmp/somedir/*.txt
  run _decrypt_directory /tmp/somedir "changeme" false
  assert_success
}

@test "_decrypt_directory => dest_file already exist" {
  run $GIT_DIR/shell/my_warp.sh -v --lib shell decrypt_directory --directory /tmp/somedir --passphrase "changeme" --remove-src false
  assert_failure 1
}

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

@test "_hello_world" {
  run $GIT_DIR/shell/my_warp.sh -d -v --lib shell hello_world
  assert_line --index 1 --partial 'VERBOSE'
  assert_line --index 2 --partial 'WARNING'
  assert_line --index 3 --partial 'ERROR'
}