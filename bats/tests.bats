#!/usr/bin/env bats

# global var
VERBOSE=false
DEBUG=false
DEFAULT=false
YUBIKEY=false
FUNC_LIST=()
unset LIB
CUR_NAME=${FUNCNAME[0]}

# load our shell functions and all libs
source $MY_GIT_DIR/shell/lib_shell.sh

CHECK_KO="[KO]"
CHECK_WARN="[WARN]"
CHECK_INFO="[INFO]"


setup() {
    load '/usr/lib/bats/bats-support/load'
    load '/usr/lib/bats/bats-assert/load'
}

####################################################################################################
########################################### PROCESS OPTS ###########################################
####################################################################################################

@test "_getopt_short" {
  run _getopt_short
  [ "$output" = "h,v,d,b,s,k" ]
}

@test "_getopt_long" {
  run _getopt_long
  [[ "$output" = *"shell:"*"debug,verbose,help,list-libs,bats,shellcheck,kcov,dry-run"*"data:,directory:,file:,header:,header-data:,method:,network:,passphrase:,remove-src:,service:,url:"*"lib:" ]]
}

@test "list-libs" {
  run $MY_GIT_DIR/shell/my_warp.sh -v --list-libs
  assert_output --partial 'shell'
}

@test "shellcheck" {
  run $MY_GIT_DIR/shell/my_warp.sh -v --lib shell -s
  assert_success
}

####################################################################################################
############################################## USAGES ##############################################
####################################################################################################

@test "usage" {
  run $MY_GIT_DIR/shell/my_warp.sh -v -h
  assert_output "Usage :
  * This help                          => my_warp.sh -h | --help
  * Verbose                            => my_warp.sh -v | --verbose
  * Debug                              => my_warp.sh -d | --debug
  * Dry run                            => my_warp.sh --dry-run
  * Select default values when asked   => my_warp.sh --default
  * Force action                       => my_warp.sh --force
  * Use a Yubikey                      => my_warp.sh --yubikey
  * List avaliable libs                => my_warp.sh --list-libs
  * Use any lib                        => my_warp.sh --lib lib_name
  * Bash Automated Testing System      => my_warp.sh -b | --bats --lib lib_name
  * Shell Syntax Checking              => my_warp.sh -s | --shellcheck --lib lib_name
  * Code coverage                      => my_warp.sh -k | --kcov --lib lib_name"
}

@test "usage libshell" {
  run $MY_GIT_DIR/shell/my_warp.sh --lib shell -h
  assert_output "my_warp.sh --lib shell curl --method  --url  --header  --header-data  --data
my_warp.sh --lib shell decrypt_directory --directory  --passphrase  --remove-src
my_warp.sh --lib shell decrypt_file --file  --passphrase  --remove-src
my_warp.sh --lib shell encrypt_directory --directory  --passphrase  --remove-src
my_warp.sh --lib shell encrypt_file --file  --passphrase  --remove-src
my_warp.sh --lib shell hello_world
my_warp.sh --lib shell host_up_show --network (192.168.1.0/24)
my_warp.sh --lib shell iptables_flush
my_warp.sh --lib shell iptables_restore
my_warp.sh --lib shell iptables_save
my_warp.sh --lib shell iptables_show
my_warp.sh --lib shell service_list
my_warp.sh --lib shell service_search --service"
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

@test "_verbose_func_space builds correct VERBOSE_SPACE" {
    FUNC_LIST=("func1:123" "func2:456")
    _verbose_func_space
    [[ "$VERBOSE_SPACE" == " func1 > func2 >" ]]
}

@test "_error logs error message" {
    DEBUG=true
    run _error "Something failed"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Something failed"* ]]
}

@test "_warning logs warning message" {
    DEBUG=true
    run _warning "Be careful"
    [[ "$output" == *"Be careful"* ]]
}

@test "_debug logs debug message only when DEBUG=true" {
    DEBUG=false
    run _debug "Hidden"
    [ "$output" = "" ]

    DEBUG=true
    run _debug "Visible"
    [[ "$output" == *"Visible"* ]]
}

@test "_verbose logs message only when VERBOSE=true" {
    VERBOSE=false
    run _verbose "Hidden"
    [ "$output" = "" ]

    VERBOSE=true
    run _verbose "Shown"
    [[ "$output" == *"Shown"* ]]
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
  run _fileexist "$MY_GIT_DIR/shell/lib_shell.sh"
  assert_success
}

@test "_fileexist => false" {
  run _fileexist "$MY_GIT_DIR/shell/lib_shell.sh2"
  assert_failure
}

@test "_filenotexist => true" {
  run _filenotexist "$MY_GIT_DIR/shell/lib_shell.sh2"
  assert_success
}

@test "_filenotexist => false" {
  run _filenotexist "$MY_GIT_DIR/shell/lib_shell.sh"
  assert_failure
}

@test "_workingdir_isnot => true" {
  run _workingdir_isnot "/thisdirwillnotexit"
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
######################################## NETWORK MANAGEMENT ########################################
####################################################################################################

@test "_valid_network" {
  run echo $(_valid_network "192.168.0.0/32")
  assert_success
}

@test "_ip2int" {
  run echo $(_ip2int "192.168.0.0")
  assert_output "3232235520"
}

@test "_int2ip" {
  run echo $(_int2ip "3232235520")
  assert_output "192.168.0.0"
}

@test "_netmask" {
  run echo $(_netmask "24")
  assert_output "255.255.255.0"
}

@test "_broadcast" {
  run echo $(_broadcast "192.168.2.0" "24")
  assert_output "192.168.2.255"
}

@test "_network" {
  run echo $(_network "192.168.2.0" "24")
  assert_output "192.168.2.0"
}

@test "_host_up_show" {
  run $MY_GIT_DIR/shell/my_warp.sh --lib shell host_up_show --network 127.0.0.1/32
  assert_output --partial '127.0.0.1'
}

@test "_iptables_show" {
  iptables() { echo "OK" ; return 0; }
  run _iptables_show
  assert_success
}

@test "_iptables_save" {
  iptables-save() { echo "OK" ; return 0; }
  run _iptables_save
  assert_success
}

@test "_iptables_restore" {
  iptables-restore() { echo "OK" ; return 0; }
  run _iptables_restore
  assert_success
}

@test "_iptables_flush" {
  iptables() { echo "OK" ; return 0; }
  run _iptables_flush
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

@test "_showU8Variation" {
  run _showU8Variation 24 24
  assert_success
}

@test "_show_color_code" {
  run _show_color_code
  assert_success
}

####################################################################################################
########################################### YAML & JSON ############################################
####################################################################################################

@test "_json_2_yaml" {
  IFS=''
  run echo $(echo "{ \"networks\": { \"internet_access\": { \"external\": [true,false], \"name\": \"internet_access\" }, \"vpn_access\": { \"external\": true, \"name\": \"vpn_access\" } } }" | _json_2_yaml)
  assert_output "networks:
  internet_access:
    external:
      - true
      - false
    name: internet_access
  vpn_access:
    external: true
    name: vpn_access"
}

@test "_yaml_2_json" {
  run echo $(echo "networks:
  internet_access:
    external:
      - true
      - false
    name: internet_access
  vpn_access:
    external: true
    name: vpn_access" | _yaml_2_json)
    assert_output "{ \"networks\": { \"internet_access\": { \"external\": [ true, false ], \"name\": \"internet_access\" }, \"vpn_access\": { \"external\": true, \"name\": \"vpn_access\" } } }"
}

@test "_json_add_key_with_value" {
  IFS=''
  run echo $(_json_add_key_with_value "{}" "" "toto" "tutu")
  assert_output "{
  \"toto\": \"tutu\"
}"
}

@test "_json_add_value_in_array" {
  IFS=''
  run echo $(_json_add_value_in_array "{}" "" "toto" "tutu" )
  assert_output "{
  \"toto\": [
    \"tutu\"
  ]
}"
}

@test "_json_remove_key" {
  IFS=''
  run echo $(_json_remove_key "{ \"toto\": \"tutu\"}" "toto")
  assert_output "{}"
}

@test "_json_replace_key_with_value" {
  IFS=''
  run echo $(_json_replace_key_with_value "{ \"toto\": \"tutu\"}" "toto" "titi")
  assert_output "{
  \"toto\": \"titi\"
}"
}

@test "_json_get_value_from_key" {
  IFS=''
  run echo $(_json_get_value_from_key "{ \"toto\": \"tutu\"}" "toto")
  assert_output "tutu"
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

@test "_keepassxc_create_database: ko PASS EMPTY" {
  run _keepassxc_create_database "" "/tmp/db.kdbx"
  [ "$status" -eq 10 ]
  [[ "$output" == *"PASS EMPTY"* ]]
}

@test "_keepassxc_create_database: ko DATABASE EMPTY" {
  run _keepassxc_create_database "secret" ""
  [ "$status" -eq 10 ]
  [[ "$output" == *"DATABASE EMPTY"* ]]
}

@test "_keepassxc_create_database" {
  rm -rf /tmp/db.kdbx
  run _keepassxc_create_database "secret" "/tmp/db.kdbx"
  assert_success
}

@test "_keepassxc_create_database again ko db exist" {
  touch "/tmp/db.kdbx"
  run _keepassxc_create_database "secret" "/tmp/db.kdbx"
  [ "$status" -eq 10 ]
  [[ "$output" == *"already exist"* ]]
}

@test "_keepassxc_add_entry" {
  run _keepassxc_add_entry "secret" "/tmp/db.kdbx" "entry1"
  assert_success
}

@test "_keepassxc_add_group" {
  run _keepassxc_add_group "secret" "/tmp/db.kdbx" "group1"
  assert_success
}

@test "_keepassxc_add_entry in group" {
  run _keepassxc_add_entry "secret" "/tmp/db.kdbx" "group1/entry2"
  assert_success
}

@test "_keepassxc_add_entry in non existant group" {
  run _keepassxc_add_entry "secret" "/tmp/db.kdbx" "group2/entry"
  assert_failure
}

@test "_keepassxc_change_password" {
  run _keepassxc_change_password "secret" "/tmp/db.kdbx" "entry1" "supersecret"
  assert_success
}

@test "_keepassxc_change_username" {
  run _keepassxc_change_username "secret" "/tmp/db.kdbx" "entry1" "superuser"
  assert_success
}

@test "_keepassxc_read" {
  run _keepassxc_read "secret" "/tmp/db.kdbx" "entry1"
  assert_success
}

@test "_keepassxc_read_username" {
  run _keepassxc_read_username "secret" "/tmp/db.kdbx" "entry1"
  assert_output 'superuser'
}

@test "_keepassxc_read_password" {
  run _keepassxc_read_password "secret" "/tmp/db.kdbx" "entry1"
  assert_output 'supersecret'
}

@test "_keepassxc_add_attachment" {
  echo "sometxt" > /tmp/somefile
  run _keepassxc_add_attachment "secret" "/tmp/db.kdbx" "entry1" "attach1" "/tmp/somefile"
  assert_success
  rm -rf /tmp/somefile
}

@test "_keepassxc_list_attachments" {
  run _keepassxc_list_attachments "secret" "/tmp/db.kdbx" "entry1"
  assert_output 'attach1'
}

@test "_keepassxc_restore_attachment" {
  run _keepassxc_restore_attachment "secret" "/tmp/db.kdbx" "entry1" "attach1" "/tmp/somefile"
  assert_success
  rm -rf /tmp/somefile
}

@test "_encrypt_file" {
  rm -rf /tmp/somefile*
  echo "some text" > /tmp/somefile.txt
  run _encrypt_file /tmp/somefile.txt "changeme" false
  assert_success
}

@test "_encrypt_file => dest_file already exist" {
  echo "some text" > /tmp/somefile.txt
  run $MY_GIT_DIR/shell/my_warp.sh -v --lib shell encrypt_file --file /tmp/somefile.txt --passphrase "changeme" --remove-src false
  assert_failure 2
}

@test "_decrypt_file" {
  rm -rf /tmp/somefile.txt
  run _decrypt_file /tmp/somefile.txt.asc "changeme" false
  assert_success
}

@test "_decrypt_file => dest_file already exist" {
  run $MY_GIT_DIR/shell/my_warp.sh -v --lib shell decrypt_file --file /tmp/somefile.txt.asc --passphrase "changeme" --remove-src false
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

@test "_decrypt_directory" {
  rm -rf /tmp/somedir/*.txt
  run _decrypt_directory /tmp/somedir "changeme" false
  assert_success
}

@test "_encrypt_directory => dest_file already exist" {
  run $MY_GIT_DIR/shell/my_warp.sh -v --lib shell encrypt_directory --directory /tmp/somedir --passphrase "changeme" --remove-src false
  assert_failure
}

@test "_decrypt_directory => dest_file already exist" {
  run $MY_GIT_DIR/shell/my_warp.sh -v --lib shell decrypt_directory --directory /tmp/somedir --passphrase "changeme" --remove-src false
  assert_failure 1
}

####################################################################################################
############################################### URL ################################################
####################################################################################################

@test "_curl GET wrong url" {
  run _curl "GET" "https://www.gnupgdsdss.org/"
  assert_failure 6
}

@test "_curl GET good url with header" {
  run _curl "GET" "https://reqbin.com/echo" "User-Agent:"
  echo $output > /tmp/titi
  result=$(_curl "GET" "https://reqbin.com/echo" "User-Agent:" |md5sum)
#  [ "$result" = "2b50b1818834b647a843cc1861dfe430  -" ]
}

@test "_encode_url" {
  run _encode_url "toto titi & é"
  assert_output 'toto%20titi%20%26%20%C3%A9%0A'
}

@test "_decode_url" {
  run _decode_url "toto%20titi%20%26%20%C3%A9%0A"
  assert_output 'toto titi & é'
}

@test "_curl Fail when METHOD is empty" {
    run _curl "" "http://example.com"
    [ "$status" -eq 10 ]
    [[ "$output" == *"METHOD EMPTY"* ]]
}

@test "_curl Fail when URL is empty" {
    run _curl "GET" ""
    [ "$status" -eq 10 ]
    [[ "$output" == *"URL EMPTY"* ]]
}

@test "_curl Fail when METHOD is invalid" {
    run _curl "INVALID" "http://example.com"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Wrong METHOD"* ]]
}

@test "_curl Success with GET and valid URL" {
    # Mock curl to avoid real network calls
    curl() { echo "OK"; return 0; }
    run _curl "GET" "http://example.com"
    [ "$status" -eq 0 ]
    [[ "$output" == "OK" ]]
}

@test "_curl Fail when response contains Unauthorized" {
    curl() { echo "Unauthorized"; return 0; }
    run _curl "GET" "http://example.com"
    [ "$status" -eq 1 ]
    [[ "$output" == *"TOKEN invalid"* ]]
}

@test "_curl Fail when curl returns DNS error (code 6)" {
    curl() { echo "DNS error"; return 6; }
    run _curl "GET" "http://example.com"
    [ "$status" -eq 6 ]
    [[ "$output" == *"DNS error for _curl"* ]]
}


####################################################################################################
######################################### INTERACTIVE ASK ##########################################
####################################################################################################

@test "_ask_yes_or_no returns y when user inputs y" {
  DEFAULT=false
  run _ask_yes_or_no "Do you agree?" <<< "y"
  [ "$status" -eq 0 ]
  [ "$output" = "y" ]
}

@test "_ask_string returns entered string" {
  DEFAULT=false
  run _ask_string "Enter string:" <<< "hello"
  [ "$status" -eq 0 ]
  [ "$output" = "hello" ]
}

@test "_ask_string uses default when empty input" {
  DEFAULT=false
  run _ask_string "Enter string:" "default_value" <<< ""
  [ "$status" -eq 0 ]
  [ "$output" = "default_value" ]
}

@test "_ask_yes_or_no" {
  run _ask_yes_or_no "question" "y" <<< "N"
  assert_output 'n'
}

@test "_ask_yes_or_no empty" {
  run _ask_yes_or_no "question" "y" <<< ""
  assert_output 'y'
}

@test "_ask_ip" {
  run _ask_ip "question" "127.0.0.1" <<< "127.0.0.2"
  assert_output '127.0.0.2'
}

@test "_ask_ip empty" {
  run _ask_ip "question" "127.0.0.1" <<< ""
  assert_output '127.0.0.1'
}

@test "_ask_network" {
  run _ask_network "question" "192.168.2.0/24" <<< "192.168.1.0/16"
  assert_output '192.168.1.0/16'
}

@test "_ask_network empty" {
  run _ask_network "question" "192.168.2.0/24" <<< ""
  assert_output '192.168.2.0/24'
}

@test "_ask_string" {
  run _ask_string "question" "toto" <<< "tutu"
  assert_output 'tutu'
}

@test "_ask_string empty" {
  run _ask_string "question" "toto" <<< ""
  assert_output 'toto'
}

####################################################################################################
######################################### EVERYTHING ELSE ##########################################
####################################################################################################
@test "_hello_world" {
  run $MY_GIT_DIR/shell/my_warp.sh -d -v --lib shell hello_world
  assert_line --index 5  'Hello world'
  assert_line --index 6 --partial 'SUCCESS'
  assert_line --index 7 --partial 'VERBOSE'
  assert_line --index 8 --partial 'WARNING'
  assert_line --index 9 --partial 'ERROR'
}

@test "_kcov" {
  run $MY_GIT_DIR/shell/my_warp.sh -v -d --lib shell -k --dry-run
  assert_success
}