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
        var min_candidate_locations: usize = 81;
        var most_constrained_digit_index: usize = 0;
        var new_placements: [9]u128 = .{ 0, 0, 0, 0, 0, 0, 0, 0, 0 };
        var have_new_placements = false;

        var pending_digits_biterate = self.pending_digits;
        while (pending_digits_biterate > 0) {
            const digit_index = @ctz(pending_digits_biterate);
            if (self.pending_digit_groups[digit_index] > 0) {
                var remove_cells_for_digit: u128 = 0;
                var other_digits_candidates_union: u128 = 0;
                for (placements_to_propagate, 0..) |placements, placement_digit_index| {
                    if (digit_index != placement_digit_index) {
                        remove_cells_for_digit |= placements;
                        other_digits_candidates_union |= self.digit_candidate_cells[placement_digit_index];
                    }
                }
                const digit_candidate_cells = &self.digit_candidate_cells[digit_index];
                const pruned_digit_candidate_cells = digit_candidate_cells.* & ~remove_cells_for_digit;
                const candidate_locations_count = @popCount(pruned_digit_candidate_cells);
                if (candidate_locations_count < 9) {
                    self.is_sudoku = false;
                    return 0;
                }
                if (pruned_digit_candidate_cells != digit_candidate_cells.*) {
                    digit_candidate_cells.* = pruned_digit_candidate_cells;
                    var hidden_singles_biterate: u128 = digit_candidate_cells.* & ~other_digits_candidates_union;
                    while (hidden_singles_biterate > 0) {
                        digit_candidate_cells.* &= SET81[@ctz(hidden_singles_biterate)];
                        hidden_singles_biterate &= hidden_singles_biterate - 1;
                    }
                    var pending_digit_groups = self.pending_digit_groups[digit_index];
                    while (pending_digit_groups > 0) {
                        const digit_candidates_in_group = digit_candidate_cells.* & GROUPS81[@ctz(pending_digit_groups)];
                        const digit_candidate_count_in_group = @popCount(digit_candidates_in_group);
                        if (digit_candidate_count_in_group == 0) {
                            self.is_sudoku = false;
                            return 0;
                        } else if (digit_candidate_count_in_group == 1) {
                            const placed_cell_index = @ctz(digit_candidates_in_group);
                            digit_candidate_cells.* &= SET81[placed_cell_index];
                            self.pending_digit_groups[digit_index] &= SET_CELL_GROUPS[placed_cell_index];
                            new_placements[digit_index] |= digit_candidates_in_group;
                            have_new_placements = true;
                        }
                        pending_digit_groups &= pending_digit_groups - 1;
                    }
                }
                if (candidate_locations_count < min_candidate_locations) {
                    min_candidate_locations = candidate_locations_count;
                    most_constrained_digit_index = digit_index;
                }
            } else {
                min_candidate_locations = 9;
                most_constrained_digit_index = digit_index;
            }
            pending_digits_biterate &= pending_digits_biterate - 1;
        }
        return if (have_new_placements) self.remove_cells(new_placements) else most_constrained_digit_index;
    }

    fn find_match(self: *Sudoku, digit_index: usize, band_combinations: [3]u192) bool {
        self.pending_digits &= ~BIT9[digit_index];

        if (self.pending_digits == 0 and self.pending_digit_groups[digit_index] == 0) {
            return true;
        }

        const pending_digits = self.pending_digits;
        const digit_candidate_cells = self.digit_candidate_cells;
        const pending_digit_groups = self.pending_digit_groups;

        const number_band0: usize = @truncate(digit_candidate_cells[digit_index] & ALL27);
        const number_band1: usize = @truncate(digit_candidate_cells[digit_index] >> 27 & ALL27);
        const number_band2: usize = @truncate(digit_candidate_cells[digit_index] >> 54 & ALL27);

        var new_band_combinations: [3]u192 = undefined;

        var ban_combinations0_biterate = band_combinations[0];
        while (ban_combinations0_biterate > 0) {
            const band0_index = @ctz(ban_combinations0_biterate);
            const possible0 = POSSIBLES[band0_index];
            if (number_band0 & possible0 == possible0) {
                new_band_combinations[0] = band_combinations[0] & NUMBER_COMBINATIONS[band0_index];
                if (new_band_combinations[0] != 0 or pending_digits == 0) {
                    var band_combinations1_biterate = band_combinations[1] & BAND_COMBINATIONS[band0_index];
                    while (band_combinations1_biterate > 0) {
                        const band1_index = @ctz(band_combinations1_biterate);
                        const possible1 = POSSIBLES[band1_index];
                        if (number_band1 & possible1 == possible1) {
                            new_band_combinations[1] = band_combinations[1] & NUMBER_COMBINATIONS[band1_index];
                            if (new_band_combinations[1] != 0 or pending_digits == 0) {
                                var band_combinations2_biterate = band_combinations[2] & BAND_COMBINATIONS[band0_index] & BAND_COMBINATIONS[band1_index];
                                while (band_combinations2_biterate > 0) {
                                    const band2_index = @ctz(band_combinations2_biterate);
                                    const possible2 = POSSIBLES[band2_index];
                                    if (number_band2 & possible2 == possible2) {
                                        new_band_combinations[2] = band_combinations[2] & NUMBER_COMBINATIONS[band2_index];
                                        if (new_band_combinations[2] != 0 or pending_digits == 0) {
                                            self.digit_candidate_cells[digit_index] = @as(u128, possible0) | @as(u128, possible1) << 27 | @as(u128, possible2) << 54;
                                            if (pending_digits == 0) {
                                                return true;
                                            }
                                            var placements_to_propagate: [9]u128 = .{ 0, 0, 0, 0, 0, 0, 0, 0, 0 };
                                            placements_to_propagate[digit_index] = self.digit_candidate_cells[digit_index];
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
                                    band_combinations2_biterate &= band_combinations2_biterate - 1;
                                }
                            }
                        }
                        band_combinations1_biterate &= band_combinations1_biterate - 1;
                    }
                }
            }
            ban_combinations0_biterate &= ban_combinations0_biterate - 1;
        }
        return false;
    }
};
