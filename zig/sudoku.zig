const std = @import("std");
const assert = std.debug.assert;

const ALL27 = @import("constants.zig").ALL27;
const ALL81 = @import("constants.zig").ALL81;
const ALL162 = @import("constants.zig").ALL162;
const BIT9 = @import("constants.zig").BIT9;
const BIT81 = @import("constants.zig").BIT81;
const GROUPS81 = @import("constants.zig").GROUPS81;
const SET81 = @import("constants.zig").SET81;
const POSSIBLES = @import("constants.zig").POSSIBLES;
const NUMBER_COMBINATIONS = @import("constants.zig").NUMBER_COMBINATIONS;
const BAND_COMBINATIONS = @import("constants.zig").BAND_COMBINATIONS;

pub const Sudoku = struct {
    is_sudoku: bool = true,
    number_cells: [9]u81 = .{ALL81} ** 9,
    numbers: usize = 0b111111111,

    pub fn solve(self: *Sudoku, cell_values: *const [81]u8) [81]u8 {
        var remove_from_others: [9]u81 = .{0} ** 9;

        for (cell_values, 0..) |value, cell_index| {
            if (value > 48) {
                const number = value - 49;
                self.number_cells[number] &= SET81[cell_index];
                remove_from_others[number] |= BIT81[cell_index];
            }
        }

        const shortest_number = self.remove_cells(remove_from_others);
        assert(self.is_sudoku);
        assert(self.find_match(shortest_number, .{ALL162} ** 3));

        var solved: [81]u8 = .{48} ** 81;
        for (&self.number_cells, 0..) |*cells, number| {
            while (cells.* > 0) {
                solved[@ctz(cells.*)] = @as(u8, @truncate(number)) + 49;
                cells.* &= cells.* - 1;
            }
        }
        return solved;
    }

    fn remove_cells(self: *Sudoku, remove_from_others: [9]u81) usize {
        var shortest_length: usize = 81;
        var shortest_number: usize = 0;
        var new_remove_from_others: [9]u81 = .{0} ** 9;
        var new_remove = false;

        var biterate = self.numbers;
        while (biterate > 0) {
            const number = @ctz(biterate);
            var remove_union: u81 = 0;
            for (remove_from_others, 0..) |other_remove, remove_number| {
                if (number != remove_number) {
                    remove_union |= other_remove;
                }
            }
            const cells = &self.number_cells[number];
            const removed = cells.* & ~remove_union;
            const ones = @popCount(removed);
            if (ones < 9) {
                self.is_sudoku = false;
                return 0;
            }
            if (removed != cells.*) {
                cells.* = removed;
                for (GROUPS81) |group_mask| {
                    const group = cells.* & group_mask;
                    const group_ones = @popCount(group);
                    if (group_ones == 0) {
                        self.is_sudoku = false;
                        return 0;
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
            if (ones < shortest_length) {
                shortest_length = ones;
                shortest_number = number;
            }
            biterate &= biterate - 1;
        }
        return if (new_remove) self.remove_cells(new_remove_from_others) else shortest_number;
    }

    fn remove_cells_single(self: *Sudoku, remove_from_others: u81) usize {
        var shortest_length: usize = 81;
        var shortest_number: usize = 0;
        var new_remove_from_others: [9]u81 = .{0} ** 9;
        var new_remove = false;

        var biterate = self.numbers;
        while (biterate > 0) {
            const number = @ctz(biterate);
            const cells = &self.number_cells[number];
            const removed = cells.* & ~remove_from_others;
            const ones = @popCount(removed);
            if (ones < 9) {
                self.is_sudoku = false;
                return 0;
            }
            if (removed != cells.*) {
                cells.* = removed;
                for (GROUPS81) |group_mask| {
                    const group = cells.* & group_mask;
                    const group_ones = @popCount(group);
                    if (group_ones == 0) {
                        self.is_sudoku = false;
                        return 0;
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
            if (ones < shortest_length) {
                shortest_length = ones;
                shortest_number = number;
            }
            biterate &= biterate - 1;
        }
        return if (new_remove) self.remove_cells(new_remove_from_others) else shortest_number;
    }

    fn find_match(self: *Sudoku, number: usize, band_combinations: [3]u162) bool {
        self.numbers ^= BIT9[number];

        const numbers = self.numbers;
        const number_cells = self.number_cells;

        const number_band0: usize = @as(usize, @truncate(number_cells[number] & ALL27));
        const number_band1: usize = @as(usize, @truncate(number_cells[number] >> 27 & ALL27));
        const number_band2: usize = @as(usize, @truncate(number_cells[number] >> 54 & ALL27));

        var new_band_combinations: [3]u162 = undefined;

        var biterate0 = band_combinations[0];
        while (biterate0 > 0) {
            const band0_index = @ctz(biterate0);
            if (number_band0 & POSSIBLES[band0_index] == POSSIBLES[band0_index]) {
                new_band_combinations[0] = band_combinations[0] & NUMBER_COMBINATIONS[band0_index];
                if (new_band_combinations[0] != 0 or numbers == 0) {
                    var biterate1 = band_combinations[1] & BAND_COMBINATIONS[band0_index];
                    while (biterate1 > 0) {
                        const band1_index = @ctz(biterate1);
                        if (number_band1 & POSSIBLES[band1_index] == POSSIBLES[band1_index]) {
                            new_band_combinations[1] = band_combinations[1] & NUMBER_COMBINATIONS[band1_index];
                            if (new_band_combinations[1] != 0 or numbers == 0) {
                                var biterate2 = band_combinations[2] & BAND_COMBINATIONS[band0_index] & BAND_COMBINATIONS[band1_index];
                                while (biterate2 > 0) {
                                    const band2_index = @ctz(biterate2);
                                    if (number_band2 & POSSIBLES[band2_index] == POSSIBLES[band2_index]) {
                                        new_band_combinations[2] = band_combinations[2] & NUMBER_COMBINATIONS[band2_index];
                                        if (new_band_combinations[2] != 0 or numbers == 0) {
                                            self.number_cells[number] = @as(u81, POSSIBLES[band0_index]) | @as(u81, POSSIBLES[band1_index]) << 27 | @as(u81, POSSIBLES[band2_index]) << 54;
                                            if (numbers == 0) {
                                                return true;
                                            }
                                            const shortest_number = self.remove_cells_single(self.number_cells[number]);
                                            if (self.is_sudoku and self.find_match(shortest_number, new_band_combinations)) {
                                                return true;
                                            } else {
                                                self.is_sudoku = true;
                                                self.numbers = numbers;
                                                self.number_cells = number_cells;
                                            }
                                        }
                                    }
                                    biterate2 &= biterate2 - 1;
                                }
                            }
                        }
                        biterate1 &= biterate1 - 1;
                    }
                }
            }
            biterate0 &= biterate0 - 1;
        }
        return false;
    }
};
