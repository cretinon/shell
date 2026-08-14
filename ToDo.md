# Analysis of `lib_shell-base.sh`

> Note: the repo moved since my earlier commit (`f9871e5`, `caf9138 "json sucks"` landed on top), so this is based on the current HEAD.
>
> **Status:** Original **A** (correctness) section is fully fixed (A1–A7), and original **B** (performance) section is fully done (B-table + B1/B2). The **Round-2** findings below come from a fresh analysis of the current code (198 BATS tests, 99.18% coverage on `lib_shell-base.sh`). Every Round-2 item was reproduced empirically before being listed.

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

**A12. Lint gap: the grep-based `_shellcheck` rules miss violations hidden on the same line** — `_curl`'s success branch has `_func_end ; return 0` (no arg, no `# no _shellcheck`) on the same line as `_func_end "1" ; return 1`, so both the "_func_end must have an arg" and "returning 0 is a bad idea" rules exclude the whole line and never flag it. The lint is line-based, not token-based.

**A13. `_netmask` / `_broadcast` / `_network` accept non-numeric masks and silently compute wrong results** — `if [ "$mask" -gt 32 ]` on a non-numeric makes `test` exit 2, which `if` treats as **false**, so the guard never fires and the mask flows into arithmetic as an empty variable (0). Verified: `_netmask "abc"` → `0.0.0.0` ret=0, `_broadcast "192.168.2.0" "abc"` → `255.255.255.255` ret=0, `_network "192.168.2.0" "abc"` → `0.0.0.0` ret=0. Same class as the old A2 — these three need the `_is_numeric` guard that `_valid_network` already has.
> **STATUS: FIXED** — commit `9f3f897` added `_is_numeric` guards to `_netmask` (`$1`) and `_broadcast`/`_network` (`$2`), so non-numeric (and negative) masks now fail loudly with `mask not numeric` (ret `10`).

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

**B4. `_log` still does needless work in default mode (B1 is incomplete)** — after B1, ERROR/WARNING/SUCCESS/INFO messages always pass the guards, so `_date` + `_verbose_func_space` run **even when DEBUG=false and VERBOSE=false**, although the final `_echoerr "$__message"` path uses neither. Guard the whole computation: `if ! $DEBUG && ! $VERBOSE; then _echoerr "$__message"; return; fi` before computing date/VERBOSE_SPACE.

**B5. `_func_start` / `_func_end` build `VERBOSE_SPACE` unconditionally** — `_verbose_func_space` runs on every instrumented call even with logging fully off, but `VERBOSE_SPACE` is only consumed when DEBUG or VERBOSE is enabled (in `_log`'s DEBUG branch and `_dump_file_*`). Wrap the call in `if $DEBUG || $VERBOSE; then _verbose_func_space; fi` in both functions.

**B6. `_epoch_2_date` still forks `awk` per call** — the millisecond split can be done with param expansion: `date -u -d "@${1%???}.${1: -3}" +"%Y-%m-%d %H:%M:%S"` is byte-identical to the awk form (verified: both yield `2024-04-05 19:34:38` for `1712345678123`) and removes the awk subprocess.

---

## 🧹 C. Maintainability / DRY

1. **Duplicate yq-version parsing** — `_json_2_yaml` and `_yaml_2_json` repeat the identical 4-step `sed` chain + version check. Extract `_yq_version()`.
2. **`_curl`'s 4-level nested if/else** for optional headers/data — build a `curl_args` array instead. Same behavior, far more readable.
3. **Netmask arithmetic duplicated** — `__mask=$((0xffffffff << (32 - "$2")))` appears in `_netmask`, `_broadcast`, `_network`. Factor a `_cidr_mask` helper.
4. **Dead code** — the commented-out `_startswith "$4" "{"` branch in `_json_add_key_with_value` should be either restored or removed.
5. **`_array_count_elt` checks `_exist "$@"`** — should be `_exist "$1"` (currently any empty arg trips it).

---

## 🩹 D. Minor / style

- `_array_*` functions juggle global `IFS=''` with save/restore — `local IFS` scoping is cleaner and safer.
- `_working_dir_count_*` / `_gen_rand` / `_gen_pin` — multi-command pipelines (`find|wc|xargs`, `tr|fold|paste|head`). Functionally fine; only worth touching if these are hot.
- `_tmp_file` calls `basename "$0"` — a subprocess; swap for `${0##*/}` (rare path).

---

## Recommended order (round 2)

1. **Fix the remaining silent correctness bug**: A11 (literal `null` value). A8/A10 (`FUNC_LIST` leaks) are fixed (`f341e0c`, plus the AGENTS.md stack-balance convention); A9 was a documentation fix; A13 is fixed (`9f3f897`).
2. **`_log`/`_func_start`/`_func_end` guards (B4/B5)** — removes per-call work in the default (non-debug, non-verbose) mode; B3 (`_is_numeric`) and B6 (`_epoch_2_date` awk) are mechanical, low-risk.
3. **A12** — decide whether to harden the grep-based lint (token-aware check) or add `# no _shellcheck` to the offending `_curl` line.
4. **DRY refactors (C)** — worth doing with the tests as a safety net.
