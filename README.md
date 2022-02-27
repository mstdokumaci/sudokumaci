# sudokumaci

A sudoku solver algorithm mixing deduction/elimination strategies with brute force trial and error in an attempt of getting a very fast implementation that can solve any valid sudoku.

Implemented in Python, NodeJS, and Rust. Rust performs best thanks to threading and Python performs worst as expected.

## Rules

- A sudoku board consists of 81 cells in 27 groups: 9 rows, 9 columns, and 9 squares.
- Each cell belongs to 3 groups: 1 row, 1 column, and 1 cell.
- Each group has 9 cells and in those cells, can host every number from 1 to 9 once and only once.
- A sudoku puzzle comes with some of the cells prefilled with numbers (called **clues**), a solver has to fill the rest of the cells without breaking the rules.

## High-Level Strategy

- Find a list of possible candidates for each empty cell by eliminating clues in prefilled cells from every other cell in their groups.
- In every group, find exclusive subset combinations and eliminate the union of these cells from other cells in the group. For example, a row with no clues and there can be found 6 cells in this row that hosts only candidates from 1 to 6. In this case, we can eliminate numbers from 1 to 6 from 3 other cells in the group.
- If these eliminations lead to revealing exact values of some cells, repeat the above eliminations until nothing is left to be revealed.
- Find a cell with the least candidates and try placing each candidate as a value and solving the puzzle with that assumption.
- If the puzzle becomes unsolvable by the assumption, try another candidate. If the puzzle is valid sudoku, one of the candidates must work.

## Implementation Strategies

### Bitsets

When solving a sudoku puzzle, we have to maintain a state that consists of many sets:

- 81 sets of candidates, one for each cell
- 27 sets of unsolved cell positions for each group
- 27 sets of negative candidates (values of solved cells) for each group

By the rules, all of these sets are limited to a maximum of 9 items. This is a call for using a 9-bit integer, that can take any value from 0 to 511. This way, high-performing bitwise operators can be used for adding or removing a value to or from this set and iterating the items.

### Coordinate system

Cells are indexed from left to right and top to bottom. The upper left corner is 0 lower right corner is 80.

Groups are indexed in this order: rows, columns, and squares. The first row has an index of 0, the last 8. The first column has an index of 9, the last 17. The first square has an index of 18, the last 26.

We prepare 2 lookup tables for finding indexes easily:

1. A table for finding 3 couples of **group index** and **cell position in group** by a given **cell index**
2. A table for finding **cell index** by a given **group index** and **cell position in group**

Cell position in rows is column index and in columns row index. In squares, on the other hand, position increases from left to right and top to bottom.

### Subset Combinations as Bitsets

In order to find exclusive subsets per group, we need a list of all subsets for a given superset of unsolved cell positions. Let's say the bitset of unsolved positions for a row is `0b10101001`, which means positions 0, 3, 5, and 7 are unsolved. For this superset we need subsets `0b1001`, `0b100001`, `0b101000`, `0b101001`, `0b10000001`, `0b10001000`, `0b10001001`, `0b10100000`, `0b10100001`, and `0b10101000`. Single item and every item subsets are excluded because they don't help with elimination.

A lookup table for finding a list of subsets by a given superset is also used for performance.
