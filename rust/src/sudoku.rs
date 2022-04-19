mod list;

const BIT9: [usize; 9] = list::BIT9;
const GROUPS: [u128; 27] = list::GROUPS;
const SET_CELLS: [u128; 81] = list::SET_CELLS;
const POSSIBLE: [[usize; 937]; 54] = list::POSSIBLE;
const BIT81: [u128; 81] = list::BIT81;

fn get_bits_list(bits: usize) -> Vec<usize> {
    BIT9.iter()
        .enumerate()
        .filter(|bit| bits & bit.1 != 0)
        .map(|bit| bit.0)
        .collect::<Vec<usize>>()
}

fn get_bits_lists() -> [Vec<usize>; 512] {
    const INIT: Vec<usize> = vec![];
    let mut bits_list = [INIT; 512];
    let mut bits = 0;
    while bits < 512 {
        bits_list[bits] = get_bits_list(bits);
        bits += 1;
    }
    bits_list
}

lazy_static! {
    pub static ref BITS_LISTS: [Vec<usize>; 512] = get_bits_lists();
}

const ALL81: u128 =
    0b111111111111111111111111111111111111111111111111111111111111111111111111111111111;

struct Board {
    is_sudoku: bool,
    numbers: usize,
    number_cells: [u128; 9],
}

impl Board {
    fn new(cell_values: [usize; 81]) -> String {
        let mut board = Board {
            is_sudoku: true,
            numbers: 0b111111111,
            number_cells: [ALL81; 9],
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

        let shortest = board.remove_from_others(remove_from_others);
        board.trial_and_error(shortest);
        assert!(board.is_sudoku);

        let mut solved: [u32; 81] = [0; 81];
        for (number, cells) in board.number_cells.iter_mut().enumerate() {
            let mut cell_index = 0;
            while *cells > 0 {
                let tz = cells.trailing_zeros() as usize;
                cell_index += tz;
                solved[cell_index] = (number + 1) as u32;
                *cells >>= tz + 1;
                cell_index += 1;
            }
        }
        solved
            .iter()
            .map(|n| char::from_digit(*n, 10).unwrap())
            .collect()
    }
    fn remove_from_others(&mut self, remove_from_others: [u128; 9]) -> (usize, u32) {
        let mut shortest_length = 81;
        let mut shortest_number = 0;
        let mut new_remove_from_others = [0; 9];
        let mut new_remove = false;
        for number in BITS_LISTS.get(self.numbers).unwrap().iter() {
            let mut union = 0;
            for (remove_number, remove) in remove_from_others.iter().enumerate() {
                if *number != remove_number {
                    union |= *remove;
                }
            }
            let cells = self.number_cells.get_mut(*number).unwrap();
            let removed = *cells & !union;
            if removed != *cells {
                *cells = removed;
                let ones = cells.count_ones();
                if ones < 9 {
                    self.is_sudoku = false;
                    return (0, 0);
                }
                for group_mask in GROUPS.iter() {
                    let group = *cells & *group_mask;
                    let group_ones = group.count_ones();
                    if group_ones == 0 {
                        self.is_sudoku = false;
                        return (0, 0);
                    } else if group_ones == 1 {
                        let set_cells = *cells & SET_CELLS[group.trailing_zeros() as usize];
                        if *cells != set_cells {
                            *cells = set_cells;
                            new_remove_from_others[*number] |= group;
                            new_remove = true;
                        }
                    }
                }
                if ones < shortest_length {
                    shortest_number = *number;
                    shortest_length = ones;
                }
            } else {
                let ones = cells.count_ones();
                if ones < shortest_length {
                    shortest_number = *number;
                    shortest_length = ones;
                }
            }
        }
        if new_remove {
            self.remove_from_others(new_remove_from_others)
        } else {
            (shortest_number, shortest_length)
        }
    }
    fn remove_single_from_others(&mut self, number: usize, cells: u128) -> (usize, u32) {
        let mut remove_from_others = [0; 9];
        remove_from_others[number] = cells;
        self.remove_from_others(remove_from_others)
    }
    fn trial_and_error(&mut self, shortest: (usize, u32)) {
        if self.is_sudoku == false {
            return;
        }

        let (number, length) = shortest;

        self.numbers ^= BIT9[number];
        let cells = self.number_cells[number];

        if length == 9 {
            if self.numbers != 0 {
                let shortest = self.remove_single_from_others(number, cells);
                self.trial_and_error(shortest);
            }
            return;
        }

        let numbers = self.numbers;
        let number_cells = self.number_cells.clone();

        let first_group = (cells & 0b111111111111111111) as usize;
        let second_group = ((cells >> 18) & 0b111111111111111111111111111) as usize;
        let third_group = ((cells >> 45) & 0b111111111111111111111111111111111111) as usize;

        for sub_list in POSSIBLE.iter() {
            let first = sub_list[0];
            if first & first_group == first {
                for index in (1..925).step_by(13) {
                    let second = sub_list[index];
                    if second & second_group == second {
                        for index in index + 1..index + 13 {
                            let third = sub_list[index];
                            if third & third_group == third {
                                self.number_cells[number] =
                                    (third as u128) << 45 | (second as u128) << 18 | first as u128;
                                self.is_sudoku = true;
                                if self.numbers == 0 {
                                    return;
                                }
                                let shortest = self
                                    .remove_single_from_others(number, self.number_cells[number]);
                                self.trial_and_error(shortest);
                                if self.is_sudoku {
                                    return;
                                } else {
                                    self.numbers = numbers;
                                    self.number_cells = number_cells.clone();
                                }
                            }
                        }
                    }
                }
            }
        }
        self.is_sudoku = false;
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
