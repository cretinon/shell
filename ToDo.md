# Analysis of `lib_shell-base.sh`

> Note: the repo moved since my earlier commit (`f9871e5`, `caf9138 "json sucks"` landed on top), so this is based on the current HEAD.
>
> **Status:** Original **A** (correctness) section is fully fixed (A1–A7), original **B** (performance) section is fully done (B-table + B1/B2), and all **Round-2** items (A8–A14, B3–B6) are fixed/done. The **Round-3** findings below come from a fresh analysis of the current code (213 BATS tests, 98.00% coverage on `lib_shell-base.sh`). Every Round-3 item was reproduced empirically before being listed.

---

## 🐛 A. Correctness bugs

### Round-1 (all fixed — kept for history)

**A1. `_curl` reports the wrong error code** — `* ) _error "Something went wrong in _curl. Return code:$__return Response:$__resp"`
> **STATUS: FIXED** — commit `94f10f6` replaced `$?` (the exit of the *case statement*, always 0) with `$__return`.

**A2. `_valid_network` accepts non-numeric masks** — `192.168.1.0/abc` slipped through the `-gt 32` comparison.
> **STATUS: FIXED** — commit `33a1665` added the `_is_numeric` guard.

**A3. `_json_add_key_with_value` no longer matches `functions.md`** — code always inserts the value unquoted (raw JSON literal).
> **STATUS: FIXED (docs updated to match code)** — `functions.md` now documents `$4` as a raw JSON literal.

**A4. `_startswith` breaks when `IFS=''`** — grep pipeline returned `127` under `IFS=''`.
> **STATUS: FIXED** — commit `b85f464` replaced it with `[[ "$__str" == "$__sub"* ]]`.

**A5. `_epoch_2_date` silently returns 0 with garbage** — `_epoch_2_date "123"` → `date: invalid date '@.123'`, ret=0.
> **STATUS: FIXED** — commit `d3a4692` added `_is_numeric` + ≥4-digit guards.

**A6. `_int2ip` silently wraps out-of-range ints** — `_int2ip "9999999999999"` → `78.114.159.255` (wrapped), ret=0.
> **STATUS: FIXED** — commit `2174a7e` restored the range check + `_is_numeric` guard, and fixed `_netmask`/`_broadcast` to pass 32-bit values.

**A7. `_decode_url` leaks the global `j`** — never `local`.
> **STATUS: FIXED** — commit `cee55c2` declared `j` local.

### Round-2 findings (post A/B fixes — all verified)

**A8. `_decode_url` leaks a `FUNC_LIST` entry on every plain-text segment** — the `* ) return ;;` branch returns **without** calling `_func_end`. Verified: `FUNC_LIST` length goes 0 → 1 after `_decode_url "abc"`, and 0 → 2 after two decodes (even `_decode_url "a%20b"` leaks one entry via the innermost recursion). Over many calls the telemetry stack (and `VERBOSE_SPACE`) grows unboundedly. Fix: replace the bare `return` with `_func_end "0" ; return 0` (and keep the recursive tail popping).
> **STATUS: FIXED** — commit `f341e0c` replaced the bare `return` with `_func_end "0" ; return 0`; verified `FUNC_LIST` stays balanced for plain, encoded and mixed decodes.

**A9. `functions.md` documents the wrong key format for the `_json_*` helpers — DOCUMENTATION problem, not a code bug** — the code is correct: every `_json_*` function builds its jq filter as `'.'"$2"` and therefore expects `$2` **without** a leading dot (e.g. `foo.bar`; nested paths are written `a.b`, and the root/empty form works too). The tests already call them this way. `functions.md` wrongly documented `.foo.bar`, which produces `..foo.bar` (jq recursive-descent → syntax error).
> **STATUS: FIXED (docs updated)** — all five `_json_*` entries in `functions.md` now document the no-dot key convention; no code change needed.
> Residual (separate, minor): `_json_get_value_from_key` swallows jq errors with `2>/dev/null`, so an invalid path (a leading dot or a typo) silently prints nothing and returns 0 — consider surfacing the error instead of hiding it.

**A10. `_gen_uuid` and `_bats` error paths skip `_func_end`** — `_gen_uuid`: `if ! _installed "uuidgen"; then _error "uuidgen not found"; return $ERROR_ARGV; fi` pops nothing. `_bats`: `cd "$MY_GIT_DIR/$LIB" || return 1` and `cd - > /dev/null || return 1` also return without `_func_end`. Same FUNC_LIST leak class as A8.
> **STATUS: FIXED** — commit `f341e0c` added `_func_end` to `_gen_uuid`'s uuidgen-missing path and to `_bats`' `cd` failure paths.
> **Convention added** — `AGENTS.md` now documents the stack-balance rule: any function that calls `_func_start` MUST call `_func_end` before **every** `return` (same line, `_func_end "<code>" ; return <code>`); telemetry-free helpers are the only exception. A function-aware audit of `lib_shell-base.sh` confirms zero remaining violations.

**A11. `_json_get_value_from_key` cannot distinguish a literal `"null"` string value from a missing key** — `[ "a$__result" == "anull" ]` returns 1 for both. Verified: `{"key":"null"}` with `"key"` → `null`, ret=1 (a real string value should be ret 0), and a missing key also ret=1. A value that legitimately equals the string `null` is indistinguishable from absence.
> **STATUS: FIXED** — replaced the string comparison with a jq type-aware check (`getpath(($p | split("."))) != null` via `jq -e --arg`), so a literal `"null"` string returns `0` while JSON `null`/missing returns `1` (per the documented contract). Extraction also switched from `'.'"$2"` to `getpath`/`--arg`, which removes the A9 residual (leading-dot keys no longer silently fail) and supports keys with special characters.

**A12. Lint gap: the grep-based `_shellcheck` rules miss violations hidden on the same line** — `_curl`'s success branch has `_func_end ; return 0` (no arg, no `# no _shellcheck`) on the same line as `_func_end "1" ; return 1`, so both the "_func_end must have an arg" and "returning 0 is a bad idea" rules exclude the whole line and never flag it. The lint is line-based, not token-based.
> **STATUS: FIXED** — the offending `_curl` line now uses `_func_end "0" ; return 0` (with `# no _shellcheck`), so the violation no longer exists. The line-based lint limitation itself remains (rules exclude a whole line when any part matches the exclusion pattern), but no current code violates the convention.

**A13. `_netmask` / `_broadcast` / `_network` accept non-numeric masks and silently compute wrong results** — `if [ "$mask" -gt 32 ]` on a non-numeric makes `test` exit 2, which `if` treats as **false**, so the guard never fires and the mask flows into arithmetic as an empty variable (0). Verified: `_netmask "abc"` → `0.0.0.0` ret=0, `_broadcast "192.168.2.0" "abc"` → `255.255.255.255` ret=0, `_network "192.168.2.0" "abc"` → `0.0.0.0` ret=0. Same class as the old A2 — these three need the `_is_numeric` guard that `_valid_network` already has.
> **STATUS: FIXED** — commit `9f3f897` added `_is_numeric` guards to `_netmask` (`$1`) and `_broadcast`/`_network` (`$2`), so non-numeric (and negative) masks now fail loudly with `mask not numeric` (ret `10`).

**A14. (ENFORCED) `_shellcheck` now rejects any `return` without `_func_end` in instrumented functions** — the AGENTS.md stack-balance convention is enforced by a new function-aware awk rule inside `_shellcheck`: it tracks functions that call `_func_start` and flags bare `return` on lines without `_func_end` (`# no _shellcheck` is the explicit opt-out). The rule immediately caught two pre-existing leaks in `lib_shell.sh`'s `_process_opts` (lines 32/35) — fixed. A BATS test asserts the rule fires.
> **STATUS: FIXED** — commit `0dc9d0a` added the lint rule; `./my_warp.sh --lib <lib> -s` now fails on any violation.

### Round-3 findings (fresh analysis after all A/B fixes — all verified)

**A15. `_timediff` silently returns wrong results for malformed timestamps** — no validation of the documented `seconds.nanoseconds` format. Verified: `_timediff "1.5" "2"` → `0s999` (should be ≈ `0s500`): for a value without a `.`, `${var%.*}`/`${var#*.}` both yield the whole string and the borrow logic misbehaves. Internal callers (`_func_end`) always pass well-formed `$EPOCHREALTIME` values, but as a public API it silently computes garbage (same class as A5/A13).
> **STATUS: FIXED** — commit `a866e4a` added a `^[0-9]+\.[0-9]+$` format guard on both args, so malformed timestamps fail loudly with `invalid timestamp, expected seconds.nanoseconds` (ret `1`).

**A16. `_kcov` uses `jq` without checking it is installed** — only `_installed "kcov"` is checked; the `jq -r ".files | .[]" "$__tmp/.../coverage.json"` summary silently prints nothing (and the function still reports success) if `jq` is missing.
> **STATUS: FIXED** — commit `a866e4a` added `_installed "jq"` → `jq not found` (ret `10`).

**A17. `_array_remove_last` on an empty array emits `unset: [-1]: bad array subscript`** — verified with an empty array. In normal flow `_func_end` keeps `FUNC_LIST` non-empty, but a stray `_func_end`/direct call on an empty array produces noisy stderr (and a `0` return).
> **STATUS: FIXED** — commit `071b8c9` guards the `unset` with a nameref length check: an empty array is left untouched with **no error** (silent no-op, as requested), non-empty arrays still pop the last element, and an empty array-name still reports `ARRAY EMPTY`.

**A18. yq version guard is bypassed when `yq --version` is unparseable** — `[ "$__yq_version" -ne 4 ]` with a non-numeric version makes `test` exit 2, which `if` treats as **false**, so `_json_2_yaml`/`_yaml_2_json` proceed without the v4 check (same `if`-exit-2 quirk as A13). Verified with a mock `yq` printing `unexpected-format`.
> **STATUS: FIXED** — commit `f1c7789` added an `_is_numeric "$__yq_version"` guard before the comparison, so unparseable and non-v4 versions now fail loudly with `yq ... not supported, need version >= 4`.

---

## ⚡ B. Performance

### Round-1 (all done — kept for history)

| Function | Status |
|---|---|
| `_date` | ✅ done (`f02d239`) — `printf '%(%Y-%m-%d %H:%M:%S)T' -1` |
| `_upper` / `_lower` | ✅ done (`f02d239`) — `${var^^}` / `${var,,}` (with `local LC_ALL=C`) |
| `_remove_last_car` | ✅ done (`f02d239`) — `${var%?}` |
| `_startswith` | ✅ done (`b85f464`) — `[[ "$str" == "$sub"* ]]` |
| `_is_ascii` | ✅ done (`f02d239`) — `[[ "$1" =~ ^[[:print:]]*$ ]]` (LC_ALL=C) |
| `_verbose_func_space` | ✅ done (`4fd91ed`) — `${FUNC_LIST[$__i]%%:*}` |
| `_func_end` | ✅ done (`4fd91ed`) — `${FUNC_LIST[$__nb]#*:}` |
| `_timediff` | ✅ done (`4fd91ed`) — `${var#"${var%%[1-9]*}"}` |
| `_func_start`/`_func_end` timestamps | ✅ done (`4fd91ed`) — `$EPOCHREALTIME` (with `local LC_ALL=C`) |

**B1. `_log` does wasted work even when suppressed** — ✅ done (`2e7946e`).
**B2. Telemetry tax** — ✅ done (`4fd91ed`).

**Note:** `_iso_date` must keep `date -u` — bash's `printf %T` does not expand `%3N`.

### Round-2 findings (post A/B fixes)

**B3. `_is_numeric` still spawns `grep` on every call** — `LC_ALL=C $GREP -q '^[0-9][0-9]*$' <<<"$1"` (subprocess) is on the validation path of `_valid_network`, `_int2ip` and `_epoch_2_date`. Replace with pure bash: `[[ "$1" =~ ^[0-9]+$ ]]` — identical for empty/non-numeric input (verified: empty, `abc`, `123` all match the grep behavior). The B-table converted `_is_ascii` but missed `_is_numeric`.
> **STATUS: DONE** — commit `8a500be` converted `_is_numeric` to `[[ "$1" =~ ^[0-9]+$ ]]` with `local LC_ALL=C` (verified identical to grep, including rejection of unicode digits).

**B4. `_log` still does needless work in default mode (B1 is incomplete)** — after B1, ERROR/WARNING/SUCCESS/INFO messages always pass the guards, so `_date` + `_verbose_func_space` run **even when DEBUG=false and VERBOSE=false**, although the final `_echoerr "$__message"` path uses neither. Guard the whole computation: `if ! $DEBUG && ! $VERBOSE; then _echoerr "$__message"; return; fi` before computing date/VERBOSE_SPACE.
> **STATUS: DONE** — commit `8a500be` added the both-off early return; the plain path now costs nothing (and the old final else branch became dead code).

**B5. `_func_start` / `_func_end` build `VERBOSE_SPACE` unconditionally** — `_verbose_func_space` runs on every instrumented call even with logging fully off, but `VERBOSE_SPACE` is only consumed when DEBUG or VERBOSE is enabled (in `_log`'s DEBUG branch and `_dump_file_*`). Wrap the call in `if $DEBUG || $VERBOSE; then _verbose_func_space; fi` in both functions.
> **STATUS: DONE** — commit `8a500be` guarded `_verbose_func_space` in both `_func_start` and `_func_end` with `$DEBUG || $VERBOSE`.

**B6. `_epoch_2_date` still forks `awk` per call** — the millisecond split can be done with param expansion: `date -u -d "@${1%???}.${1: -3}" +"%Y-%m-%d %H:%M:%S"` is byte-identical to the awk form (verified: both yield `2024-04-05 19:34:38` for `1712345678123`) and removes the awk subprocess.
> **STATUS: DONE** — commit `899afcb` replaced the awk pipeline with `${1%???}.${1: -3}` param expansion (verified identical for multiple inputs).

### Round-3 findings (fresh analysis after all A/B fixes)

**B7. `_json_get_value_from_key` now forks `jq` twice** — the A11 fix added a second `jq -e` call for the type-aware existence check on top of the extraction `jq`. Verified a single-call version gives identical results for all cases (string `null` → 0, JSON null/missing → 1, `false`/`0`/`""`/nested → 0):
```bash
__result=$(echo "$1" | jq -r --arg p "$2" 'getpath(($p | split("."))) | if . == null then error("not found") else . end' 2>/dev/null)
__return=$? ; if [ "$__return" -ne 0 ]; then __return=1 ; fi
```
This halves the jq invocations in this helper.

**B8. `_log` builds `VERBOSE_SPACE` in VERBOSE-only mode where it is unused** — the B4 both-off guard doesn't cover `DEBUG=false VERBOSE=true`: `_log` still runs `_verbose_func_space`, but the VERBOSE output branch never uses `VERBOSE_SPACE` (only the DEBUG branch does). Guard it with `if $DEBUG; then _verbose_func_space; fi` (the `_dump_file_*` consumers are refreshed by `_func_start`/`_func_end`, not by `_log`).

---

## 🧹 C. Maintainability / DRY

**C1. Duplicate yq-version parsing** — `_json_2_yaml` and `_yaml_2_json` repeat the identical 4-step `sed` chain + version check. Extract `_yq_version()`.

**C2. `_curl`'s 4-level nested if/else** for optional headers/data — build a `curl_args` array instead. Same behavior, far more readable.

**C3. Netmask arithmetic duplicated** — `__mask=$((0xffffffff << (32 - "$2")))` appears in `_netmask`, `_broadcast`, `_network`. Factor a `_cidr_mask` helper.

**C4. Dead code** — the commented-out `_startswith "$4" "{"` branch in `_json_add_key_with_value` should be either restored or removed.

**C5. `_array_count_elt` checks `_exist "$@"`** — should be `_exist "$1"` (currently any empty arg trips it).

---

## 🩹 D. Minor / style

**D1. `_array_*` functions juggle global `IFS=''` with save/restore** — `local IFS` scoping is cleaner and safer.

**D2. `_working_dir_count_*` / `_gen_rand` / `_gen_pin`** — multi-command pipelines (`find|wc|xargs`, `tr|fold|paste|head`). Functionally fine; only worth touching if these are hot.

**D3. `_tmp_file` calls `basename "$0"`** — a subprocess; swap for `${0##*/}` (rare path).

---

## Recommended order (round 3)

1. **Round-2 correctness bugs — ALL FIXED**: A8/A10 (`FUNC_LIST` leaks, `f341e0c`), A9 (documentation fix), A11 (literal `null` value), A12 (`_curl` line made compliant), A13 (non-numeric masks, `9f3f897`), A14 (lint enforcement, `0dc9d0a`).
2. **Round-2 performance — ALL DONE**: B3/B4/B5 (`8a500be`), B6 (`899afcb`). The B section is complete.
3. **Round-3 silent-correctness fixes — ALL FIXED**: A15 (`_timediff` format validation, `a866e4a`), A16 (`_kcov` jq check, `a866e4a`), A17 (`_array_remove_last` no-op, `071b8c9`), A18 (yq version guard, `f1c7789`).
4. **Round-3 performance (low-risk, mechanical)**: B7 (single-jq in `_json_get_value_from_key`), B8 (`_log` VERBOSE_SPACE only when DEBUG).
5. **DRY refactors (C)** — worth doing with the tests as a safety net.
