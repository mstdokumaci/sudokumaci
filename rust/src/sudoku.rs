const fn get_cell_index(group: usize, pos: usize) -> usize {
    let gindex: usize = group / 9 | 0;
    let group = group % 9;
    match gindex {
        0 => (group * 9 + pos),
        1 => (pos * 9 + group),
        2 => ((group / 3 | 0) * 27 + (pos / 3 | 0) * 9 + (group % 3) * 3 + (pos % 3)),
        _ => unreachable!(),
    }
}

const fn get_cell_indexes() -> [[usize; 9]; 27] {
    let mut map = [[0; 9]; 27];
    let mut group: usize = 0;
    let mut pos: usize = 0;
    while group < 27 {
        while pos < 9 {
            map[group][pos] = get_cell_index(group, pos);
            pos += 1;
        }
        group += 1;
        pos = 0;
    }
    map
}

const CELL_INDEX: [[usize; 9]; 27] = get_cell_indexes();

const BIT9: [usize; 9] = [
    0b1,
    0b10,
    0b100,
    0b1000,
    0b10000,
    0b100000,
    0b1000000,
    0b10000000,
    0b100000000,
];

fn get_bits_list_for_bits(bits: usize) -> Vec<usize> {
    let mut list: Vec<usize> = vec![];
    let mut bit: usize = 0;
    while bit < 9 {
        if bits & BIT9[bit] != 0 {
            list.push(bit);
        }
        bit += 1;
    }
    list
}

fn get_bits_list() -> [Vec<usize>; 512] {
    const INIT: Vec<usize> = vec![];
    let mut bits_list: [Vec<usize>; 512] = [INIT; 512];
    let mut bits = 0;
    while bits < 512 {
        bits_list[bits] = get_bits_list_for_bits(bits);
        bits += 1;
    }
    bits_list
}

lazy_static! {
    static ref BITS_LIST: [Vec<usize>; 512] = get_bits_list();
}

struct Biterator {
    bits: usize,
    index: usize,
}

impl Biterator {
    fn new(bits: usize) -> Biterator {
        Biterator { bits, index: 0 }
    }
}

impl Iterator for Biterator {
    type Item = usize;

    fn next(&mut self) -> Option<usize> {
        while self.bits & 1 == 0 {
            if self.bits == 0 {
                return None;
            }
            self.bits >>= 1;
            self.index += 1;
        }
        self.bits >>= 1;
        self.index += 1;
        Some(self.index - 1)
    }
}

fn get_subbits(super_bits: usize) -> Vec<usize> {
    let mut subbits_list: Vec<usize> = vec![];
    let super_length = super_bits.count_ones() as usize;
    let mut sub_bits = 0;
    while sub_bits < super_bits {
        sub_bits += 1;
        let sub_length = sub_bits.count_ones() as usize;
        if sub_bits & !super_bits == 0 && sub_length < super_length && sub_length > 1 {
            subbits_list.push(sub_bits);
        }
    }
    subbits_list
}

fn get_subbits_list() -> [Vec<usize>; 512] {
    const INIT: Vec<usize> = vec![];
    let mut subbits_list: [Vec<usize>; 512] = [INIT; 512];
    let mut bits = 0;
    while bits < 512 {
        subbits_list[bits] = get_subbits(bits);
        bits += 1;
    }
    subbits_list
}

lazy_static! {
    static ref SUBBITS_LIST: [Vec<usize>; 512] = get_subbits_list();
}

#[derive(Copy, Clone)]
struct GroupPos {
    group: usize,
    pos: usize,
}

const fn get_gps(index: usize) -> [GroupPos; 3] {
    let row = index / 9 | 0;
    let col = index % 9;
    let sqr = (row / 3 | 0) * 3 + (col / 3 | 0);
    let pos = row % 3 * 3 + col % 3;
    [
        GroupPos {
            group: row,
            pos: col,
        },
        GroupPos {
            group: col + 9,
            pos: row,
        },
        GroupPos {
            group: sqr + 18,
            pos: pos,
        },
    ]
}

const fn get_cell_gps() -> [[GroupPos; 3]; 81] {
    let mut map = [[GroupPos { group: 0, pos: 0 }; 3]; 81];
    let mut index: usize = 0;
    while index < 81 {
        map[index] = get_gps(index);
        index += 1;
    }
    map
}

const CELL_GROUP_POS: [[GroupPos; 3]; 81] = get_cell_gps();

struct Shortest {
    length: usize,
    index: usize,
}

const EMPTY_SHORTEST: Shortest = Shortest {
    length: 10,
    index: 81,
};

struct Board {
    is_sudoku: bool,
    group_cells: [usize; 27],
    group_negatives: [usize; 27],
    cell_candidates: [usize; 81],
    changed_groups: usize,
    shortest: Shortest,
}

impl Board {
    fn new(cell_values: [usize; 81]) -> String {
        let mut board = Board {
            is_sudoku: true,
            group_cells: [0; 27],
            group_negatives: [0; 27],
            cell_candidates: [0; 81],
            changed_groups: 0,
            shortest: EMPTY_SHORTEST,
        };
        for cell in 0..81 {
            let value = cell_values[cell];
            let cellgps = CELL_GROUP_POS[cell];
            if value == 0 {
                for cellgp in cellgps.iter() {
                    board.group_cells[cellgp.group] |= BIT9[cellgp.pos];
                }
                board.cell_candidates[cell] = 511;
            } else {
                let candidates = BIT9[value - 1];
                for cellgp in cellgps.iter() {
                    board.group_negatives[cellgp.group] |= candidates;
                }
                board.cell_candidates[cell] = candidates;
            }
        }
        board.eliminate_group_negatives();
        board.eliminate_exclusive_combinations();
        assert!(board.is_sudoku);
        if !board.is_solved() {
            board.trial_and_error();
        }
        assert!(board.is_sudoku);
        board
            .cell_candidates
            .iter()
            .map(|candidate| match candidate.count_ones() {
                1 => (candidate.trailing_zeros() + 1).to_string(),
                _ => String::from("0"),
            })
            .collect::<Vec<String>>()
            .join("")
    }
    fn set_value(&mut self, cellgps: &[GroupPos; 3], candidates: usize) -> bool {
        for cellgp in cellgps.iter() {
            self.group_cells[cellgp.group] &= !BIT9[cellgp.pos];
            self.is_sudoku &= self.group_negatives[cellgp.group] & candidates == 0;
            self.group_negatives[cellgp.group] |= candidates;
        }
        return self.is_sudoku;
    }
    fn remove_candidates_from_cell(
        &mut self,
        cell: &usize,
        cellgps: &[GroupPos; 3],
        candidates: &usize,
    ) -> bool {
        if (self.cell_candidates[*cell] & *candidates) == 0 {
            return false;
        }

        self.cell_candidates[*cell] &= !*candidates;
        let candidates = self.cell_candidates[*cell];
        for cellgp in cellgps.iter() {
            self.changed_groups |= 1 << cellgp.group;
        }

        let candidate_count = candidates.count_ones() as usize;
        if candidate_count == 0 {
            self.is_sudoku = false;
            return self.is_sudoku;
        } else if candidate_count == 1 {
            if self.shortest.index == *cell {
                self.shortest = EMPTY_SHORTEST;
            }
            return self.set_value(&cellgps, candidates);
        } else if candidate_count < self.shortest.length {
            self.shortest = Shortest {
                length: candidate_count,
                index: *cell,
            };
        }
        false
    }
    fn eliminate_group_negatives(&mut self) {
        self.changed_groups = 0;

        loop {
            let mut negatives = false;
            for group in 0..9 {
                for pos in BITS_LIST[self.group_cells[group]].iter() {
                    let cell = CELL_INDEX.get(group).unwrap().get(*pos).unwrap();
                    let cellgps = CELL_GROUP_POS.get(*cell).unwrap();
                    let mut candidates = 0;
                    for cellgp in cellgps.iter() {
                        candidates |= self.group_negatives[cellgp.group];
                    }
                    negatives |= self.remove_candidates_from_cell(cell, cellgps, &candidates);
                }
            }
            if !negatives {
                return;
            }
        }
    }
    fn eliminate_exclusive_combinations_from_group(
        &mut self,
        gbits: usize,
        cell_indexes: &[usize; 9],
    ) -> bool {
        for subbits in SUBBITS_LIST[gbits].iter() {
            let mut union: usize = 0;
            for pos in BITS_LIST[*subbits].iter() {
                union |= self.cell_candidates[*cell_indexes.get(*pos).unwrap()];
            }
            if union.count_ones() == subbits.count_ones() {
                let compbits = gbits & !(*subbits);
                let mut negatives = false;
                for pos in BITS_LIST[compbits].iter() {
                    let cell = cell_indexes.get(*pos).unwrap();
                    negatives |= self.remove_candidates_from_cell(
                        cell,
                        CELL_GROUP_POS.get(*cell).unwrap(),
                        &union,
                    );
                }
                return negatives
                    | self.eliminate_exclusive_combinations_from_group(*subbits, cell_indexes)
                    | self.eliminate_exclusive_combinations_from_group(compbits, cell_indexes);
            }
        }
        false
    }
    fn eliminate_exclusive_combinations(&mut self) {
        loop {
            let mut negatives = false;
            for group in Biterator::new(self.changed_groups) {
                negatives |= self.eliminate_exclusive_combinations_from_group(
                    self.group_cells[group],
                    CELL_INDEX.get(group).unwrap(),
                );
            }
            if negatives {
                self.eliminate_group_negatives();
            } else {
                return;
            }
        }
    }
    fn is_solved(&self) -> bool {
        self.is_sudoku
            && (self.group_cells[0]
                | self.group_cells[1]
                | self.group_cells[2]
                | self.group_cells[3]
                | self.group_cells[4]
                | self.group_cells[5]
                | self.group_cells[6]
                | self.group_cells[7]
                | self.group_cells[8]
                == 0)
    }
    fn update_shortest(&mut self) {
        for group in [22, 23, 25, 21, 19, 20, 26, 24, 18].iter() {
            for pos in BITS_LIST[self.group_cells[*group]].iter() {
                let cell = CELL_INDEX[*group][*pos];
                let length = self.cell_candidates[cell].count_ones() as usize;
                if length == 2 {
                    self.shortest = Shortest {
                        length: length,
                        index: cell,
                    };
                    return;
                } else if length < self.shortest.length {
                    self.shortest = Shortest {
                        length: length,
                        index: cell,
                    };
                }
            }
        }
    }
    fn trial_and_error(&mut self) {
        if self.shortest.length > 9 {
            self.update_shortest()
        }

        let cell = self.shortest.index;
        let cell_candidates = self.cell_candidates.clone();
        let group_cells = self.group_cells.clone();
        let group_negatives = self.group_negatives.clone();

        for candidate in BITS_LIST[self.cell_candidates[cell]].iter() {
            let set_candidates = BIT9[*candidate];
            self.cell_candidates[cell] = set_candidates;
            self.shortest = EMPTY_SHORTEST;
            self.set_value(CELL_GROUP_POS.get(cell).unwrap(), set_candidates);
            self.eliminate_group_negatives();
            self.eliminate_exclusive_combinations();

            if self.is_solved() {
                return;
            } else if self.is_sudoku {
                self.trial_and_error();
                if self.is_solved() {
                    return;
                }
            }

            self.cell_candidates = cell_candidates.clone();
            self.group_cells = group_cells.clone();
            self.group_negatives = group_negatives.clone();
            self.is_sudoku = true;
            self.shortest = EMPTY_SHORTEST;
        }
    }
}

const FIRST_LINE: &str =
    "╔═════════╤═════════╤═════════╦═════════╤═════════╤═════════╦═════════╤═════════╤═════════╗";
const EVERY_LINE: &str =
    "╟─────────┼─────────┼─────────╫─────────┼─────────┼─────────╫─────────┼─────────┼─────────╢";
const THREE_LINE: &str =
    "╠═════════╪═════════╪═════════╬═════════╪═════════╪═════════╬═════════╪═════════╪═════════╣";
const LAST_LINE: &str =
    "╚═════════╧═════════╧═════════╩═════════╧═════════╧═════════╩═════════╧═════════╧═════════╝";

fn print_board(board: &Board) {
    println!("{}", FIRST_LINE);
    for line_count in 0..9 {
        print!("{}", "║");
        for cell_count in 0..9 {
            let cell = cell_count + line_count * 9;
            print!(
                "{: ^9}",
                BITS_LIST[board.cell_candidates[cell]]
                    .iter()
                    .map(|x| (x + 1).to_string())
                    .collect::<Vec<String>>()
                    .join("")
            );
            if cell_count == 8 {
                print!("{}", "║\n");
            } else if cell_count % 3 == 2 {
                print!("{}", "║");
            } else {
                print!("{}", "│");
            }
        }
        if line_count == 8 {
            println!("{}", LAST_LINE);
        } else if line_count % 3 == 2 {
            println!("{}", THREE_LINE);
        } else {
            println!("{}", EVERY_LINE);
        }
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
        assert!(value < 10);
        cell_values[index] = value;
    }
    Board::new(cell_values)
}
