# `lib_shell.sh` — Function Reference

This document describes every function defined in `lib_shell.sh`.

> **General conventions**
> - Functions whose name starts with a single underscore (e.g. `_info`) are library functions.
> - Functions ending with `() {` and implementing telemetry call `_func_start` / `_func_end`; the telemetry functions themselves (`_func_start`, `_func_end`, `_log`, `_verbose_func_space`) do not for recursion reasons.
> - Many helpers accept their input either as arguments or via stdin (piped). When no argument is given, stdin is used.
> - Exit code `0` means success, non-zero means failure 

---

## Logger & Output Helpers

### `_echoerr`
1. **Description:** Prints a message to standard error (stderr), with `echo -e` so escape sequences are interpreted.
2. **Usage:**
   - `_echoerr "message"`
   - `_echoerr $@`
3. **Returns:** Always `0` (exit status of `echo`).

### `_verbose_func_space`
1. **Description:** Builds the global `VERBOSE_SPACE` string by concatenating the function names stored in `FUNC_LIST`, producing an indentation/trace prefix like ` func1 > func2 >`.
2. **Usage:**
   - `_verbose_func_space` (no arguments; relies on the global `FUNC_LIST` array)
3. **Returns:** Always `0`. Sets the global variable `VERBOSE_SPACE`.

### `_func_start`
1. **Description:** Telemetry hook called at the entry point of every instrumented library function. Records the caller's name and a start timestamp (seconds.nanoseconds) into the global `FUNC_LIST` array. When `DEBUG` is enabled, logs the start and, if `VERBOSE` is enabled, logs each argument (`$1`, `$2`, ...) or `no args`.
2. **Usage:**
   - `_func_start "$@"` (pass through the calling function's arguments)
3. **Returns:** Always `0`. Side effect: appends `caller:start_time` to `FUNC_LIST`, sets `VERBOSE_SPACE`.

### `_func_end`
1. **Description:** Telemetry hook called before returning from an instrumented function. Pops the last entry from `FUNC_LIST`, computes the elapsed duration in nanoseconds via `_timediff`, and, when `DEBUG` is enabled, logs an `End` (or `End - returning:<code> - in <duration>ns`) message.
2. **Usage:**
   - `_func_end` — plain end
   - `_func_end "0"` — end reporting a return code, e.g. `_func_end "$return_code"`
3. **Returns:** Always `0`. Side effect: removes the last element of `FUNC_LIST`.

### `_error`
1. **Description:** Logs a message at the **ERROR** level with a red ✗ check prefix.
2. **Usage:**
   - `_error "message"`
3. **Returns:** Always `0` (relies on `_log`).

### `_warning`
1. **Description:** Logs a message at the **WARNING** level with a yellow ▲ prefix.
2. **Usage:**
   - `_warning "message"`
3. **Returns:** Always `0`.

### `_success`
1. **Description:** Logs a message at the **SUCCESS** level with a green ✓ prefix.
2. **Usage:**
   - `_success "message"`
3. **Returns:** Always `0`.

### `_info`
1. **Description:** Logs a message at the **INFO** level with a blue ★ prefix.
2. **Usage:**
   - `_info "message"`
3. **Returns:** Always `0`.

### `_debug`
1. **Description:** Logs a message at the **DEBUG** level (no colored prefix). Output is suppressed unless the global `DEBUG` variable is `true`.
2. **Usage:**
   - `_debug "message"`
3. **Returns:** Always `0`.

### `_verbose`
1. **Description:** Logs a message at the **VERBOSE** level (no colored prefix). Output is suppressed unless the global `VERBOSE` variable is `true`.
2. **Usage:**
   - `_verbose "message"`
3. **Returns:** Always `0`.

### `_verbose_file`
1. **Description:** Dumps the content of a file to stderr between `--- dump file start ---` / `--- dump file end ---` markers. The markers are always logged at VERBOSE level; the actual file content is only printed when `$VERBOSE` is `true`.
2. **Usage:**
   - `_verbose_file "/path/to/file"`
   - `$1` — path of the file to dump
3. **Returns:**
   - `0` — file exists (dumped when `VERBOSE=true`)
   - `1` — file does not exist (logs `can verbose $1, not exist`)

### `_log`
1. **Description:** Core logger used by `_error`, `_warning`, `_success`, `_info`, `_debug`, `_verbose`. Formats the message with level, color, date, and function trace (`VERBOSE_SPACE`), and prints to stderr. Suppresses DEBUG/VERBOSE messages when the corresponding flags are off.
2. **Usage:**
   - `_log "<level>" "<color-ansi>" "<message>"`
     - `$1` — level string, e.g. `ERROR  `, `WARNING`, `INFO   `
     - `$2` — ANSI color code, e.g. `\033[0;31m`
     - `$3` — message
3. **Returns:** Always `0`.

---

## Validation Primitives

### `_exist`
1. **Description:** Checks whether the first argument is a non-empty string (presence check).
2. **Usage:**
   - `_exist "$var"` — true if `$var` is non-empty
3. **Returns:**
   - `0` — argument is non-empty
   - `1` — argument is empty/not present

### `_fileexist`
1. **Description:** Checks whether the file or path given as `$1` exists on disk.
2. **Usage:**
   - `_fileexist "/path/to/file"`
3. **Returns:**
   - `0` — path exists
   - `1` — path does not exist

### `_remotefileexist`
1. **Description:** Same existence check as `_fileexist` but designed for NFS/remote files: it uses `timeout 1 stat -t "$1"` so a hanging filesystem answers within 1 second instead of blocking.
2. **Usage:**
   - `_remotefileexist "/path/to/remote/file"`
   - `$1` — path to check
3. **Returns:**
   - `0` — path exists (stat returned `0`)
   - `1` — path does not exist, or the check timed out after 1 second (stat returned `124`)

### `_func_exist`
1. **Description:** Checks whether a shell function with the given name is defined.
2. **Usage:**
   - `_func_exist "_func_exist"`
   - `$1` — function name to look up
3. **Returns:**
   - `0` — a function with that name exists (`type -t` returns `function`)
   - `1` — no such function (or `$1` empty)

### `_installed`
1. **Description:** Checks whether a command/binary is available in `PATH`.
2. **Usage:**
   - `_installed "curl"`
3. **Returns:**
   - `0` — command found
   - `1` — command not found

---

## Working Directory Helpers

### `_working_dir`
1. **Description:** Prints the basename of the current working directory.
2. **Usage:**
   - `_working_dir` (no arguments)
3. **Returns:** Always `0`. Outputs the directory basename on stdout.

### `_working_dir_count_file`
1. **Description:** Counts files in the current directory (depth 1). With an argument, counts only files matching the given name pattern.
2. **Usage:**
   - `_working_dir_count_file` — count all files
   - `_working_dir_count_file "*.conf"` — count files matching pattern
3. **Returns:** Always `0`. Outputs the file count on stdout.

### `_working_dir_count_dir`
1. **Description:** Counts directories in the current directory (depth 1). With an argument, counts only directories matching the given name pattern.
2. **Usage:**
   - `_working_dir_count_dir` — count all directories
   - `_working_dir_count_dir "build*"` — count directories matching pattern
3. **Returns:** Always `0`. Outputs the directory count on stdout.

### `_working_dir_list_dir_by_creation_date`
1. **Description:** Lists directories in the current directory (depth 1) sorted by their creation date.
2. **Usage:**
   - `_working_dir_list_dir_by_creation_date` (no arguments)
3. **Returns:** Always `0`. Outputs one directory path per line, sorted by creation time.

---

## Temporary Files & Random Generation

### `_tmp_file`
1. **Description:** Prints a pseudo-random temporary file path under `/tmp` based on the current script name and the calling function name.
2. **Usage:**
   - `_tmp_file` (no arguments; must be called from inside a function)
3. **Returns:**
   - `0` — success; prints the temp path on stdout
   - `1` — called outside a function (logs `we'r not in a function, weird`)

### `_gen_rand`
1. **Description:** Generates a random alphanumeric string (uppercase letters and digits, excluding `I`, `O`, `S`) from `/dev/urandom`.
2. **Usage:**
   - `_gen_rand` — default: blocks of `4`, separator `-`, max `29` chars
   - `_gen_rand 8` — 8-char blocks
   - `_gen_rand 8 "."` — 8-char blocks joined with `.`
   - `_gen_rand 8 "." 12` — truncated to 12 chars
   - `$1` — block width (default `4`)
   - `$2` — block separator (default `-`)
   - `$3` — maximum output length (default `29`)
3. **Returns:** Always `0`. Outputs the random string on stdout.

### `_gen_pin`
1. **Description:** Generates a random numeric PIN from `/dev/urandom`.
2. **Usage:**
   - `_gen_pin` — default length `6`
   - `_gen_pin 8` — 8-digit PIN
   - `$1` — length (default `6`)
3. **Returns:** Always `0`. Outputs the PIN on stdout.

### `_gen_uuid`
1. **Description:** Generates a UUID using the `uuidgen` command.
2. **Usage:**
   - `_gen_uuid` (no arguments; requires `uuidgen` installed)
3. **Returns:**
   - `0` — success; outputs the UUID on stdout
   - `10` (`ERROR_ARGV`) — `uuidgen` not installed

---

## Process Options & Orchestrator Helpers

> These functions implement the orchestrator's CLI parsing, usage display, and library loading. They rely on the runtime globals `$MY_GIT_DIR`, `$LIB`, `$CUR_NAME`, `$OPTS`, and the per-lib `GETOPT_SHORT_<LIB>` variables set up by `my_warp.sh`.

### `_process_opts`
1. **Description:** Parses the command-line arguments with `getopt` (short options from `_getopt_short`, long options from `_getopt_long`), sets the matching global flags (`VERBOSE`, `DEBUG`, `DRY_RUN`, `DEFAULT`, `FORCE`, `YUBIKEY`, `LIB`, `ACTION`), and dispatches the `--help`, `--list-libs`, `--bats`, `--shellcheck`, and `--kcov` actions.
2. **Usage:**
   - `_process_opts "$@"`
3. **Returns:**
   - `0` — options parsed and the requested action succeeded
   - `1` — bad/missing argument, or one of the dispatched actions failed

### `_getopt_short`
1. **Description:** Builds the short option string for `getopt` by concatenating the `GETOPT_SHORT_<LIB>` variable of every installed library (e.g. `GETOPT_SHORT_SHELL=h,v,d,b,s,k`), joined with commas.
2. **Usage:**
   - `_getopt_short` (no arguments; requires `MY_GIT_DIR` and `_get_installed_libs`)
3. **Returns:** Always `0`. Outputs the short option list on stdout (e.g. `h,v,d,b,s,k`).

### `_getopt_long`
1. **Description:** Builds the long option string for `getopt` from the `# usage` comment lines of every installed library plus the built-in options (`debug,verbose,help,list-libs,bats,shellcheck,kcov,dry-run,default,force,yubikey`, the `lib:` placeholder, and each library name).
2. **Usage:**
   - `_getopt_long` (no arguments; requires `MY_GIT_DIR` and `_get_installed_libs`)
3. **Returns:** Always `0`. Outputs the long option list on stdout.

### `_usage`
1. **Description:** Prints the orchestrator usage. Without `$LIB`, prints the generic help; with `$LIB` set, calls the optional `_usage_$LIB` function and lists every `# usage` line of the library as `$CUR_NAME --lib $LIB <command>`.
2. **Usage:**
   - `_usage`
   - `_usage` with `$LIB` set (e.g. via `./my_warp.sh --lib shell -h`)
3. **Returns:**
   - `0` — usage displayed
   - `1` — `$LIB` is set but `$MY_GIT_DIR/$LIB/lib_$LIB.sh` does not exist (`No such LIB`)

### `_load_libs`
1. **Description:** Sources `lib_shell.sh` (itself) and then every installed library `$MY_GIT_DIR/<lib>/lib_<lib>.sh` found by `_get_installed_libs`.
2. **Usage:**
   - `_load_libs` (no arguments; requires `MY_GIT_DIR`)
3. **Returns:** Always `0` (unless a `source` fails). Not telemetry-instrumented.

### `_load_lib`
1. **Description:** Sources a single library `$MY_GIT_DIR/$1/lib_$1.sh`.
2. **Usage:**
   - `_load_lib "shell"`
   - `$1` — library name
3. **Returns:**
   - `0` — library sourced successfully
   - `10` (`ERROR_ARGV`) — `$1` empty (`LIB EMPTY`) or `$MY_GIT_DIR/$1/lib_$1.sh` does not exist

### `_load_conf`
1. **Description:** Sources a configuration file. If a `my_<basename>` variant exists next to it (e.g. `my_my_warp.conf`), that one is sourced instead of the original.
2. **Usage:**
   - `_load_conf "/path/to/conf/file"`
   - `$1` — path of the configuration file
3. **Returns:**
   - `0` — configuration sourced
   - `10` (`ERROR_ARGV`) — `$1` empty (`CONF EMPTY`) or the file does not exist

### `_get_installed_libs`
1. **Description:** Lists the names of all installed libraries, i.e. every directory under `$MY_GIT_DIR` that contains a matching `lib_<dir>.sh` file.
2. **Usage:**
   - `_get_installed_libs` (no arguments; requires `MY_GIT_DIR`)
3. **Returns:** Always `0`. Outputs the space-separated list of library names on stdout (trailing space removed).

---

## Time Management

### `_date`
1. **Description:** Prints the current local date/time formatted as `YYYY-MM-DD HH:MM:SS`.
2. **Usage:**
   - `_date` (no arguments)
3. **Returns:** Always `0`. Outputs the date string on stdout.

### `_iso_date`
1. **Description:** Prints the current UTC date/time in ISO 8601 format with milliseconds (`YYYY-MM-DDTHH:MM:SS.mmmZ`).
2. **Usage:**
   - `_iso_date` (no arguments)
3. **Returns:** Always `0`. Outputs the ISO date string on stdout.

### `_timediff`
1. **Description:** Computes the duration between two timestamps in `seconds.nanoseconds` format and prints it as `<seconds>s<nanoseconds>` with full nanosecond precision (no rounding), e.g. `12s345678901`.
2. **Usage:**
   - `_timediff "start" "end"`
     - `$1` — start timestamp, e.g. `1712345678.123456789`
     - `$2` — end timestamp, same format
3. **Returns:**
   - `0` — success; outputs the duration on stdout
   - `1` — start or end time empty, or either timestamp not in `seconds.nanoseconds` format (`invalid timestamp, expected seconds.nanoseconds`)

### `_epoch_2_date`
1. **Description:** Converts an epoch timestamp (milliseconds) to a UTC date string `YYYY-MM-DD HH:MM:SS`. The input must be a non-empty numeric string of at least 4 digits (e.g. `1000` → `1970-01-01 00:00:01`).
2. **Usage:**
   - `_epoch_2_date "1712345678123"` (epoch in milliseconds)
3. **Returns:**
   - `0` — success; outputs the UTC date on stdout
   - `1` — argument empty (`DATE EMPTY`), non-numeric input (`epoch not numeric`), or input shorter than 4 digits (`epoch too short`)

### `_date_2_epoch`
1. **Description:** Converts a date string to a UTC epoch timestamp in **milliseconds** (`%s%3N`).
2. **Usage:**
   - `_date_2_epoch "2024-04-05 12:34:56"`
3. **Returns:**
   - `0` — success; outputs the epoch milliseconds on stdout
   - `1` — argument empty

---

## Array Management

> Arrays are passed by **name** (nameref), not by value. They must exist in the caller's scope.

### `_array_print`
1. **Description:** Prints all elements of an array, one per line, prefixed with their index (`[0]:value`).
2. **Usage:**
   - `_array_print "my_array"` — `$1` is the array name
3. **Returns:**
   - `0` — success
   - `1` — array name empty

### `_array_print_index`
1. **Description:** Prints the element of an array at a given index.
2. **Usage:**
   - `_array_print_index "my_array" "2"` — `$1` array name, `$2` index
3. **Returns:**
   - `0` — success; outputs the element on stdout
   - `1` — array name or index empty

### `_array_add`
1. **Description:** Appends an element to an array.
2. **Usage:**
   - `_array_add "my_array" "new_element"` — `$1` array name, `$2` element
3. **Returns:**
   - `0` — success
   - `1` — array name or element empty

### `_array_remove_last`
1. **Description:** Removes the last element of an array.
2. **Usage:**
   - `_array_remove_last "my_array"` — `$1` array name
3. **Returns:**
   - `0` — success
   - `1` — array name empty

### `_array_remove_index`
1. **Description:** Removes the element at a given index and re-indexes the array (holes are compacted).
2. **Usage:**
   - `_array_remove_index "my_array" "2"` — `$1` array name, `$2` index
3. **Returns:**
   - `0` — success
   - `1` — array name or index empty

### `_array_count_elt`
1. **Description:** Prints the number of elements in an array.
2. **Usage:**
   - `_array_count_elt "my_array"` — `$1` array name
3. **Returns:**
   - `0` — success; outputs the element count on stdout
   - `1` — no argument given

---

## YAML & JSON Management

> JSON helpers require `jq`; YAML helpers require `yq` (version 4). Unless stated otherwise, input is the JSON/YAML text (argument or stdin) and the converted output is printed on stdout.

### `_json_2_yaml`
1. **Description:** Converts JSON input to YAML using `yq`.
2. **Usage:**
   - `_json_2_yaml "$json"`
   - `echo "$json" | _json_2_yaml`
3. **Returns:**
   - `0` — success; outputs YAML on stdout
   - `10` (`ERROR_ARGV`) — `yq` not installed
   - `1` — unsupported `yq` version (needs v4) or `yq` conversion error

### `_yaml_2_json`
1. **Description:** Converts YAML input to JSON using `yq`.
2. **Usage:**
   - `_yaml_2_yaml "$yaml"`
   - `echo "$yaml" | _yaml_2_json`
3. **Returns:**
   - `0` — success; outputs JSON on stdout
   - `10` (`ERROR_ARGV`) — `yq` not installed
   - `1` — unsupported `yq` version (needs v4) or `yq` conversion error

### `_json_add_key_with_value`
1. **Description:** Adds a key/value pair into a JSON document at a given path. The value is inserted as a raw JSON literal (object, array, number, boolean, or quoted string), so `$4` must be valid JSON.
2. **Usage:**
   - `_json_add_key_with_value "$json" "path" "key" "value"`
     - `$1` — JSON input
     - `$2` — target path, e.g. `foo` or empty for root (keys are never prefixed with a leading dot)
     - `$3` — key to add
     - `$4` — value to set as a JSON literal, e.g. `{"a":1}`, `true`, `1`, or `"text"`
3. **Returns:**
   - `0` — success; outputs the modified JSON on stdout
   - `10` (`ERROR_ARGV`) — missing JSON/key/value, or `jq` not installed
   - `1` — `jq` processing error

### `_json_add_value_in_array`
1. **Description:** Appends a value to an array inside a JSON document (creates the array path if needed).
2. **Usage:**
   - `_json_add_value_in_array "$json" "path" "array" "value"`
     - `$1` — JSON input
     - `$2` — optional parent path prefix (if empty, `$3` is used directly); keys are never prefixed with a leading dot
     - `$3` — array key/path
     - `$4` — value to append (string, or `{...}` JSON object)
3. **Returns:**
   - `0` — success; outputs the modified JSON on stdout
   - `10` (`ERROR_ARGV`) — missing JSON/array/value, or `jq` not installed
   - `1` — `jq` processing error

### `_json_remove_key`
1. **Description:** Removes a key (or path) from a JSON document.
2. **Usage:**
   - `_json_remove_key "$json" "foo.bar"`
     - `$1` — JSON input
     - `$2` — key/path to delete, e.g. `foo` (never prefixed with a leading dot)
3. **Returns:**
   - `0` — success; outputs the modified JSON on stdout
   - `10` (`ERROR_ARGV`) — missing JSON/key, or `jq` not installed
   - `1` — `jq` processing error

### `_json_replace_key_with_value`
1. **Description:** Replaces the value of an existing key in a JSON document.
2. **Usage:**
   - `_json_replace_key_with_value "$json" "foo" "new_value"`
     - `$1` — JSON input
     - `$2` — key/path whose value to replace (never prefixed with a leading dot)
     - `$3` — new value (string)
3. **Returns:**
   - `0` — success; outputs the modified JSON on stdout
   - `10` (`ERROR_ARGV`) — missing JSON/key/value, or `jq` not installed
   - `1` — `jq` processing error

### `_json_get_value_from_key`
1. **Description:** Extracts the value of a key (or path) from a JSON document and prints it without quotes (`jq -r`). The key is resolved via `getpath`, so keys containing special characters are supported.
2. **Usage:**
   - `_json_get_value_from_key "$json" "foo.bar"`
     - `$1` — JSON input
     - `$2` — key/path to read (never prefixed with a leading dot)
3. **Returns:**
   - `0` — key found and value not `null`; outputs the raw value on stdout (a JSON string equal to `"null"` is a valid value and returns `0`)
   - `10` (`ERROR_ARGV`) — missing JSON/key, or `jq` not installed
   - `1` — key resolves to JSON `null`/missing

### `_json_get_value_from_array`
1. **Description:** Iterates the elements of an array at a given path and prints the value of a key for every matching element, one per line (`jq -r`). An optional `(match-key, match-value)` pair restricts the iteration to elements where `.[match-key] == match-value`; pass both empty to match all elements. The array path is resolved via `getpath`, so keys containing special characters are supported.
2. **Usage:**
   - `_json_get_value_from_array "$json" "content.sections" "dashboardId" "child-123" "name"` — prints the `name` of every section whose `dashboardId` equals `child-123`.
   - `_json_get_value_from_array "$json" "content.sections" "" "" "name"` — prints the `name` of every section.
     - `$1` — JSON input
     - `$2` — array path to read (never prefixed with a leading dot)
     - `$3` — match key (empty to match all)
     - `$4` — match value (empty to match all)
     - `$5` — key whose value is printed for each matching element
3. **Returns:**
   - `0` — success; outputs the key values on stdout (no output when the array is empty or no element matches)
   - `10` (`ERROR_ARGV`) — missing JSON/array path/return key, or `jq` not installed
   - `1` — `jq` processing error

---

## String Management

### `_upper`
1. **Description:** Converts the input string to uppercase.
2. **Usage:**
   - `_upper "hello world"`
   - `echo "hello world" | _upper`
3. **Returns:** Always `0`. Outputs the uppercased string on stdout.

### `_lower`
1. **Description:** Converts the input string to lowercase.
2. **Usage:**
   - `_lower "HELLO WORLD"`
   - `echo "HELLO WORLD" | _lower`
3. **Returns:** Always `0`. Outputs the lowercased string on stdout.

### `_remove_french`
1. **Description:** Removes all French accentuation from the input string, replacing each accented letter with its unaccented base letter (`è`/`È` → `e`/`E`, `à`/`À` → `a`/`A`, `ç`/`Ç` → `c`/`C`, ...). Covers `à â ä é è ê ë î ï ô ö ù û ü ÿ ç` and their uppercase forms. Non-accented characters (including ligatures like `œ`/`æ`) are left unchanged.
2. **Usage:**
   - `_remove_french "Crème Brûlée"`
   - `echo "déjà vu" | _remove_french`
3. **Returns:** Always `0`. Outputs the accent-free string on stdout.

### `_remove_last_car`
1. **Description:** Removes the last character of the input string.
2. **Usage:**
   - `_remove_last_car "hello"`
   - `echo "hello" | _remove_last_car`
3. **Returns:** Always `0`. Outputs the truncated string on stdout.

### `_is_ascii`
1. **Description:** Checks whether the given string contains only printable ASCII characters (0x20–0x7E).
2. **Usage:**
   - `_is_ascii "some-string"`
3. **Returns:**
   - `0` — string is printable ASCII
   - `1` — string contains non-ASCII or non-printable characters

### `_is_numeric`
1. **Description:** Checks whether the given string contains only digits (0–9).
2. **Usage:**
   - `_is_numeric "123"`
3. **Returns:**
   - `0` — string is numeric
   - `1` — string is empty or contains non-digit characters

### `_startswith`
1. **Description:** Checks whether a string starts with a given prefix. Pure-bash implementation (no subprocess), so it works regardless of the current `IFS` setting.
2. **Usage:**
   - `_startswith "hello world" "hello"`
     - `$1` — string to test
     - `$2` — prefix to look for
3. **Returns:**
   - `0` — string starts with the prefix
   - `1` — otherwise (or prefix not found)

### `_contains`
1. **Description:** Checks whether the first string contains a substring or regex pattern given as `$2` (tested with `[[ $1 =~ $2 ]]`).
2. **Usage:**
   - `_contains "hello world" "world"`
   - `$1` — string to search in
   - `$2` — substring or extended regular expression to look for
3. **Returns:**
   - `0` — match found
   - `1` — no match (or `$2` empty)

---

## URL & HTTP

### `_curl`
1. **Description:** Wrapper around `curl` performing a request with the given HTTP method, URL, optional headers, and optional data. Prints the response body on stdout. Detects `Unauthorized` responses and reports an invalid token. Detects HTTP `504 Gateway Time-out` responses and reports the error.
2. **Usage:**
   - `_curl "GET" "https://api.example.com/resource"`
   - `_curl "GET" "https://api.example.com/resource" "Authorization: Bearer x"`
   - `_curl "POST" "https://api.example.com/resource" "Content-Type: application/json" "X-Custom: 1" '{"key":"value"}'`
     - `$1` — HTTP method: `POST`, `PUT`, `DELETE`, or `GET`
     - `$2` — URL (must be ASCII)
     - `$3` — optional header
     - `$4` — optional second header
     - `$5` — optional request body (`-d`)
3. **Returns:**
   - `0` — success; outputs the response body on stdout
   - `10` (`ERROR_ARGV`) — missing method/URL, non-ASCII URL, `curl` not installed, or wrong method
   - `1` — `Unauthorized` detected in response (invalid token)
   - `1` — HTTP `504 Gateway Time-out` detected in the response
   - `3` — curl "URL malformed" error
   - `6` — curl "could not resolve host" (DNS) error
   - `35` — curl SSL connect error
   - other — any other curl error code

### `_encode_url`
1. **Description:** Percent-encodes a URL/string using `jq -Rr @uri`.
2. **Usage:**
   - `_encode_url "https://example.com/a b&c"`
   - `echo "a b&c" | _encode_url`
3. **Returns:**
   - `0` — success; outputs the encoded string on stdout
   - `10` (`ERROR_ARGV`) — empty input or `jq` not installed

### `_decode_url`
1. **Description:** Percent-decodes a URL-encoded string (handles `%XX` and `+` as space). Recursive implementation.
2. **Usage:**
   - `_decode_url "a%20b%26c"`
   - `$1` (and following args) — the encoded string
3. **Returns:**
   - `0` — success; outputs the decoded string on stdout
   - `10` (`ERROR_ARGV`) — empty input

---

## Network Management

### `_valid_ipv4`
1. **Description:** Validates that the argument is a well-formed IPv4 address (no leading zeros, each octet ≤ 255).
2. **Usage:**
   - `_valid_ipv4 "192.168.1.1"`
3. **Returns:**
   - `0` — valid IPv4
   - `10` (`ERROR_ARGV`) — no argument given
   - `1` — invalid format, leading zero, or octet > 255

### `_valid_network`
1. **Description:** Validates a network in CIDR notation, e.g. `192.168.1.0/24` (valid IP + numeric mask ≤ 32).
2. **Usage:**
   - `_valid_network "192.168.1.0/24"`
3. **Returns:**
   - `0` — valid network
   - `10` (`ERROR_ARGV`) — no argument given
   - `1` — invalid IP, missing mask, non-numeric mask, or mask > 32

### `_ip2int`
1. **Description:** Converts a dotted-quad IPv4 address to its 32-bit integer representation.
2. **Usage:**
   - `_ip2int "192.168.1.1"`
3. **Returns:**
   - `0` — success; outputs the integer on stdout
   - `10` (`ERROR_ARGV`) — missing/invalid IP

### `_int2ip`
1. **Description:** Converts a 32-bit integer (0–4294967295) to a dotted-quad IPv4 address. Out-of-range, negative, or non-numeric input is rejected.
2. **Usage:**
   - `_int2ip "3232235777"`
3. **Returns:**
   - `0` — success; outputs the IP on stdout
   - `10` (`ERROR_ARGV`) — argument empty (`INT EMPTY`), non-numeric input (`int not numeric`), or integer greater than `4294967295` (`int too large`)

### `_netmask`
1. **Description:** Converts a CIDR prefix length to a netmask, e.g. `24` → `255.255.255.0`.
2. **Usage:**
   - `_netmask "24"`
3. **Returns:**
   - `0` — success; outputs the netmask on stdout
   - `10` (`ERROR_ARGV`) — missing mask, non-numeric mask (`mask not numeric`), or mask > 32

### `_broadcast`
1. **Description:** Computes the broadcast address of a network given an IP and a CIDR mask, e.g. `192.0.2.0 24` → `192.0.2.255`.
2. **Usage:**
   - `_broadcast "192.0.2.0" "24"` — `$1` IP, `$2` mask
3. **Returns:**
   - `0` — success; outputs the broadcast address on stdout
   - `10` (`ERROR_ARGV`) — missing IP/mask, invalid IP, non-numeric mask (`mask not numeric`), or mask > 32

### `_network`
1. **Description:** Computes the network address given an IP and a CIDR mask, e.g. `192.0.2.10 24` → `192.0.2.0`.
2. **Usage:**
   - `_network "192.0.2.10" "24"` — `$1` IP, `$2` mask
3. **Returns:**
   - `0` — success; outputs the network address on stdout
   - `10` (`ERROR_ARGV`) — missing IP/mask, invalid IP, non-numeric mask (`mask not numeric`), or mask > 32

---

## Architecture Detection

### `_os_arch`
1. **Description:** Prints the machine hardware name (`uname -m`), e.g. `x86_64`, `armv7l`.
2. **Usage:**
   - `_os_arch` (no arguments)
3. **Returns:** Always `0`. Outputs the architecture on stdout.

### `_raspberry`
1. **Description:** Returns success when the current machine architecture is `armv7l` (typical Raspberry Pi), failure otherwise.
2. **Usage:**
   - `_raspberry` (no arguments)
3. **Returns:**
   - `0` — architecture is `armv7l`
   - `1` — otherwise

### `_x86_64`
1. **Description:** Returns success when the current machine architecture is `x86_64`, failure otherwise.
2. **Usage:**
   - `_x86_64` (no arguments)
3. **Returns:**
   - `0` — architecture is `x86_64`
   - `1` — otherwise

---

## Interactive Ask Helpers

> These helpers prompt the user on the terminal. When the global `DEFAULT` is `true`, they skip the prompt and return the provided default value instead. They rely on `_valid_ipv4` / `_valid_network` for input validation.

### `_ask_yes_or_no`
1. **Description:** Asks a yes/no question. With `$2` set, the prompt shows `[Y/n]` or `[y/N]` and an empty answer uses that default. When `WHIPTAIL=true`, the question is displayed with `whiptail` instead of a text prompt. Prints `y` or `n`.
2. **Usage:**
   - `_ask_yes_or_no "Do you agree?"`
   - `_ask_yes_or_no "Do you agree?" "y"` — default answer `y`
   - `$1` — question text
   - `$2` — optional default (`y` or `n`)
3. **Returns:**
   - `0` — answered (or default used); outputs `y`/`n` on stdout
   - `10` (`ERROR_ARGV`) — question empty, invalid default, or `whiptail` not installed
   - loops with a warning until a valid `Y`/`N` (or accepted default) is entered

### `_ask_string`
1. **Description:** Asks a free-text question and prints the answer. An empty answer falls back to the optional default `$2`.
2. **Usage:**
   - `_ask_string "Project name?"`
   - `_ask_string "Project name?" "myproject"` — default `myproject`
   - `$1` — question text
   - `$2` — optional default value
3. **Returns:**
   - `0` — answered (or default used); outputs the string on stdout
   - `10` (`ERROR_ARGV`) — question empty, or default empty while `DEFAULT=true`

### `_ask_ip`
1. **Description:** Asks for an IPv4 address and validates it with `_valid_ipv4` (loop until valid). An empty answer uses the optional default `$2`.
2. **Usage:**
   - `_ask_ip "Server IP?"`
   - `_ask_ip "Server IP?" "192.168.1.1"` — default IP
   - `$1` — question text
   - `$2` — optional default IP
3. **Returns:**
   - `0` — answered (or default used); outputs the IP on stdout
   - `1` — invalid default while `DEFAULT=true` (logs `default value is not a valid ip address`)

### `_ask_network`
1. **Description:** Asks for a network in CIDR notation and validates it with `_valid_network` (loop until valid). An empty answer uses the optional default `$2`.
2. **Usage:**
   - `_ask_network "VPN network?"`
   - `_ask_network "VPN network?" "192.168.1.0/24"` — default network
   - `$1` — question text
   - `$2` — optional default network
3. **Returns:**
   - `0` — answered (or default used); outputs the network on stdout
   - `1` — invalid default while `DEFAULT=true` (logs `default value is not a valid network`)

---

## Display Helpers

### `_showU8Variation`
1. **Description:** Displays a UTF-8 table showing how characters render in the terminal using variation selectors. The first argument selects the variation selector (1–26); the remaining arguments are hex code points (e.g. `24` for the table of `0x2400`-based glyphs). When no hex code point is given, the table defaults to `26` (U+2600 Miscellaneous Symbols).
2. **Usage:**
   - `_showU8Variation 24 24`
   - `_showU8Variation 7` — selector only; defaults to code point `26`
   - `$1` — variation selector number (1–256; values 1–16 map to U+FE00–U+FE0F, 17–256 to U+E0100–U+E01EF)
   - `$@` — hex code point arguments
3. **Returns:**
   - `0` — table printed to stdout (exit status of the last `printf`)
   - `1` — `$1` empty (`VARIATION SELECTOR EMPTY`), not numeric (`VARIATION SELECTOR not numeric`), or outside 1–256 (`VARIATION SELECTOR must be between 1 and 256`)
   - Not telemetry-instrumented.

### `_show_color_code`
1. **Description:** Prints a matrix of ANSI escape codes combining background, text, and mode attributes so the user can see how every `\e[<bg>;<mode>;<color>m` combination renders. With an argument, that text is used as the sample instead of the escape sequence itself.
2. **Usage:**
   - `_show_color_code`
   - `_show_color_code "sample"` — print `sample` with each combination
3. **Returns:** Always `0` (exit status of the last `printf`). Prints the color matrix to stdout. Not telemetry-instrumented.

---

## Tests & CI

> These functions are the orchestrator's testing/CI entry points. They rely on the runtime globals `$LIB`, `$MY_GIT_DIR`, `$GREP`, and `$DRY_RUN` set by `my_warp.sh`.

### `_shellcheck`
1. **Description:** Runs ShellCheck on the target library files and then applies the project's custom lint rules (each function must have exactly one `# usage:`/`# call:` line and 1–2 `# description:` lines directly above its definition; `_error` must be followed by `return`/`exit` >0; use `$GREP` not raw `grep`; `_func_end` must take an argument and be followed by `return`/`exit`; `_func_end "1"` requires an `_error` on the same line; `return 0` is only allowed as the last line of a function (followed by its closing `}`); use `_curl` not raw `curl`; no `docker` piped to another command; `$?` must be tested with an `_error`; every `return` in a function that calls `_func_start` must be on the same line as `_func_end` — stack-balance rule). Comment lines and lines exempted with `# no _shellcheck` are skipped. Prints `no error found with shellcheck in ...` on success.
2. **Usage:**
   - `_shellcheck "file1.sh" "file2.sh"` — check the given files
   - `_shellcheck` — check all `*.sh` files under `$MY_GIT_DIR/$LIB` (requires `$LIB` set and `$MY_GIT_DIR/$LIB/lib_$LIB.sh` to exist)
3. **Returns:**
   - `0` — ShellCheck and all custom lint checks pass
   - `10` (`ERROR_ARGV`) — `shellcheck` not installed
   - `1` — lib file not found, ShellCheck errors, or a custom lint rule violation

### `_bats`
1. **Description:** Runs the BATS test suite (`bats/tests.bats`) of the library `$LIB` with verbose output.
2. **Usage:**
   - `_bats` — requires `$LIB` set and `$MY_GIT_DIR/$LIB/bats/tests.bats` to exist
3. **Returns:**
   - `0` — BATS tests passed
   - `10` (`ERROR_ARGV`) — `$LIB` empty or lib file not found
   - `1` — `bats` not installed or tests failed

### `_kcov`
1. **Description:** Measures test code coverage of the library `$LIB` using `kcov`, prints per-file coverage percentages (from `coverage.json`), and uploads the `cobertura.xml` report to Codecov when `codecov`, `$CODECOV_TOKEN`, and `$GITHUB_USERNAME` are available. Does nothing (dry-run) when `$DRY_RUN` is `true`. When the argument `AI` is passed, the temporary report directory is **not** removed; instead the full path of `cobertura.xml` is logged with `_info`.
2. **Usage:**
   - `_kcov` — requires `$LIB` set and `kcov` installed; cleans up the temporary report
   - `_kcov AI` — same as above, but keeps the report and prints its full path via `_info`
   - `$1` — optional; when set to `AI`, keeps the `cobertura.xml` report
3. **Returns:**
   - `0` — success (dry-run included; upload return code is not checked — see TODO in source)
   - `10` (`ERROR_ARGV`) — `$LIB` empty, `kcov` not installed, or `jq` not installed
   - `1` — `_tmp_file` failed

### `_kcov_resume`
1. **Description:** Summarizes the coverage report produced by `_kcov`: locates the `cobertura.xml` file inside the given kcov temporary/report directory and prints, for each file present in the report, the line numbers that are **not covered** (i.e. with `hits="0"`). The file list is discovered from the report itself (e.g. `lib_shell.sh` + `my_warp.sh` for the shell lib, `lib_tempo_shell.sh` for the tempo_shell lib). Output is one line per file as `file:line1,line2,...`; a file with every line covered prints `file:` followed by an empty list.
2. **Usage:**
   - `_kcov_resume "$__tmp"` — where `$__tmp` is the temporary directory used by `_kcov` (or any directory containing a `cobertura.xml`)
   - `$1` — directory containing the kcov report (`cobertura.xml`); may be the `_kcov` temp dir or the kept report dir
3. **Returns:**
   - `0` — success; outputs the uncovered line numbers per file on stdout
   - `10` (`ERROR_ARGV`) — directory argument empty or directory does not exist
   - `1` — no `cobertura.xml` found inside the directory

---

## Demo

### `_hello_world`
1. **Description:** Demo function that prints `Hello world` and exercises all logger levels (`_success`, `_verbose`, `_info`, `_warning`, `_error`).
2. **Usage:**
   - `_hello_world` (no arguments)
3. **Returns:** Always `0`. Outputs `Hello world` on stdout and log lines on stderr.

---

## Global Variables Reference

| Variable | Type | Purpose |
|----------|------|---------|
| `CHECK_KO` | string (ANSI) | Red ✗ prefix used by error logs |
| `CHECK_WARN` | string (ANSI) | Yellow ▲ prefix used by warning logs |
| `CHECK_SUCCESS` | string (ANSI) | Green ✓ prefix used by success logs |
| `CHECK_INFO` | string (ANSI) | Blue ★ prefix used by info logs |
| `ERROR_ARGV` | integer | Exit code (`10`) used for argument/validation errors |
| `GREP` / `EGREP` | string | Preconfigured `grep --text` binary path |
| `VERBOSE_SPACE` | string | Function-trace indentation prefix built by `_verbose_func_space` |
| `FUNC_LIST` | array | Telemetry stack of `function:start_time` entries |
| `VERBOSE` / `DEBUG` | boolean | Enable verbose / debug logging (consumed by `_log`, `_func_start`, `_func_end`) |
| `DRY_RUN` | boolean | When `true`, `_kcov` skips the real coverage run |
| `DEFAULT` | boolean | When `true`, the `_ask_*` helpers return the provided default without prompting |
| `FORCE` | boolean | When `true`, bypasses the cache (used by `_check_cache_or_force` in the `tempo_shell` feature library) |
| `YUBIKEY` | boolean | Enables YubiKey integrations in the `tempo_shell` feature library |
| `LIB` | string | Currently selected library name (`_process_opts`, `_usage`, `_load_lib`, `_shellcheck`, `_bats`, `_kcov`) |
| `MY_GIT_DIR` | string | Base directory of the local git repositories |
| `CUR_NAME` | string | Name of the running orchestrator script (`${0##*/}`), used in help/usage output |
| `OPTS` | string | Normalized option string produced by `getopt` in `_process_opts` |
| `ACTION` | boolean | Set to `true` when `--help`, `--bats`, `--shellcheck`, `--kcov` or `--list-libs` was requested |
| `GETOPT_SHORT_<LIB>` | string | Per-library short option list consumed by `_getopt_short` (e.g. `GETOPT_SHORT_SHELL=h,v,d,b,s,k`) |
