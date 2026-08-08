// =============================================================================
// SUDOKU SOLVER - PRECOMPUTED LOOKUP TABLES
// =============================================================================
//
// This file contains all lookup tables computed at compile time.
// These tables encode the structure and constraints of a Sudoku puzzle,
// enabling fast bitwise operations at runtime.
//
// Table Summary:
// - BIT* arrays: Single-bit masks for indexing
// - HOUSE_CELLS: Cells belonging to each row/column/box
// - CLEAR_*: Masks for eliminating candidates from peer cells
// - VALID_BAND_CELLS: The 162 valid ways to place a digit in a 3x9 band
// - ROW_BANDS: Row mask → compatible band patterns
// - PATTERNS_FOR_*: Pattern compatibility for search pruning
// - ROW_BOARD_CLEARS: Pattern matching for box-line reduction
//
// =============================================================================

const std = @import("std");

// =============================================================================
// UNIVERSAL BIT MASKS
// =============================================================================

/// All 27 houses set (9 rows + 9 columns + 9 boxes)
pub const ALL27: usize = 0b111111111111111111111111111;

/// All 81 cells set
pub const ALL81: u81 = 0b111111111111111111111111111111111111111111111111111111111111111111111111111111111;

/// All 162 band patterns set
pub const ALL162: u192 = 0b111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111111;

// =============================================================================
// SINGLE-BIT MASKS
// =============================================================================

/// BIT9[i] = 1 << i, for selecting individual digits (0-8)
pub const BIT9 = [9]usize{
    0b000000001,
    0b000000010,
    0b000000100,
    0b000001000,
    0b000010000,
    0b000100000,
    0b001000000,
    0b010000000,
    0b100000000,
};

/// BIT27[i] = 1 << i, for selecting individual houses (0-26)
const BIT27 = [27]usize{
    0b000000000000000000000000001,
    0b000000000000000000000000010,
    0b000000000000000000000000100,
    0b000000000000000000000001000,
    0b000000000000000000000010000,
    0b000000000000000000000100000,
    0b000000000000000000001000000,
    0b000000000000000000010000000,
    0b000000000000000000100000000,
    0b000000000000000001000000000,
    0b000000000000000010000000000,
    0b000000000000000100000000000,
    0b000000000000001000000000000,
    0b000000000000010000000000000,
    0b000000000000100000000000000,
    0b000000000001000000000000000,
    0b000000000010000000000000000,
    0b000000000100000000000000000,
    0b000000001000000000000000000,
    0b000000010000000000000000000,
    0b000000100000000000000000000,
    0b000001000000000000000000000,
    0b000010000000000000000000000,
    0b000100000000000000000000000,
    0b001000000000000000000000000,
    0b010000000000000000000000000,
    0b100000000000000000000000000,
};

/// BIT81[i] = 1 << i, for selecting individual cells (0-80)
pub const BIT81 = [81]u81{
    0b000000000000000000000000000000000000000000000000000000000000000000000000000000001,
    0b000000000000000000000000000000000000000000000000000000000000000000000000000000010,
    0b000000000000000000000000000000000000000000000000000000000000000000000000000000100,
    0b000000000000000000000000000000000000000000000000000000000000000000000000000001000,
    0b000000000000000000000000000000000000000000000000000000000000000000000000000010000,
    0b000000000000000000000000000000000000000000000000000000000000000000000000000100000,
    0b000000000000000000000000000000000000000000000000000000000000000000000000001000000,
    0b000000000000000000000000000000000000000000000000000000000000000000000000010000000,
    0b000000000000000000000000000000000000000000000000000000000000000000000000100000000,
    0b000000000000000000000000000000000000000000000000000000000000000000000001000000000,
    0b000000000000000000000000000000000000000000000000000000000000000000000010000000000,
    0b000000000000000000000000000000000000000000000000000000000000000000000100000000000,
    0b000000000000000000000000000000000000000000000000000000000000000000001000000000000,
    0b000000000000000000000000000000000000000000000000000000000000000000010000000000000,
    0b000000000000000000000000000000000000000000000000000000000000000000100000000000000,
    0b000000000000000000000000000000000000000000000000000000000000000001000000000000000,
    0b000000000000000000000000000000000000000000000000000000000000000010000000000000000,
    0b000000000000000000000000000000000000000000000000000000000000000100000000000000000,
    0b000000000000000000000000000000000000000000000000000000000000001000000000000000000,
    0b000000000000000000000000000000000000000000000000000000000000010000000000000000000,
    0b000000000000000000000000000000000000000000000000000000000000100000000000000000000,
    0b000000000000000000000000000000000000000000000000000000000001000000000000000000000,
    0b000000000000000000000000000000000000000000000000000000000010000000000000000000000,
    0b000000000000000000000000000000000000000000000000000000000100000000000000000000000,
    0b000000000000000000000000000000000000000000000000000000001000000000000000000000000,
    0b000000000000000000000000000000000000000000000000000000010000000000000000000000000,
    0b000000000000000000000000000000000000000000000000000000100000000000000000000000000,
    0b000000000000000000000000000000000000000000000000000001000000000000000000000000000,
    0b000000000000000000000000000000000000000000000000000010000000000000000000000000000,
    0b000000000000000000000000000000000000000000000000000100000000000000000000000000000,
    0b000000000000000000000000000000000000000000000000001000000000000000000000000000000,
    0b000000000000000000000000000000000000000000000000010000000000000000000000000000000,
    0b000000000000000000000000000000000000000000000000100000000000000000000000000000000,
    0b000000000000000000000000000000000000000000000001000000000000000000000000000000000,
    0b000000000000000000000000000000000000000000000010000000000000000000000000000000000,
    0b000000000000000000000000000000000000000000000100000000000000000000000000000000000,
    0b000000000000000000000000000000000000000000001000000000000000000000000000000000000,
    0b000000000000000000000000000000000000000000010000000000000000000000000000000000000,
    0b000000000000000000000000000000000000000000100000000000000000000000000000000000000,
    0b000000000000000000000000000000000000000001000000000000000000000000000000000000000,
    0b000000000000000000000000000000000000000010000000000000000000000000000000000000000,
    0b000000000000000000000000000000000000000100000000000000000000000000000000000000000,
    0b000000000000000000000000000000000000001000000000000000000000000000000000000000000,
    0b000000000000000000000000000000000000010000000000000000000000000000000000000000000,
    0b000000000000000000000000000000000000100000000000000000000000000000000000000000000,
    0b000000000000000000000000000000000001000000000000000000000000000000000000000000000,
    0b000000000000000000000000000000000010000000000000000000000000000000000000000000000,
    0b000000000000000000000000000000000100000000000000000000000000000000000000000000000,
    0b000000000000000000000000000000001000000000000000000000000000000000000000000000000,
    0b000000000000000000000000000000010000000000000000000000000000000000000000000000000,
    0b000000000000000000000000000000100000000000000000000000000000000000000000000000000,
    0b000000000000000000000000000001000000000000000000000000000000000000000000000000000,
    0b000000000000000000000000000010000000000000000000000000000000000000000000000000000,
    0b000000000000000000000000000100000000000000000000000000000000000000000000000000000,
    0b000000000000000000000000001000000000000000000000000000000000000000000000000000000,
    0b000000000000000000000000010000000000000000000000000000000000000000000000000000000,
    0b000000000000000000000000100000000000000000000000000000000000000000000000000000000,
    0b000000000000000000000001000000000000000000000000000000000000000000000000000000000,
    0b000000000000000000000010000000000000000000000000000000000000000000000000000000000,
    0b000000000000000000000100000000000000000000000000000000000000000000000000000000000,
    0b000000000000000000001000000000000000000000000000000000000000000000000000000000000,
    0b000000000000000000010000000000000000000000000000000000000000000000000000000000000,
    0b000000000000000000100000000000000000000000000000000000000000000000000000000000000,
    0b000000000000000001000000000000000000000000000000000000000000000000000000000000000,
    0b000000000000000010000000000000000000000000000000000000000000000000000000000000000,
    0b000000000000000100000000000000000000000000000000000000000000000000000000000000000,
    0b000000000000001000000000000000000000000000000000000000000000000000000000000000000,
    0b000000000000010000000000000000000000000000000000000000000000000000000000000000000,
    0b000000000000100000000000000000000000000000000000000000000000000000000000000000000,
    0b000000000001000000000000000000000000000000000000000000000000000000000000000000000,
    0b000000000010000000000000000000000000000000000000000000000000000000000000000000000,
    0b000000000100000000000000000000000000000000000000000000000000000000000000000000000,
    0b000000001000000000000000000000000000000000000000000000000000000000000000000000000,
    0b000000010000000000000000000000000000000000000000000000000000000000000000000000000,
    0b000000100000000000000000000000000000000000000000000000000000000000000000000000000,
    0b000001000000000000000000000000000000000000000000000000000000000000000000000000000,
    0b000010000000000000000000000000000000000000000000000000000000000000000000000000000,
    0b000100000000000000000000000000000000000000000000000000000000000000000000000000000,
    0b001000000000000000000000000000000000000000000000000000000000000000000000000000000,
    0b010000000000000000000000000000000000000000000000000000000000000000000000000000000,
    0b100000000000000000000000000000000000000000000000000000000000000000000000000000000,
};

// =============================================================================
// HOUSE DEFINITIONS
// =============================================================================
//
// A "house" is a row, column, or box - any group of 9 cells that must
// contain each digit exactly once.
//
// House indices:
//   0-8:   Rows (top to bottom)
//   9-17:  Columns (left to right)
//   18-26: Boxes (left-to-right, top-to-bottom)

/// Cells within a band's 6 "mini-houses" (3 rows + 3 boxes within one band)
const BAND_HOUSE_CELLS = [6]usize{
    0b000000000000000000111111111, // Row 0 of band
    0b000000000111111111000000000, // Row 1 of band
    0b111111111000000000000000000, // Row 2 of band
    0b000000111000000111000000111, // Box 0 of band (leftmost)
    0b000111000000111000000111000, // Box 1 of band (middle)
    0b111000000111000000111000000, // Box 2 of band (rightmost)
};

/// HOUSE_CELLS[h] = bitmask of all cells in house h
/// Houses 0-8: rows, 9-17: columns, 18-26: boxes
pub const HOUSE_CELLS = [27]u81{
    // Rows 0-8
    0b000000000000000000000000000000000000000000000000000000000000000000000000111111111,
    0b000000000000000000000000000000000000000000000000000000000000000111111111000000000,
    0b000000000000000000000000000000000000000000000000000000111111111000000000000000000,
    0b000000000000000000000000000000000000000000000111111111000000000000000000000000000,
    0b000000000000000000000000000000000000111111111000000000000000000000000000000000000,
    0b000000000000000000000000000111111111000000000000000000000000000000000000000000000,
    0b000000000000000000111111111000000000000000000000000000000000000000000000000000000,
    0b000000000111111111000000000000000000000000000000000000000000000000000000000000000,
    0b111111111000000000000000000000000000000000000000000000000000000000000000000000000,
    // Columns 0-8
    0b000000001000000001000000001000000001000000001000000001000000001000000001000000001,
    0b000000010000000010000000010000000010000000010000000010000000010000000010000000010,
    0b000000100000000100000000100000000100000000100000000100000000100000000100000000100,
    0b000001000000001000000001000000001000000001000000001000000001000000001000000001000,
    0b000010000000010000000010000000010000000010000000010000000010000000010000000010000,
    0b000100000000100000000100000000100000000100000000100000000100000000100000000100000,
    0b001000000001000000001000000001000000001000000001000000001000000001000000001000000,
    0b010000000010000000010000000010000000010000000010000000010000000010000000010000000,
    0b100000000100000000100000000100000000100000000100000000100000000100000000100000000,
    // Boxes 0-8
    0b000000000000000000000000000000000000000000000000000000000000111000000111000000111,
    0b000000000000000000000000000000000000000000000000000000000111000000111000000111000,
    0b000000000000000000000000000000000000000000000000000000111000000111000000111000000,
    0b000000000000000000000000000000000111000000111000000111000000000000000000000000000,
    0b000000000000000000000000000000111000000111000000111000000000000000000000000000000,
    0b000000000000000000000000000111000000111000000111000000000000000000000000000000000,
    0b000000111000000111000000111000000000000000000000000000000000000000000000000000000,
    0b000111000000111000000111000000000000000000000000000000000000000000000000000000000,
    0b111000000111000000111000000000000000000000000000000000000000000000000000000000000,
};

// =============================================================================
// CANDIDATE ELIMINATION MASKS
// =============================================================================

/// CLEAR_BAND_HOUSES[cell] = mask that preserves houses NOT containing this cell
/// (for cells 0-26 within a single band)
fn generate_clear_band_houses() [27]usize {
    var masks: [27]usize = undefined;
    for (0..27) |cell| {
        const row = cell / 9;
        const box = (cell % 9) / 3;
        // All houses except this cell's row and box, plus the cell itself
        masks[cell] = ((BAND_HOUSE_CELLS[row] | BAND_HOUSE_CELLS[box + 3]) ^ ALL27) | BIT27[cell];
    }
    return masks;
}

const CLEAR_BAND_HOUSES = generate_clear_band_houses();

/// CLEAR_HOUSES[cell] = mask to keep this cell + eliminate all 20 peer cells
/// (All cells sharing a row, column, or box with this cell are zeroed)
fn generate_clear_houses() [81]u81 {
    var masks: [81]u81 = undefined;
    for (0..81) |cell| {
        const row = cell / 9;
        const col = cell % 9;
        const box = (row / 3) * 3 + (col / 3);
        // XOR removes all cells in same row/col/box, then OR adds back this cell
        masks[cell] = ((HOUSE_CELLS[row] | HOUSE_CELLS[col + 9] | HOUSE_CELLS[box + 18]) ^ ALL81) | BIT81[cell];
    }
    return masks;
}

pub const CLEAR_HOUSES = generate_clear_houses();

/// CLEAR_HOUSE_INDEXES[cell] = mask to mark houses as "satisfied" when placing at cell
/// Returns complement of the 3 house bits (row, column, box) that this cell belongs to
fn generate_clear_house_indexes() [81]usize {
    var masks: [81]usize = undefined;
    for (0..81) |cell| {
        const row = cell / 9;
        const col = cell % 9;
        const box = (row / 3) * 3 + (col / 3);
        masks[cell] = (BIT9[row] | BIT9[col] << 9 | BIT9[box] << 18) ^ ALL27;
    }
    return masks;
}

pub const CLEAR_HOUSE_INDEXES = generate_clear_house_indexes();

// =============================================================================
// BAND PATTERNS
// =============================================================================
//
// A "band" is a horizontal strip of 3 rows (rows 0-2, 3-5, or 6-8).
// For any digit, there are exactly 162 valid ways to place its 3 instances
// within a band such that:
//   - One instance per row
//   - One instance per box (within the band)
//   - All three in different columns
//

/// VALID_BAND_CELLS[i] = the 27-bit pattern for the i-th valid band placement
/// Each pattern has exactly 3 bits set (one per row in the band)
fn generate_valid_band_cells() [162]usize {
    @setEvalBranchQuota(10000);
    var patterns: [162]usize = .{0} ** 162;
    patterns[0] = ALL27; // Start with all cells available

    // Progressively constrain by placing one cell per row
    for (0..3) |row| {
        var write_index: u8 = 0;
        for (patterns) |pattern| {
            if (pattern == 0) break;

            // Get columns available in this row
            const available_cols: usize = (pattern & BAND_HOUSE_CELLS[row]) >> row * 9;
            for (0..9) |col| {
                if (available_cols & BIT9[col] != 0) {
                    // Place digit at (row, col) and eliminate peers
                    patterns[write_index] = pattern & CLEAR_BAND_HOUSES[row * 9 + col];
                    write_index += 1;
                }
            }
        }
    }
    return patterns;
}

pub const VALID_BAND_CELLS = generate_valid_band_cells();

// =============================================================================
// ROW → BAND PATTERN MAPPING
// =============================================================================
//
// ROW_BANDS enables instant lookup of which band patterns are compatible
// with a given row's candidate mask.
//

/// ROW_BANDS[row_in_band][row_candidates] = bitmask of compatible band patterns
/// row_in_band: 0, 1, or 2 (position within band)
/// row_candidates: 9-bit mask of columns where digit can go in that row
fn generate_row_bands() [3][512]u192 {
    @setEvalBranchQuota(100000);
    var table: [3][512]u192 = .{.{0} ** 512} ** 3;

    for (VALID_BAND_CELLS, 0..) |pattern, pattern_index| {
        const row0_cols: usize = pattern & 0b111111111;
        const row1_cols: usize = pattern >> 9 & 0b111111111;
        const row2_cols: usize = pattern >> 18 & 0b111111111;

        // For each possible row candidate mask, check if this pattern fits
        for (0..512) |candidates| {
            if (row0_cols & candidates == row0_cols) {
                table[0][candidates] |= @as(u192, 1) << @intCast(pattern_index);
            }
            if (row1_cols & candidates == row1_cols) {
                table[1][candidates] |= @as(u192, 1) << @intCast(pattern_index);
            }
            if (row2_cols & candidates == row2_cols) {
                table[2][candidates] |= @as(u192, 1) << @intCast(pattern_index);
            }
        }
    }
    return table;
}

pub const ROW_BANDS = generate_row_bands();

// =============================================================================
// BOX-LINE REDUCTION TABLES
// =============================================================================
//
// Box-line reduction: When a digit within a box is confined to a single row/col,
// it can be eliminated from that row/col in other boxes.
//
// These tables encode 108 reduction patterns:
// - Patterns 0-53: "If digit is in row R of box B, eliminate from row R outside B"
// - Patterns 54-107: Reverse patterns (for symmetric eliminations)
//

fn update_row_board_clears(
    table: *[9][512]u128,
    forward_idx: usize,
    reverse_idx: usize,
    pattern_a: u128,
    pattern_b: u128,
) void {
    for (0..9) |row| {
        const pattern_a_row = (pattern_a >> (row * 9)) & 0b111111111;
        const pattern_b_row = (pattern_b >> (row * 9)) & 0b111111111;
        var max_row: usize = 0;
        if (pattern_a_row > pattern_b_row) {
            max_row = pattern_a_row;
        } else {
            max_row = pattern_b_row;
        }
        for (1..max_row) |candidates| {
            if (pattern_a_row & candidates == candidates) {
                table[row][candidates] |= @as(u128, 1) << @intCast(forward_idx);
            }
            if (pattern_b_row & candidates == candidates) {
                table[row][candidates] |= @as(u128, 1) << @intCast(reverse_idx);
            }
        }
    }
}

/// Houses containing cells REMOVED by a keep-mask (the complement of the
/// stored 81-bit cell mask, ~6 cells per board-clear pattern).
fn houses_of_removed_cells(keep: u128) usize {
    var houses: usize = 0;
    var removed = @as(u128, ALL81) ^ keep;
    while (removed > 0) : (removed &= removed - 1) {
        // CLEAR_HOUSE_INDEXES is a complement mask; XOR recovers the
        // positive house mask (row | col << 9 | box << 18)
        houses |= ALL27 ^ CLEAR_HOUSE_INDEXES[@ctz(removed)];
    }
    // fwd = box∩row/col (5 houses: row/col + box + 3 cols/rows),
    // rev = row/col outside box (9 houses: row/col + 6 cols/rows + 2 boxes)
    std.debug.assert(@popCount(houses) >= 5 and @popCount(houses) <= 9);
    return houses;
}

fn generate_row_based_board_clears() struct { [9][512]u128, [108]u128 } {
    @setEvalBranchQuota(1000000);
    var row_lookup: [9][512]u128 = .{.{0} ** 512} ** 9;
    var clear_masks: [108]u128 = undefined;
    var forward_index: usize = 0;
    var reverse_index: usize = 54;

    for (0..9) |box| {
        const first_row = (box / 3) * 3;
        const first_col = (box % 3) * 3;

        // Row-based reductions for this box
        for (first_row..first_row + 3) |row| {
            // Pattern A: Digit confined to row within box → clear row outside box
            // Pattern B: Digit confined to box within row → clear box outside row
            const pattern_a = (ALL81 ^ HOUSE_CELLS[row]) | HOUSE_CELLS[box + 18];
            const pattern_b = (ALL81 ^ HOUSE_CELLS[box + 18]) | HOUSE_CELLS[row];
            update_row_board_clears(&row_lookup, forward_index, reverse_index, pattern_a, pattern_b);
            // Pack the removed-cells house mask into spare bits 81-107 so the
            // apply loop derives both the cell mask and the houses from one load.
            clear_masks[forward_index] = pattern_b | @as(u128, houses_of_removed_cells(pattern_b)) << 81;
            clear_masks[reverse_index] = pattern_a | @as(u128, houses_of_removed_cells(pattern_a)) << 81;
            forward_index += 1;
            reverse_index += 1;
        }

        // Column-based reductions for this box
        for (first_col..first_col + 3) |col| {
            const pattern_a = (ALL81 ^ HOUSE_CELLS[col + 9]) | HOUSE_CELLS[box + 18];
            const pattern_b = (ALL81 ^ HOUSE_CELLS[box + 18]) | HOUSE_CELLS[col + 9];
            update_row_board_clears(&row_lookup, forward_index, reverse_index, pattern_a, pattern_b);
            clear_masks[forward_index] = pattern_b | @as(u128, houses_of_removed_cells(pattern_b)) << 81;
            clear_masks[reverse_index] = pattern_a | @as(u128, houses_of_removed_cells(pattern_a)) << 81;
            forward_index += 1;
            reverse_index += 1;
        }
    }
    return .{ row_lookup, clear_masks };
}

const ROW_BASED_BOARD_CLEARS = generate_row_based_board_clears();

/// ROW_BOARD_CLEARS[row][row_candidates] = bitmask of applicable reduction patterns
pub const ROW_BOARD_CLEARS = ROW_BASED_BOARD_CLEARS[0];

/// BOARD_CLEARS[pattern_index] = cell mask to apply when reduction pattern matches
pub const BOARD_CLEARS = ROW_BASED_BOARD_CLEARS[1];

// =============================================================================
// BAND PATTERN COMPATIBILITY
// =============================================================================
//
// When searching for valid digit placements, we need to know which band patterns
// are compatible with each other:
//
// 1. PATTERNS_FOR_OTHER_DIGITS: Patterns that don't share any cells
//    Used to reserve space for future digits - if we use pattern P for digit 5,
//    other digits can only use patterns that don't overlap with P's cells.
//
// 2. PATTERNS_FOR_SAME_DIGIT: Patterns that use different column sets
//    Used when placing all 9 instances of a single digit - the 3 band patterns
//    must use disjoint columns (since each digit appears once per column).
//

/// PATTERNS_FOR_OTHER_DIGITS[p] = patterns that share no cells with pattern p
/// Reserves space: if digit D uses pattern p, other digits can only use these patterns
fn generate_digit_compatible_bands() [162]u192 {
    @setEvalBranchQuota(100000);
    var compat: [162]u192 = undefined;

    for (VALID_BAND_CELLS, 0..) |pattern1, i| {
        var mask: u192 = 0;
        for (VALID_BAND_CELLS, 0..) |pattern2, j| {
            // Compatible if no cells overlap
            if (pattern1 & pattern2 == 0) {
                mask |= @as(u192, 1) << @intCast(j);
            }
        }
        compat[i] = mask;
    }
    return compat;
}

pub const PATTERNS_FOR_OTHER_DIGITS = generate_digit_compatible_bands();

/// PATTERNS_FOR_SAME_DIGIT[p] = patterns that use completely different columns
/// Column constraint: a digit's 3 band patterns must cover disjoint column sets
fn generate_board_compatible_bands() [162]u192 {
    @setEvalBranchQuota(100000);
    var compat: [162]u192 = undefined;

    for (VALID_BAND_CELLS, 0..) |pattern1, i| {
        var mask: u192 = 0;
        // Collapse pattern to column set (OR all 3 rows together)
        const cols1 = pattern1 | pattern1 >> 9 | pattern1 >> 18;

        for (VALID_BAND_CELLS, 0..) |pattern2, j| {
            const cols2 = pattern2 | pattern2 >> 9 | pattern2 >> 18;
            // Compatible if column sets don't overlap
            if (cols1 & cols2 == 0) {
                mask |= @as(u192, 1) << @intCast(j);
            }
        }
        compat[i] = mask;
    }
    return compat;
}

pub const PATTERNS_FOR_SAME_DIGIT = generate_board_compatible_bands();
