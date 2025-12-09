const std = @import("std");
const assert = std.debug.assert;

// =============================================================================
// CONSTANTS IMPORTS
// =============================================================================

const constants = @import("constants.zig");

// Bitmasks representing "all" bits set for different sizes
const ALL_9_DIGITS: usize = 0b111111111; // Bits 0-8 set (9 digits)
const ALL_27_HOUSES: usize = constants.ALL27; // Bits for 27 houses (9 rows + 9 cols + 9 boxes)
const ALL_81_CELLS: u128 = constants.ALL81; // Bits for 81 cells
const ALL_162_PATTERNS: u192 = constants.ALL162; // Bits for 162 valid band patterns

// Single-bit masks
const BIT9 = constants.BIT9; // BIT9[i] = 1 << i for i in 0..8
const BIT81 = constants.BIT81; // BIT81[i] = 1 << i for i in 0..80

// House (row/column/box) related tables
const HOUSE_CELLS = constants.HOUSE_CELLS; // Cells belonging to each house
const CLEAR_HOUSES = constants.CLEAR_HOUSES; // Mask to clear all peer cells
const CLEAR_HOUSE_INDEXES = constants.CLEAR_HOUSE_INDEXES; // Mask to clear house indexes

// Band pattern tables
const VALID_BAND_CELLS = constants.VALID_BAND_CELLS; // 162 valid digit placements per band
const ROW_BANDS = constants.ROW_BANDS; // Row mask → compatible band patterns
const BOARD_CLEARS = constants.BOARD_CLEARS; // Box-line reduction masks
const ROW_BOARD_CLEARS = constants.ROW_BOARD_CLEARS; // Row mask → applicable reductions
const DIGIT_COMPATIBLE_BANDS = constants.DIGIT_COMPATIBLE_BANDS; // Non-overlapping band patterns
const BOARD_COMPATIBLE_BANDS = constants.BOARD_COMPATIBLE_BANDS; // Column-compatible band patterns

// ASCII constants for parsing
const ASCII_ZERO: u8 = '0'; // = 48
const ASCII_ONE: u8 = '1'; // = 49

// Row extraction constants
const ROW_MASK: u128 = 0b111111111; // 9 bits for one row
const BITS_PER_ROW: u7 = 9;

// Board clears pattern mask (54 bits for forward patterns, 54 for reverse)
const BOARD_CLEARS_HALF_MASK: u128 = (1 << 54) - 1;

// Invalid state sentinel - returned when puzzle has no solution
const INVALID_DIGIT_INDEX: usize = 9;

// =============================================================================
// HELPER FUNCTIONS
// =============================================================================

/// Extracts the 9-bit row mask from a 81-bit cell bitboard
inline fn getRowMask(cells: u128, row_index: usize) u9 {
    return @truncate(cells >> @intCast(row_index * BITS_PER_ROW) & ROW_MASK);
}

/// Computes the intersection of all valid band patterns compatible with current row candidates.
/// Used for box-line reduction to find patterns that match all 9 rows.
inline fn getMatchingBoardClears(candidate_cells: u128) u128 {
    return ROW_BOARD_CLEARS[0][getRowMask(candidate_cells, 0)] &
        ROW_BOARD_CLEARS[1][getRowMask(candidate_cells, 1)] &
        ROW_BOARD_CLEARS[2][getRowMask(candidate_cells, 2)] &
        ROW_BOARD_CLEARS[3][getRowMask(candidate_cells, 3)] &
        ROW_BOARD_CLEARS[4][getRowMask(candidate_cells, 4)] &
        ROW_BOARD_CLEARS[5][getRowMask(candidate_cells, 5)] &
        ROW_BOARD_CLEARS[6][getRowMask(candidate_cells, 6)] &
        ROW_BOARD_CLEARS[7][getRowMask(candidate_cells, 7)] &
        ROW_BOARD_CLEARS[8][getRowMask(candidate_cells, 8)];
}

/// Computes valid band patterns by intersecting row constraints for a 3-row band.
/// band_start_row should be 0, 3, or 6 (the first row of the band).
inline fn getValidBandPatterns(candidate_cells: u128, band_start_row: usize, existing_constraints: u192) u192 {
    return ROW_BANDS[0][getRowMask(candidate_cells, band_start_row)] &
        ROW_BANDS[1][getRowMask(candidate_cells, band_start_row + 1)] &
        ROW_BANDS[2][getRowMask(candidate_cells, band_start_row + 2)] &
        existing_constraints;
}

/// Standard bit iteration: clears lowest set bit
inline fn clearLowestBit(x: anytype) @TypeOf(x) {
    return x & (x - 1);
}

// =============================================================================
// SUDOKU SOLVER
// =============================================================================

pub const Sudoku = struct {
    /// Bitmask of digits (0-8) that haven't been fully placed yet
    pending_digits: usize = ALL_9_DIGITS,

    /// For each digit, a bitmask of cells where that digit could still go
    digit_candidate_cells: [9]u128 = .{ALL_81_CELLS} ** 9,

    /// For each digit, a bitmask of houses (rows/cols/boxes) where that digit still needs placement
    pending_digit_houses: [9]usize = .{ALL_27_HOUSES} ** 9,

    /// Resets the solver state for a new puzzle
    pub fn reset(self: *Sudoku) void {
        self.pending_digits = ALL_9_DIGITS;
        self.digit_candidate_cells = .{ALL_81_CELLS} ** 9;
        self.pending_digit_houses = .{ALL_27_HOUSES} ** 9;
    }

    /// Main entry point: solves a puzzle and writes the solution to `out`.
    /// - `out`: 81-byte buffer to receive the solution
    /// - `cell_values`: 81-byte input puzzle ('0' or '.' for empty, '1'-'9' for givens)
    pub fn solve(self: *Sudoku, out: []u8, cell_values: []const u8) void {
        var initial_placements: [9]u128 = .{0} ** 9;

        // ─────────────────────────────────────────────────────────────────────
        // PHASE 1: Parse input and initialize constraints
        // ─────────────────────────────────────────────────────────────────────
        for (cell_values, 0..) |value, cell_index| {
            if (value > ASCII_ZERO) {
                const digit_index = value - ASCII_ONE;
                // Remove this cell from all peer cells' candidates
                self.digit_candidate_cells[digit_index] &= CLEAR_HOUSES[cell_index];
                // Mark this cell as a known placement
                initial_placements[digit_index] |= BIT81[cell_index];
            }
        }

        // ─────────────────────────────────────────────────────────────────────
        // PHASE 2: Constraint propagation + search
        // ─────────────────────────────────────────────────────────────────────
        const most_constrained_digit = self.propagateConstraints(initial_placements);
        assert(most_constrained_digit < INVALID_DIGIT_INDEX);
        assert(self.searchValidBands(most_constrained_digit, .{ALL_162_PATTERNS} ** 3));

        // ─────────────────────────────────────────────────────────────────────
        // PHASE 3: Convert bitboards to string output
        // ─────────────────────────────────────────────────────────────────────
        for (&self.digit_candidate_cells, 0..) |*digit_cells, digit_index| {
            const digit_char: u8 = @as(u8, @truncate(digit_index)) + ASCII_ONE;
            // Iterate through all set bits (each representing a cell with this digit)
            while (digit_cells.* > 0) : (digit_cells.* = clearLowestBit(digit_cells.*)) {
                out[@ctz(digit_cells.*)] = digit_char;
            }
        }
    }

    // =========================================================================
    // CONSTRAINT PROPAGATION
    // =========================================================================

    /// Propagates constraints from new placements, applying:
    /// 1. Naked singles (cells with only one candidate)
    /// 2. Hidden singles (digits with only one location in a house)
    /// 3. Box-line reduction (when a digit is confined to one row/col within a box)
    ///
    /// Returns the index of the most constrained digit for search, or INVALID_DIGIT_INDEX if invalid.
    fn propagateConstraints(self: *Sudoku, new_placements: [9]u128) usize {
        var min_candidates: usize = 81;
        var most_constrained_digit: usize = 0;
        var discovered_placements: [9]u128 = .{0} ** 9;
        var found_new_placements = false;

        // Process each pending digit
        var remaining_digits = self.pending_digits;
        while (remaining_digits > 0) : (remaining_digits = clearLowestBit(remaining_digits)) {
            const digit = @ctz(remaining_digits);

            if (self.pending_digit_houses[digit] > 0) {
                // ─────────────────────────────────────────────────────────────
                // Step 1: Compute cells to clear (placed by other digits)
                // ─────────────────────────────────────────────────────────────
                var cells_used_by_other_digits: u128 = 0;
                var other_digits_candidates: u128 = 0;
                for (new_placements, 0..) |placements, other_digit| {
                    if (digit != other_digit) {
                        cells_used_by_other_digits |= placements;
                        other_digits_candidates |= self.digit_candidate_cells[other_digit];
                    }
                }

                // ─────────────────────────────────────────────────────────────
                // Step 2: Apply constraints and check validity
                // ─────────────────────────────────────────────────────────────
                const candidates = &self.digit_candidate_cells[digit];
                const pruned_candidates = candidates.* & ~cells_used_by_other_digits;
                const candidate_count = @popCount(pruned_candidates);

                // A digit must have at least 9 candidate cells (one per house)
                if (candidate_count < 9) {
                    return INVALID_DIGIT_INDEX;
                }

                if (pruned_candidates != candidates.*) {
                    candidates.* = pruned_candidates;

                    // ─────────────────────────────────────────────────────────
                    // Step 3: Find hidden singles
                    // Cells that are candidates for this digit but no other digit
                    // ─────────────────────────────────────────────────────────
                    var unique_cells = candidates.* & ~other_digits_candidates;
                    while (unique_cells > 0) : (unique_cells = clearLowestBit(unique_cells)) {
                        const cell = @ctz(unique_cells);
                        const houses_after_placement = self.pending_digit_houses[digit] & CLEAR_HOUSE_INDEXES[cell];
                        if (houses_after_placement != self.pending_digit_houses[digit]) {
                            // Found a hidden single - this cell must contain this digit
                            self.pending_digit_houses[digit] = houses_after_placement;
                            candidates.* &= CLEAR_HOUSES[cell];
                            discovered_placements[digit] |= unique_cells;
                            found_new_placements = true;
                        }
                    }

                    // ─────────────────────────────────────────────────────────
                    // Step 4: Box-line reduction (only when candidates are sparse)
                    // ─────────────────────────────────────────────────────────
                    if (candidate_count < 40) {
                        var reduction_found = true;
                        while (reduction_found) {
                            reduction_found = false;
                            // Find patterns that match the current candidate configuration
                            var matching_patterns = getMatchingBoardClears(candidates.*);
                            // Remove patterns that cancel out (pattern + reverse both match)
                            const forward_patterns = matching_patterns & BOARD_CLEARS_HALF_MASK;
                            const reverse_patterns = matching_patterns >> 54;
                            const non_canceling = forward_patterns ^ reverse_patterns;
                            matching_patterns &= (non_canceling << 54) | non_canceling;

                            reduction_found = matching_patterns > 0;
                            while (matching_patterns > 0) : (matching_patterns = clearLowestBit(matching_patterns)) {
                                candidates.* &= BOARD_CLEARS[@ctz(matching_patterns)];
                            }
                        }
                    }

                    // ─────────────────────────────────────────────────────────
                    // Step 5: Find naked singles in houses
                    // ─────────────────────────────────────────────────────────
                    var remaining_houses = self.pending_digit_houses[digit];
                    while (remaining_houses > 0) : (remaining_houses = clearLowestBit(remaining_houses)) {
                        const house = @ctz(remaining_houses);
                        const candidates_in_house = candidates.* & HOUSE_CELLS[house];
                        const count_in_house = @popCount(candidates_in_house);

                        if (count_in_house == 0) {
                            return INVALID_DIGIT_INDEX; // No valid cell for this digit in house
                        } else if (count_in_house == 1) {
                            // Naked single - only one cell possible in this house
                            const cell = @ctz(candidates_in_house);
                            candidates.* &= CLEAR_HOUSES[cell];
                            self.pending_digit_houses[digit] &= CLEAR_HOUSE_INDEXES[cell];
                            discovered_placements[digit] |= candidates_in_house;
                            found_new_placements = true;
                        }
                    }
                }

                // Track most constrained digit for search phase
                if (candidate_count < min_candidates) {
                    min_candidates = candidate_count;
                    most_constrained_digit = digit;
                }
            } else {
                // Digit is fully placed - prioritize it for finalization
                min_candidates = 9;
                most_constrained_digit = digit;
            }
        }

        // Recurse if new placements were discovered, otherwise return best digit for search
        return if (found_new_placements)
            self.propagateConstraints(discovered_placements)
        else
            most_constrained_digit;
    }

    // =========================================================================
    // BAND-PATTERN SEARCH
    // =========================================================================

    /// Searches for a valid placement of the given digit using band patterns.
    /// A complete placement consists of 3 compatible band patterns (one per horizontal band).
    ///
    /// - `digit`: The digit (0-8) to place
    /// - `available_patterns`: Patterns still available for future digits (per band)
    ///
    /// Returns true if a valid solution was found.
    fn searchValidBands(self: *Sudoku, digit: usize, available_patterns: [3]u192) bool {
        self.pending_digits ^= BIT9[digit];

        // ─────────────────────────────────────────────────────────────────────
        // Base case: all digits placed
        // ─────────────────────────────────────────────────────────────────────
        if (self.pending_digits == 0 and self.pending_digit_houses[digit] == 0) {
            return true;
        }

        // Save state for backtracking
        const saved_pending_digits = self.pending_digits;
        const saved_candidates = self.digit_candidate_cells;
        const saved_houses = self.pending_digit_houses;

        // ─────────────────────────────────────────────────────────────────────
        // Compute valid band patterns for current digit
        // ─────────────────────────────────────────────────────────────────────
        const candidates = &self.digit_candidate_cells[digit];
        const valid_patterns: [3]u192 = .{
            getValidBandPatterns(candidates.*, 0, available_patterns[0]),
            getValidBandPatterns(candidates.*, 3, available_patterns[1]),
            getValidBandPatterns(candidates.*, 6, available_patterns[2]),
        };

        var patterns_to_reserve: [3]u192 = undefined;

        // ─────────────────────────────────────────────────────────────────────
        // Try all combinations of compatible band patterns
        // ─────────────────────────────────────────────────────────────────────
        var band0_iter = valid_patterns[0];
        while (band0_iter > 0) : (band0_iter = clearLowestBit(band0_iter)) {
            const pattern0 = @ctz(band0_iter);
            patterns_to_reserve[0] = available_patterns[0] & DIGIT_COMPATIBLE_BANDS[pattern0];

            // Skip if this pattern blocks all future patterns (unless we're on the last digit)
            if (patterns_to_reserve[0] != 0 or saved_pending_digits == 0) {
                var band1_iter = valid_patterns[1] & BOARD_COMPATIBLE_BANDS[pattern0];
                while (band1_iter > 0) : (band1_iter = clearLowestBit(band1_iter)) {
                    const pattern1 = @ctz(band1_iter);
                    patterns_to_reserve[1] = available_patterns[1] & DIGIT_COMPATIBLE_BANDS[pattern1];

                    if (patterns_to_reserve[1] != 0 or saved_pending_digits == 0) {
                        var band2_iter = valid_patterns[2] & BOARD_COMPATIBLE_BANDS[pattern0] & BOARD_COMPATIBLE_BANDS[pattern1];
                        while (band2_iter > 0) : (band2_iter = clearLowestBit(band2_iter)) {
                            const pattern2 = @ctz(band2_iter);
                            patterns_to_reserve[2] = available_patterns[2] & DIGIT_COMPATIBLE_BANDS[pattern2];

                            if (patterns_to_reserve[2] != 0 or saved_pending_digits == 0) {
                                // ─────────────────────────────────────────────
                                // Place all 9 instances of this digit
                                // ─────────────────────────────────────────────
                                candidates.* = @as(u128, VALID_BAND_CELLS[pattern0]) |
                                    @as(u128, VALID_BAND_CELLS[pattern1]) << 27 |
                                    @as(u128, VALID_BAND_CELLS[pattern2]) << 54;

                                if (saved_pending_digits == 0) {
                                    return true; // All digits placed!
                                }

                                // Propagate and recurse
                                var new_placements: [9]u128 = .{0} ** 9;
                                new_placements[digit] = candidates.*;
                                const next_digit = self.propagateConstraints(new_placements);

                                if (next_digit < INVALID_DIGIT_INDEX and self.searchValidBands(next_digit, patterns_to_reserve)) {
                                    return true;
                                }

                                // Backtrack: restore state
                                self.pending_digits = saved_pending_digits;
                                self.digit_candidate_cells = saved_candidates;
                                self.pending_digit_houses = saved_houses;
                            }
                        }
                    }
                }
            }
        }

        return false; // No valid combination found
    }
};
