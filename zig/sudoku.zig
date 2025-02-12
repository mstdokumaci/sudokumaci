const std = @import("std");
const assert = std.debug.assert;

const ALL27 = @import("constants.zig").ALL27;
const ALL81 = @import("constants.zig").ALL81;
const ALL162 = @import("constants.zig").ALL162;
const BIT81 = @import("constants.zig").BIT81;
const GROUPS81 = @import("constants.zig").GROUPS81;
const SET81 = @import("constants.zig").SET81;
const POSSIBLES = @import("constants.zig").POSSIBLES;
const NUMBER_COMBINATIONS = @import("constants.zig").NUMBER_COMBINATIONS;
const BAND_COMBINATIONS = @import("constants.zig").BAND_COMBINATIONS;

const NumberCount = struct {
    number: usize,
    count: usize,

    fn lessThan(context: void, a: NumberCount, b: NumberCount) bool {
        _ = context;
        return a.count < b.count;
    }
};

pub const Sudoku = struct {
    is_sudoku: bool = true,
    number_cells: [9]u81 = .{ALL81} ** 9,
    numbers: [9]u8 = .{0} ** 9,
    number_bands: [9][3]u27 = .{.{0} ** 3} ** 9,
    number_band_matches: [9][3]u8 = .{.{0} ** 3} ** 9,

    pub fn solve(self: *Sudoku, cell_values: *const [81]u8) [81]u8 {
        var remove_from_others: [9]u81 = .{0} ** 9;

        for (cell_values, 0..) |value, cell_index| {
            if (value > 48) {
                const number = value - 49;
                self.number_cells[number] &= SET81[cell_index];
                remove_from_others[number] |= BIT81[cell_index];
            }
        }

        self.remove_cells(remove_from_others);
        assert(self.is_sudoku);
        self.prepare();
        assert(self.find_match(0, .{ALL162} ** 3));

        var solved: [81]u8 = .{48} ** 81;
        for (self.number_band_matches, 0..) |number_band_matches, number| {
            var cells: u81 = POSSIBLES[number_band_matches[0]] | @as(u81, POSSIBLES[number_band_matches[1]]) << 27 | @as(u81, POSSIBLES[number_band_matches[2]]) << 54;
            while (cells > 0) {
                solved[@ctz(cells)] = @as(u8, @truncate(number)) + 49;
                cells &= cells - 1;
            }
        }
        return solved;
    }

    fn remove_cells(self: *Sudoku, remove_from_others: [9]u81) void {
        var new_remove_from_others: [9]u81 = .{0} ** 9;
        var new_remove = false;

        for (0..9) |number| {
            var remove_union: u81 = 0;
            for (remove_from_others, 0..) |other_remove, remove_number| {
                if (number != remove_number) {
                    remove_union |= other_remove;
                }
            }
            const cells = &self.number_cells[number];
            const removed = cells.* & ~remove_union;
            if (removed != cells.*) {
                cells.* = removed;
                for (GROUPS81) |group_mask| {
                    const group = cells.* & group_mask;
                    const group_ones = @popCount(group);
                    if (group_ones == 0) {
                        self.is_sudoku = false;
                        return;
                    } else if (group_ones == 1) {
                        const set_cells = cells.* & SET81[@ctz(group)];
                        if (set_cells != cells.*) {
                            cells.* = set_cells;
                            new_remove_from_others[number] |= group;
                            new_remove = true;
                        }
                    }
                }
            }
        }
        if (new_remove) {
            self.remove_cells(new_remove_from_others);
        }
    }

    fn prepare(self: *Sudoku) void {
        var number_counts: [9]NumberCount = undefined;
        for (self.number_cells, 0..) |cells, number| {
            number_counts[number] = NumberCount{ .number = number, .count = @popCount(cells) };
        }

        std.mem.sort(comptime NumberCount, &number_counts, {}, comptime NumberCount.lessThan);

        for (number_counts, 0..) |number_count, i| {
            self.numbers[i] = @as(u8, @truncate(number_count.number));

            self.number_bands[number_count.number] = .{
                @intCast(self.number_cells[number_count.number] & ALL27),
                @intCast((self.number_cells[number_count.number] >> 27) & ALL27),
                @intCast((self.number_cells[number_count.number] >> 54) & ALL27),
            };
        }
    }

    fn find_match(self: *Sudoku, number_index: usize, combination_sets: [3]u162) bool {
        const number = self.numbers[number_index];
        const number_bands = self.number_bands[number];

        var biterate0 = combination_sets[0];
        while (biterate0 > 0) {
            const band0_index = @ctz(biterate0);
            if (number_bands[0] & POSSIBLES[band0_index] == POSSIBLES[band0_index] and (combination_sets[0] & NUMBER_COMBINATIONS[band0_index] > 0 or number_index == 8)) {
                var biterate1 = combination_sets[1] & BAND_COMBINATIONS[band0_index];
                while (biterate1 > 0) {
                    const band1_index = @ctz(biterate1);
                    if (number_bands[1] & POSSIBLES[band1_index] == POSSIBLES[band1_index] and (combination_sets[1] & NUMBER_COMBINATIONS[band1_index] > 0 or number_index == 8)) {
                        var biterate2 = combination_sets[2] & BAND_COMBINATIONS[band0_index] & BAND_COMBINATIONS[band1_index];
                        while (biterate2 > 0) {
                            const band2_index = @ctz(biterate2);
                            if (number_bands[2] & POSSIBLES[band2_index] == POSSIBLES[band2_index] and (number_index == 8 or (combination_sets[2] & NUMBER_COMBINATIONS[band2_index] > 0 and self.find_match(number_index + 1, .{ combination_sets[0] & NUMBER_COMBINATIONS[band0_index], combination_sets[1] & NUMBER_COMBINATIONS[band1_index], combination_sets[2] & NUMBER_COMBINATIONS[band2_index] })))) {
                                self.number_band_matches[number] = .{
                                    @as(u8, @truncate(band0_index)),
                                    @as(u8, @truncate(band1_index)),
                                    @as(u8, @truncate(band2_index)),
                                };
                                return true;
                            }
                            biterate2 &= biterate2 - 1;
                        }
                    }
                    biterate1 &= biterate1 - 1;
                }
            }
            biterate0 &= biterate0 - 1;
        }
        return false;
    }
};
