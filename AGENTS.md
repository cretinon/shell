# AGENTS.md

## Project Overview

This project is a modular, well-tested bash library and orchestration system. It consists of an orchestrator script, foundational utility libraries, a comprehensive testing suite, and structured CI/CD integrations.

### Architecture

* **Main Orchestrator (`my_warp.sh`)**: The primary entry point script. It loads global user configuration, parses command-line arguments, dynamically loads the core library components, and routes execution to selected target functions.
* **Library (`lib_shell.sh`)**: Implements the reusable, library-agnostic runtime plus the CLI dispatcher. It is always loaded (first) by `my_warp.sh` and provides:
  - Stack trace and function telemetry (`_func_start`, `_func_end`, `_verbose_func_space`)
  - Standardized logger output (`_info`, `_success`, `_warning`, `_error`, `_debug`, `_verbose`, `_log`, `_verbose_file`)
  - Core validation primitives (`_exist`, `_fileexist`, `_remotefileexist`, `_func_exist`, `_installed`)
  - Working directory helpers (`_working_dir`, `_working_dir_count_file`, `_working_dir_count_dir`, `_working_dir_list_dir_by_creation_date`)
  - Temporary files & random/UUID generation (`_tmp_file`, `_gen_rand`, `_gen_pin`, `_gen_uuid`)
  - Orchestrator helpers: CLI parsing (`_process_opts`, `_getopt_short`, `_getopt_long`), usage display (`_usage`), and library/configuration loading (`_load_libs`, `_load_lib`, `_load_conf`, `_get_installed_libs`)
  - Time management (`_date`, `_iso_date`, `_timediff`, `_epoch_2_date`, `_date_2_epoch`)
  - Array manipulation (`_array_print`, `_array_print_index`, `_array_add`, `_array_remove_last`, `_array_remove_index`, `_array_count_elt`)
  - YAML & JSON converters (`_json_2_yaml`, `_yaml_2_json`, `_json_add_key_with_value`, `_json_add_value_in_array`, `_json_remove_key`, `_json_replace_key_with_value`, `_json_get_value_from_key`)
  - String management (`_upper`, `_lower`, `_remove_last_car`, `_is_ascii`, `_is_numeric`, `_startswith`, `_contains`)
  - URL & HTTP helpers (`_curl`, `_encode_url`, `_decode_url`)
  - Network computation helpers (IP validation/conversion, netmask, broadcast, network address: `_valid_ipv4`, `_valid_network`, `_ip2int`, `_int2ip`, `_netmask`, `_broadcast`, `_network`)
  - Architecture detection (`_os_arch`, `_raspberry`, `_x86_64`)
  - Interactive prompting and user-input sanitization (`_ask_yes_or_no`, `_ask_string`, `_ask_ip`, `_ask_network`)
  - Test & CI harness entry points (`_shellcheck`, `_bats`, `_kcov`, `_kcov_resume`)
  - Display helpers (`_showU8Variation`, `_show_color_code`) and demo (`_hello_world`)
  - CLI dispatcher (`_process_lib_shell`) routing orchestrator calls to the base-level commands (`hello_world`, `curl`) and providing the library short options (`GETOPT_SHORT_SHELL`)

---

## Documentation (Mandatory Reading for AI Agents)

### `functions.md` — Reference of `lib_shell.sh`

* **Mandatory reading**: Any AI agent (or contributor) working on this repository MUST read `functions.md` **before** reading, editing, calling, or testing any function of `lib_shell.sh`.
* `functions.md` is the authoritative API reference for `lib_shell.sh`. It documents every function with:
  1. a short description of what the function does,
  2. its usage parameters,
  3. its return values.
* When working with a function from `lib_shell.sh`, always consult its entry in `functions.md` first and follow it.

### Keeping `AGENTS.md` (this file) in Sync with `lib_shell.sh`

* **Mandatory sync**: Any change made to `lib_shell.sh` MUST be reflected in this file.
* **Minimum requirement — the Architecture section**: the `### Architecture` section (in the Project Overview) must at least always be in sync with `lib_shell.sh`. Every function or function group added to, removed from, or renamed in `lib_shell.sh` must be correspondingly added, removed, or renamed in the relevant bullet of the Architecture section.
* Before finalizing any commit or task touching `lib_shell.sh`, verify that the Architecture section still reflects the current function inventory of `lib_shell.sh` (cross-check with `functions.md`).

### Keeping `functions.md` in Sync with `lib_shell.sh`

* **Mandatory sync**: Any change made to `lib_shell.sh` MUST be mirrored in `functions.md`:
  - **Adding** a function → add a new entry with its description, usage parameters, and return values.
  - **Modifying** a function (signature, parameters, behavior, or return codes) → update its existing entry accordingly.
  - **Removing** a function → remove its entry.
* Before finalizing any commit or task touching `lib_shell.sh`, verify that `functions.md` is up to date and consistent with the source code.
* When in doubt, treat `functions.md` as the source of truth for the public API of `lib_shell.sh` and reconcile any discrepancy with the code.

### Keeping `bats/tests.bats` in Sync with `lib_shell.sh`

* **Mandatory sync**: Any change made to `lib_shell.sh` MUST be mirrored in `bats/tests.bats`:
  - **Adding** a function → add BATS test cases covering its nominal behavior and its error/edge branches (missing arguments, invalid input, non-zero return codes).
  - **Modifying** a function (signature, parameters, behavior, or return codes) → update or extend the existing test cases so the suite still reflects the actual behavior.
  - **Removing** a function → remove the test cases that only exercised that function.
* **Coverage requirement**: The BATS suite must keep `lib_shell.sh` above the project's coverage minimum (see the Quality section below). New or modified functions must not regress coverage without a compensating test.
* **Mandatory verification**: Before finalizing any commit or task touching `lib_shell.sh`, run the BATS suite through the orchestrator wrapper (`./my_warp.sh --lib shell -b`) and verify every test passes.
* When in doubt, treat the actual behavior of `lib_shell.sh` as the source of truth for what `bats/tests.bats` must assert.

### `ToDo.md` — Tracking Bugs & Features

* `ToDo.md` is the project's **issue tracker**: it references and keeps track of bugs that need to be corrected and features we want to add to the codebase.
* **Mandatory reading**: Any AI agent (or contributor) working on this repository MUST read `ToDo.md` to know what remains to be done.
* **Mandatory sync**: Like `functions.md`, `ToDo.md` MUST be kept in sync with the base code:
  - **Correcting a bug** → update its entry in `ToDo.md` (mark it as fixed, e.g. `STATUS: FIXED`), so the list reflects the current state.
  - **Adding a feature** → add an entry for it in `ToDo.md`.
  - **Abandoning/deleting** a bug or feature → remove or update its entry.
* Before finalizing any commit or task that fixes a tracked bug or adds a tracked feature, verify that `ToDo.md` is up to date.

---

## Setup & Configuration

### Initial Configuration

To initialize the environment, create the configuration directory and save a configuration file at `${HOME}/conf/my_warp.conf`.

```shell
# Create configuration directory
mkdir -p ${HOME}/conf

# Generate the minimal configuration file
echo -e "VERBOSE=false\nDEBUG=false\nYUBIKEY=false\nFUNC_LIST=()\nMY_GIT_DIR=\"\${HOME}/git\"" > ${HOME}/conf/my_warp.conf

# Source the configuration file
. ${HOME}/conf/my_warp.conf

# Make the orchestrator executable
chmod +x ${MY_GIT_DIR}/shell/my_warp.sh
```

### Configuration Variables

* `VERBOSE` (boolean): Set to `true` to display verbose step-by-step logs.
* `DEBUG` (boolean): Set to `true` to output execution trace logs and internal shell diagnostics.
* `YUBIKEY` (boolean): Flags whether cryptographic hardware (YubiKey) integrations are available/enabled.
* `MY_GIT_DIR` (string): The base directory pointing to local Git repositories (e.g., `"${HOME}/git"`).
* `FUNC_LIST` (array): Array recording function calls and telemetry tracking data during execution.

---

##  Command-Line Interface (CLI) Usage

The orchestrator handles option processing for library dynamic execution, syntax validation, and test harness execution.

### General Usage & Helper

```shell
# Display available options and command help
${MY_GIT_DIR}/shell/my_warp.sh -h
```

### Library Operations

```shell
# List all installed libraries
${MY_GIT_DIR}/shell/my_warp.sh --list-libs

# Call a feature library function directly with optional parameters
${MY_GIT_DIR}/shell/my_warp.sh --lib shell decrypt_file --file "/path/to/file.asc" --passphrase "secret" --remove-src false
```

### Development & Maintenance Actions

```shell
# Perform syntax checks with ShellCheck on a library (set LIB to library name : LIB=shell or LIB=ansible for example)
${MY_GIT_DIR}/shell/my_warp.sh --lib "$LIB" -s

# Run automated tests using BATS
${MY_GIT_DIR}/shell/my_warp.sh --lib "$LIB" -b

# Measure test code coverage using kcov
${MY_GIT_DIR}/shell/my_warp.sh --lib "$LIB" -k AI
```

---

## Testing & Quality Control

### Testing Framework

* **Harness**: The suite relies on the **BATS (Bash Automated Testing System)** framework.
* **Test Definitions**: Configured under `${MY_GIT_DIR}/${LIB}/bats/tests.bats`.
* **Testing Command**: MUST be triggered through the orchestrator wrapper via `${MY_GIT_DIR}/shell/my_warp.sh --lib "$LIB" -b` — never by calling `bats` directly.

### Writing Tests

* Every BATS test case must be self-contained: it should set up its own fixtures (files, mocks, environment) and clean up after itself.
* Prefer asserting behavior through the library's own functions and the BATS assertions (`assert_success`, `assert_failure`, `assert_output`, `assert_line`) over brittle string comparisons.
* Run the new tests through the orchestrator wrapper and verify they pass before finalizing any change.

### Quality Checks & Linters

* **ShellCheck**: All shell files are kept clean of syntax or standard violations. Ignore rules are centralized at file headers (e.g., `SC2119`, `SC2120`).
* **Code Coverage**: Tracked via **kcov** with results sent to Codecov under guidelines configured in `.codecov.yml`, targeting a coverage minimum of **80%**.
* **Continuous Integration**: Uses **CircleCI** (`${MY_GIT_DIR}/${LIB}/.circleci/config.yml`) to provision fresh Debian/Ubuntu-based testing containers, install dependency binaries, and execute the full suite of checks.

### Pre-Commit Verification Gate (MANDATORY)

> These three checks are the project's **only** sanctioned quality gate. They MUST be run through the orchestrator wrapper — **never** by invoking the underlying binaries (`shellcheck`, `bats`, `kcov`) directly. The wrapper applies the project's custom lint rules and runtime setup that a direct binary invocation bypasses.

Run all three checks, in this order, and verify each exits with code `0` **before** committing or finalizing any change:

1. **ShellCheck** — syntax + project lint rules:
   ```shell
   ${MY_GIT_DIR}/shell/my_warp.sh --lib "$LIB" -s
   ```
   Exit code must be `0`.

2. **BATS** — automated test suite:
   ```shell
   ${MY_GIT_DIR}/shell/my_warp.sh --lib "$LIB" -b
   ```
   Exit code must be `0` and all tests must pass.

3. **kcov** — code coverage:
   ```shell
   ${MY_GIT_DIR}/shell/my_warp.sh --lib "$LIB" -k AI
   ```
   Exit code must be `0`.

**Rules for AI agents & contributors:**
- ALWAYS use the wrapper (`./my_warp.sh --lib <lib> -s|-b|-k`) to run these checks.
- NEVER invoke `shellcheck`, `bats`, or `kcov` binaries directly, even if they are installed on the system.
- NEVER skip or assume a check passes — always actually run it and verify the exit code.
- If any check fails, fix the root cause and re-run ALL THREE checks until every exit code is `0`.
- When finishing a task or preparing a commit, report the result of the three checks.

---

## Git Workflow Rules

### Do's and Don'ts

**Do:**
- DO commit changes when asked to commit.
- DO stage only the relevant files for the change (avoid blind `git add .`).
- DO write a clear, "why"-focused commit message.

**Don't:**
- DON'T push. When asked to "commit" (e.g. *"commit all changes"*), only commit — never push.
- DON'T force-push, amend, or rewrite history.

---

## Code Style & Conventions

- **Naming Conventions**:
  - Library functions must start with a single underscore (e.g. `_usage`).
  - Script-specific functions or local variables must start with a double underscore (e.g. `__line`).
- **Section Organization**:
  - Group related functions under banner comments, e.g. `### STACK TRACE ###`, `### NETWORK MANAGEMENT ###`, `### INTERACTIVE ASK ###`. Section banners are a series of `#` lines spanning the terminal width with the section name centered.
- **`# usage:` Comments**:
  - Every function that is reachable from the orchestrator CLI must be documented with a `# usage:` comment line directly above its definition, e.g. `# usage: _decrypt_file --file ($1) --passphrase ($2) --remove-src ($3)`. These lines are parsed by `_usage` and `_getopt_long` to build the CLI help and option list.
- **Argument Validation at Entry**:
  - Every function must validate its arguments at the top, before doing any work, using `_exist`, `_fileexist`, or `_installed` as appropriate.
  - Standard error messages use the uppercase argument name + `EMPTY` (e.g. `_error "PASS EMPTY"`, `_error "DATABASE EMPTY"`, `_error "URL EMPTY"`).
- **Return Codes**:
  - `0` — success.
  - `1` — generic error/failure.
  - `10` (`ERROR_ARGV`) — argument/validation error.
  - Always `return` a non-zero code on error; never silently swallow a failure.
- **Telemetry Hooks**:
  - Every library function must invoke `_func_start` (with arguments if applicable) at its entry point, and `_func_end` before returning.
  - **Stack-balance rule (`_func_end` before every `return`)**: any function that calls `_func_start` MUST call `_func_end` before **every** `return`, including error and early-exit paths. Each `return` must appear on the **same line** as its `_func_end` call, in the form `_func_end "<code>" ; return <code>` (e.g. `_func_end "$ERROR_ARGV" ; return $ERROR_ARGV`). Never `return` alone from an instrumented function, or the `FUNC_LIST` telemetry stack grows unboundedly (and `VERBOSE_SPACE` with it). The only exceptions are telemetry-free helpers (e.g. the `_array_*` management functions, `_log`, `_exist`), which must state that explicitly. **This rule is enforced by the `_shellcheck` lint (stack-balance rule), so `./my_warp.sh --lib <lib> -s` fails on any violation.**
  - Keep `FUNC_LIST` balanced: every `_func_start` must be matched by exactly one `_func_end` on every code path.
- **Lint Exemptions**:
  - When a line intentionally violates a lint rule (e.g. `return 0` in a success path, or a `grep` that must be raw), append the comment `# no _shellcheck` to that line so the custom lint rules skip it. Never silently disable linting; always explain the exemption.
- **Command Substitution in `# usage:` parsing**:
  - Keep `# usage:` lines short and with a consistent shape — they are consumed by `cut`/`sed` pipelines that strip `($1)`, `($2)`, etc.
- **Variable Quoting**:
  - Always quote variable expansions to prevent word splitting/globbing (e.g. use `"$__dashboard_id"` instead of `$__dashboard_id`).
  - Use `local LC_ALL=C` in functions that do case conversion, regex matching, or locale-sensitive formatting so behavior is deterministic regardless of the environment locale.
- **Error Handling**:
  - Check for variable presence using the utility functions `_exist` or `_notexist`.
  - Check for file existence using `_fileexist` or `_filenotexist`.
  - Check for installed binaries using `_installed` or `_notinstalled`.
  - Output standardized logs using `_info`, `_verbose`, `_warning`, or `_error`.
  - Always return a non-zero exit code or exit `1` on error.
  - Avoid raw `grep` in favor of the preconfigured `$GREP` (enforced by lint).
* Temporary Files & Folders (AI Agents)
  * **Mandatory location**: Any temporary file or folder created by an AI agent MUST be created under `/tmp/ECA`.
  * Create the directory first if it does not exist: `mkdir -p /tmp/ECA`.
  * NEVER create temporary files or folders inside the repository working tree (e.g. under `${MY_GIT_DIR}/shell/...`) — they pollute `git status` and risk being committed by mistake.
