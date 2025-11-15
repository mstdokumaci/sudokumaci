const std = @import("std");
const AtomicOrder = std.builtin.AtomicOrder;
const AtomicRmwOp = std.builtin.AtomicRmwOp;
const Sudoku = @import("sudoku.zig").Sudoku;

var next_thread_index: usize = 0;

fn solve(thread_index: usize, batch_size: usize, count: usize, results: []u8) !void {
    var start = thread_index * batch_size;
    while (start < count) {
        const end = @min(start + batch_size, count);
        for (start..end) |puzzle_index| {
            var sudoku = Sudoku{};
            const result_index = puzzle_index * 164;
            results[result_index + 81] = ',';
            @memcpy(results[result_index + 82 ..], &sudoku.solve(results[result_index .. result_index + 81]));
            results[result_index + 163] = '\n';
        }
        const new_thread_index = @atomicRmw(usize, &next_thread_index, AtomicRmwOp.Add, 1, AtomicOrder.monotonic);
        start = new_thread_index * batch_size;
    }
}

pub fn main() !void {
    const args = try std.process.argsAlloc(std.heap.c_allocator);
    defer std.process.argsFree(std.heap.c_allocator, args);

    if (args.len != 2) {
        std.debug.print("Usage: sudokumaci <filename>\n", .{});
        return;
    }

    const filename = args[1];
    const file = try std.fs.cwd().openFile(filename, .{});
    defer file.close();

    const file_contents = try file.readToEndAlloc(std.heap.c_allocator, std.math.maxInt(usize));
    defer std.heap.c_allocator.free(file_contents);

    // Allocate a buffer for results
    const results = try std.heap.c_allocator.alloc(u8, file_contents.len * 2);
    defer std.heap.c_allocator.free(results);

    // Copy puzzles to results buffer
    var count: usize = 0;
    var line_iter = std.mem.splitScalar(u8, file_contents, '\n');
    while (line_iter.next()) |line| {
        @memcpy(results[count * 164 ..], line[0..81]);
        count += 1;
    }

    const thread_count = try std.Thread.getCpuCount();
    const batch_size: usize = @min(count / thread_count + 1, 128);
    next_thread_index = thread_count;

    var threads: [100]std.Thread = undefined;
    for (0..thread_count) |thread_index| {
        threads[thread_index] = try std.Thread.spawn(.{}, solve, .{ thread_index, batch_size, count, results });
    }

    for (0..thread_count) |thread_index| {
        threads[thread_index].join();
    }

    try std.fs.File.stdout().writeAll(results[0 .. count * 164 - 1]);
}
