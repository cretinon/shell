# AGENTS.md

## Project Overview

This project is a modular, well-tested bash library and orchestration system. It consists of an orchestrator script, foundational utility libraries, a comprehensive testing suite, and structured CI/CD integrations.

### Architecture

* **Main Orchestrator (`my_warp.sh`)**: The primary entry point script. It loads global user configuration, parses command-line arguments, dynamically loads the core library components, and routes execution to selected target functions.
* **Core Base Library (`lib_shell-base.sh`)**: Implements essential runtime utilities:
  - Stack trace and function telemetry (`_func_start`, `_func_end`, `_verbose_func_space`)
  - Standardized logger output (`_info`, `_success`, `_warning`, `_error`, `_debug`)
  - Core validation primitives (`_exist`, `_notexist`, `_installed`, `_notinstalled`, `_fileexist`, `_filenotexist`)
  - Core array manipulation routines (`_array_print`, `_array_add`, `_array_remove_last`, `_array_remove_index`, `_array_count_elt`)
* **Feature Library (`lib_shell.sh`)**: Implements domain-specific logic including:
  - Encryption and backup utilities (KeePassXC CLI orchestration, GnuPG file and directory encryption/decryption)
  - Network computation helpers (IP-to-integer conversion, netmask, broadcast, and network address calculations)
  - Interactive prompting and user-input sanitation helpers (`_ask_yes_or_no`, `_ask_string`, `_ask_ip`, `_ask_network`)
  - Integration helpers (JSON/YAML converters, curl wrappers with error handling, URL encoders/decoders)
  - System installation utilities (OpenTofu automated installation for Debian 13)

---

## Documentation (Mandatory Reading for AI Agents)

### `functions.md` — Reference of `lib_shell-base.sh`

* **Mandatory reading**: Any AI agent (or contributor) working on this repository MUST read `functions.md` **before** reading, editing, calling, or testing any function of `lib_shell-base.sh`.
* `functions.md` is the authoritative API reference for `lib_shell-base.sh`. It documents every function with:
  1. a short description of what the function does,
  2. its usage parameters,
  3. its return values.
* When working with a function from `lib_shell-base.sh`, always consult its entry in `functions.md` first and follow it.

### Keeping `functions.md` in Sync with `lib_shell-base.sh`

* **Mandatory sync**: Any change made to `lib_shell-base.sh` MUST be mirrored in `functions.md`:
  - **Adding** a function → add a new entry with its description, usage parameters, and return values.
  - **Modifying** a function (signature, parameters, behavior, or return codes) → update its existing entry accordingly.
  - **Removing** a function → remove its entry.
* Before finalizing any commit or task touching `lib_shell-base.sh`, verify that `functions.md` is up to date and consistent with the source code.
* When in doubt, treat `functions.md` as the source of truth for the public API of `lib_shell-base.sh` and reconcile any discrepancy with the code.

### Keeping `bats/tests.bats` in Sync with `lib_shell-base.sh`

* **Mandatory sync**: Any change made to `lib_shell-base.sh` MUST be mirrored in `bats/tests.bats`:
  - **Adding** a function → add BATS test cases covering its nominal behavior and its error/edge branches (missing arguments, invalid input, non-zero return codes).
  - **Modifying** a function (signature, parameters, behavior, or return codes) → update or extend the existing test cases so the suite still reflects the actual behavior.
  - **Removing** a function → remove the test cases that only exercised that function.
* **Coverage requirement**: The BATS suite must keep `lib_shell-base.sh` above the project's coverage minimum (see the Quality section below). New or modified functions must not regress coverage without a compensating test.
* **Mandatory verification**: Before finalizing any commit or task touching `lib_shell-base.sh`, run the BATS suite through the orchestrator wrapper (`./my_warp.sh --lib shell -b`) and verify every test passes.
* When in doubt, treat the actual behavior of `lib_shell-base.sh` as the source of truth for what `bats/tests.bats` must assert.

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
# Make the orchestrator executable
chmod +x ${HOME}/git/shell/my_warp.sh

# Create configuration directory
mkdir -p ${HOME}/conf

# Generate the minimal configuration file
echo -e "VERBOSE=false\nDEBUG=false\nYUBIKEY=false\nFUNC_LIST=()\nMY_GIT_DIR=\"\${HOME}/git\"" > ${HOME}/conf/my_warp.conf
```

### Configuration Variables

* `VERBOSE` (boolean): Set to `true` to display verbose step-by-step logs.
* `DEBUG` (boolean): Set to `true` to output execution trace logs and internal shell diagnostics.
* `YUBIKEY` (boolean): Flags whether cryptographic hardware (YubiKey) integrations are available/enabled.
* `MY_GIT_DIR` (string): The base directory pointing to local Git repositories (e.g., `"${HOME}/git"`).
* `FUNC_LIST` (array): Array recording function calls and telemetry tracking data during execution.

---

## Command-Line Interface (CLI) Usage

The orchestrator handles option processing for library dynamic execution, syntax validation, and test harness execution.

### General Usage & Helper

```shell
# Display available options and command help
./my_warp.sh -h
```

### Library Operations

```shell
# List all installed libraries
./my_warp.sh --list-libs

# Call a feature library function directly with optional parameters
./my_warp.sh --lib shell decrypt_file --file "/path/to/file.asc" --passphrase "secret" --remove-src false
```

### Development & Maintenance Actions

```shell
# Perform syntax checks with ShellCheck on a library
./my_warp.sh --lib shell -s

# Run automated tests using BATS
./my_warp.sh --lib shell -b

# Measure test code coverage using kcov
./my_warp.sh --lib shell -k AI

```

---

## Testing & Quality Control

### Testing Framework

* **Harness**: The suite relies on the **BATS (Bash Automated Testing System)** framework.
* **Test Definitions**: Configured under `bats/tests.bats`.
* **Testing Command**: MUST be triggered through the orchestrator wrapper via `./my_warp.sh --lib shell -b` — never by calling `bats` directly.

### Writing Tests

* **BATS-first rule**: If you need to test something in shell, do NOT write ad-hoc shell code (one-liners, `bash -c` snippets, manual scripts). Instead, write a BATS test case in `bats/tests.bats`.
* Every BATS test case must be self-contained: it should set up its own fixtures (files, mocks, environment) and clean up after itself.
* Prefer asserting behavior through the library's own functions and the BATS assertions (`assert_success`, `assert_failure`, `assert_output`, `assert_line`) over brittle string comparisons.
* Run the new tests through the orchestrator wrapper (`./my_warp.sh --lib shell -b`) and verify they pass before finalizing any change.

### Quality Checks & Linters

* **ShellCheck**: All files (`my_warp.sh`, `lib_shell.sh`, `lib_shell-base.sh`) are kept clean of syntax or standard violations. Ignore rules are centralized at file headers (e.g., `SC2119`, `SC2120`).
* **Code Coverage**: Tracked via **kcov** with results sent to Codecov under guidelines configured in `.codecov.yml`, targeting a coverage minimum of **80%**.
* **Continuous Integration**: Uses **CircleCI** (`.circleci/config.yml`) to provision fresh Debian/Ubuntu-based testing containers, install dependency binaries (`keepassxc`, `kcov`, `shellcheck`, `bats`, `iptables`, `nmap`), and execute the full suite of checks.

### Pre-Commit Verification Gate (MANDATORY)

> These three checks are the project's **only** sanctioned quality gate. They MUST
> be run through the orchestrator wrapper — **never** by invoking the underlying
> binaries (`shellcheck`, `bats`, `kcov`) directly. The wrapper applies the
> project's custom lint rules and runtime setup that a direct binary invocation
> bypasses.

Run all three checks, in this order, and verify each exits with code `0` **before**
committing or finalizing any change:

1. **ShellCheck** — syntax + project lint rules:
   ```shell
   ./my_warp.sh --lib shell -s
   ```
   Exit code must be `0`.

2. **BATS** — automated test suite:
   ```shell
   ./my_warp.sh --lib shell -b
   ```
   Exit code must be `0` and all tests must pass.

3. **kcov** — code coverage:
   ```shell
   ./my_warp.sh --lib shell -k AI
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
- **Telemetry Hooks**:
  - Every library function must invoke `_func_start` (with arguments if applicable) at its entry point, and `_func_end` before returning.
  - **Stack-balance rule (`_func_end` before every `return`)**: any function that calls `_func_start` MUST call `_func_end` before **every** `return`, including error and early-exit paths. Each `return` must appear on the **same line** as its `_func_end` call, in the form `_func_end "<code>" ; return <code>` (e.g. `_func_end "$ERROR_ARGV" ; return $ERROR_ARGV`). Never `return` alone from an instrumented function, or the `FUNC_LIST` telemetry stack grows unboundedly (and `VERBOSE_SPACE` with it). The only exceptions are telemetry-free helpers (e.g. the `_array_*` management functions, `_log`, `_exist`), which must state that explicitly. **This rule is enforced by the `_shellcheck` lint (stack-balance rule), so `./my_warp.sh --lib <lib> -s` fails on any violation.**
  - Keep `FUNC_LIST` balanced: every `_func_start` must be matched by exactly one `_func_end` on every code path.
- **Variable Quoting**:
  - Always quote variable expansions to prevent word splitting/globbing (e.g. use `"$__dashboard_id"` instead of `$__dashboard_id`).
- **Error Handling**:
  - Check for variable presence using the utility functions `_exist` or `_notexist`.
  - Check for file existence using `_fileexist` or `_filenotexist`.
  - Output standardized logs using `_info`, `_verbose`, `_warning`, or `_error`.
  - Always return a non-zero exit code or exit `1` on error.
