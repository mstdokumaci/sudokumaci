# Build

```sh
zig build-exe -O ReleaseFast main.zig
```

# Run

```sh
time ./main ../test-data/debug.sudokus > ../test-data/debug.solved
time ./main ../test-data/serg_benchmark.sudokus > ../test-data/serg_benchmark.solved
time ./main ../test-data/forum_hardest_1106.sudokus > ../test-data/forum_hardest_1106.solved
time ./main ../test-data/all_17_clue.sudokus > ../test-data/all_17_clue.solved
```
