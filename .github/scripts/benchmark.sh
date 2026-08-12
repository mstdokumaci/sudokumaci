#!/usr/bin/env bash
# Benchmark sudokumaci vs tdoku (t-dillon/tdoku) on the test-data sets.
# Informational only: always exits 0 unless a solver fails or solutions are wrong.
set -euo pipefail

MAIN_BIN="${MAIN_BIN:-./main}"
TDOKU_BENCH="${TDOKU_BENCH:-tdoku/build/run_benchmark}"
SUDOKU_RUNS="${SUDOKU_RUNS:-5}"
TDOKU_RUNS="${TDOKU_RUNS:-3}"
OUT_DIR="${OUT_DIR:-bench-results}"

mkdir -p "$OUT_DIR"
SUMMARY="$OUT_DIR/results.md"

for bin in "$MAIN_BIN" "$TDOKU_BENCH"; do
    [[ -x "$bin" ]] || { echo "error: $bin not executable (set MAIN_BIN/TDOKU_BENCH)" >&2; exit 1; }
done

DATASETS=(all_17_clue.sudokus serg_benchmark.sudokus forum_hardest_1106.sudokus)
DATA_DIR="test-data"

# Pin to one CPU where taskset exists (Linux CI); no-op on macOS.
PIN=()
if command -v taskset >/dev/null && taskset -c 0 true 2>/dev/null; then
    PIN=(taskset -c 0)
fi

main_pps() { sed -n 's/.*puzzles\/sec: \([0-9][0-9.]*\).*/\1/p'; }
min_float() { awk 'NR==1{min=$1} $1<min{min=$1} END{print min}'; }

# tdoku CSV: compiler,version,flags,file,solver,puzzles/sec,usec,pct_no_guess,guesses
tdoku_pps() { awk -F',' 'NF>=6 && $6 ~ /^[0-9.]+$/ {v=$6} END {print v}'; }

validate() { # $1 = puzzle,solution file
    python3 - "$1" <<'PY'
import sys
bad = n = 0
for lineno, line in enumerate(open(sys.argv[1]), 1):
    line = line.strip()
    if not line:
        continue
    n += 1
    try:
        p, s = line.split(',')
    except ValueError:
        print(f"line {lineno}: not puzzle,solution"); bad += 1; continue
    if len(p) != 81 or len(s) != 81 or any(c not in '123456789' for c in s):
        print(f"line {lineno}: bad length or chars"); bad += 1; continue
    if any(p[i] != '0' and p[i] != s[i] for i in range(81)):
        print(f"line {lineno}: contradicts givens"); bad += 1; continue
    rows_ok = all(len({s[r * 9 + c] for c in range(9)}) == 9 for r in range(9))
    cols_ok = all(len({s[r * 9 + c] for r in range(9)}) == 9 for c in range(9))
    boxes_ok = all(len({s[(b // 3) * 27 + (b % 3) * 3 + r * 9 + c]
                       for r in range(3) for c in range(3)}) == 9 for b in range(9))
    if not (rows_ok and cols_ok and boxes_ok):
        print(f"line {lineno}: row/col/box violation"); bad += 1
print(f"validated {n} solutions, {bad} invalid")
sys.exit(1 if bad else 0)
PY
}

run_main() { # extra args appended after --bench
    local min_pps="" pps i
    for i in $(seq 1 "$SUDOKU_RUNS"); do
        pps=$(${PIN[@]+"${PIN[@]}"} "$MAIN_BIN" --bench "$@" "$f" 2>&1 | main_pps)
        min_pps=$(printf '%s\n%s\n' "${min_pps:-$pps}" "$pps" | min_float)
    done
    printf '%s' "$min_pps"
}

run_tdoku() {
    local min_pps="" pps i rc out
    for i in $(seq 1 "$TDOKU_RUNS"); do
        out=$(mktemp)
        rc=0
        "$TDOKU_BENCH" -s tdoku -r 0 -n "$puzzle_count" -v 1 -c 1 -w 2 -t 5 "$f" >"$out" 2>&1 || rc=$?
        pps=$(tdoku_pps <"$out")
        if [[ -z "$pps" ]]; then
            echo "tdoku run $i failed (exit $rc):" >&2
            tail -15 "$out" >&2
            rm -f "$out"
            exit 1
        fi
        rm -f "$out"
        min_pps=$(printf '%s\n%s\n' "${min_pps:-$pps}" "$pps" | min_float)
    done
    printf '%s' "$min_pps"
}

fmt() { awk -v x="$1" 'BEGIN{printf "%.0f", x}'; }

{
    echo "# Benchmark: sudokumaci vs tdoku"
    echo
    echo "Runner: $(uname -sm)"
    echo
    echo "| dataset | solver | config | puzzles/sec | ratio vs tdoku |"
    echo "|---|---|---|---|---|"
    for ds in "${DATASETS[@]}"; do
        f="$DATA_DIR/$ds"
        puzzle_count=$(wc -l < "$f")
        tdoku_pps=$(run_tdoku)
        j1_pps=$(run_main -j 1)
        def_pps=$(run_main)
        ratio=$(awk -v a="$tdoku_pps" -v b="$j1_pps" 'BEGIN{printf "%.2f", a / b}')
        echo "| $ds | tdoku | 1 thread | $(fmt "$tdoku_pps") | - |"
        echo "| $ds | sudokumaci | -j 1 | $(fmt "$j1_pps") | ${ratio}x |"
        echo "| $ds | sudokumaci | default threads | $(fmt "$def_pps") | - |"

        "$MAIN_BIN" "$f" > "$OUT_DIR/$ds.solved"
        validate "$OUT_DIR/$ds.solved"
    done
} | tee "$SUMMARY"

if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
    cat "$SUMMARY" >> "$GITHUB_STEP_SUMMARY"
fi
