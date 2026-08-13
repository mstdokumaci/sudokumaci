#!/usr/bin/env bash
# Interleaved paired A/B benchmark.
# Usage: ab_bench.sh <binA> <binB> <rounds> <dataset...>
# Runs A and B alternately per pair (order swaps each pair to cancel drift),
# reports the median of per-pair after/before ratios.
set -euo pipefail

BIN_A="$1"; BIN_B="$2"; ROUNDS="$3"; shift 3
OUT_DIR="${OUT_DIR:-benchmark/results}"
# Default: all threads. Pass THREADS="-j 1" when comparing against tdoku (single-threaded).
THREADS="${THREADS:-}"

[[ -x "$BIN_A" ]] || { echo "error: $BIN_A not executable" >&2; exit 1; }
[[ -x "$BIN_B" ]] || { echo "error: $BIN_B not executable" >&2; exit 1; }

mkdir -p "$OUT_DIR"

main_pps() { sed -n 's/.*puzzles\/sec: \([0-9][0-9.]*\).*/\1/p'; }

median() { sort -n | awk '{a[NR]=$1} END{print (NR%2)?a[(NR+1)/2]:(a[NR/2]+a[NR/2+1])/2}'; }

run_once() { # $1 = bin, $2 = dataset
    "$1" --bench $THREADS "$2" 2>&1 | main_pps
}

cpu_info() {
    echo "$(sysctl -n machdep.cpu.brand_string 2>/dev/null || echo unknown) | $(sysctl -n hw.logicalcpu 2>/dev/null || echo "?") logical cpus"
}

{
echo "# Paired A/B - $(date) - $(cpu_info)"
echo
echo "Threads: ${THREADS:-default} | rounds: $ROUNDS | per-pair ratios (after/before), median"
echo
for f in "$@"; do
    ds=$(basename "$f")
    a_vals=(); b_vals=(); ratios=()
    for ((i = 1; i <= ROUNDS; i++)); do
        if (( i % 2 == 1 )); then
            a=$("$BIN_A" --bench $THREADS "$f" 2>&1 | main_pps)
            b=$("$BIN_B" --bench $THREADS "$f" 2>&1 | main_pps)
        else
            b=$("$BIN_B" --bench $THREADS "$f" 2>&1 | main_pps)
            a=$("$BIN_A" --bench $THREADS "$f" 2>&1 | main_pps)
        fi
        [[ -n "$a" && -n "$b" ]] || { echo "error: empty run in round $i for $ds" >&2; exit 1; }
        a_vals+=("$a"); b_vals+=("$b")
        ratios+=("$(awk -v x="$b" -v y="$a" 'BEGIN{printf "%.4f", x / y}')")
    done
    med_a=$(printf '%s\n' "${a_vals[@]}" | median)
    med_b=$(printf '%s\n' "${b_vals[@]}" | median)
    med_r=$(printf '%s\n' "${ratios[@]}" | median)
    delta=$(awk -v r="$med_r" 'BEGIN{printf "%.1f", (r - 1) * 100}')
    echo "$ds"
    echo "  per-pair ratios: ${ratios[*]}"
    echo "  median: before=$med_a after=$med_b ratio=$med_r delta=$delta%"
done
} | tee "$OUT_DIR/ab_paired.md"
