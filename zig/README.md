# A Blazing Fast Sudoku Solver
High-performance Sudoku solver written in Zig, designed for competitive speed. It can solve hundreds of thousands of the most difficult Sudoku puzzles under a second.

This is not a typical backtracking solver. It uses a highly optimized, bitmask-based core combined with an advanced search algorithm that operates on pre-computed patterns rather than individual cells. The result is a solver that is exceptionally fast, particularly on puzzles that would stall conventional algorithms.

## Features

- High-Performance Core: The entire logic relies on bitwise operations on integers to represent the board and its constraints, making it incredibly fast.
- Advanced Search Algorithm: Implements a specialized form of Algorithm X (Exact Cover) that decomposes the board into "bands" and finds solutions by fitting pre-computed patterns together.
- Massive Compile-Time Pre-computation: All complex constraint-checking and pattern generation is handled at compile time, leaving only the fastest operations for runtime.
- Efficient Logical Solver: Before searching, a powerful constraint propagation engine solves for "Naked Singles" and "Hidden Singles" recursively, finishing easy puzzles without ever needing the search algorithm.
- Parallel Processing: Built to tear through large datasets, it uses a dynamic work-stealing model to distribute puzzles across all available CPU cores for maximum throughput.
- Written in Zig: Leverages the Zig programming language for low-level control, performance, and compile-time execution.

# The Core Strategy: Beyond Backtracking

For a Sudoku enthusiast, the magic of this solver is that it doesn't "guess" by placing numbers in cells one-by-one. That's slow. Instead, it thinks about the puzzle on a much higher level.

## Thinking in Patterns, Not Cells

Imagine you have to place all nine '1's on the board, then all nine '2's, and so on. This solver's goal is to find a complete "placement pattern" for each digit that is compatible with the patterns of all other digits.

To do this, it first breaks the 9x9 board into three horizontal Bands:

- **Top Band**: Rows 1, 2, 3
- **Middle Band**: Rows 4, 5, 6
- **Bottom Band**: Rows 7, 8, 9

For any given digit (say, a '5'), there are only a fixed number of ways it can be placed in a band without clashing with itself (one '5' per row, one '5' per 3x3 box). This solver calculates all 162 of these valid "band patterns" before it even starts solving.

## A Two-Dimensional Puzzle

The solver's job is to pick the right patterns for each digit. This becomes a fascinating two-dimensional puzzle:

1. **The Vertical Fit (Placing one Digit)**

    When placing the '5's, the solver must choose one pattern for the top band, one for the middle, and one for the bottom. These three patterns must fit together vertically like puzzle pieces, meaning they can't use the same column. The solver intelligently picks three patterns that are a perfect column-wise match.

2. **The Horizontal Fit (Placing all Digits)**

    Once the solver finds a valid placement for all the '5's, it moves on to the next digit, say '8'. Here's the key: it already knows exactly which cells in each band are occupied by '5's. So, when choosing patterns for the '8's, it will only consider patterns that use empty cells. This massively constrains the search.

This process repeats. Each placed digit's pattern becomes a constraint that simplifies the puzzle for the next, until a full, valid solution is found.

# Technical Deep Dive

For the technically-minded, this solver combines several high-performance computing techniques.

## Data Representation

The state of the board and its constraints are stored entirely in bitmasks.

- `digit_candidate_cells: [9]u128`: An array where each `u128` bitmask represents the 81 cells of the board. The n-th bit is '1' if the digit can potentially be placed in that cell.
- `pending_digit_houses: [9]usize`: A bitmask tracking which "houses" (rows, columns, boxes) still need a given digit to be placed.

All constraint propagation is done through bitwise `AND`, `OR`, `XOR`, and `NOT` operations on these integers, which is orders of magnitude faster than object- or array-based approaches.

## Compile-Time Pre-computation (`constants.zig`)

The solver's speed is heavily reliant on work done at compile-time via Zig's `comptime` feature. The most complex logic is pre-calculated and baked into the executable as static lookup tables.

- `VALID_BAND_CELLS: [162]usize`: An array containing all 162 valid placement patterns for a single digit within one 3x9 horizontal band.
- `DIGIT_COMPATIBLE_BANDS: [162]u192`: A lookup table for intra-band compatibility. For a given band pattern `P`, `DIGIT_COMPATIBLE_BANDS[P]` is a bitmask of all other patterns in `VALID_BAND_CELLS` that do not share any cells with `P`. This is used to find valid placements for different digits within the same band. The check is `(pattern1 & pattern2 == 0)`.
- `BOARD_COMPATIBLE_BANDS: [162]u192`: A lookup table for inter-band compatibility. It determines if two patterns can be used for the same digit in different bands. This is done by checking if their column occupancies are disjoint. The check is `(column_mask(p1) & column_mask(p2) == 0)`.

## `find_valid_bands`: Algorithm X on a Higher Level

The core `find_valid_bands` function is a recursive backtracking search that effectively solves an Exact Cover problem.

- **Items**: The 9 digits to be placed.
- **Sets**: The collection of valid board-level placements for each digit.

The nested loops iterate through the pre-computed and pre-filtered patterns, pruning the search space aggressively. The `new_reduced_bands` variable passed during recursion carries the successively smaller set of valid patterns, a direct result of the two-dimensional pruning strategy.

## Parallelization (`main.zig`)

To solve large files of puzzles, the solver creates a thread for each available CPU core. A simple but robust dynamic work-stealing model is used to ensure efficient load balancing.

- A global atomic counter `next_thread_index` tracks the next batch of puzzles to solve.
- When a thread finishes its current batch, it atomically increments this counter to claim the next batch.
- This prevents threads from sitting idle if they happen to finish an easy batch of puzzles early. All I/O is done on pre-allocated buffers to minimize overhead.

# How to Build and Run

## Requirements
- The Zig Compiler (developed on version 0.14.1 or newer)

## Build

To build the optimized executable:
```sh
zig build-exe -O ReleaseFast main.zig
```

## Usage

Run the solver by passing a filename as an argument. The file should contain one 81-character Sudoku puzzle per line, using '0' for empty cells. The output will be the puzzles and solutions, printed to standard output.

```sh
time ./main ../test-data/debug.sudokus > ../test-data/debug.solved
time ./main ../test-data/serg_benchmark.sudokus > ../test-data/serg_benchmark.solved
time ./main ../test-data/forum_hardest_1106.sudokus > ../test-data/forum_hardest_1106.solved
time ./main ../test-data/all_17_clue.sudokus > ../test-data/all_17_clue.solved
```

# Code Structure

- `main.zig`: Handles file I/O, command-line parsing, and the parallel distribution of work to solver threads.
- `sudoku.zig`: The heart of the solver. Contains the Sudoku struct and the core solve function, which implements the logical constraint propagation and the find_valid_bands search algorithm.
- `constants.zig`: Contains all the compile-time logic to generate the pattern and compatibility lookup tables that make the solver so fast.