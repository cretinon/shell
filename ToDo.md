# Analysis of `lib_shell-base.sh`

> Note: the repo moved since my earlier commit (`f9871e5`, `caf9138 "json sucks"` landed on top), so this is based on the current HEAD.

---

## 🐛 A. Correctness bugs (highest priority)

**A1. `_curl` reports the wrong error code** — line ~647
```bash
* )  _error "Something went wrong in _curl. Return code:$__return Response:$__resp"
```
> **STATUS: FIXED** — commit `94f10f6` replaced `$?` (which was the exit of the *case statement*, always 0) with `$__return`, so the real curl error code is now reported.

**A2. `_valid_network` accepts non-numeric masks** — line ~728
```bash
if ! _is_numeric "$__mask"; then _error "mask not numeric" ; _func_end "1" ; return 1 ; fi
if [ "$__mask" -gt 32 ]; then _error "mask > 32" ; _func_end "1" ; return 1 ; fi
```
> **STATUS: FIXED** — commit `33a1665` added the `_is_numeric` guard before the numeric comparison, so `192.168.1.0/abc` is now rejected with `mask not numeric` instead of slipping through.

**A3. `_json_add_key_with_value` no longer matches `functions.md`**
The object/string branch is commented out in `caf9138`, leaving only:
```bash
echo "$1" | jq '.'"$2"' += {"'"$3"'":'"$4"'}'
```
This always inserts the value **unquoted** (object syntax). Verified: `_json_add_key_with_value "{}" "" "toto" "tutu"` → jq error `tutu/0 is not defined`, ret=3. But `functions.md` documents "if the value starts with `{` → object, otherwise → string". Either restore the branch (and fix `_startswith`, see A4) or update `functions.md` — currently code and docs disagree, and plain-string callers silently break.
> **STATUS: FIXED (docs updated to match code)** — see commit in this session; `functions.md` now documents the value as a raw JSON literal.

**A4. `_startswith` breaks when `IFS=''`** — line ~578
```bash
[[ "$__str" == "$__sub"* ]]
```
> **STATUS: FIXED** — commit `b85f464` replaced the `$GREP` pipeline (which depended on word splitting and returned `127` under `IFS=''`) with a pure-bash pattern match: `[[ "$__str" == "$__sub"* ]]`. Faster and IFS-independent.

**A5. `_epoch_2_date` silently returns 0 with garbage** — `_epoch_2_date "123"` → `date: invalid date '@.123'`, ret=0. No input-length validation.
> **STATUS: FIXED** — commit `d3a4692` added `_is_numeric` and minimum-length (≥ 4 digits) guards before the awk/date conversion. Garbage/short input is now rejected with a clear `_error` message (`epoch not numeric` / `epoch too short`) and a non-zero return code; valid millisecond epochs are unchanged.

**A6. `_int2ip` silently wraps out-of-range ints** — the `> 4294967295` check is commented out; `_int2ip "9999999999999"` → `78.114.159.255` (wrapped), ret=0.
> **STATUS: FIXED** — commit `2174a7e` restored the `> 4294967295` check and added a `_is_numeric` guard, so out-of-range/negative/non-numeric input now fails loudly with `int too large` / `int not numeric`. `_netmask` and `_broadcast` were updated to mask their intermediate 64-bit values to 32 bits before calling `_int2ip`.

**A7. `_decode_url` leaks the global `j`** — `j` is never `local`. Verified pollution after a call. Fix: `local j`.

---

## ⚡ B. Performance (eliminate subprocesses — all bash 5 builtins)

| Function | Current (subprocess) | Builtin alternative |
|---|---|---|
| `_date` | `date '+%Y-%m-%d %H:%M:%S'` | `printf '%(%Y-%m-%d %H:%M:%S)T' -1` |
| `_upper` / `_lower` | `echo \| tr ...` | `${var^^}` / `${var,,}` |
| `_remove_last_car` | `echo \| sed` | `${var%?}` |
| `_startswith` | ✅ done (`b85f464`) — `[[ "$str" == "$sub"* ]]` | — |
| `_is_ascii` | `grep -q '^[ -~]*$'` | `[[ "$1" =~ ^[ -~]*$ ]]` (LC_ALL=C) |
| `_verbose_func_space` | `echo \| cut` per element | `${FUNC_LIST[$i]%%:*}` |
| `_func_end` | `echo ... \| cut -d: -f2` | `${FUNC_LIST[$__nb]#*:}` |
| `_timediff` | 4× `echo \| sed` | pure arithmetic/`${var#0}` |
| `_func_start`/`_func_end` timestamps | `date +"%s.%N"` (2 subprocesses per call) | `$EPOCHREALTIME` (bash 5.0+, verified available) |

**B1. `_log` does wasted work even when suppressed** — `_date` (subprocess!) and `_verbose_func_space` run **before** the DEBUG/VERBOSE early-return checks. Reordering the guards first makes the common (suppressed) path free.

**B2. Telemetry tax** — every instrumented function pays: `date` (×2) + `_array_add` + `_verbose_func_space` loop + `_timediff` (4 sed) + `_date`. Using `$EPOCHREALTIME` + param expansion removes ~7 subprocesses per instrumented call. Biggest single win for hot loops.

**Note:** `_iso_date` must keep `date -u` — bash's `printf %T` does **not** expand `%3N` (verified), and it's not UTC.

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
- `_tmp_file` calls `basename "$0"` — a subprocess, but only on `_tmp_file` calls (rare).

---

## Recommended order

1. **Fix the remaining bugs (A5–A7)** — A1, A2, A4 are already fixed (see STATUS above). A5 and A6 are silent-validation failures; A7 is a global-variable leak.
2. **`_log` reorder + `$EPOCHREALTIME` + `_timediff` param expansion (B1/B2)** — measurable speedup on every instrumented call.
3. **Builtin replacements (B table)** — mechanical, low risk (`_startswith` already converted in `b85f464`).
4. **DRY refactors (C)** — worth doing with the existing tests as a safety net (currently 170 tests + 99.16% coverage on this file).
