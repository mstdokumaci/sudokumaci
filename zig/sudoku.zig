const std = @import("std");
const assert = std.debug.assert;

const ALL27 = @import("constants.zig").ALL27;
const ALL81 = @import("constants.zig").ALL81;
const ALL162 = @import("constants.zig").ALL162;
const BIT9 = @import("constants.zig").BIT9;
const BIT81 = @import("constants.zig").BIT81;
const HOUSE_CELLS = @import("constants.zig").HOUSE_CELLS;
const CLEAR_HOUSES = @import("constants.zig").CLEAR_HOUSES;
const CLEAR_HOUSE_INDEXES = @import("constants.zig").CLEAR_HOUSE_INDEXES;
const VALID_BAND_CELLS = @import("constants.zig").VALID_BAND_CELLS;
const ROW_BANDS = @import("constants.zig").ROW_BANDS;
const BOARD_CLEARS = @import("constants.zig").BOARD_CLEARS;
const ROW_BOARD_CLEARS = @import("constants.zig").ROW_BOARD_CLEARS;
const DIGIT_COMPATIBLE_BANDS = @import("constants.zig").DIGIT_COMPATIBLE_BANDS;
const BOARD_COMPATIBLE_BANDS = @import("constants.zig").BOARD_COMPATIBLE_BANDS;

pub const Sudoku = struct {
    pending_digits: usize = 0b111111111,
    digit_candidate_cells: [9]u128 = .{ ALL81, ALL81, ALL81, ALL81, ALL81, ALL81, ALL81, ALL81, ALL81 },
    pending_digit_houses: [9]usize = .{ ALL27, ALL27, ALL27, ALL27, ALL27, ALL27, ALL27, ALL27, ALL27 },

    pub fn solve(self: *Sudoku, cell_values: []const u8) [81]u8 {
        var initial_fixed_placements: [9]u128 = .{ 0, 0, 0, 0, 0, 0, 0, 0, 0 };

        // Initialize digit candidate cells and fixed placements based on the input cell values
        for (cell_values, 0..) |value, cell_index| {
            if (value > 48) {
                const digit_index = value - 49;
                self.digit_candidate_cells[digit_index] &= CLEAR_HOUSES[cell_index];
                initial_fixed_placements[digit_index] |= BIT81[cell_index];
            }
        }

        // Attempt solving the Sudoku puzzle
        const most_constrained_digit_index = self.clear_for_placements(initial_fixed_placements);
        assert(most_constrained_digit_index < 9);
        assert(self.find_valid_bands(most_constrained_digit_index, .{ ALL162, ALL162, ALL162 }));

        // Convert the solved state into a string representation
        var solved: [81]u8 = undefined;
        for (&self.digit_candidate_cells, 0..) |*digit_cells, digit_index| {
            const digit_str = @as(u8, @truncate(digit_index)) + 49;
            while (digit_cells.* > 0) : (digit_cells.* &= digit_cells.* - 1) {
                solved[@ctz(digit_cells.*)] = digit_str;
            }
        }
        return solved;
    }

    fn clear_for_placements(self: *Sudoku, placements_to_propagate: [9]u128) usize {
        var min_candidate_count: usize = 81;
        var most_constrained_digit_index: usize = 0;
        var new_placements: [9]u128 = .{ 0, 0, 0, 0, 0, 0, 0, 0, 0 };
        var have_new_placements = false;

        var digits_biterate = self.pending_digits;
        while (digits_biterate > 0) : (digits_biterate &= digits_biterate - 1) {
            const digit_index = @ctz(digits_biterate);
            if (self.pending_digit_houses[digit_index] > 0) {
                var clear_cells_for_digit: u128 = 0;
                var other_digits_candidates_union: u128 = 0;
                for (placements_to_propagate, 0..) |placements, placement_digit_index| {
                    if (digit_index != placement_digit_index) {
                        clear_cells_for_digit |= placements;
                        other_digits_candidates_union |= self.digit_candidate_cells[placement_digit_index];
                    }
                }
                const current_candidate_cells = &self.digit_candidate_cells[digit_index];
                const pruned_current_candidate_cells = current_candidate_cells.* & ~clear_cells_for_digit;
                const candidate_count = @popCount(pruned_current_candidate_cells);
                if (candidate_count < 9) {
                    // We found an invalid placement, return 9 to indicate failure
                    return 9;
                }
                if (pruned_current_candidate_cells != current_candidate_cells.*) {
                    current_candidate_cells.* = pruned_current_candidate_cells;
                    if (candidate_count < 35) {
                        var board_clears_biterate = ROW_BOARD_CLEARS[0][@truncate(current_candidate_cells.* & 0b111111111)] &
                            ROW_BOARD_CLEARS[1][@truncate(current_candidate_cells.* >> 9 & 0b111111111)] &
                            ROW_BOARD_CLEARS[2][@truncate(current_candidate_cells.* >> 18 & 0b111111111)] &
                            ROW_BOARD_CLEARS[3][@truncate(current_candidate_cells.* >> 27 & 0b111111111)] &
                            ROW_BOARD_CLEARS[4][@truncate(current_candidate_cells.* >> 36 & 0b111111111)] &
                            ROW_BOARD_CLEARS[5][@truncate(current_candidate_cells.* >> 45 & 0b111111111)] &
                            ROW_BOARD_CLEARS[6][@truncate(current_candidate_cells.* >> 54 & 0b111111111)] &
                            ROW_BOARD_CLEARS[7][@truncate(current_candidate_cells.* >> 63 & 0b111111111)] &
                            ROW_BOARD_CLEARS[8][@truncate(current_candidate_cells.* >> 72 & 0b111111111)];
                        while (board_clears_biterate > 0) : (board_clears_biterate &= board_clears_biterate - 1) {
                            current_candidate_cells.* &= BOARD_CLEARS[@ctz(board_clears_biterate)];
                        }
                    }
                    var hidden_singles_biterate: u128 = current_candidate_cells.* & ~other_digits_candidates_union;
                    while (hidden_singles_biterate > 0) : (hidden_singles_biterate &= hidden_singles_biterate - 1) {
                        current_candidate_cells.* &= CLEAR_HOUSES[@ctz(hidden_singles_biterate)];
                    }
                    var houses_biterate = self.pending_digit_houses[digit_index];
                    while (houses_biterate > 0) : (houses_biterate &= houses_biterate - 1) {
                        const digit_candidates_in_house = current_candidate_cells.* & HOUSE_CELLS[@ctz(houses_biterate)];
                        const digit_candidate_count_in_house = @popCount(digit_candidates_in_house);
                        if (digit_candidate_count_in_house == 0) {
                            // We found an invalid placement, return 9 to indicate failure
                            return 9;
                        } else if (digit_candidate_count_in_house == 1) {
                            // We found a single candidate in the house, place it
                            const placed_cell_index = @ctz(digit_candidates_in_house);
                            current_candidate_cells.* &= CLEAR_HOUSES[placed_cell_index];
                            self.pending_digit_houses[digit_index] &= CLEAR_HOUSE_INDEXES[placed_cell_index];
                            new_placements[digit_index] |= digit_candidates_in_house;
                            have_new_placements = true;
                        }
                    }
                }
                if (candidate_count < min_candidate_count) {
                    min_candidate_count = candidate_count;
                    most_constrained_digit_index = digit_index;
                }
            } else {
                min_candidate_count = 9;
                most_constrained_digit_index = digit_index;
            }
        }
        return if (have_new_placements) self.clear_for_placements(new_placements) else most_constrained_digit_index;
    }

    fn find_valid_bands(self: *Sudoku, digit_index: usize, reduced_bands: [3]u192) bool {
        self.pending_digits ^= BIT9[digit_index];

        // If there are no pending digits and no pending houses for the current digit, we have a valid solution
        if (self.pending_digits == 0 and self.pending_digit_houses[digit_index] == 0) {
            return true;
        }

        // Make a copy of the current state to restore for backtracking
        const pending_digits = self.pending_digits;
        const digit_candidate_cells = self.digit_candidate_cells;
        const pending_digit_houses = self.pending_digit_houses;

        // Initialize new reduced bands
        var new_reduced_bands: [3]u192 = undefined;

        // Calculate the candidate cell bands for the current digit
        const current_candidate_cells = &self.digit_candidate_cells[digit_index];
        const candidate_cell_bands: [3]u192 = .{
            ROW_BANDS[0][@truncate(current_candidate_cells.* & 0b111111111)] & ROW_BANDS[1][@truncate(current_candidate_cells.* >> 9 & 0b111111111)] & ROW_BANDS[2][@truncate(current_candidate_cells.* >> 18 & 0b111111111)] & reduced_bands[0],
            ROW_BANDS[0][@truncate(current_candidate_cells.* >> 27 & 0b111111111)] & ROW_BANDS[1][@truncate(current_candidate_cells.* >> 36 & 0b111111111)] & ROW_BANDS[2][@truncate(current_candidate_cells.* >> 45 & 0b111111111)] & reduced_bands[1],
            ROW_BANDS[0][@truncate(current_candidate_cells.* >> 54 & 0b111111111)] & ROW_BANDS[1][@truncate(current_candidate_cells.* >> 63 & 0b111111111)] & ROW_BANDS[2][@truncate(current_candidate_cells.* >> 72 & 0b111111111)] & reduced_bands[2],
        };

        var band0_biterate = candidate_cell_bands[0];
        while (band0_biterate > 0) : (band0_biterate &= band0_biterate - 1) {
            const valid_band0_index = @ctz(band0_biterate);
            new_reduced_bands[0] = reduced_bands[0] & DIGIT_COMPATIBLE_BANDS[valid_band0_index];
            if (new_reduced_bands[0] != 0 or pending_digits == 0) {
                var band1_biterate = candidate_cell_bands[1] & BOARD_COMPATIBLE_BANDS[valid_band0_index];
                while (band1_biterate > 0) : (band1_biterate &= band1_biterate - 1) {
                    const valid_band1_index = @ctz(band1_biterate);
                    new_reduced_bands[1] = reduced_bands[1] & DIGIT_COMPATIBLE_BANDS[valid_band1_index];
                    if (new_reduced_bands[1] != 0 or pending_digits == 0) {
                        var band2_biterate = candidate_cell_bands[2] & BOARD_COMPATIBLE_BANDS[valid_band0_index] & BOARD_COMPATIBLE_BANDS[valid_band1_index];
                        while (band2_biterate > 0) : (band2_biterate &= band2_biterate - 1) {
                            const valid_band2_index = @ctz(band2_biterate);
                            new_reduced_bands[2] = reduced_bands[2] & DIGIT_COMPATIBLE_BANDS[valid_band2_index];
                            if (new_reduced_bands[2] != 0 or pending_digits == 0) {
                                current_candidate_cells.* = @as(u128, VALID_BAND_CELLS[valid_band0_index]) | @as(u128, VALID_BAND_CELLS[valid_band1_index]) << 27 | @as(u128, VALID_BAND_CELLS[valid_band2_index]) << 54;
                                if (pending_digits == 0) {
                                    // If no digits are pending, we have a valid solution
                                    return true;
                                }
                                var placements_to_propagate: [9]u128 = .{ 0, 0, 0, 0, 0, 0, 0, 0, 0 };
                                placements_to_propagate[digit_index] = current_candidate_cells.*;
                                const most_constrained_digit_index = self.clear_for_placements(placements_to_propagate);
                                if (most_constrained_digit_index < 9 and self.find_valid_bands(most_constrained_digit_index, new_reduced_bands)) {
                                    // If recursion finds a valid solution, return true
                                    return true;
                                } else {
                                    // Restore the previous state for backtracking
                                    self.pending_digits = pending_digits;
                                    self.digit_candidate_cells = digit_candidate_cells;
                                    self.pending_digit_houses = pending_digit_houses;
                                }
                            }
                        }
                    }
                }
            }
        }

        // If no valid bands were found, return false
        return false;
    }
};
