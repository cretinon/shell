# AGENTS.md

## Project Overview

Modular, well-tested bash library and orchestration system: an orchestrator script
(`my_warp.sh`), a foundational utility library (`lib_shell.sh`), a BATS test suite,
and structured CI/CD (CircleCI + Codecov). Feature libraries (`mcp`, `storm`, ...)
live in sibling projects and are loaded dynamically on top of this base.

### Architecture (high level)

* **Main Orchestrator (`my_warp.sh`)**: Entry point. Loads `${HOME}/conf/my_warp.conf`,
  sources `lib_shell.sh`, loads the installed feature libraries, parses the CLI, and
  routes execution to the requested action or library function.
* **Library (`lib_shell.sh`)**: Library-agnostic runtime + CLI dispatcher. Function
  groups: stack-trace/telemetry, logger, validation primitives, working-dir helpers,
  temp files & random generation, orchestrator helpers (option parsing, usage,
  lib/conf loading), time management, array management, YAML/JSON converters, string
  management, git helpers, URL/HTTP helpers, network computation, architecture
  detection, interactive ask helpers, display helpers, test/CI harness (`-s|-b|-k`),
  and the demo/CLI dispatcher. The authoritative per-function API reference is
  `functions.md` — auto-generated, never hand-maintained (see Documentation).
* **Feature libraries (other projects)**: e.g. `mcp`, `storm`; each adds
  `lib_<name>.sh` implementing domain logic on top of `lib_shell.sh`.

## Documentation

### Doc markers in `lib_shell.sh` are the source of truth

Every function is documented just above its definition with
`# usage:`/`# call:`, `# description:`, `# example:`, `# param:` and `# return:`
markers, grouped under `# doc-section:` banners (conventions: `agents/rules/shell.md`).
Edit these markers in the code — never edit the generated reference by hand.

### `functions.md` — auto-generated function reference

* `functions.md` is regenerated from the `lib_shell.sh` markers by `_doc`:

  ```shell
  ${MY_GIT_DIR}/shell/my_warp.sh --lib shell --doc functions.md
  ```

* After any doc-marker change, regenerate and commit `functions.md`. The BATS test
  `_doc => documented mode regenerates functions.md (shell)` diffs the committed file
  against a fresh generation, so any drift fails the suite.
* Consult `functions.md` (or the source markers) before reading, editing, calling, or
  testing a function of `lib_shell.sh`.

### `bats/tests.bats` — keep in sync with `lib_shell.sh`

* **Adding** a function → add BATS cases covering its nominal behavior and its
  error/edge branches (missing args, invalid input, non-zero returns).
* **Modifying** a function → update/extend its tests so the suite reflects the
  actual behavior.
* **Removing** a function → remove the tests that only exercised it.
* Coverage must stay above the project minimum (see Quality section); when in doubt,
  the actual behavior of `lib_shell.sh` is the source of truth for the tests.

## Setup & Configuration

Full, human-oriented installation instructions live in `README.md`. For agents:

* The orchestrator sources `${HOME}/conf/my_warp.conf`; feature libraries may also
  auto-load their own conf (`<lib>/conf/<lib>.conf`, see each project's AGENTS.md).
* Variables used by the runtime (`conf` file or environment, environment wins):

| Variable | Type | Purpose |
|----------|------|---------|
| `VERBOSE` | boolean | Display verbose step-by-step logs. |
| `DEBUG` | boolean | Execution trace logs and internal shell diagnostics. |
| `YUBIKEY` | boolean | Cryptographic hardware (YubiKey) availability. |
| `MY_GIT_DIR` | string | Base directory of the local Git repositories. |
| `FUNC_LIST` | array | Function-call/telemetry tracking data. |

## Command-Line Interface (CLI)

All commands go through the orchestrator wrapper — never raw binaries:

```shell
${MY_GIT_DIR}/shell/my_warp.sh --lib <LIB> <action> [args]
```

* `-s` ShellCheck · `-b [filter]` BATS (filter runs only matching `@test`s) ·
  `-k` kcov · `--doc <file>` regenerate the `functions.md` reference ·
  `--list-libs` · `-h` help.
* Full usage examples: `README.md`.

## Testing & Quality Control

* **Harness**: BATS, tests under `<LIB>/bats/tests.bats`; MUST be triggered through
  the wrapper (`my_warp.sh --lib <LIB> -b [filter]`), never by calling `bats` directly.
* **Lint**: ShellCheck through `-s`; ignore rules centralized in file headers.
* **Coverage**: kcov through `-k`, results to Codecov, minimum **80%**.
  (Full suite & coverage are run only by the `code_reviewer` sub-agent, before any
  commit / PR / task completion — see `agents/rules/code_review.md`.)

### Who runs what

| Role | Runs |
|------|------|
| Implementing agent | only the tests it wrote/modified: `-b '^<test-name>$'` (exit `0`); may run `-s`. NEVER full `-b`, NEVER `-k`. |
| `code_reviewer` sub-agent | the full gate, in order: `-s` → full `-b` → `-k`; each exit code must be `0`. |

### Pre-commit verification gate (mandatory)

The three checks above are the project's only sanctioned quality gate. Always use the
wrapper — never `shellcheck`/`bats`/`kcov` binaries directly. The gate is executed by
the `code_reviewer` sub-agent before committing or finalizing any change; if a check
fails, fix the root cause and re-run until every exit code is `0`.

## Git Workflow Rules

**Do:**
- DO commit changes when asked to commit.
- DO stage only the relevant files for the change (avoid blind `git add .`).
- DO write a clear, "why"-focused commit message.

**Don't:**
- DON'T push. When asked to "commit" (e.g. *"commit all changes"*), only commit — never push.
- DON'T force-push, amend, or rewrite history.

## Code Style & Conventions

* **Full conventions live in the agents rules**: `${MY_GIT_DIR}/agents/rules/shell.md`
  (naming, `# usage:`/`# call:`/`# description:` comments, argument validation, return
  codes, telemetry hooks, jq usage, lint exemptions, variable quoting). ECA loads it
  automatically when reading/editing `**.sh` files; this section only keeps
  project-wide rules.
* **Section Organization**: group related functions under banner comments — a series
  of `#` lines spanning the terminal width with the section name centered.
* **Temporary files & folders (AI agents)**: any temp file/folder MUST be created
  under `/tmp/ECA` (create it first with `mkdir -p /tmp/ECA`); NEVER inside the
  repository working tree — they pollute `git status` and risk being committed.
