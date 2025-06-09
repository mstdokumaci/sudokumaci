# Zig Sudoku Solver

This is an extremely high-performance Sudoku solver written in Zig. It is designed from the ground up to minimize traditional backtracking search by using a powerful, table-driven deductive engine. The solver leverages extensive compile-time precomputation and a sophisticated pattern-based approach to solve even the most difficult puzzles with remarkable speed.

## High-Level Strategy

The core philosophy of Sudokumaci is to treat Sudoku not as a search problem, but as a pure constraint propagation problem. The goal is to define the rules and structure of Sudoku so completely in precomputed lookup tables that the solution can be found by continuously applying these rules to narrow down possibilities until the final state is reached.

The solver operates on a novel concept of **"Band Patterns"**. A Sudoku board is divided into three 3x9 "bands" (rows 0-2, 3-5, 6-8). A "band pattern" is a valid placement of a single digit within one of these bands—meaning its three instances are in different rows, columns, and 3x3 boxes within that band.

The entire solving process can be visualized as a two-stage pipeline:

<details>
<summary>📈 Show High-Level Flowchart</summary>

```svg
<svg width="640" height="140" xmlns="[http://www.w3.org/2000/svg](http://www.w3.org/2000/svg)" font-family="monospace" font-size="14px">
    <style>
        .box { fill: #1a1a1a; stroke: #888; stroke-width: 1.5; rx: 5; }
        .arrow { fill: none; stroke: #4e8; stroke-width: 2; marker-end: url(#arrowhead); }
        .text { fill: #eee; text-anchor: middle; dominant-baseline: middle; }
        .subtext { fill: #999; text-anchor: middle; dominant-baseline: middle; font-size: 11px;}
    </style>
    <defs>
        <marker id="arrowhead" viewBox="0 0 10 10" refX="5" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse">
            <path d="M 0 0 L 10 5 L 0 10 z" fill="#4e8" />
        </marker>
    </defs>
    <rect x="10" y="40" width="120" height="60" class="box"/>
    <text x="70" y="70" class="text">Puzzle Input</text>
    <rect x="180" y="40" width="120" height="60" class="box"/>
    <text x="240" y="62" class="text">Propagation</text>
    <text x="240" y="82" class="subtext">(Deduction)</text>
    <rect x="350" y="40" width="120" height="60" class="box"/>
    <text x="410" y="62" class="text">Search</text>
    <text x="410" y="82" class="subtext">(If Needed)</text>
    <rect x="510" y="40" width="120" height="60" class="box"/>
    <text x="570" y="70" class="text">Solved Grid</text>
    <path d="M 130 70 H 170" class="arrow"/>
    <path d="M 300 70 H 340" class="arrow"/>
    <path d="M 470 70 H 500" class="arrow"/>
</svg>
```
</details>

1.  **Deductive Propagation Engine**: This stage uses a powerful set of rules to eliminate impossible candidates from the grid. It iteratively applies these rules until no more deductions can be made. This engine is so effective that it can fully solve many hard puzzles on its own.
2.  **Pattern-Based Search**: If the puzzle is not fully solved by propagation, a highly optimized backtracking search begins. Instead of guessing one cell at a time, it finds a valid placement for an entire digit by selecting a valid combination of three compatible band patterns.

This strategy ensures that the search phase is only used as a last resort and operates on a massively constrained problem space, making it incredibly fast.

***

## Technical Details

The solver's performance is achieved through a combination of efficient data representation, massive compile-time precomputation, and a synergistic solving pipeline.

### Data Representation

The entire state of the Sudoku grid is stored in **bitboards**.

* `digit_candidate_cells: [9]u128`: An array where each `u128` represents the 81 cells of the board. A bit at position `i` is set if that cell is a possible candidate for the digit corresponding to the array index.
* This structure allows for extremely fast logical operations (AND, OR, NOT) to manipulate candidate sets, which are executed with single CPU instructions.

### Compile-Time Precomputation 🧠

The heart of the solver is a set of large lookup tables generated at compile time (`comptime`) using Zig's powerful metaprogramming capabilities. This offloads an immense amount of logical calculation from runtime to compile time.

* `VALID_BAND_CELLS: [162]usize`: The fundamental building blocks. This table contains the 162 unique, valid ways a single digit can be placed within one 3x9 band.
* `ROW_BANDS: [3][512]u192`: An accelerator for the **search engine**. It maps a 9-bit row candidate mask to a `u192` bitmask of all `VALID_BAND_CELLS` patterns compatible with it. This allows the search to instantly filter its options instead of checking them one by one.
* `ROW_BANDS_UNION: [3][512]usize`: An accelerator for the **propagation engine**. It maps a 9-bit row candidate mask to the bitwise `OR` union of all compatible `VALID_BAND_CELLS` patterns. This is key for the advanced consistency check.
* `DIGIT_COMPATIBLE_BANDS` & `BOARD_COMPATIBLE_BANDS`: These `[162]u192` tables store compatibility information between pairs of band patterns, used to prune the search tree aggressively.

### The Solving Pipeline ⚙️

The solver uses a synergistic pipeline where the propagation and search engines feed into each other, creating a virtuous cycle.

<details>
<summary>🔧 Show Detailed Pipeline Diagram</summary>

```svg
<svg width="600" height="300" xmlns="[http://www.w3.org/2000/svg](http://www.w3.org/2000/svg)" font-family="monospace" font-size="14px">
    <style>
        .box { fill: #1a1a1a; stroke: #888; stroke-width: 1.5; rx: 5; }
        .prop_box { fill: #2a2a20; stroke: #b8860b; stroke-width: 1; rx: 3;}
        .search_box { fill: #1a2a1a; stroke: #4e8; stroke-width: 1; rx: 3;}
        .arrow { fill: none; stroke: #999; stroke-width: 2; marker-end: url(#arrowhead); }
        .arrow_strong { fill: none; stroke: #4e8; stroke-width: 2; marker-end: url(#arrowhead_strong); }
        .arrow_feedback { fill: none; stroke: #ff6347; stroke-width: 2; marker-end: url(#arrowhead_feedback); }
        .text { fill: #eee; text-anchor: middle; dominant-baseline: middle; }
        .subtext { fill: #999; text-anchor: middle; dominant-baseline: middle; font-size: 11px;}
        .title { fill: #ccc; text-anchor: middle; font-size: 16px; font-weight: bold;}
    </style>
    <defs>
        <marker id="arrowhead" viewBox="0 0 10 10" refX="5" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse"><path d="M 0 0 L 10 5 L 0 10 z" fill="#999" /></marker>
        <marker id="arrowhead_strong" viewBox="0 0 10 10" refX="5" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse"><path d="M 0 0 L 10 5 L 0 10 z" fill="#4e8" /></marker>
        <marker id="arrowhead_feedback" viewBox="0 0 10 10" refX="5" refY="5" markerWidth="6" markerHeight="6" orient="auto-start-reverse"><path d="M 0 0 L 10 5 L 0 10 z" fill="#ff6347" /></marker>
    </defs>

    <rect x="200" y="80" width="200" height="50" class="box"/>
    <text x="300" y="105" class="text">Candidate Bitboards</text>
    <text x="300" y="10" class="title">Solving Pipeline</text>

    <rect x="10" y="160" width="260" height="130" class="prop_box"/>
    <text x="140" y="175" class="text" style="fill: #d2b48c; font-weight: bold;">Propagation Engine</text>
    <text x="140" y="200" class="text">1. Singles (Naked/Hidden)</text>
    <text x="140" y="225" class="text">2. Band Consistency</text>
    <text x="140" y="250" class="subtext">(uses ROW_BANDS_UNION)</text>
    <text x="140" y="270" class="subtext">Heuristic: if popCount &lt; 30</text>

    <rect x="330" y="160" width="260" height="130" class="search_box"/>
    <text x="460" y="175" class="text" style="fill: #98fb98; font-weight: bold;">Search Engine</text>
    <text x="460" y="200" class="text">1. Select Digit (MCD)</text>
    <text x="460" y="225" class="text">2. Find Band Combo</text>
    <text x="460" y="250" class="subtext">(uses ROW_BANDS)</text>
    <text x="460" y="270" class="subtext">3. Place & Recurse</text>


    <path d="M 300 130 V 150" class="arrow"/>
    <path d="M 300 160 H 280" class="arrow"/>
    <path d="M 320 160 H 330" class="arrow"/>

    <path d="M 140 150 V 105 H 190" class="arrow_feedback"/>
    <text x="110" y="125" class="text" style="font-size:12px; fill:#ff6347;">Refine</text>

    <path d="M 460 290 V 320 H 140 V 290" class="arrow_strong" style="display:none;"/>
    <path d="M 460 290 c 0 40 -320 40 -320 0" class="arrow_strong" />
    <text x="300" y="315" class="text" style="font-size:12px; fill:#98fb98;">New Placement</text>
</svg>
```
</details>

#### **Step 1: The Propagation Engine (`clear_for_placements`)**

This is an iterative engine that runs until the puzzle state is completely stable. It applies two main techniques in a cycle:

1.  **Singles Detection**: Finds and places Naked and Hidden Singles using standard bitboard operations. This handles the most direct deductions.
2.  **Band-Pattern Consistency**: This is the solver's most advanced deductive rule.
    * It uses the `ROW_BANDS_UNION` table to calculate the union of all cells that are part of any valid band pattern for a given digit.
    * It then intersects this union with the current candidates for that digit. Any candidate that is not part of this union is provably impossible and is eliminated.
    * **Performance Heuristic**: This powerful check is only activated when a digit's candidate count drops below 30 (`if (candidate_locations_count < 30)`), focusing its power where it's most effective and avoiding wasted computation on wide-open grids.

#### **Step 2: The Search Engine (`find_valid_bands`)**

If propagation cannot fully solve the puzzle, the search engine is activated. This is a highly optimized backtracking algorithm.

1.  **Select Digit**: It chooses the most constrained digit (fewest remaining candidates) to place next.
2.  **Pre-filter Patterns**: Using the `ROW_BANDS` table, it instantly determines the complete set of valid band patterns for the chosen digit without any looping.
3.  **Find Combination**: It searches for a combination of three mutually compatible patterns (one for each band) from this pre-filtered set. Compatibility is checked using the `BOARD_COMPATIBLE_BANDS` and `DIGIT_COMPATIBLE_BANDS` tables.
4.  **Place & Recurse**: Once a valid combination is found, it tentatively places the 9 instances of the digit and makes a recursive call. If that path fails, it backtracks and tries the next combination. Because the set of patterns is so heavily pruned beforehand, this search is incredibly efficient.

### Concurrency Model

The solver is fully multithreaded to process large files of puzzles in parallel. It uses a simple but effective **work-stealing** model where each thread processes puzzles in batches and atomically claims a new batch when it finishes, ensuring all CPU cores remain fully utilized.

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
