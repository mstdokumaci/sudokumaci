# Sudokumaci - Zig Sudoku Solver

A Sudoku solver that solves ~1.3 million puzzles per second on modern hardware (multi-threaded; ~150,000 single-threaded). Most solvers guess one cell at a time. This one places whole digits at once, using precomputed band patterns.

## Core Idea

Traditional solvers ask: *"What digit goes in this cell?"*

This solver asks: *"Where do all 9 instances of this digit go?"*

Within a 3-row band, one digit has exactly 162 valid placements: one in each row, one in each box, with distinct columns across the band. All of them are precomputed at compile time, so solving is a search over compatible band patterns instead of a per-cell guess.

## Constraint Propagation

After each placement, three rules prune candidates:

- **Naked singles**: a cell with one candidate left takes that digit.
- **Hidden singles**: a digit with only one possible cell in a house takes it.
- **Box-line reduction**: a digit confined to one row/col of a box is eliminated from that row/col in other boxes.

## Band-Pattern Search

When propagation stalls, the solver picks the most constrained digit and searches for its placement: three band patterns, one per band. Two precomputed tables prune the search:

- `PATTERNS_FOR_OTHER_DIGITS`: patterns that share no cells, for two digits in the same band
- `PATTERNS_FOR_SAME_DIGIT`: patterns with disjoint column sets, for one digit across the three bands

Failed combinations backtrack to the next candidate.

## Data Structures: Bitboards

Each digit keeps a u128 candidate mask, one bit per cell.

- Eliminate a digit from 20 peers? One AND: `candidates &= ~peer_mask`
- Count candidates? One instruction: `@popCount(candidates)`
- Find the first candidate? One instruction: `@ctz(candidates)`

## Compile-Time Precomputation

All lookup tables are generated at compile time using Zig's `comptime`:

| Table | Size | Purpose |
|-------|------|---------|
| `VALID_BAND_CELLS[162]` | 162 patterns | All valid digit placements in a band |
| `ROW_BANDS[3][512]` | 3×512 entries | Row mask → compatible band patterns |
| `ROW_REDUCTION_PATTERNS[9][512]` | 9×512 entries | Row mask → applicable reductions |
| `PATTERNS_FOR_OTHER_DIGITS[162]` | 162 bitmasks | Pattern → non-overlapping patterns |
| `PATTERNS_FOR_SAME_DIGIT[162]` | 162 bitmasks | Pattern → column-compatible patterns |

No runtime work goes into building these tables.

## Concurrency

Threads claim puzzles in batches from one shared atomic counter. The thread that finishes its batch first claims the next one; there is no coordination between workers. Simpler than work-stealing: all unclaimed work lives in a single pool.

## Performance

Measured on a 2.3 GHz Intel Core i9-9880H (16 logical CPUs), ReleaseFast build, solving `test-data/all_17_clue.sudokus` (49,151 17-clue puzzles).

Benchmark method matches tdoku: five untimed warmup passes, then one timed pass.

| Metric | 1 thread | All threads |
|--------|----------|-------------|
| Puzzles/second | ~148,000 | ~1,360,000 |
| Time per puzzle | ~6.7µs | ~0.73µs |
| Wall time | ~330ms | ~36ms |

## Build & Run

### Requirements
- Zig 0.15.x

### Build
```bash
# -lc required on Linux (std.heap.c_allocator); harmless on macOS
zig build-exe -O ReleaseFast -mcpu=native -lc main.zig
```

### Usage
```bash
# Solve puzzles from file (one 81-char puzzle per line, '0' for empty cells)
./main puzzles.txt > solutions.txt

# Limit worker threads (default: one per CPU)
./main -j 1 puzzles.txt

# Benchmark mode: five untimed warmup passes, then a timed pass; prints puzzles/sec to stderr
./main --bench [-j N] puzzles.txt

# Benchmark
time ./main test-data/all_17_clue.sudokus > test-data/all_17_clue.solved
```

### Benchmark

GitHub Actions runs this automatically on pushes/PRs touching solver code (see `.github/workflows/benchmark.yml`):

- `benchmark-macos` (macos-15-intel): sudokumaci vs [tdoku](https://github.com/t-dillon/tdoku). tdoku is x86-only, and its Linux builds return wrong solutions on some puzzles (upstream bug), so it only runs on Intel macOS where it is correct.
- `benchmark-linux-arm` (ubuntu-24.04-arm): sudokumaci-only on ARM64.

To run locally:

```bash
# sudokumaci only
bash benchmark/scripts/benchmark.sh

# sudokumaci vs tdoku (build tdoku once: git clone https://github.com/t-dillon/tdoku && cd tdoku && ./BUILD.sh)
TDOKU_BENCH=/path/to/tdoku/build/run_benchmark bash benchmark/scripts/benchmark.sh
```

### Input Format
```
000000010400000000020000000000050407008000300001090000300400200050100000000806000
005300000800000020070010500400005300010070006003200080060500009004000030000009700
...
```

### Output Format
```
000000010400000000020000000000050407008000300001090000300400200050100000000806000,693784512487512936125963874932651487568247391741398625319475268856129743274836159
005300000800000020070010500400005300010070006003200080060500009004000030000009700,145327698839654127672918543496185372218473956753296481367542819984761235521839764
...
```

## Why This Approach?

| Aspect | Traditional Backtracking | Band-Pattern Search |
|--------|-------------------------|---------------------|
| Branching factor | Up to 9 per cell | ~tens per digit |
| Decisions per puzzle | Up to 81 | Up to 9 |
| Constraint checking | Per-cell validation | Pre-filtered by tables |
| Cache efficiency | Random cell access | Sequential table lookups |

Searching by digit instead of by cell cuts decisions per puzzle from up to 81 to up to 9, and the compatibility tables filter the options before the search runs.
