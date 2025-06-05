const std = @import("std");
const assert = std.debug.assert;

const ALL27 = @import("constants.zig").ALL27;
const ALL81 = @import("constants.zig").ALL81;
const ALL162 = @import("constants.zig").ALL162;
const BIT9 = @import("constants.zig").BIT9;
const BIT81 = @import("constants.zig").BIT81;
const GROUPS81 = @import("constants.zig").GROUPS81;
const SET81 = @import("constants.zig").SET81;
const SET_CELL_GROUPS = @import("constants.zig").SET_CELL_GROUPS;
const POSSIBLES = @import("constants.zig").POSSIBLES;
const NUMBER_COMBINATIONS = @import("constants.zig").NUMBER_COMBINATIONS;
const BAND_COMBINATIONS = @import("constants.zig").BAND_COMBINATIONS;

pub const Sudoku = struct {
    is_sudoku: bool = true,
    pending_digits: usize = 0b111111111,
    digit_candidate_cells: [9]u128 = .{ ALL81, ALL81, ALL81, ALL81, ALL81, ALL81, ALL81, ALL81, ALL81 },
    pending_digit_groups: [9]usize = .{ ALL27, ALL27, ALL27, ALL27, ALL27, ALL27, ALL27, ALL27, ALL27 },

    pub fn solve(self: *Sudoku, cell_values: []const u8) [81]u8 {
        var initial_fixed_placements: [9]u128 = .{ 0, 0, 0, 0, 0, 0, 0, 0, 0 };

        for (cell_values, 0..) |value, cell_index| {
            if (value > 48) {
                const digit_index = value - 49;
                self.digit_candidate_cells[digit_index] &= SET81[cell_index];
                initial_fixed_placements[digit_index] |= BIT81[cell_index];
            }
        }

        const most_constrained_digit_index = self.remove_cells(initial_fixed_placements);
        assert(self.is_sudoku);
        assert(self.find_match(most_constrained_digit_index, .{ ALL162, ALL162, ALL162 }));

        var solved: [81]u8 = undefined;
        for (&self.digit_candidate_cells, 0..) |*digit_cells, digit_index| {
            const digit_str = @as(u8, @truncate(digit_index)) + 49;
            while (digit_cells.* > 0) {
                solved[@ctz(digit_cells.*)] = digit_str;
                digit_cells.* &= digit_cells.* - 1;
            }
        }
        return solved;
    }

    fn remove_cells(self: *Sudoku, placements_to_propagate: [9]u128) usize {
        var min_digit_locations: usize = 81;
        var most_constrained_digit_index: usize = 0;
        var new_placements: [9]u128 = .{ 0, 0, 0, 0, 0, 0, 0, 0, 0 };
        var have_new_placements = false;

        var pending_digits_biterate = self.pending_digits;
        while (pending_digits_biterate > 0) {
            const digit_index = @ctz(pending_digits_biterate);
            if (self.pending_digit_groups[digit_index] > 0) {
                var remove_union: u128 = 0;
                var others_union: u128 = 0;
                for (placements_to_propagate, 0..) |other_remove, remove_digit_index| {
                    if (digit_index != remove_digit_index) {
                        remove_union |= other_remove;
                        others_union |= self.digit_candidate_cells[remove_digit_index];
                    }
                }
                const cells = &self.digit_candidate_cells[digit_index];
                const removed = cells.* & ~remove_union;
                const ones = @popCount(removed);
                if (ones < 9) {
                    self.is_sudoku = false;
                    return 0;
                }
                if (removed != cells.*) {
                    cells.* = removed;
                    var hidden_singles: u128 = cells.* & ~others_union;
                    while (hidden_singles > 0) {
                        cells.* &= SET81[@ctz(hidden_singles)];
                        hidden_singles &= hidden_singles - 1;
                    }
                    var pending_digit_groups = self.pending_digit_groups[digit_index];
                    while (pending_digit_groups > 0) {
                        const group = cells.* & GROUPS81[@ctz(pending_digit_groups)];
                        const group_ones = @popCount(group);
                        if (group_ones == 0) {
                            self.is_sudoku = false;
                            return 0;
                        } else if (group_ones == 1) {
                            const cell_index = @ctz(group);
                            cells.* &= SET81[cell_index];
                            self.pending_digit_groups[digit_index] &= SET_CELL_GROUPS[cell_index];
                            new_placements[digit_index] |= group;
                            have_new_placements = true;
                        }
                        pending_digit_groups &= pending_digit_groups - 1;
                    }
                }
                if (ones < min_digit_locations) {
                    min_digit_locations = ones;
                    most_constrained_digit_index = digit_index;
                }
            } else {
                min_digit_locations = 9;
                most_constrained_digit_index = digit_index;
            }
            pending_digits_biterate &= pending_digits_biterate - 1;
        }
        return if (have_new_placements) self.remove_cells(new_placements) else most_constrained_digit_index;
    }

    fn find_match(self: *Sudoku, number: usize, band_combinations: [3]u192) bool {
        self.pending_digits &= ~BIT9[number];

        if (self.pending_digits == 0 and self.pending_digit_groups[number] == 0) {
            return true;
        }

        const pending_digits = self.pending_digits;
        const digit_candidate_cells = self.digit_candidate_cells;
        const pending_digit_groups = self.pending_digit_groups;

        const number_band0: usize = @truncate(digit_candidate_cells[number] & ALL27);
        const number_band1: usize = @truncate(digit_candidate_cells[number] >> 27 & ALL27);
        const number_band2: usize = @truncate(digit_candidate_cells[number] >> 54 & ALL27);

        var new_band_combinations: [3]u192 = undefined;

        var biterate0 = band_combinations[0];
        while (biterate0 > 0) {
            const band0_index = @ctz(biterate0);
            const possible0 = POSSIBLES[band0_index];
            if (number_band0 & possible0 == possible0) {
                new_band_combinations[0] = band_combinations[0] & NUMBER_COMBINATIONS[band0_index];
                if (new_band_combinations[0] != 0 or pending_digits == 0) {
                    var biterate1 = band_combinations[1] & BAND_COMBINATIONS[band0_index];
                    while (biterate1 > 0) {
                        const band1_index = @ctz(biterate1);
                        const possible1 = POSSIBLES[band1_index];
                        if (number_band1 & possible1 == possible1) {
                            new_band_combinations[1] = band_combinations[1] & NUMBER_COMBINATIONS[band1_index];
                            if (new_band_combinations[1] != 0 or pending_digits == 0) {
                                var biterate2 = band_combinations[2] & BAND_COMBINATIONS[band0_index] & BAND_COMBINATIONS[band1_index];
                                while (biterate2 > 0) {
                                    const band2_index = @ctz(biterate2);
                                    const possible2 = POSSIBLES[band2_index];
                                    if (number_band2 & possible2 == possible2) {
                                        new_band_combinations[2] = band_combinations[2] & NUMBER_COMBINATIONS[band2_index];
                                        if (new_band_combinations[2] != 0 or pending_digits == 0) {
                                            self.digit_candidate_cells[number] = @as(u128, possible0) | @as(u128, possible1) << 27 | @as(u128, possible2) << 54;
                                            if (pending_digits == 0) {
                                                return true;
                                            }
                                            var placements_to_propagate: [9]u128 = .{ 0, 0, 0, 0, 0, 0, 0, 0, 0 };
                                            placements_to_propagate[number] = self.digit_candidate_cells[number];
                                            const most_constrained_digit_index = self.remove_cells(placements_to_propagate);
                                            if (self.is_sudoku and self.find_match(most_constrained_digit_index, new_band_combinations)) {
                                                return true;
                                            } else {
                                                self.is_sudoku = true;
                                                self.pending_digits = pending_digits;
                                                self.digit_candidate_cells = digit_candidate_cells;
                                                self.pending_digit_groups = pending_digit_groups;
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
