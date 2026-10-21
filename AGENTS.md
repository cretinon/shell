# AGENTS.md — shell

> Base file of every shell project. A project file inherits it with `LIB="<name>"`. Sections marked **(base)** apply to every library. The other sections describe `shell` itself.

## Project Overview

- `shell` is the foundation of the bash libraries: the orchestrator `my_warp.sh` and the runtime library `lib_shell.sh`.
- Feature libraries (`mcp`, `storm`, `tofu`...) live in sibling projects and load on top of it.
- `my_warp.sh`:
  1. loads `${HOME}/conf/my_warp.conf`
  2. sources `lib_shell.sh`
  3. loads the installed libraries
  4. parses the CLI and runs the requested action
- A library is discovered when `${MY_GIT_DIR}/<lib>/lib_<lib>.sh` exists.

## Project Layout

| Path | Edit it to... |
|------|---------------|
| `my_warp.sh` | change the orchestrator: conf loading, global defaults |
| `lib_shell.sh` | change a runtime helper |
| `bats/tests.bats` | change the tests |
| `README.md` | document installation and usage for users |

- Generated, never edited by hand: `functions.md`.
- Helper families of `lib_shell.sh`:
  - runtime: telemetry, logging, validation
  - data: JSON/YAML, arrays, strings, time
  - integration: git and GitHub, HTTP, network
  - orchestration: option parsing, usage, test harness, TUI
- `functions.md` lists every function.

## Invariants

- **Library-agnostic**: `lib_shell.sh` holds no domain logic. Domain code belongs to a feature library.

## Prerequisites (base)

- `bash` 5 or later, `jq`, `yq` v4
- `bats` with `bats-support`, `bats-assert`, `bats-file`
- `shellcheck`, `kcov`
- `MY_GIT_DIR` set, `${HOME}/conf/my_warp.conf` present

## Configuration (base)

- Precedence: environment > `<LIB>/conf/<LIB>.conf` > default.
- A library auto-loads and exports its own conf when a variable is unset.
- Secrets come from the environment or a git-ignored conf, never from the code.

Runtime variables:

| Variable | Default | Purpose |
|----------|---------|---------|
| `MY_GIT_DIR` | from conf | Base directory of the repositories |
| `VERBOSE` | `false` | Step-by-step logs |
| `DEBUG` | `false` | Trace logs |
| `YUBIKEY` | from conf | A YubiKey is available |
| `CURL_TIMEOUT` | `10` | Bound of every `_curl` request, in seconds |

- `CURL_TIMEOUT`: a request that reaches it fails with `curl timeout`.

## External Access

| Component | Reaches | Through |
|-----------|---------|---------|
| `_curl` | any URL the caller gives | `curl` |
| `_git_issue_*`, `_git_issue_count` | GitHub REST API | `_curl` |

- Nothing runs on the network unless a caller asks for it.

## Commands (base)

Every command goes through the wrapper. Never call `shellcheck`, `bats` or `kcov` directly.

```shell
${MY_GIT_DIR}/shell/my_warp.sh --lib <LIB> <action> [args]
```

| Option | Action |
|--------|--------|
| `-s` | Lint with ShellCheck |
| `-b [regex]` | BATS suite, optionally filtered on `@test` names |
| `-k` | Coverage with kcov |
| `--doc functions.md` | Regenerate the function reference |
| `--list-libs` | List the installed libraries |
| `-h` | Help |

## Documentation (base)

- The doc markers above each function of `lib_<LIB>.sh` are the source of truth.
- After any marker change, run `--doc functions.md` and commit the result. A test of the suite fails when the committed file drifts.
- Read `functions.md` before calling, editing or testing a function.
- `README.md` explains how to use the library, not how the code works.

## Testing (base)

- Add a function → test its nominal path and every error branch.
- Change a function → update its tests in the same change.
- Remove a function → remove the tests that only covered it.
- Tests never reach a live network: mock `_curl` and external binaries through function overrides or `PATH`.
- Tests write only to `$BATS_TEST_TMPDIR`.
- Coverage minimum: **80%**.

| Role | Runs |
|------|------|
| Implementing agent | `-s`, and `-b '<regex>'` on its own tests only |
| `code_reviewer` | Full gate: `-s` → `-b` → `-k`, every exit code `0` |

- The full gate runs before any commit, PR or task completion.
- CI (CircleCI) runs the same gate and uploads coverage to Codecov.

## Git Workflow (base)

- Commit only when asked. Never push.
- Stage only the files of the change. No `git add .`.
- Write a why-focused commit message.
- Never amend, force-push or rewrite history.

## Code Style (base)

- Conventions: `${MY_GIT_DIR}/agents/rules/shell.md` (naming, doc markers, validation, telemetry, return codes).
- Return codes: `0` success, `1` failure, `10` (`ERROR_ARGV`) invalid argument.
- stdout carries the function result only. Logs go to stderr.
- Group functions under banner comments: `#` lines spanning the terminal width, section name centred.
- Lint exemptions (`# no _shellcheck`) are added by the code owner only.
- Temp files go under `/tmp/ECA` (`mkdir -p /tmp/ECA` first), never inside a repository.

## Open Issues

See the open issues of the repository on GitHub.
