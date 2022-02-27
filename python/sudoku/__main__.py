import os
import sys

from sudoku.sudoku import solve

if len(sys.argv) == 2:
    filename = sys.argv[1]

    with open(
        os.path.join(os.getcwd(), filename),
        "r",
    ) as file:
        sudokus = tuple(line.strip() for line in file if line.strip())
        sys.stdout.write("\n".join(f"{puzzle},{solve(puzzle)}" for puzzle in sudokus))
else:
    print("Usage: pipenv run python -m sudoku <filename>")
