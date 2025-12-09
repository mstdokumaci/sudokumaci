const std = @import("std");
const AtomicOrder = std.builtin.AtomicOrder;
const AtomicRmwOp = std.builtin.AtomicRmwOp;
const Sudoku = @import("sudoku.zig").Sudoku;

// =============================================================================
// CONFIGURATION
// =============================================================================

/// Number of puzzles each thread processes before claiming more work
const BATCH_SIZE_LIMIT: usize = 128;

/// Size of output record: 81 (puzzle) + 1 (comma) + 81 (solution) + 1 (newline)
const OUTPUT_RECORD_SIZE: usize = 164;

/// Size of a puzzle string (81 cells)
const PUZZLE_SIZE: usize = 81;

// =============================================================================
// SHARED STATE
// =============================================================================

/// Atomic counter for dynamic batch assignment
/// Threads atomically fetch-and-add to claim their next batch
var next_batch_index: usize = 0;

// =============================================================================
// WORKER THREAD
// =============================================================================

/// Worker function executed by each thread.
/// Processes puzzles in batches, writing solutions directly to the shared output buffer.
fn solveWorker(initial_batch: usize, batch_size: usize, puzzle_count: usize, output: []u8) !void {
    var current_batch = initial_batch;
    var solver = Sudoku{};

    while (current_batch < puzzle_count) {
        const batch_start = current_batch;
        const batch_end = @min(current_batch + batch_size, puzzle_count);

        // Process all puzzles in this batch
        for (batch_start..batch_end) |puzzle_index| {
            solver.reset();

            const record_offset = puzzle_index * OUTPUT_RECORD_SIZE;
            const puzzle_slice = output[record_offset .. record_offset + PUZZLE_SIZE];
            const solution_slice = output[record_offset + PUZZLE_SIZE + 1 .. record_offset + OUTPUT_RECORD_SIZE - 1];

            // Format: puzzle,solution\n
            output[record_offset + PUZZLE_SIZE] = ',';
            solver.solve(solution_slice, puzzle_slice);
            output[record_offset + OUTPUT_RECORD_SIZE - 1] = '\n';
        }

        // Claim next batch atomically
        const claimed_batch = @atomicRmw(usize, &next_batch_index, AtomicRmwOp.Add, 1, AtomicOrder.monotonic);
        current_batch = claimed_batch * batch_size;
    }
}

// =============================================================================
// MAIN ENTRY POINT
// =============================================================================

pub fn main() !void {
    // ─────────────────────────────────────────────────────────────────────────
    // Parse command-line arguments
    // ─────────────────────────────────────────────────────────────────────────
    const args = try std.process.argsAlloc(std.heap.c_allocator);
    defer std.process.argsFree(std.heap.c_allocator, args);

    if (args.len != 2) {
        std.debug.print("Usage: sudokumaci <filename>\n", .{});
        return;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Read input file
    // ─────────────────────────────────────────────────────────────────────────
    const filename = args[1];
    const file = try std.fs.cwd().openFile(filename, .{});
    defer file.close();

    const file_contents = try file.readToEndAlloc(std.heap.c_allocator, std.math.maxInt(usize));
    defer std.heap.c_allocator.free(file_contents);

    // ─────────────────────────────────────────────────────────────────────────
    // Allocate output buffer and copy puzzles
    // ─────────────────────────────────────────────────────────────────────────
    const output = try std.heap.c_allocator.alloc(u8, file_contents.len * 2);
    defer std.heap.c_allocator.free(output);

    var puzzle_count: usize = 0;
    var line_iter = std.mem.splitScalar(u8, file_contents, '\n');
    while (line_iter.next()) |line| {
        @memcpy(output[puzzle_count * OUTPUT_RECORD_SIZE ..], line[0..PUZZLE_SIZE]);
        puzzle_count += 1;
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Launch worker threads
    // ─────────────────────────────────────────────────────────────────────────
    const thread_count = try std.Thread.getCpuCount();
    const batch_size: usize = @min(puzzle_count / thread_count + 1, BATCH_SIZE_LIMIT);

    // Initialize shared counter: first N batches are pre-assigned to threads
    next_batch_index = thread_count;

    var threads: [100]std.Thread = undefined;
    for (0..thread_count) |thread_index| {
        const initial_batch = thread_index * batch_size;
        threads[thread_index] = try std.Thread.spawn(.{}, solveWorker, .{ initial_batch, batch_size, puzzle_count, output });
    }

    // ─────────────────────────────────────────────────────────────────────────
    // Wait for completion and output results
    // ─────────────────────────────────────────────────────────────────────────
    for (0..thread_count) |thread_index| {
        threads[thread_index].join();
    }

    // Write all results to stdout (excluding final newline)
    try std.fs.File.stdout().writeAll(output[0 .. puzzle_count * OUTPUT_RECORD_SIZE - 1]);
}
