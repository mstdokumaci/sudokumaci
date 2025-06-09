# Zig Sudoku Solver

This is an extremely high-performance Sudoku solver written in Zig. It is designed from the ground up to minimize traditional backtracking search by using a powerful, table-driven deductive engine. The solver leverages extensive compile-time precomputation and a sophisticated pattern-based approach to solve even the most difficult puzzles with remarkable speed.

## High-Level Strategy

The core philosophy of Sudokumaci is to treat Sudoku not as a search problem, but as a pure constraint propagation problem. The goal is to define the rules and structure of Sudoku so completely in precomputed lookup tables that the solution can be found by continuously applying these rules to narrow down possibilities until the final state is reached.

The solver operates on a novel concept of **"Band Patterns"**. A Sudoku board is divided into three 3x9 "bands" (rows 0-2, 3-5, 6-8). A "band pattern" is a valid placement of a single digit within one of these bands—meaning its three instances are in different rows, columns, and 3x3 boxes within that band.

1.  **Deductive Propagation Engine**: This stage uses a powerful set of rules to eliminate impossible candidates from the grid. It iteratively applies these rules until no more deductions can be made. This engine is so effective that it can fully solve many hard puzzles on its own.
2.  **Pattern-Based Search**: If the puzzle is not fully solved by propagation, a highly optimized backtracking search begins. Instead of guessing one cell at a time, it finds a valid placement for an entire digit by selecting a valid combination of three compatible band patterns.

This strategy ensures that the search phase is only used as a last resort and operates on a massively constrained problem space, making it incredibly fast.

## Technical Details

The solver's performance is achieved through a combination of efficient data representation, massive compile-time precomputation, and a synergistic solving pipeline.

### Data Representation

The entire state of the Sudoku grid is stored in **bitboards**.

- `digit_candidate_cells: [9]u128`: An array where each `u128` represents the 81 cells of the board. A bit at position `i` is set if that cell is a possible candidate for the digit corresponding to the array index.
- This structure allows for extremely fast logical operations (AND, OR, NOT) to manipulate candidate sets, which are executed with single CPU instructions.

### Compile-Time Precomputation 🧠

The heart of the solver is a set of large lookup tables generated at compile time (`comptime`) using Zig's powerful metaprogramming capabilities. This offloads an immense amount of logical calculation from runtime to compile time.

- `VALID_BAND_CELLS: [162]usize`: The fundamental building blocks. This table contains the 162 unique, valid ways a single digit can be placed within one 3x9 band.
- `ROW_BANDS: [3][512]u192`: An accelerator for the **search engine**. It maps a 9-bit row candidate mask to a `u192` bitmask of all `VALID_BAND_CELLS` patterns compatible with it. This allows the search to instantly filter its options instead of checking them one by one.
- `ROW_BANDS_UNION: [3][512]usize`: An accelerator for the **propagation engine**. It maps a 9-bit row candidate mask to the bitwise `OR` union of all compatible `VALID_BAND_CELLS` patterns. This is key for the advanced consistency check.
- `DIGIT_COMPATIBLE_BANDS` & `BOARD_COMPATIBLE_BANDS`: These `[162]u192` tables store compatibility information between pairs of band patterns, used to prune the search tree aggressively.

### Solver Steps

#### **Step 1: The Propagation Engine (`clear_for_placements`)**

This is an iterative engine that runs until the puzzle state is completely stable. It applies two main techniques in a cycle:

1.  **Singles Detection**: Finds and places Naked and Hidden Singles using standard bitboard operations. This handles the most direct deductions.
2.  **Band-Pattern Consistency**: This is the solver's most advanced deductive rule.
    - It uses the `ROW_BANDS_UNION` table to calculate the union of all cells that are part of any valid band pattern for a given digit.
    - It then intersects this union with the current candidates for that digit. Any candidate that is not part of this union is provably impossible and is eliminated.
    - **Performance Heuristic**: This powerful check is only activated when a digit's candidate count drops below 30 (`if (candidate_locations_count < 30)`), focusing its power where it's most effective and avoiding wasted computation on wide-open grids.

#### **Step 2: The Search Engine (`find_valid_bands`)**

If propagation cannot fully solve the puzzle, the search engine is activated. This is a highly optimized backtracking algorithm.

1.  **Select Digit**: It chooses the most constrained digit (fewest remaining candidates) to place next.
2.  **Pre-filter Patterns**: Using the `ROW_BANDS` table, it instantly determines the complete set of valid band patterns for the chosen digit without any looping.
3.  **Find Combination**: It searches for a combination of three mutually compatible patterns (one for each band) from this pre-filtered set. Compatibility is checked using the `BOARD_COMPATIBLE_BANDS` and `DIGIT_COMPATIBLE_BANDS` tables.
4.  **Place & Recurse**: Once a valid combination is found, it tentatively places the 9 instances of the digit and makes a recursive call. If that path fails, it backtracks and tries the next combination. Because the set of patterns is so heavily pruned beforehand, this search is incredibly efficient.

### Concurrency Model

The solver is fully multithreaded to process large files of puzzles in parallel. It uses a simple but effective **work-stealing** model where each thread processes puzzles in batches and atomically claims a new batch when it finishes, ensuring all CPU cores remain fully utilized.

## How to Build and Run

### Requirements
- The Zig Compiler (developed on version 0.14.1 or newer)

### Build

To build the optimized executable:

```sh
zig build-exe -O ReleaseFast main.zig
```

### Usage

Run the solver by passing a filename as an argument. The file should contain one 81-character Sudoku puzzle per line, using '0' for empty cells. The output will be the puzzles and solutions, printed to standard output.

```sh
time ./main ../test-data/debug.sudokus > ../test-data/debug.solved
time ./main ../test-data/serg_benchmark.sudokus > ../test-data/serg_benchmark.solved
time ./main ../test-data/forum_hardest_1106.sudokus > ../test-data/forum_hardest_1106.solved
time ./main ../test-data/all_17_clue.sudokus > ../test-data/all_17_clue.solved
```
