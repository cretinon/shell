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
# or
./my_warp.sh --help
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
# or
./my_warp.sh --lib shell --shellcheck

# Run automated tests using BATS
./my_warp.sh --lib shell -b
# or
./my_warp.sh --lib shell --bats

# Measure test code coverage using kcov
./my_warp.sh --lib shell -k
# or
./my_warp.sh --lib shell --kcov
```

---

## Testing & Quality Control

### Testing Framework

* **Harness**: The suite relies on the **BATS (Bash Automated Testing System)** framework.
* **Test Definitions**: Configured under `bats/tests.bats`.
* **Testing Command**: Can be triggered locally with `bats bats/tests.bats` or through the orchestrator wrapper via `./my_warp.sh --lib shell -b`.

### Quality Checks & Linters

* **ShellCheck**: All files (`my_warp.sh`, `lib_shell.sh`, `lib_shell-base.sh`) are kept clean of syntax or standard violations. Ignore rules are centralized at file headers (e.g., `SC2119`, `SC2120`).
* **Pre-commit Hooks**: Managed via `.pre-commit-config.yaml`. Runs syntax check with local `shell-lint` on commit staging.
* **Code Coverage**: Tracked via **kcov** with results sent to Codecov under guidelines configured in `.codecov.yml`, targeting a coverage minimum of **80%**.
* **Continuous Integration**: Uses **CircleCI** (`.circleci/config.yml`) to provision fresh Debian/Ubuntu-based testing containers, install dependency binaries (`keepassxc`, `kcov`, `shellcheck`, `bats`, `iptables`, `nmap`), and execute the full suite of checks.
