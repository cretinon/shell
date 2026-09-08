# shell

Bash library and orchestration system: reusable shell functions (logging, validation,
arrays, YAML/JSON, network, time, telemetry, test harness) plus the `my_warp.sh`
orchestrator used to call functions and libraries across projects.

[![CircleCI](https://dl.circleci.com/status-badge/img/circleci/PJuzGhtpJT1B6rC5YF9SLA/RD3EguHi6n1Hz4ZnXR7yD2/tree/main.svg?style=svg)](https://dl.circleci.com/status-badge/redirect/circleci/PJuzGhtpJT1B6rC5YF9SLA/RD3EguHi6n1Hz4ZnXR7yD2/tree/main) [![codecov](https://codecov.io/github/cretinon/shell/graph/badge.svg?token=KEXL9YUJNL)](https://codecov.io/github/cretinon/shell)

## What's inside

* `my_warp.sh` — orchestrator entry point; loads the conf, sources the libraries and
  dispatches the requested action/function.
* `lib_shell.sh` — core runtime + utilities (telemetry, logger, validation, arrays,
  YAML/JSON, strings, git, network, time, test harness, CLI dispatcher).
* `functions.md` — auto-generated API reference (see *Documentation* below).
* Domain feature libraries live in separate projects (`mcp`, `storm`, `tempo_shell`, ...)
  and are loaded on top of this base.

## Setup

Check out the repositories under `${HOME}/git`, then create the orchestrator conf file:

```shell
mkdir -p ${HOME}/conf
cat > ${HOME}/conf/my_warp.conf <<'EOF'
VERBOSE=false
DEBUG=false
YUBIKEY=false
FUNC_LIST=()
MY_GIT_DIR="${HOME}/git"
EOF
chmod +x ${HOME}/git/shell/my_warp.sh
```

### Configuration variables

* `VERBOSE` (boolean): verbose step-by-step logs.
* `DEBUG` (boolean): execution trace logs and internal shell diagnostics.
* `YUBIKEY` (boolean): cryptographic hardware (YubiKey) availability.
* `MY_GIT_DIR` (string): base directory of the local Git repositories.
* `FUNC_LIST` (array): function-call/telemetry tracking data.

## Usage

```shell
# Display help
${MY_GIT_DIR}/shell/my_warp.sh -h

# List installed libraries
${MY_GIT_DIR}/shell/my_warp.sh --list-libs

# Call a feature-library function
${MY_GIT_DIR}/shell/my_warp.sh --lib "$LIB" <function_name> --<argument> <value>
```

### Development & maintenance

```shell
# ShellCheck a library (LIB=shell, LIB=ansible, ...)
${MY_GIT_DIR}/shell/my_warp.sh --lib "$LIB" -s

# Run the BATS tests (optionally filtered by regex)
${MY_GIT_DIR}/shell/my_warp.sh --lib "$LIB" -b
${MY_GIT_DIR}/shell/my_warp.sh --lib "$LIB" -b '<regex>'

# Measure test coverage with kcov
${MY_GIT_DIR}/shell/my_warp.sh --lib "$LIB" -k AI

# Regenerate the functions.md reference from the lib doc markers
${MY_GIT_DIR}/shell/my_warp.sh --lib shell --doc functions.md
```

## Documentation

* `functions.md` — per-function reference of `lib_shell.sh`, **auto-generated** by
  `_doc` from the `# doc-section:` / `# description:` / `# example:` / `# param:` /
  `# return:` markers in the source. Edit the source comments, then regenerate with
  `--doc`; a BATS test enforces that the committed file stays in sync.
* `AGENTS.md` — contributor/agent rules (sync requirements, quality gate, git and
  coding conventions).

## Testing & quality

* BATS harness (`bats/tests.bats`), ShellCheck, kcov coverage (min 80%) — see
  `AGENTS.md` and the CircleCI config.
