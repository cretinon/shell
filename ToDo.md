# Analysis of `lib_shell-base.sh`

> Note: the repo moved since my earlier commit (`f9871e5`, `caf9138 "json sucks"` landed on top), so this is based on the current HEAD.

---

## 🐛 A. Correctness bugs (highest priority)

**A1. `_curl` reports the wrong error code** — line ~633
```bash
* ) _error "Something went wrong in _curl. Return code:$? Response:$__resp"
```
`$?` here is the exit of the *case statement* (0), not the curl code. Verified: mock curl returning `99` prints `Return code:0`. Should be `Return code:$__return`.

**A2. `_valid_network` accepts non-numeric masks** — line ~718
```bash
if [ "$__mask" -gt 32 ]; then _error "mask > 32"; return 1; fi
```
With `192.168.1.0/abc`, `[ "abc" -gt 32 ]` throws a bash error but returns non-zero → the guard is skipped → **function returns 0 (valid!)**. Needs `[[ "$__mask" =~ ^[0-9]+$ ]]` before the comparison.

**A3. `_json_add_key_with_value` no longer matches `functions.md`**
The object/string branch is commented out in `caf9138`, leaving only:
```bash
echo "$1" | jq '.'"$2"' += {"'"$3"'":'"$4"'}'
```
This always inserts the value **unquoted** (object syntax). Verified: `_json_add_key_with_value "{}" "" "toto" "tutu"` → jq error `tutu/0 is not defined`, ret=3. But `functions.md` documents "if the value starts with `{` → object, otherwise → string". Either restore the branch (and fix `_startswith`, see A4) or update `functions.md` — currently code and docs disagree, and plain-string callers silently break.

> **STATUS: FIXED (docs updated to match code)** — see commit in this session; `functions.md` now documents the value as a raw JSON literal.

**A4. `_startswith` breaks when `IFS=''`** — line ~577
```bash
echo "$__str" | $GREP "^$__sub" >/dev/null 2>&1
```
`$GREP` = `/usr/bin/grep --text` depends on **word splitting**, so with `IFS=''` (exactly what the JSON tests set) it returns `127`, not `0/1`. Verified. Pure-bash fix is also faster: `[[ "$1" == "$2"* ]]`.

**A5. `_epoch_2_date` silently returns 0 with garbage** — `_epoch_2_date "123"` → `date: invalid date '@.123'`, ret=0. No input-length validation.

**A6. `_int2ip` silently wraps out-of-range ints** — the `> 4294967295` check is commented out; `_int2ip "9999999999999"` → `78.114.159.255` (wrapped), ret=0.

**A7. `_decode_url` leaks the global `j`** — `j` is never `local`. Verified pollution after a call. Fix: `local j`.

---

## ⚡ B. Performance (eliminate subprocesses — all bash 5 builtins)

| Function | Current (subprocess) | Builtin alternative |
|---|---|---|
| `_date` | `date '+%Y-%m-%d %H:%M:%S'` | `printf '%(%Y-%m-%d %H:%M:%S)T' -1` |
| `_upper` / `_lower` | `echo \| tr ...` | `${var^^}` / `${var,,}` |
| `_remove_last_car` | `echo \| sed` | `${var%?}` |
| `_startswith` | `echo \| grep` | `[[ "$1" == "$2"* ]]` |
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
4. **Dead code** — the commented-out `_startswith "$4" "{"` branch in `_json_add_key_with_value` (and the commented `-gt 4294967295` check in `_int2ip`) should be either restored or removed.
5. **`_array_count_elt` checks `_exist "$@"`** — should be `_exist "$1"` (currently any empty arg trips it).

---

## 🩹 D. Minor / style

- `_array_*` functions juggle global `IFS=''` with save/restore — `local IFS` scoping is cleaner and safer.
- `_working_dir_count_*` / `_gen_rand` / `_gen_pin` — multi-command pipelines (`find|wc|xargs`, `tr|fold|paste|head`). Functionally fine; only worth touching if these are hot.
- `_tmp_file` calls `basename "$0"` — a subprocess, but only on `_tmp_file` calls (rare).

---

## Recommended order

1. **Fix the bugs (A1–A7)** — A2 and A4 are silent-validation failures; A3 is a live doc/code drift.
2. **`_log` reorder + `$EPOCHREALTIME` + `_timediff` param expansion (B1/B2)** — measurable speedup on every instrumented call.
3. **Builtin replacements (B table)** — mechanical, low risk, and `_startswith`'s rewrite also fixes A4.
4. **DRY refactors (C)** — worth doing with the existing tests as a safety net (currently 156 tests + 99.57% coverage on this file).
