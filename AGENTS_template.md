# AGENTS.md — <LIB>

> Inherits `${MY_GIT_DIR}/shell/AGENTS.md` with `LIB="<LIB>"`. Read it first in every session. This file only adds or overrides.

## Project Overview

- <One sentence: what `<LIB>` is.>
- <One sentence: who or what consumes it.>
- Depends on: `lib_shell.sh` <, other projects>.

## Project Layout

| Path | Edit it to... |
|------|---------------|
| `lib_<LIB>.sh` | <change the library logic> |
| `bats/tests.bats` | <change the tests> |
| `conf/<LIB>.conf` | <change local defaults> |
| `README.md` | <document usage for users> |

Generated, never edited by hand: `functions.md`.

## Invariants

Rules an edit must never break. Each one is stated once, here.

- **<Name>**: <rule>. <Why, in one sentence.>

## Prerequisites

Base rules apply. Additions:

- <binary, version, service>

## Configuration

Base rules apply. Variables of `conf/<LIB>.conf`:

| Variable | Default | Purpose |
|----------|---------|---------|
| `<VAR>` | `<value>` | <one short line> |

- `<VAR>`: <extra detail, error message when unset>.

## External Access

| Component | Reaches | Through |
|-----------|---------|---------|
| `<function or tool>` | <service> | `_curl` / `ssh` / ... |

- Everything else runs offline.
- Secrets: <variable names>, from environment or git-ignored conf.

## Commands

Base rules apply. Additions:

- <project command or caveat>

## Documentation

Base rules apply.

## Testing

Base rules apply. Additions:

- <mocking strategy, test groups>

## Git Workflow

Base rules apply.

## Code Style

Base rules apply. Additions:

- <project-specific convention>

## Open Issues

See the open issues of the repository on GitHub.
