# shell

Bash library and orchestration system: reusable shell functions (logging, validation, arrays, YAML/JSON, network, time, telemetry, test harness) plus the `my_warp.sh` orchestrator, the single entry point used to call functions and libraries across projects.

[![CircleCI](https://dl.circleci.com/status-badge/img/circleci/PJuzGhtpJT1B6rC5YF9SLA/RD3EguHi6n1Hz4ZnXR7yD2/tree/main.svg?style=svg)](https://dl.circleci.com/status-badge/redirect/circleci/PJuzGhtpJT1B6rC5YF9SLA/RD3EguHi6n1Hz4ZnXR7yD2/tree/main)

[![Codecov](https://codecov.io/github/cretinon/shell/graph/badge.svg)](https://codecov.io/github/cretinon/shell)

## Table of contents

* [Main files](#main-files)
* [Prerequisites](#prerequisites)
* [Setup](#setup)
* [Configuration variables](#configuration-variables)
* [Usage](#usage)
* [Testing & quality](#testing--quality)
* [Documentation](#documentation)
* [Troubleshooting](#troubleshooting)
* [License](#license)

## Main files

* `my_warp.sh` — orchestrator entry point. Loads the conf, sources the libraries, dispatches the requested action.
* `lib_shell.sh` — core runtime and utilities (telemetry, logger, validation, arrays, YAML/JSON, strings, git, network, time, test harness, CLI dispatcher).
* `functions.md` — auto-generated API reference (see [Documentation](#documentation)).
* `bats/tests.bats` — BATS test suite of this library.
* [AGENTS.md](AGENTS.md) — contributor and agent rules (sync requirements, quality gate, git and coding conventions).
* `.circleci/config.yml` — CI pipeline running the quality gate.
* Domain feature libraries live in separate projects (`mcp`, `storm`, `tempo_shell`, ...) and are loaded on top of this base.

## Prerequisites

* `git`, `bash` and `getopt` (util-linux) to run the orchestrator.
* `jq` for the JSON helpers and the coverage summary.
* `shellcheck` for `-s`.
* `bats` with `bats-support`, `bats-assert` and `bats-file` for `-b`.
* `kcov` for `-k`.
* The tools used by the feature libraries you load.
* Optional: a `CODECOV_TOKEN` to upload the coverage report.

On Debian/Ubuntu:

```shell
sudo apt install -y git bash util-linux jq shellcheck bats bats-support bats-assert bats-file kcov
```

## Setup

1. Clone the repositories side by side under `${HOME}/git`, because the orchestrator loads the feature libraries from `MY_GIT_DIR`:

```shell
mkdir -p "${HOME}/git"
git clone https://github.com/cretinon/shell.git "${HOME}/git/shell"
git clone <feature-library-url> "${HOME}/git/<lib>"
```

2. Make `MY_GIT_DIR` available in your shell, so the examples below can be typed as is:

```shell
export MY_GIT_DIR="${HOME}/git"
```

3. Create `${HOME}/conf/my_warp.conf` (create `${HOME}/conf` first if needed) with this content:

```shell
# ${HOME}/conf/my_warp.conf
VERBOSE=false
DEBUG=false
YUBIKEY=false
FUNC_LIST=()
MY_GIT_DIR="${HOME}/git"
```

## Configuration variables

Every variable is set in `${HOME}/conf/my_warp.conf`. Any of them can also be exported in the environment, which takes precedence over the conf file.

* `VERBOSE` (boolean): verbose step-by-step logs.
* `DEBUG` (boolean): execution trace logs and internal shell diagnostics.
* `YUBIKEY` (boolean): cryptographic hardware (YubiKey) availability.
* `MY_GIT_DIR` (string, required): base directory of the local Git repositories.
* `FUNC_LIST` (array): function-call/telemetry tracking data.

## Usage

The orchestrator wrapper is the only entry point. Never call `lib_shell.sh`, `bats`, `shellcheck` or `kcov` directly.

```shell
# Display help
${MY_GIT_DIR}/shell/my_warp.sh -h

# List installed libraries
${MY_GIT_DIR}/shell/my_warp.sh --list-libs
```

Sample output of `--list-libs` (your installed libraries will differ):

```text
ansible docker linux_ha mcp shell storm tempo_shell tofu
```

```shell
# Call a feature-library function
${MY_GIT_DIR}/shell/my_warp.sh --lib <lib> <function> [<option> <value>]
```

## Testing & quality

```shell
# Run ShellCheck on a library (e.g. shell, mcp, storm, tempo_shell, ...)
${MY_GIT_DIR}/shell/my_warp.sh --lib <lib> -s

# Run your own tests only (regex filter on the @test names)
${MY_GIT_DIR}/shell/my_warp.sh --lib <lib> -b '<regex>'

# Run the FULL suite (quality-gate owner only)
${MY_GIT_DIR}/shell/my_warp.sh --lib <lib> -b

# Measure the coverage, minimum 80% (quality-gate owner only), cleans its temp report
${MY_GIT_DIR}/shell/my_warp.sh --lib <lib> -k

# Same, with the literal AI keyword: keeps the report and logs the path of its cobertura.xml
${MY_GIT_DIR}/shell/my_warp.sh --lib <lib> -k AI

# Regenerate the functions.md reference from the lib doc markers
${MY_GIT_DIR}/shell/my_warp.sh --lib shell --doc functions.md
```

The gate is lint, then tests, then coverage, and it runs in CI (`.circleci/config.yml`).

## Documentation

* `functions.md` — per-function reference of `lib_shell.sh`. It is **auto-generated** by `_doc` from the `# usage:` / `# call:`, `# description:`, `# example:`, `# param:` and `# return:` markers in the source. Edit the source comments, then regenerate with `--doc`. A BATS test enforces that the committed file stays in sync.

## Troubleshooting

The wrapper exits `0` on success, `1` on a generic failure and `10` (`ERROR_ARGV`) when an argument is invalid or a required tool is missing.

* `${HOME}/conf/my_warp.conf does not exist` — the conf file of step 3 of [Setup](#setup) is missing.
* `${MY_GIT_DIR}/shell/lib_shell.sh does not exist` — `MY_GIT_DIR` does not point to the directory holding the `shell` project.
* `Function _process_lib_<lib> not found in lib <lib>` — the feature library is not checked out under `MY_GIT_DIR`.
* Unknown or mistyped library — compare the `--lib` value with the output of `--list-libs`.

## License

MIT, see [LICENSE](LICENSE).
