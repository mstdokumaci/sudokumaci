use crate::bitset;
pub mod list;

const GROUPS: [u128; 27] = list::GROUPS;
const SET_CELLS: [u128; 81] = list::SET_CELLS;
const POSSIBLES: [usize; 162] = list::POSSIBLES;
const POSSIBLE_COMBINATONS: [[usize; 3]; 162] = list::POSSIBLE_COMBINATONS;
const ROW_COMBINATONS: [[usize; 3]; 162] = list::ROW_COMBINATONS;
const BIT81: [u128; 81] = list::BIT81;
const ALL81: u128 = list::ALL81;

struct Board {
    is_sudoku: bool,
    number_cells: [u128; 9],
    numbers: [usize; 9],
    number_rows: [[usize; 3]; 9],
    number_row_matches: [[usize; 3]; 9],
}

impl Board {
    fn new(cell_values: [usize; 81]) -> String {
        let mut board = Board {
            is_sudoku: true,
            number_cells: [ALL81; 9],
            numbers: [0; 9],
            number_rows: [[0; 3]; 9],
            number_row_matches: [[0; 3]; 9],
        };

        let mut remove_from_others = [0; 9];

        for cell_index in 0..81 {
            let value = cell_values[cell_index];
            if value > 0 {
                let number = value - 1;
                board.number_cells[number] &= SET_CELLS[cell_index];
                remove_from_others[number] |= BIT81[cell_index];
            }
        }

        board.remove_from_others(remove_from_others);
        assert!(board.is_sudoku);

        board.prepare();
        board.is_sudoku = board.find_match(
            0,
            [[
                0b1111111111111111111111111111111111111111111111111111111111111111,
                0b1111111111111111111111111111111111111111111111111111111111111111,
                0b1111111111111111111111111111111111,
            ]; 3],
        );
        assert!(board.is_sudoku);

        let mut solved: [u32; 81] = [0; 81];
        for (number, number_row_match) in board.number_row_matches.iter().enumerate() {
            let mut cells = POSSIBLES[number_row_match[0]] as u128
                | (POSSIBLES[number_row_match[1]] as u128) << 27
                | (POSSIBLES[number_row_match[2]] as u128) << 54;
            let mut cell_index = 0;
            while cells != 0 {
                let tz = cells.trailing_zeros() as usize;
                cell_index += tz;
                solved[cell_index] = (number + 1) as u32;
                cells >>= tz + 1;
                cell_index += 1;
            }
        }
        solved
            .iter()
            .map(|n| char::from_digit(*n, 10).unwrap())
            .collect()
    }
    fn remove_from_others(&mut self, remove_from_others: [u128; 9]) {
        let mut new_remove_from_others = [0; 9];
        let mut new_remove = false;
        for number in 0..9 {
            let mut union = 0;
            for (remove_number, remove) in remove_from_others.iter().enumerate() {
                if number != remove_number {
                    union |= *remove;
                }
            }
            let cells = self.number_cells.get_mut(number).unwrap();
            let removed = *cells & !union;
            if removed != *cells {
                *cells = removed;
                for group_mask in GROUPS.iter() {
                    let group = *cells & *group_mask;
                    let group_ones = group.count_ones();
                    if group_ones == 0 {
                        self.is_sudoku = false;
                        return;
                    } else if group_ones == 1 {
                        let set_cells = *cells & SET_CELLS[group.trailing_zeros() as usize];
                        if set_cells != *cells {
                            *cells = set_cells;
                            new_remove_from_others[number] |= group;
                            new_remove = true;
                        }
                    }
                }
            }
        }
        if new_remove {
            self.remove_from_others(new_remove_from_others)
        }
    }
    fn prepare(&mut self) {
        let mut number_cells: Vec<(usize, &u128)> = self.number_cells.iter().enumerate().collect();
        number_cells.sort_unstable_by(|a, b| a.1.count_ones().cmp(&b.1.count_ones()));
        for (i, (number, _)) in number_cells.iter().enumerate() {
            self.numbers[i] = *number;
            self.number_rows[*number] = [
                (self.number_cells[*number] & 0b111111111111111111111111111) as usize,
                ((self.number_cells[*number] >> 27) & 0b111111111111111111111111111) as usize,
                ((self.number_cells[*number] >> 54) & 0b111111111111111111111111111) as usize,
            ]
        }
    }
    fn find_match(&mut self, number_index: usize, bit_lists: [[usize; 3]; 3]) -> bool {
        let number = self.numbers[number_index];
        let number_rows = self.number_rows[number];
        let biterator0 = bitset::BitSetTraverse::new(bit_lists[0]).into_iter();
        for row0_index in biterator0 {
            if number_rows[0] & POSSIBLES[row0_index] == POSSIBLES[row0_index] {
                let biterator1 = bitset::BitSetTraverse::new(bitset::intersect2(
                    &bit_lists[1],
                    &ROW_COMBINATONS[row0_index],
                ))
                .into_iter();
                for row1_index in biterator1 {
                    if number_rows[1] & POSSIBLES[row1_index] == POSSIBLES[row1_index] {
                        let biterator2 = bitset::BitSetTraverse::new(bitset::intersect3(
                            &bit_lists[2],
                            &ROW_COMBINATONS[row0_index],
                            &ROW_COMBINATONS[row1_index],
                        ))
                        .into_iter();
                        for row2_index in biterator2 {
                            if (number_rows[2] & POSSIBLES[row2_index] == POSSIBLES[row2_index])
                                && (number_index == 8
                                    || self.find_match(
                                        number_index + 1,
                                        [
                                            bitset::intersect2(
                                                &bit_lists[0],
                                                &POSSIBLE_COMBINATONS[row0_index],
                                            ),
                                            bitset::intersect2(
                                                &bit_lists[1],
                                                &POSSIBLE_COMBINATONS[row1_index],
                                            ),
                                            bitset::intersect2(
                                                &bit_lists[2],
                                                &POSSIBLE_COMBINATONS[row2_index],
                                            ),
                                        ],
                                    ))
                            {
                                self.number_row_matches[number] =
                                    [row0_index, row1_index, row2_index];
                                return true;
                            }
                        }
                    }
                }
            }
        }
        false
    }
}

pub fn solve(puzzle: &str) -> String {
    assert_eq!(puzzle.len(), 81);
    let mut cell_values = [0; 81];
    for (index, value) in puzzle
        .chars()
        .map(|c| c.to_digit(10).unwrap() as usize)
        .enumerate()
    {
        cell_values[index] = value;
    }
    Board::new(cell_values)
}
