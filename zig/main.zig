const std = @import("std");
const Sudoku = @import("sudoku.zig").Sudoku;

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

    const stdout = std.io.getStdOut().writer();

    var iter = std.mem.split(u8, file_contents, "\n");
    while (iter.next()) |puzzle| {
        var sudoku = Sudoku{};
        const solved = sudoku.solve(puzzle[0..81]);

        try stdout.print("{s},{s}\n", .{ puzzle, solved });
    }
}
