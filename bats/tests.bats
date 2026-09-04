#!/usr/bin/env bats

# global var (DEBUG/VERBOSE are overridable via env: DEBUG=true VERBOSE=true bats ...)
VERBOSE=${VERBOSE:-false}
DEBUG=${DEBUG:-false}
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
  [[ "$output" == *"h,v,d,b,s,k"* ]]
}

@test "_getopt_long" {
  run _getopt_long
  [[ "$output" = *"shell:"*"debug,verbose,help,list-libs,bats,shellcheck,kcov,dry-run"*"lib:" ]]
}

@test "list-libs" {
  run $MY_GIT_DIR/shell/my_warp.sh -v --list-libs
  assert_output --partial 'shell'
}

@test "shellcheck" {
  run $MY_GIT_DIR/shell/my_warp.sh -v --lib shell -s
  assert_success
}

@test "_process_opts => bad first argument" {
  run $MY_GIT_DIR/shell/my_warp.sh hello_world
  assert_failure
  [[ "$output" == *"Bad or missing argument"* ]]
}

@test "_process_opts => --default --force --yubikey" {
  run $MY_GIT_DIR/shell/my_warp.sh --default --force --yubikey --lib shell hello_world
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
  * Bats subset (regex filter)         => my_warp.sh -b --lib lib_name '<regex>'
  * Shell Syntax Checking              => my_warp.sh -s | --shellcheck --lib lib_name
  * Code coverage                      => my_warp.sh -k | --kcov --lib lib_name
  * Code coverage keep report (AI)     => my_warp.sh -k AI --lib lib_name"
}

@test "usage calls _usage_shell when defined" {
  _usage_shell() { echo "custom shell usage"; }
  LIB=shell
  run _usage
  assert_success
  [[ "$output" == *"custom shell usage"* ]]
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

@test "_load_conf => sources my_ variant when present" {
  local __dir="$BATS_TEST_TMPDIR/conf_my"
  mkdir -p "$__dir"
  echo "TEST_CONF_VAR=base" > "$__dir/test.conf"
  echo "TEST_CONF_VAR=my"   > "$__dir/my_test.conf"
  run _load_conf "$__dir/test.conf"
  assert_success
  rm -rf "$__dir"
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

@test "_func_start/_func_end manage FUNC_LIST" {
    FUNC_LIST=()
    _func_start
    [[ "${#FUNC_LIST[@]}" -eq 1 ]]
    [[ "${FUNC_LIST[0]}" == *":"* ]]
    _func_end "0"
    [[ "${#FUNC_LIST[@]}" -eq 0 ]]
}

@test "_func_end without arg keeps FUNC_LIST balanced" {
    FUNC_LIST=()
    _func_start
    _func_end
    [[ "${#FUNC_LIST[@]}" -eq 0 ]]
}

@test "_func_start/_func_end skip VERBOSE_SPACE when logging off" {
    VERBOSE_SPACE="STALE"
    FUNC_LIST=()
    DEBUG=false
    VERBOSE=false
    _func_start
    [ "$VERBOSE_SPACE" = "STALE" ]
    _func_end "0"
    [ "$VERBOSE_SPACE" = "STALE" ]
}

@test "_func_start debug output with args" {
    DEBUG=true
    VERBOSE=true
    FUNC_LIST=()
    run _func_start "arg1" "arg2"
    [[ "$output" == *"Start"* ]]
    [[ "$output" == *'Start > $1:"arg1"'* ]]
    [[ "$output" == *'Start > $2:"arg2"'* ]]
    FUNC_LIST=()
}

@test "_func_start debug output no args" {
    DEBUG=true
    VERBOSE=true
    FUNC_LIST=()
    run _func_start
    [[ "$output" == *"Start"* ]]
    [[ "$output" == *"no args"* ]]
    FUNC_LIST=()
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

@test "_log suppressed path does not touch VERBOSE_SPACE" {
    VERBOSE_SPACE="STALE"
    FUNC_LIST=("f1:100")
    DEBUG=false
    _debug "Hidden" >/dev/null 2>&1
    [ "$VERBOSE_SPACE" = "STALE" ]
}

@test "_log both-off path does not touch VERBOSE_SPACE" {
    VERBOSE_SPACE="STALE"
    FUNC_LIST=("f1:100")
    DEBUG=false
    VERBOSE=false
    _error "msg" >/dev/null 2>&1
    [ "$VERBOSE_SPACE" = "STALE" ]
}

@test "_log VERBOSE-only path does not touch VERBOSE_SPACE" {
    VERBOSE_SPACE="STALE"
    FUNC_LIST=("f1:100")
    DEBUG=false
    VERBOSE=true
    _error "msg" >/dev/null 2>&1
    [ "$VERBOSE_SPACE" = "STALE" ]
}

@test "_verbose_file dumps existing file when VERBOSE=true" {
    local __f="$BATS_TEST_TMPDIR/dump_verbose.txt"
    echo "content line" > "$__f"
    VERBOSE=true
    run _verbose_file "$__f"
    assert_success
    [[ "$output" == *"--- dump file start"* ]]
    [[ "$output" == *"content line"* ]]
    [[ "$output" == *"--- dump file end"* ]]
    rm -f "$__f"
}

@test "_verbose_file on missing file => error" {
    run _verbose_file "$BATS_TEST_TMPDIR/does_not_exist_verbose"
    assert_failure
    [[ "$output" == *"can verbose"* ]]
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

@test "_start_with => true with IFS empty" {
  IFS=''
  run _startswith "-toto" "-"
  assert_success
}

@test "_start_with => false with IFS empty" {
  IFS=''
  run _startswith "-toto" "*"
  assert_failure
}

@test "_contains => true" {
  run _contains "hello world" "world"
  assert_success
}

@test "_contains => false" {
  run _contains "hello world" "xyz"
  assert_failure
}

@test "_is_numeric => true" {
  run _is_numeric "123"
  assert_success
}

@test "_is_numeric => false" {
  run _is_numeric "abc"
  assert_failure
}

@test "_is_numeric => empty" {
  run _is_numeric ""
  assert_failure
}

@test "_is_numeric => unicode digits rejected" {
  run _is_numeric "١٢٣"
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

@test "_installed => true" {
  run _installed "bats"
  assert_success
}

@test "_installed => false" {
  run _installed "batse"
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

@test "_remotefileexist => true" {
  run _remotefileexist "$MY_GIT_DIR/shell/lib_shell.sh"
  assert_success
}

@test "_remotefileexist => false" {
  run _remotefileexist "$MY_GIT_DIR/shell/lib_shell.sh2"
  assert_failure
}

@test "_remotefileexist => timeout" {
  timeout() { return 124; }
  VERBOSE=true
  run _remotefileexist "$MY_GIT_DIR/shell/lib_shell.sh"
  assert_failure
  [[ "$output" == *"Timeout"* ]]
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

@test "_valid_network => non-numeric mask" {
  run _valid_network "192.168.1.0/abc"
  assert_failure
  [[ "$output" == *"mask not numeric"* ]]
}

@test "_valid_network => mask > 32" {
  run _valid_network "192.168.1.0/33"
  assert_failure
  [[ "$output" == *"mask > 32"* ]]
}

@test "_valid_network => missing mask" {
  run _valid_network "192.168.1.0"
  assert_failure
  [[ "$output" == *"MASK EMPTY"* ]]
}

@test "_valid_network => empty" {
  run _valid_network
  assert_failure
  [[ "$output" == *"NETWORK EMPTY"* ]]
}

@test "_ip2int" {
  run echo $(_ip2int "192.168.0.0")
  assert_output "3232235520"
}

@test "_int2ip" {
  run echo $(_int2ip "3232235520")
  assert_output "192.168.0.0"
}

@test "_int2ip => too large" {
  run _int2ip "4294967296"
  assert_failure
  [[ "$output" == *"int too large"* ]]
}

@test "_int2ip => huge int wraps nothing" {
  run _int2ip "9999999999999"
  assert_failure
  [[ "$output" == *"int too large"* ]]
}

@test "_int2ip => negative" {
  run _int2ip "-1"
  assert_failure
  [[ "$output" == *"int not numeric"* ]]
}

@test "_int2ip => non-numeric" {
  run _int2ip "abc"
  assert_failure
  [[ "$output" == *"int not numeric"* ]]
}

@test "_int2ip => empty" {
  run _int2ip ""
  assert_failure
  [[ "$output" == *"INT EMPTY"* ]]
}

@test "_netmask" {
  run echo $(_netmask "24")
  assert_output "255.255.255.0"
}

@test "_netmask => non-numeric mask" {
  run _netmask "abc"
  assert_failure
  [[ "$output" == *"mask not numeric"* ]]
}

@test "_broadcast" {
  run echo $(_broadcast "192.168.2.0" "24")
  assert_output "192.168.2.255"
}

@test "_broadcast => non-numeric mask" {
  run _broadcast "192.168.2.0" "abc"
  assert_failure
  [[ "$output" == *"mask not numeric"* ]]
}

@test "_network" {
  run echo $(_network "192.168.2.0" "24")
  assert_output "192.168.2.0"
}

@test "_network => non-numeric mask" {
  run _network "192.168.2.0" "abc"
  assert_failure
  [[ "$output" == *"mask not numeric"* ]]
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

@test "_upper => empty input" {
  run _upper ""
  assert_output ""
}

@test "_lower => empty input" {
  run _lower ""
  assert_output ""
}

@test "_remove_french" {
  run _remove_french "àâäéèêëîïôöùûüÿçÀÂÄÉÈÊËÎÏÔÖÙÛÜŸÇ"
  assert_output "aaaeeeeiioouuuycAAAEEEEIIOOUUUYC"
}

@test "| _remove_french" {
  run echo $(echo "Héllo Wörld Crème Brûlée Noël à Nîmes déjà vu" | _remove_french)
  assert_output "Hello World Creme Brulee Noel a Nimes deja vu"
}

@test "_remove_french => empty input" {
  run _remove_french ""
  assert_output ""
}

@test "_remove_french => no accent leaves string unchanged" {
  run _remove_french "azerty 123 ABC"
  assert_output "azerty 123 ABC"
}

@test "_remove_french => chained with _upper" {
  run echo $(echo "déjà vu" | _remove_french | _upper)
  assert_output "DEJA VU"
}

@test "_remove_last_car" {
  run _remove_last_car "hello"
  assert_output "hell"
}

@test "| _remove_last_car" {
  run echo $(echo "hello" | _remove_last_car)
  assert_output "hell"
}

@test "_remove_last_car => empty input" {
  run _remove_last_car ""
  assert_output ""
}

@test "_is_ascii => true" {
  run _is_ascii "some-string_123"
  assert_success
}

@test "_is_ascii => empty" {
  run _is_ascii ""
  assert_success
}

@test "_is_ascii => non-ASCII" {
  run _is_ascii "café"
  assert_failure
}

@test "_is_ascii => tab" {
  run _is_ascii $'a\tb'
  assert_failure
}

@test "_showU8Variation" {
  run _showU8Variation 24 24
  assert_success
}

@test "_showU8Variation zero codepoint" {
  run _showU8Variation 24 0
  assert_success
}

@test "_showU8Variation defaults codepoint to 26" {
  run _showU8Variation 7
  assert_success
  [[ "$output" == *"U026yx"* ]]
  [[ "$output" == *"defaulting to 26"* ]]
}

@test "_showU8Variation => empty selector" {
  run _showU8Variation
  assert_failure
  [[ "$output" == *"VARIATION SELECTOR EMPTY"* ]]
}

@test "_showU8Variation => non-numeric selector" {
  run _showU8Variation "abc" 24
  assert_failure
  [[ "$output" == *"VARIATION SELECTOR not numeric"* ]]
}

@test "_showU8Variation => selector out of range" {
  run _showU8Variation 257 24
  assert_failure
  [[ "$output" == *"must be between 1 and 256"* ]]
}

@test "_show_color_code" {
  run _show_color_code
  assert_success
}

@test "_show_color_code with text arg" {
  run _show_color_code "sample"
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

@test "_yaml_2_json => unsupported yq version" {
  yq() { echo "yq (https://github.com/mikefarah/yq/) version v3.0.0"; }
  run _yaml_2_json "{}"
  assert_failure
  [[ "$output" == *"not supported"* ]]
}

@test "_yaml_2_json => unparseable yq version" {
  yq() { echo "unexpected-format"; }
  run _yaml_2_json "{}"
  assert_failure
  [[ "$output" == *"not supported"* ]]
}

@test "_json_add_key_with_value => boolean" {
  IFS=''
  run echo $(_json_add_key_with_value "{}" "" "toto" "true")
  assert_output "{
  \"toto\": true
}"
}

@test "_json_add_key_with_value => int" {
  IFS=''
  run echo $(_json_add_key_with_value "{}" "" "toto" "1")
  assert_output "{
  \"toto\": 1
}"
}

@test "_json_add_key_with_value => text" {
  IFS=''
  run echo $(_json_add_key_with_value "{}" "" "toto" "\"text\"")
  assert_output "{
  \"toto\": \"text\"
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

@test "_json_get_value_from_key => string null value" {
  run _json_get_value_from_key '{"key":"null"}' "key"
  assert_success
  assert_output "null"
}

@test "_json_get_value_from_key => JSON null value" {
  run _json_get_value_from_key '{"key":null}' "key"
  assert_failure
}

@test "_json_get_value_from_key => missing key" {
  run _json_get_value_from_key '{"key":"val"}' "other"
  assert_failure
}

@test "_json_get_value_from_key => non-null false/zero/empty values" {
  run _json_get_value_from_key '{"a":false}' "a"
  assert_success
  assert_output "false"
  run _json_get_value_from_key '{"b":0}' "b"
  assert_success
  assert_output "0"
  run _json_get_value_from_key '{"c":""}' "c"
  assert_success
  assert_output ""
}

@test "_json_get_value_from_key => nested path" {
  run _json_get_value_from_key '{"a":{"b":"deep"}}' "a.b"
  assert_success
  assert_output "deep"
}

@test "_json_get_value_from_array => all elements" {
  run _json_get_value_from_array '{"content":{"sections":[{"dashboardId":"x","name":"Inv"},{"dashboardId":"y","name":"Cap"}]}}' "content.sections" "" "" "name"
  assert_success
  assert_output "Inv
Cap"
}

@test "_json_get_value_from_array => filtered" {
  run _json_get_value_from_array '{"content":{"sections":[{"dashboardId":"x","name":"Inv"},{"dashboardId":"y","name":"Cap"}]}}' "content.sections" "dashboardId" "x" "name"
  assert_success
  assert_output "Inv"
}

@test "_json_get_value_from_array => empty array" {
  run _json_get_value_from_array '{"content":{"sections":[]}}' "content.sections" "" "" "name"
  assert_success
  assert_output ""
}

@test "_json_get_value_from_array => missing path" {
  run _json_get_value_from_array '{}' "content.sections" "" "" "name"
  assert_success
  assert_output ""
}

@test "_json_get_value_from_array => no match" {
  run _json_get_value_from_array '{"content":{"sections":[{"dashboardId":"x","name":"Inv"}]}}' "content.sections" "dashboardId" "zzz" "name"
  assert_success
  assert_output ""
}

@test "_json_get_value_from_array => missing JSON" {
  run _json_get_value_from_array
  assert_failure
  assert_output --partial "JSON EMPTY"
}

@test "_json_get_value_from_array => missing array path" {
  run _json_get_value_from_array '{"a":1}'
  assert_failure
  assert_output --partial "ARRAY PATH EMPTY"
}

@test "_json_get_value_from_array => missing return key" {
  run _json_get_value_from_array '{"a":1}' "a.b" "" ""
  assert_failure
  assert_output --partial "RETURN KEY EMPTY"
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

@test "_array_remove_last on empty array does nothing" {
  local __my_array=()
  local __err
  __err=$(_array_remove_last __my_array 2>&1)
  [ -z "$__err" ]
  [[ "${#__my_array[@]}" -eq 0 ]]
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
####################################################################################################
############################################### GIT ################################################
####################################################################################################

# Creates a git work repo (committed file) with a local bare remote as upstream.
__git_test_init_repo() {
    local __work="$1"
    local __remote="$2"

    git init -q --bare -b main "$__remote"
    git init -q -b main "$__work"
    git -C "$__work" config user.email "test@example.com"
    git -C "$__work" config user.name "Tester"
    git -C "$__work" remote add origin "$__remote"
    echo "hello" > "$__work/file.txt"
    git -C "$__work" add file.txt
    git -C "$__work" commit -q -m "init"
    git -C "$__work" push -q origin main
    git -C "$__work" branch --set-upstream-to=origin/main main
}

@test "_git_upstream => success" {
    local __dir
    __dir="$BATS_RUN_TMPDIR/git-upstream-ok"
    __git_test_init_repo "$__dir" "$__dir-remote.git"

    run _git_upstream "$__dir"
    assert_success
    assert_output "origin/main"
}

@test "_git_upstream => no upstream" {
    local __dir
    __dir="$BATS_RUN_TMPDIR/git-upstream-none"
    git init -q -b main "$__dir"
    git -C "$__dir" config user.email "test@example.com"
    git -C "$__dir" config user.name "Tester"
    echo "hello" > "$__dir/file.txt"
    git -C "$__dir" add file.txt
    git -C "$__dir" commit -q -m "init"

    run _git_upstream "$__dir"
    assert_failure 1
    [[ "$output" == *"UPSTREAM:"* ]]
}

@test "_git_upstream => not a git directory" {
    local __dir
    __dir="$BATS_RUN_TMPDIR/git-upstream-nogit"
    mkdir -p "$__dir"

    run _git_upstream "$__dir"
    assert_failure 1
    [[ "$output" == *"UPSTREAM:"* ]]
}

@test "_git_upstream => empty dir argument" {
    run _git_upstream ""
    assert_failure 10
    [[ "$output" == *"DIR EMPTY"* ]]
}

@test "_git_commits_ahead => 0 ahead" {
    local __dir
    __dir="$BATS_RUN_TMPDIR/git-ahead-0"
    __git_test_init_repo "$__dir" "$__dir-remote.git"

    run _git_commits_ahead "$__dir"
    assert_success
    assert_output "0"
}

@test "_git_commits_ahead => 2 ahead" {
    local __dir
    __dir="$BATS_RUN_TMPDIR/git-ahead-2"
    __git_test_init_repo "$__dir" "$__dir-remote.git"
    echo "b" > "$__dir/b.txt"
    git -C "$__dir" add b.txt
    git -C "$__dir" commit -q -m "b"
    echo "c" > "$__dir/c.txt"
    git -C "$__dir" add c.txt
    git -C "$__dir" commit -q -m "c"

    run _git_commits_ahead "$__dir"
    assert_success
    assert_output "2"
}

@test "_git_commits_ahead => no upstream" {
    local __dir
    __dir="$BATS_RUN_TMPDIR/git-ahead-none"
    git init -q -b main "$__dir"
    git -C "$__dir" config user.email "test@example.com"
    git -C "$__dir" config user.name "Tester"
    echo "hello" > "$__dir/file.txt"
    git -C "$__dir" add file.txt
    git -C "$__dir" commit -q -m "init"

    run _git_commits_ahead "$__dir"
    assert_failure 1
    [[ "$output" == *"UPSTREAM:"* ]]
}

@test "_git_commits_ahead => empty dir argument" {
    run _git_commits_ahead ""
    assert_failure 10
    [[ "$output" == *"DIR EMPTY"* ]]
}

@test "_git_staged_shortstat => staged changes" {
    local __dir
    __dir="$BATS_RUN_TMPDIR/git-shortstat-staged"
    __git_test_init_repo "$__dir" "$__dir-remote.git"
    echo "world" > "$__dir/file.txt"
    git -C "$__dir" add file.txt

    run _git_staged_shortstat "$__dir"
    assert_success
    [[ "$output" == *"file changed"* ]]
}

@test "_git_staged_shortstat => nothing staged" {
    local __dir
    __dir="$BATS_RUN_TMPDIR/git-shortstat-empty"
    __git_test_init_repo "$__dir" "$__dir-remote.git"

    run _git_staged_shortstat "$__dir"
    assert_success
    assert_output ""
}

@test "_git_staged_shortstat => not a git directory" {
    local __dir
    __dir="$BATS_RUN_TMPDIR/git-shortstat-nogit"
    mkdir -p "$__dir"

    run _git_staged_shortstat "$__dir"
    assert_failure 1
    [[ "$output" == *"GIT:"* ]]
}

@test "_git_staged_shortstat => empty dir argument" {
    run _git_staged_shortstat ""
    assert_failure 10
    [[ "$output" == *"DIR EMPTY"* ]]
}

@test "_git_staged_stat => staged changes" {
    local __dir
    __dir="$BATS_RUN_TMPDIR/git-stat-staged"
    __git_test_init_repo "$__dir" "$__dir-remote.git"
    echo "world" > "$__dir/file.txt"
    git -C "$__dir" add file.txt

    run _git_staged_stat "$__dir"
    assert_success
    [[ "$output" == *"file.txt"* ]]
}

@test "_git_staged_stat => nothing staged" {
    local __dir
    __dir="$BATS_RUN_TMPDIR/git-stat-empty"
    __git_test_init_repo "$__dir" "$__dir-remote.git"

    run _git_staged_stat "$__dir"
    assert_success
    assert_output ""
}

@test "_git_staged_stat => not a git directory" {
    local __dir
    __dir="$BATS_RUN_TMPDIR/git-stat-nogit"
    mkdir -p "$__dir"

    run _git_staged_stat "$__dir"
    assert_failure 1
    [[ "$output" == *"GIT:"* ]]
}

@test "_git_staged_stat => empty dir argument" {
    run _git_staged_stat ""
    assert_failure 10
    [[ "$output" == *"DIR EMPTY"* ]]
}

@test "_git_is_work_tree => in a git repo" {
    local __dir
    __dir="$BATS_RUN_TMPDIR/git-isworktree-ok"
    __git_test_init_repo "$__dir" "$__dir-remote.git"

    run _git_is_work_tree "$__dir"
    assert_success
}

@test "_git_is_work_tree => not a git directory" {
    local __dir
    __dir="$BATS_RUN_TMPDIR/git-isworktree-nogit"
    mkdir -p "$__dir"

    run _git_is_work_tree "$__dir"
    assert_failure 1
    [[ "$output" == *"GIT:"* ]]
}

@test "_git_is_work_tree => empty dir argument" {
    run _git_is_work_tree ""
    assert_failure 10
    [[ "$output" == *"DIR EMPTY"* ]]
}

@test "_git_porcelain_status => clean" {
    local __dir
    __dir="$BATS_RUN_TMPDIR/git-porcelain-clean"
    __git_test_init_repo "$__dir" "$__dir-remote.git"

    run _git_porcelain_status "$__dir"
    assert_success
    assert_output ""
}

@test "_git_porcelain_status => dirty" {
    local __dir
    __dir="$BATS_RUN_TMPDIR/git-porcelain-dirty"
    __git_test_init_repo "$__dir" "$__dir-remote.git"
    echo "change" >> "$__dir/file.txt"

    run _git_porcelain_status "$__dir"
    assert_success
    [[ "$output" == *"file.txt"* ]]
}

@test "_git_porcelain_status => not a git directory" {
    local __dir
    __dir="$BATS_RUN_TMPDIR/git-porcelain-nogit"
    mkdir -p "$__dir"

    run _git_porcelain_status "$__dir"
    assert_failure 1
    [[ "$output" == *"GIT:"* ]]
}

@test "_git_porcelain_status => empty dir argument" {
    run _git_porcelain_status ""
    assert_failure 10
    [[ "$output" == *"DIR EMPTY"* ]]
}

@test "_git_diff => HEAD with unstaged changes" {
    local __dir
    __dir="$BATS_RUN_TMPDIR/git-diff-head"
    __git_test_init_repo "$__dir" "$__dir-remote.git"
    echo "change" >> "$__dir/file.txt"

    run _git_diff "$__dir" HEAD
    assert_success
    [[ "$output" == *"diff --git"* ]]
    [[ "$output" == *"file.txt"* ]]
}

@test "_git_diff => --cached with staged changes" {
    local __dir
    __dir="$BATS_RUN_TMPDIR/git-diff-cached"
    __git_test_init_repo "$__dir" "$__dir-remote.git"
    echo "change" >> "$__dir/file.txt"
    git -C "$__dir" add file.txt

    run _git_diff "$__dir" --cached
    assert_success
    [[ "$output" == *"diff --git"* ]]
    [[ "$output" == *"file.txt"* ]]
}

@test "_git_diff => plain with unstaged changes" {
    local __dir
    __dir="$BATS_RUN_TMPDIR/git-diff-plain"
    __git_test_init_repo "$__dir" "$__dir-remote.git"
    echo "change" >> "$__dir/file.txt"

    run _git_diff "$__dir"
    assert_success
    [[ "$output" == *"diff --git"* ]]
    [[ "$output" == *"file.txt"* ]]
}

@test "_git_diff => no changes (empty)" {
    local __dir
    __dir="$BATS_RUN_TMPDIR/git-diff-empty"
    __git_test_init_repo "$__dir" "$__dir-remote.git"

    run _git_diff "$__dir" HEAD
    assert_success
    assert_output ""
}

@test "_git_diff => not a git directory" {
    local __dir
    __dir="$BATS_RUN_TMPDIR/git-diff-nogit"
    mkdir -p "$__dir"

    run _git_diff "$__dir" HEAD
    assert_failure 1
    [[ "$output" == *"GIT:"* ]]
}

@test "_git_diff => empty dir argument" {
    run _git_diff ""
    assert_failure 10
    [[ "$output" == *"DIR EMPTY"* ]]
}

@test "_git_add => stages a modified file" {
    local __dir
    __dir="$BATS_RUN_TMPDIR/git-add-staged"
    __git_test_init_repo "$__dir" "$__dir-remote.git"
    echo "change" >> "$__dir/file.txt"

    run _git_add "$__dir"
    assert_success

    run _git_porcelain_status "$__dir"
    assert_success
    [[ "$output" == *"M  file.txt"* ]]
}

@test "_git_add => not a git directory" {
    local __dir
    __dir="$BATS_RUN_TMPDIR/git-add-nogit"
    mkdir -p "$__dir"

    run _git_add "$__dir"
    assert_failure 1
    [[ "$output" == *"GIT:"* ]]
}

@test "_git_add => empty dir argument" {
    run _git_add ""
    assert_failure 10
    [[ "$output" == *"DIR EMPTY"* ]]
}

@test "_git_commit => commits staged changes" {
    local __dir
    __dir="$BATS_RUN_TMPDIR/git-commit-ok"
    __git_test_init_repo "$__dir" "$__dir-remote.git"
    echo "change" >> "$__dir/file.txt"
    git -C "$__dir" add file.txt

    run _git_commit "$__dir" "my commit message"
    assert_success
    [[ "$output" == *"my commit message"* ]]

    run git -C "$__dir" log -1 --format=%s
    assert_output "my commit message"
}

@test "_git_commit => empty message argument" {
    local __dir
    __dir="$BATS_RUN_TMPDIR/git-commit-nomsg"
    __git_test_init_repo "$__dir" "$__dir-remote.git"

    run _git_commit "$__dir" ""
    assert_failure 10
    [[ "$output" == *"MESSAGE EMPTY"* ]]
}

@test "_git_commit => not a git directory" {
    local __dir
    __dir="$BATS_RUN_TMPDIR/git-commit-nogit"
    mkdir -p "$__dir"

    run _git_commit "$__dir" "msg"
    assert_failure 1
    [[ "$output" == *"GIT:"* ]]
}

@test "_git_commit => empty dir argument" {
    run _git_commit "" "msg"
    assert_failure 10
    [[ "$output" == *"DIR EMPTY"* ]]
}

@test "_git_upstream => git not installed" {
    _installed() { return 1; }
    run _git_upstream "$BATS_RUN_TMPDIR"
    assert_failure 10
    [[ "$output" == *"GIT: not found"* ]]
}

@test "_git_commits_ahead => git not installed" {
    _installed() { return 1; }
    run _git_commits_ahead "$BATS_RUN_TMPDIR"
    assert_failure 10
    [[ "$output" == *"GIT: not found"* ]]
}

@test "_git_staged_shortstat => git not installed" {
    _installed() { return 1; }
    run _git_staged_shortstat "$BATS_RUN_TMPDIR"
    assert_failure 10
    [[ "$output" == *"GIT: not found"* ]]
}

@test "_git_staged_stat => git not installed" {
    _installed() { return 1; }
    run _git_staged_stat "$BATS_RUN_TMPDIR"
    assert_failure 10
    [[ "$output" == *"GIT: not found"* ]]
}

@test "_git_is_work_tree => git not installed" {
    _installed() { return 1; }
    run _git_is_work_tree "$BATS_RUN_TMPDIR"
    assert_failure 10
    [[ "$output" == *"GIT: not found"* ]]
}

@test "_git_porcelain_status => git not installed" {
    _installed() { return 1; }
    run _git_porcelain_status "$BATS_RUN_TMPDIR"
    assert_failure 10
    [[ "$output" == *"GIT: not found"* ]]
}

@test "_git_diff => git not installed" {
    _installed() { return 1; }
    run _git_diff "$BATS_RUN_TMPDIR" HEAD
    assert_failure 10
    [[ "$output" == *"GIT: not found"* ]]
}

@test "_git_add => git not installed" {
    _installed() { return 1; }
    run _git_add "$BATS_RUN_TMPDIR"
    assert_failure 10
    [[ "$output" == *"GIT: not found"* ]]
}

@test "_git_commit => git not installed" {
    _installed() { return 1; }
    run _git_commit "$BATS_RUN_TMPDIR" "msg"
    assert_failure 10
    [[ "$output" == *"GIT: not found"* ]]
}

####################################################################################################
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
  assert_output 'toto%20titi%20%26%20%C3%A9'
}

@test "_decode_url" {
  run _decode_url "toto%20titi%20%26%20%C3%A9"
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

@test "_curl Fail when response is HTTP 400 (Bad Request)" {
    # Mock curl: emit the body followed by the HTTP status code appended by --write-out
    curl() { printf 'Bad Request\n400'; return 0; }
    run _curl "GET" "http://example.com"
    [ "$status" -eq 1 ]
    [[ "$output" == *"400 Bad Request"* ]]
}

@test "_curl Fail when response is HTTP 401 (Unauthorized)" {
    # Mock curl: emit the body followed by the HTTP status code appended by --write-out
    curl() { printf 'Unauthorized\n401'; return 0; }
    run _curl "GET" "http://example.com"
    [ "$status" -eq 1 ]
    [[ "$output" == *"401 Unauthorized"* ]]
}

@test "_curl Fail when response is HTTP 403 (Forbidden)" {
    # Mock curl: emit the body followed by the HTTP status code appended by --write-out
    curl() { printf 'Forbidden\n403'; return 0; }
    run _curl "GET" "http://example.com"
    [ "$status" -eq 1 ]
    [[ "$output" == *"403 Forbidden"* ]]
}

@test "_curl Fail when response is HTTP 404 (Not Found)" {
    # Mock curl: emit the body followed by the HTTP status code appended by --write-out
    curl() { printf 'Not Found\n404'; return 0; }
    run _curl "GET" "http://example.com"
    [ "$status" -eq 1 ]
    [[ "$output" == *"404 Not Found"* ]]
}

@test "_curl Fail when response is HTTP 500 (Internal Server Error)" {
    # Mock curl: emit the body followed by the HTTP status code appended by --write-out
    curl() { printf 'Internal Server Error\n500'; return 0; }
    run _curl "GET" "http://example.com"
    [ "$status" -eq 1 ]
    [[ "$output" == *"500 Internal Server Error"* ]]
}

@test "_curl Fail when response is HTTP 502 (Bad Gateway)" {
    # Mock curl: emit the body followed by the HTTP status code appended by --write-out
    curl() { printf 'Bad Gateway\n502'; return 0; }
    run _curl "GET" "http://example.com"
    [ "$status" -eq 1 ]
    [[ "$output" == *"502 Bad Gateway"* ]]
}

@test "_curl Fail when response is HTTP 503 (Service Unavailable)" {
    # Mock curl: emit the body followed by the HTTP status code appended by --write-out
    curl() { printf 'Service Unavailable\n503'; return 0; }
    run _curl "GET" "http://example.com"
    [ "$status" -eq 1 ]
    [[ "$output" == *"503 Service Unavailable"* ]]
}

@test "_curl Fail when response is HTTP 504 (Gateway Time-out)" {
    # Mock curl: emit the body followed by the HTTP status code appended by --write-out
    curl() { printf 'Gateway Time-out\n504'; return 0; }
    run _curl "GET" "http://example.com"
    [ "$status" -eq 1 ]
    [[ "$output" == *"504 Gateway Time-out"* ]]
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

@test "_ask_yes_or_no DEFAULT=true returns default" {
  DEFAULT=true
  run _ask_yes_or_no "question" "y"
  assert_output 'y'
}

@test "_ask_yes_or_no DEFAULT=true invalid default" {
  DEFAULT=true
  run _ask_yes_or_no "question" "z"
  [ "$status" -eq 10 ]
  [[ "$output" == *"default value is not a valid y/n"* ]]
}

@test "_ask_yes_or_no DEFAULT=true empty default" {
  DEFAULT=true
  run _ask_yes_or_no "question"
  [ "$status" -eq 10 ]
  [[ "$output" == *"default value is empty"* ]]
}

@test "_ask_yes_or_no WHIPTAIL=true yes" {
  WHIPTAIL=true
  whiptail() { return 0; }
  run _ask_yes_or_no "question"
  assert_output 'y'
}

@test "_ask_yes_or_no WHIPTAIL=true no" {
  WHIPTAIL=true
  whiptail() { return 1; }
  run _ask_yes_or_no "question"
  assert_output 'n'
}

@test "_ask_yes_or_no WHIPTAIL=true whiptail missing" {
  WHIPTAIL=true
  _installed() { return 1; }
  run _ask_yes_or_no "question"
  [ "$status" -eq 10 ]
  [[ "$output" == *"whiptail not found"* ]]
}

@test "_ask_yes_or_no default n case" {
  DEFAULT=false
  run _ask_yes_or_no "question" "n" <<< ""
  assert_output 'n'
}

@test "_ask_yes_or_no invalid default" {
  DEFAULT=false
  run _ask_yes_or_no "question" "z" <<< "y"
  [ "$status" -eq 10 ]
  [[ "$output" == *"default value is not valid y/n"* ]]
}

@test "_ask_yes_or_no invalid input warns then accepts" {
  DEFAULT=false
  run _ask_yes_or_no "question" <<< $'x\ny'
  assert_output --partial 'y'
}

@test "_ask_yes_or_no empty answer without default warns" {
  DEFAULT=false
  run _ask_yes_or_no "question" <<< $'\ny'
  assert_output --partial 'y'
}

@test "_ask_ip DEFAULT=true valid default" {
  DEFAULT=true
  run _ask_ip "question" "127.0.0.1"
  assert_output '127.0.0.1'
}

@test "_ask_ip DEFAULT=true invalid default" {
  DEFAULT=true
  run _ask_ip "question" "999.1.1.1"
  [ "$status" -eq 1 ]
  [[ "$output" == *"default value is not a valid ip address"* ]]
}

@test "_ask_ip DEFAULT=true empty default" {
  DEFAULT=true
  run _ask_ip "question"
  [ "$status" -eq 1 ]
  [[ "$output" == *"default value is empty"* ]]
}

@test "_ask_ip invalid input warns then accepts" {
  DEFAULT=false
  run _ask_ip "question" <<< $'notanip\n127.0.0.1'
  assert_output --partial '127.0.0.1'
}

@test "_ask_ip empty answer with invalid default" {
  DEFAULT=false
  run _ask_ip "question" "999.1.1.1" <<< ""
  [ "$status" -eq 1 ]
  [[ "$output" == *"default value is not a valid ip address"* ]]
}

@test "_ask_network DEFAULT=true valid default" {
  DEFAULT=true
  run _ask_network "question" "192.168.2.0/24"
  assert_output '192.168.2.0/24'
}

@test "_ask_network DEFAULT=true invalid default" {
  DEFAULT=true
  run _ask_network "question" "notanetwork"
  [ "$status" -eq 1 ]
  [[ "$output" == *"default value is not a valid network"* ]]
}

@test "_ask_network DEFAULT=true empty default" {
  DEFAULT=true
  run _ask_network "question"
  [ "$status" -eq 1 ]
  [[ "$output" == *"default value is empty"* ]]
}

@test "_ask_network invalid input warns then accepts" {
  DEFAULT=false
  run _ask_network "question" <<< $'badnetwork\n192.168.1.0/16'
  assert_output --partial '192.168.1.0/16'
}

@test "_ask_network empty answer with invalid default" {
  DEFAULT=false
  run _ask_network "question" "badnetwork" <<< ""
  [ "$status" -eq 1 ]
  [[ "$output" == *"default value is not a valid network"* ]]
}

@test "_ask_string DEFAULT=true returns default" {
  DEFAULT=true
  run _ask_string "question" "toto"
  assert_output 'toto'
}

@test "_ask_string DEFAULT=true empty default" {
  DEFAULT=true
  run _ask_string "question"
  [ "$status" -eq 1 ]
  [[ "$output" == *"default value is empty"* ]]
}

@test "_ask_string empty input warns then accepts" {
  DEFAULT=false
  run _ask_string "question" <<< $'\nhello'
  assert_output --partial 'hello'
}

####################################################################################################
######################################### EVERYTHING ELSE ##########################################
####################################################################################################
@test "_hello_world" {
  run $MY_GIT_DIR/shell/my_warp.sh -d -v --lib shell hello_world
  assert_line --index 5  'Hello world'
  assert_line --index 6 --partial 'SUCCESS'
  assert_line --index 7 --partial 'VERBOSE'
  assert_line --index 8 --partial 'INFO'
  assert_line --index 9 --partial 'WARNING'
  assert_line --index 10 --partial 'ERROR'
}

@test "_kcov" {
  run $MY_GIT_DIR/shell/my_warp.sh -v -d --lib shell -k --dry-run
  assert_success
}

@test "my_warp.sh => conf not found" {
  local __fake_home="$BATS_TEST_TMPDIR/home_no_conf"
  mkdir -p "$__fake_home"
  run env HOME="$__fake_home" "$MY_GIT_DIR/shell/my_warp.sh"
  assert_output --partial "$__fake_home/conf/my_warp.conf does not exist"
}

@test "my_warp.sh => lib_shell.sh not found" {
  local __fake_home="$BATS_TEST_TMPDIR/home_no_lib"
  mkdir -p "$__fake_home/conf" "$__fake_home/git/shell"
  echo -e "VERBOSE=false\nDEBUG=false\nMY_GIT_DIR=\"$__fake_home/git\"" > "$__fake_home/conf/my_warp.conf"
  run env HOME="$__fake_home" "$MY_GIT_DIR/shell/my_warp.sh"
  assert_output --partial "$__fake_home/git/shell/lib_shell.sh does not exist"
}

@test "my_warp.sh => dispatcher curl with options" {
  local __bindir="$BATS_TEST_TMPDIR/bin"
  mkdir -p "$__bindir"
  printf '#!/bin/bash\necho "OK"\nexit 0\n' > "$__bindir/curl"
  chmod +x "$__bindir/curl"
  run env PATH="$__bindir:$PATH" $MY_GIT_DIR/shell/my_warp.sh --lib shell curl --method POST --url "http://example.com" --header "H1" --header-data "H2" --data "data"
  assert_success
  [[ "$output" == *"OK"* ]]
}

@test "my_warp.sh => dispatcher unknown command" {
  run $MY_GIT_DIR/shell/my_warp.sh --lib shell this_command_does_not_exist
  assert_failure
  [[ "$output" == *"command this_command_does_not_exist not found"* ]]
}

####################################################################################################
############################## BASE LIBRARY COVERAGE ###############################################
####################################################################################################

######################################## WORKING DIR ###############################################

@test "_working_dir" {
  run _working_dir
  assert_success
  assert_output "$(basename "$PWD")"
}

@test "_working_dir_count_file => no pattern" {
  run _working_dir_count_file
  assert_success
  [[ "$output" =~ ^[0-9]+$ ]]
}

@test "_working_dir_count_file => with pattern" {
  run _working_dir_count_file "*.sh"
  assert_success
  [[ "$output" =~ ^[0-9]+$ ]]
}

@test "_working_dir_count_dir => no pattern" {
  run _working_dir_count_dir
  assert_success
  [[ "$output" =~ ^[0-9]+$ ]]
}

@test "_working_dir_count_dir => with pattern" {
  run _working_dir_count_dir "bats"
  assert_success
  [[ "$output" =~ ^[0-9]+$ ]]
}

@test "_working_dir_list_dir_by_creation_date" {
  run _working_dir_list_dir_by_creation_date
  assert_success
}

######################################## RAND & UUID ###############################################

@test "_gen_rand" {
  run _gen_rand
  assert_success
  [[ "$output" =~ ^[A-Z0-9-]+$ ]]
}

@test "_gen_rand with args" {
  run _gen_rand 8 "." 12
  assert_success
  [[ "$output" =~ ^[A-Z0-9.]+$ ]]
}

@test "_gen_pin" {
  run _gen_pin
  assert_success
  [[ "$output" =~ ^[0-9]{6}$ ]]
}

@test "_gen_pin with length" {
  run _gen_pin 8
  assert_success
  [[ "$output" =~ ^[0-9]{8}$ ]]
}

@test "_gen_uuid" {
  run _gen_uuid
  assert_success
  [[ "$output" =~ ^[0-9a-fA-F-]{36}$ ]]
}

@test "_gen_uuid keeps FUNC_LIST balanced when uuidgen missing" {
  FUNC_LIST=()
  _installed() { return 1; }
  _gen_uuid >/dev/null 2>&1 || true
  [[ "${#FUNC_LIST[@]}" -eq 0 ]]
}

######################################## TIME MANAGEMENT ###########################################

@test "_date" {
  run _date
  assert_success
  [[ "$output" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}[[:space:]][0-9]{2}:[0-9]{2}:[0-9]{2}$ ]]
}

@test "_timediff" {
  run _timediff "1712345678.123456789" "1712345678.223456789"
  assert_output "0s100000000"
}

@test "_timediff => borrow" {
  run _timediff "1712345678.900000000" "1712345679.100000000"
  assert_output "0s200000000"
}

@test "_timediff => leading zeros" {
  run _timediff "1712345678.001234567" "1712345678.005000000"
  assert_output "0s3765433"
}

@test "_timediff => nanosecond precision" {
  run _timediff "1.000000001" "1.000000002"
  assert_output "0s1"
}

@test "_timediff => empty start" {
  run _timediff "" "1712345678.123456789"
  assert_failure
  [[ "$output" == *"start time EMPTY"* ]]
}

@test "_timediff => empty end" {
  run _timediff "1712345678.123456789" ""
  assert_failure
  [[ "$output" == *"end time EMPTY"* ]]
}

@test "_timediff => invalid format first arg" {
  run _timediff "1.5" "2"
  assert_failure
  [[ "$output" == *"invalid timestamp"* ]]
}

@test "_timediff => invalid format second arg" {
  run _timediff "1.5" "abc"
  assert_failure
  [[ "$output" == *"invalid timestamp"* ]]
}

@test "_iso_date" {
  run _iso_date
  assert_success
  [[ "$output" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}\.[0-9]{3}Z$ ]]
}

@test "_epoch_2_date" {
  run _epoch_2_date "1712345678123"
  assert_output "2024-04-05 19:34:38"
}

@test "_epoch_2_date => minimum length" {
  run _epoch_2_date "1000"
  assert_output "1970-01-01 00:00:01"
}

@test "_epoch_2_date => non-numeric" {
  run _epoch_2_date "abc"
  assert_failure
  [[ "$output" == *"epoch not numeric"* ]]
}

@test "_epoch_2_date => too short" {
  run _epoch_2_date "123"
  assert_failure
  [[ "$output" == *"epoch too short"* ]]
}

@test "_epoch_2_date => empty" {
  run _epoch_2_date ""
  assert_failure
  [[ "$output" == *"DATE EMPTY"* ]]
}

@test "_date_2_epoch" {
  run _date_2_epoch "2024-04-05 21:34:38"
  assert_success
  [[ "$output" =~ ^[0-9]+$ ]]
}

@test "_tmp_file outside a function => error" {
  run bash -c "source $MY_GIT_DIR/shell/lib_shell.sh; _tmp_file"
  assert_failure
  [[ "$output" == *"we'r not in a function, weird"* ]]
}

@test "_tmp_file works when \$0 starts with a dash (login shell style)" {
  run bash -c "source $MY_GIT_DIR/shell/lib_shell.sh; _tmp_file_from_dash() { _tmp_file; }; _tmp_file_from_dash" -bash
  assert_success
  [[ "$output" == "/tmp/"* ]]
}

######################################## JSON OBJECT BRANCHES ######################################

@test "_json_add_key_with_value with object value" {
  run _json_add_key_with_value "{}" "" "toto" '{"a":1}'
  assert_output "{
  \"toto\": {
    \"a\": 1
  }
}"
}

@test "_json_add_value_in_array with object value" {
  run _json_add_value_in_array "{}" "" "toto" '{"a":1}'
  assert_output "{
  \"toto\": [
    {
      \"a\": 1
    }
  ]
}"
}

@test "_json_add_value_in_array with object value and IFS empty" {
  IFS=''
  run _json_add_value_in_array "{}" "" "toto" '{"a":1}'
  assert_output "{
  \"toto\": [
    {
      \"a\": 1
    }
  ]
}"
}

######################################## CURL BRANCHES ############################################

@test "_curl with 2 headers" {
  curl() { echo "OK"; return 0; }
  run _curl "GET" "http://example.com" "H1" "H2"
  [ "$status" -eq 0 ]
  [[ "$output" == "OK" ]]
}

@test "_curl with 2 headers and data" {
  curl() { echo "OK"; return 0; }
  run _curl "POST" "http://example.com" "H1" "H2" "data"
  [ "$status" -eq 0 ]
  [[ "$output" == "OK" ]]
}

@test "_curl Fail when curl returns code 3 (Wrong URL)" {
  curl() { return 3; }
  run _curl "GET" "http://example.com"
  [ "$status" -eq 3 ]
  [[ "$output" == *"Wrong URL"* ]]
}

@test "_curl Fail when curl returns code 35 (SSL)" {
  curl() { return 35; }
  run _curl "GET" "http://example.com"
  [ "$status" -eq 35 ]
  [[ "$output" == *"SSL error"* ]]
}

@test "_curl Fail when curl returns code 5 (Could not resolve proxy)" {
  curl() { return 5; }
  run _curl "GET" "http://example.com"
  [ "$status" -eq 5 ]
  [[ "$output" == *"Proxy error"* ]]
}

@test "_curl Fail when curl returns code 7 (Failed to connect to host)" {
  curl() { return 7; }
  run _curl "GET" "http://example.com"
  [ "$status" -eq 7 ]
  [[ "$output" == *"Connection error"* ]]
}

@test "_curl Fail when curl returns code 23 (Write error)" {
  curl() { return 23; }
  run _curl "GET" "http://example.com"
  [ "$status" -eq 23 ]
  [[ "$output" == *"Write error"* ]]
}

@test "_curl Fail when curl returns code 26 (Read error)" {
  curl() { return 26; }
  run _curl "GET" "http://example.com"
  [ "$status" -eq 26 ]
  [[ "$output" == *"Read error"* ]]
}

@test "_curl Fail when curl returns code 47 (Too many redirects)" {
  curl() { return 47; }
  run _curl "GET" "http://example.com"
  [ "$status" -eq 47 ]
  [[ "$output" == *"Too many redirects"* ]]
}

@test "_curl Fail when curl returns other code" {
  curl() { return 99; }
  run _curl "GET" "http://example.com"
  [ "$status" -eq 99 ]
  [[ "$output" == *"Something went wrong"* ]]
}

######################################## DECODE URL BRANCHES #######################################

@test "_decode_url with plus sign" {
  run _decode_url "a+b"
  assert_output "a b"
}

@test "_decode_url plain text" {
  run _decode_url "abc"
  assert_output "abc"
}

@test "_decode_url does not leak global j" {
  j="KEEP_ME"
  _decode_url "a%20b+c" >/dev/null
  [ "$j" == "KEEP_ME" ]
}

@test "_decode_url keeps FUNC_LIST balanced" {
  FUNC_LIST=()
  _decode_url "abc" >/dev/null 2>&1
  [[ "${#FUNC_LIST[@]}" -eq 0 ]]
  _decode_url "a%20b+c" >/dev/null 2>&1
  [[ "${#FUNC_LIST[@]}" -eq 0 ]]
}

######################################## SHELLCHECK BRANCHES #######################################

@test "_shellcheck with explicit files (no LIB)" {
  run _shellcheck "$MY_GIT_DIR/shell/lib_shell.sh"
  assert_success
}

@test "_shellcheck => _error must be followed by return or exit >0" {
  local f="$BATS_TEST_TMPDIR/bad_error.sh"
  printf '#!/bin/bash\n_error "some error message"\n' > "$f"
  run _shellcheck "$f"
  [ "$status" -eq 1 ]
  [[ "$output" == *"_error must be followed by return or exit >0"* ]]
}

@test "_shellcheck => grep is not allowed" {
  local f="$BATS_TEST_TMPDIR/raw_grep.sh"
  printf '#!/bin/bash\n# call: _myfunc ()\n# description: test fixture.\n_myfunc() {\n    echo "hello" | grep hello\n}\n' > "$f"
  run _shellcheck "$f"
  [ "$status" -eq 1 ]
  [[ "$output" == *"grep is not allowed"* ]]
}

@test "_shellcheck => _func_end must have an arg" {
  local f="$BATS_TEST_TMPDIR/func_end_noarg.sh"
  printf '#!/bin/bash\n# call: _myfunc ()\n# description: test fixture.\n_myfunc() {\n    _func_end\n}\n' > "$f"
  run _shellcheck "$f"
  [ "$status" -eq 1 ]
  [[ "$output" == *"_func_end must have an arg then followed by return"* ]]
}

@test "_shellcheck => _func_end must be followed by return" {
  local f="$BATS_TEST_TMPDIR/func_end_noreturn.sh"
  printf '#!/bin/bash\n# call: _myfunc ()\n# description: test fixture.\n_myfunc() {\n    _func_end "0"\n}\n' > "$f"
  run _shellcheck "$f"
  [ "$status" -eq 1 ]
  [[ "$output" == *"_func_end must be followed by return"* ]]
}

@test "_shellcheck => must have an _error message if we return 1" {
  local f="$BATS_TEST_TMPDIR/func_end_noerror.sh"
  printf '#!/bin/bash\n# call: _myfunc ()\n# description: test fixture.\n_myfunc() {\n    _func_end "1" ; return 1\n}\n' > "$f"
  run _shellcheck "$f"
  [ "$status" -eq 1 ]
  [[ "$output" == *"must have an _error message if we return 1"* ]]
}

@test "_shellcheck => returning 0 is a bad idea" {
  local f="$BATS_TEST_TMPDIR/return_zero.sh"
  printf '#!/bin/bash\n# call: _myfunc ()\n# description: test fixture.\n_myfunc() {\n    if [ "$1" = "x" ]; then\n        return 0\n    fi\n    echo "done"\n}\n' > "$f"
  run _shellcheck "$f"
  [ "$status" -eq 1 ]
  [[ "$output" == *"returning 0 is may be a bad idea"* ]]
}

@test "_shellcheck => return 0 before the last } of a function is allowed" {
  local f="$BATS_TEST_TMPDIR/return_zero_end.sh"
  printf '#!/bin/bash\n# call: _myfunc ()\n# description: test fixture.\n_myfunc() {\n    _func_start "$@"\n    echo "done"\n    _func_end "0" ; return 0\n}\n__TOP_LEVEL=1\n' > "$f"
  run _shellcheck "$f"
  [ "$status" -eq 0 ]
  [[ "$output" == *"no error found with shellcheck"* ]]
}

@test "_shellcheck => do not use curl but _curl" {
  local f="$BATS_TEST_TMPDIR/raw_curl.sh"
  printf '#!/bin/bash\n# call: _myfunc ()\n# description: test fixture.\n_myfunc() {\n    curl http://example.com\n}\n' > "$f"
  run _shellcheck "$f"
  [ "$status" -eq 1 ]
  [[ "$output" == *"do not use curl but _curl instead"* ]]
}

@test "_shellcheck => can't test docker return with a pipe" {
  local f="$BATS_TEST_TMPDIR/docker_pipe.sh"
  printf '#!/bin/bash\n# call: _myfunc ()\n# description: test fixture.\n_myfunc() {\n    docker ps | wc -l\n}\n' > "$f"
  run _shellcheck "$f"
  [ "$status" -eq 1 ]
  [[ "$output" == *"can't test docker return is used with a pipe"* ]]
}

@test "_shellcheck => we must test \$? with an _error" {
  local f="$BATS_TEST_TMPDIR/dollar_question.sh"
  printf '#!/bin/bash\n# call: _myfunc ()\n# description: test fixture.\n_myfunc() {\n    ls > /dev/null\n    echo "$?"\n}\n' > "$f"
  run _shellcheck "$f"
  [ "$status" -eq 1 ]
  [[ "$output" == *"we must test \$? and have _error if smth goes wrong"* ]]
}

@test "_shellcheck => something went wrong with shellcheck" {
  local f="$BATS_TEST_TMPDIR/bad_syntax.sh"
  printf '#!/bin/bash\nif then\n' > "$f"
  run _shellcheck "$f"
  [ "$status" -eq 1 ]
  [[ "$output" == *"something went wrong with shellcheck"* ]]
}

@test "_shellcheck => _func_end missing before return" {
  local f="$BATS_TEST_TMPDIR/func_end_missing.sh"
  printf '#!/bin/bash\n# call: _myfunc ()\n# description: test fixture.\n_myfunc() {\n    _func_start "$@"\n    _error "oops" ; return 1\n}\n' > "$f"
  run _shellcheck "$f"
  [ "$status" -eq 1 ]
  [[ "$output" == *"_func_end missing before return"* ]]
}

######################################## BATS & KCOV BRANCHES ######################################

@test "_bats when bats fails" {
  LIB=shell
  bats() { return 1; }
  run _bats
  [ "$status" -eq 1 ]
  [[ "$output" == *"something went wrong with bats"* ]]
}

@test "_bats when bats not installed" {
  LIB=shell
  _installed() { return 1; }
  run _bats
  [ "$status" -eq 1 ]
  [[ "$output" == *"bats not found"* ]]
}

@test "_bats forwards the filter regex to bats --filter" {
  LIB=shell
  bats() { printf '%s\n' "$@"; return 0; }
  run _bats "^_load_lib => true$"
  [ "$status" -eq 0 ]
  [[ "$output" == *"--filter"* ]]
  [[ "$output" == *"^_load_lib => true$"* ]]
  [[ "$output" == *"bats/tests.bats"* ]]
}

@test "_bats without filter does not pass --filter" {
  LIB=shell
  bats() { printf '%s\n' "$@"; return 0; }
  run _bats
  [ "$status" -eq 0 ]
  [[ "$output" == *"--verbose-run"* ]]
  [[ "$output" != *"--filter"* ]]
}

@test "_bats rejects more than one filter argument" {
  LIB=shell
  bats() { printf '%s\n' "$@"; return 0; }
  run _bats "alpha" "beta"
  [ "$status" -eq 10 ]
  [[ "$output" == *"too many arguments: only one filter regex is supported"* ]]
}

@test "_kcov real run with mocked kcov" {
  DRY_RUN=false
  LIB=shell
  kcov() {
    mkdir -p "$3/my_warp.sh"
    printf '{"files":[{"file":"test.sh","percent_covered":"50"}]}' > "$3/my_warp.sh/coverage.json"
    return 0
  }
  run _kcov
  assert_success
  [[ "$output" == *"test.sh 50"* ]]
}

@test "_kcov fails when jq missing" {
  LIB=shell
  _installed() { case "$1" in jq) return 1 ;; *) return 0 ;; esac; }
  run _kcov
  assert_failure
  [[ "$output" == *"jq not found"* ]]
}

@test "_kcov real run with upload and keep (AI)" {
  DRY_RUN=false
  LIB=shell
  CODECOV_TOKEN="fake-token"
  GITHUB_USERNAME="fake-user"
  kcov() {
    mkdir -p "$3/my_warp.sh"
    printf '{"files":[{"file":"test.sh","percent_covered":"50"}]}' > "$3/my_warp.sh/coverage.json"
    cat > "$3/my_warp.sh/cobertura.xml" <<'EOF'
<coverage line-rate="0.5">
  <packages>
    <package name="shell">
      <classes>
        <class name="lib_shell.sh" filename="lib_shell.sh" line-rate="0.5">
          <lines>
            <line number="1" hits="0"/>
          </lines>
        </class>
      </classes>
    </package>
  </packages>
</coverage>
EOF
    return 0
  }
  codecov() { return 0; }
  run _kcov AI
  assert_success
  [[ "$output" == *"kcov report kept at:"* ]]
  [[ "$output" == *"uncovered lines: lib_shell.sh:1"* ]]
}

@test "_kcov_resume => outputs uncovered lines per file" {
  local __dir="$BATS_TEST_TMPDIR/resume"
  mkdir -p "$__dir"
  cat > "$__dir/cobertura.xml" <<'EOF'
<coverage line-rate="0.5">
  <packages>
    <package name="shell">
      <classes>
        <class name="lib_shell.sh" filename="lib_shell.sh" line-rate="0.5">
          <lines>
            <line number="156" hits="1"/>
            <line number="191" hits="0"/>
            <line number="206" hits="0"/>
            <line number="222" hits="1"/>
          </lines>
        </class>
        <class name="my_warp.sh" filename="my_warp.sh" line-rate="1.0">
          <lines>
            <line number="1" hits="1"/>
            <line number="2" hits="1"/>
          </lines>
        </class>
      </classes>
    </package>
  </packages>
</coverage>
EOF
  run _kcov_resume "$__dir"
  assert_success
  [[ "$output" == *"lib_shell.sh:191,206"* ]]
  [[ "$output" == *"my_warp.sh:"* ]]
}

@test "_kcov_resume => discovers files from the report (e.g. lib_tempo_shell.sh)" {
  local __dir="$BATS_TEST_TMPDIR/resume_tempo"
  mkdir -p "$__dir"
  cat > "$__dir/cobertura.xml" <<'EOF'
<coverage line-rate="0.5">
  <packages>
    <package name="tempo_shell">
      <classes>
        <class name="lib_tempo_shell.sh" filename="lib_tempo_shell.sh" line-rate="0.5">
          <lines>
            <line number="10" hits="0"/>
            <line number="11" hits="1"/>
          </lines>
        </class>
      </classes>
    </package>
  </packages>
</coverage>
EOF
  run _kcov_resume "$__dir"
  assert_success
  [[ "$output" == *"lib_tempo_shell.sh:10"* ]]
}

@test "_kcov_resume => empty lists when all lines covered" {
  local __dir="$BATS_TEST_TMPDIR/resume_ok"
  mkdir -p "$__dir"
  cat > "$__dir/cobertura.xml" <<'EOF'
<coverage line-rate="1.0">
  <packages>
    <package name="shell">
      <classes>
        <class name="lib_shell.sh" filename="lib_shell.sh" line-rate="1.0">
          <lines>
            <line number="156" hits="1"/>
            <line number="191" hits="1"/>
          </lines>
        </class>
        <class name="my_warp.sh" filename="my_warp.sh" line-rate="1.0">
          <lines>
            <line number="1" hits="1"/>
          </lines>
        </class>
      </classes>
    </package>
  </packages>
</coverage>
EOF
  run _kcov_resume "$__dir"
  assert_success
  [[ "$output" == *"lib_shell.sh:"* ]]
  [[ "$output" == *"my_warp.sh:"* ]]
}

@test "_kcov_resume => cobertura.xml not found" {
  local __dir="$BATS_TEST_TMPDIR/resume_missing"
  mkdir -p "$__dir"
  run _kcov_resume "$__dir"
  [ "$status" -eq 1 ]
  [[ "$output" == *"cobertura.xml not found"* ]]
}

@test "_kcov_resume => dir empty" {
  run _kcov_resume
  [ "$status" -eq 10 ]
  [[ "$output" == *"DIR EMPTY"* ]]
}

@test "_kcov_resume => dir does not exist" {
  run _kcov_resume "$BATS_TEST_TMPDIR/does_not_exist"
  [ "$status" -eq 10 ]
  [[ "$output" == *"DIR NOT FOUND"* ]]
}