const TWENTY_SEVEN = [
  0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20, 21,
  22, 23, 24, 25, 26,
];

const BIT9 = [
  0b1, 0b10, 0b100, 0b1000, 0b10000, 0b100000, 0b1000000, 0b10000000,
  0b100000000,
];

const CELL_INDEXES = TWENTY_SEVEN.map((gindex) =>
  BIT9.map((_, pos) => {
    const group = gindex % 9;
    switch ((gindex / 9) | 0) {
      case 0:
        return group * 9 + pos;
      case 1:
        return pos * 9 + group;
      case 2:
        return (
          ((group / 3) | 0) * 27 +
          ((pos / 3) | 0) * 9 +
          (group % 3) * 3 +
          (pos % 3)
        );
    }
  })
);

const BITS_LISTS = [...Array(512)].map((_, bits) => {
  const list = [];
  for (let i = 0; i < 9; i++) {
    if (bits & BIT9[i]) {
      list.push(i);
    }
  }
  return list;
});

function count1s(i) {
  i = i - ((i >> 1) & 0x55555555);
  i = (i & 0x33333333) + ((i >> 2) & 0x33333333);
  i = (i + (i >> 4)) & 0x0f0f0f0f;
  i = i + (i >> 8);
  i = i + (i >> 16);
  return +(i & 0x3f);
}

function is_valid_subset(super_length, super_bits, sub_bits) {
  if (sub_bits & ~super_bits) return false;
  const sub_length = count1s(sub_bits);
  return sub_length < super_length && sub_length > 1;
}

const SUBBITS_LISTS = [...Array(512)]
  .map((_, super_bits) => count1s(super_bits))
  .map((super_length, super_bits) =>
    [...Array(super_bits)]
      .map((_, sub_bits) => sub_bits)
      .filter((sub_bits) => is_valid_subset(super_length, super_bits, sub_bits))
      .map((sub_bits) => sub_bits)
  );

const CELL_GROUP_POS = [...Array(81)].map((_, index) => {
  const row = (index / 9) | 0;
  const col = index % 9;
  const sqr = ((row / 3) | 0) * 3 + ((col / 3) | 0);
  const sqp = (row % 3) * 3 + (col % 3);
  return [
    { group: row, pos: col },
    { group: col + 9, pos: row },
    { group: sqr + 18, pos: sqp },
  ];
});

const EMTPY_SHORTEST = [10, 81];
const EMPTY_27 = Array(27).fill(0);
const GROUP_ORDER = [22, 23, 25, 21, 19, 20, 26, 24, 18];

class Board {
  new(cell_values) {
    this.is_sudoku = true;
    this.group_cells = EMPTY_27.slice();
    this.group_negatives = EMPTY_27.slice();
    this.cell_candidates = cell_values.map((value, cell) => {
      const cellgps = CELL_GROUP_POS[cell];
      if (value == 0) {
        this.group_cells[cellgps[0].group] |= BIT9[cellgps[0].pos];
        this.group_cells[cellgps[1].group] |= BIT9[cellgps[1].pos];
        this.group_cells[cellgps[2].group] |= BIT9[cellgps[2].pos];
        return 511;
      } else {
        const candidates = BIT9[value - 1];
        this.group_negatives[cellgps[0].group] |= candidates;
        this.group_negatives[cellgps[1].group] |= candidates;
        this.group_negatives[cellgps[2].group] |= candidates;
        return candidates;
      }
    });
    this.shortest = EMTPY_SHORTEST;
    this.eliminate_group_negatives();
    this.eliminate_exclusive_subsets();
    assert(this.is_sudoku);
    if (!this.is_solved()) {
      this.trial_and_error();
    }
    assert(this.is_sudoku);
    return this.cell_candidates
      .map((candidates) => {
        const bits_list = BITS_LISTS[candidates];
        return bits_list.length == 1 ? bits_list[0] + 1 : '0';
      })
      .join('');
  }
  set_value(cellgps, candidates) {
    for (let i = 0; i < 3; i++) {
      const cellgp = cellgps[i];
      this.group_cells[cellgp.group] &= ~BIT9[cellgp.pos];
      this.is_sudoku &= (this.group_negatives[cellgp.group] & candidates) == 0;
      this.group_negatives[cellgp.group] |= candidates;
    }
    return this.is_sudoku;
  }
  remove_candidates_from_cell(cell, cellgps, candidates) {
    candidates = this.cell_candidates[cell] &= ~candidates;
    const candidate_count = count1s(candidates);
    if (candidate_count == 0) {
      this.is_sudoku = false;
      return false;
    }
    if (candidate_count == 1) {
      if (this.shortest[1] == cell) {
        this.shortest = EMTPY_SHORTEST;
      }
      return this.set_value(cellgps, candidates);
    } else if (candidate_count < this.shortest[0]) {
      this.shortest = [candidate_count, cell];
    }

    return false;
  }
  remove_negatives_from_cell(cell, cellgps) {
    const candidates =
      this.group_negatives[cellgps[0].group] |
      this.group_negatives[cellgps[1].group] |
      this.group_negatives[cellgps[2].group];

    if ((this.cell_candidates[cell] & candidates) == 0) {
      return false;
    }

    this.changed_groups |=
      (1 << cellgps[0].group) |
      (1 << cellgps[1].group) |
      (1 << cellgps[2].group);

    return this.remove_candidates_from_cell(cell, cellgps, candidates);
  }
  eliminate_group_negatives() {
    this.changed_groups = 0;

    let negatives = true;
    while (this.is_sudoku & negatives) {
      negatives = false;
      for (let group = 0; group < 9; group++) {
        const bits_list = BITS_LISTS[this.group_cells[group]];
        const length = bits_list.length;
        for (let i = 0; i < length; i++) {
          const pos = bits_list[i];
          const cell = CELL_INDEXES[group][pos];
          negatives |= this.remove_negatives_from_cell(
            cell,
            CELL_GROUP_POS[cell]
          );
        }
      }
    }
  }
  remove_union_from_cell(cell, cellgps, union) {
    if ((this.cell_candidates[cell] & union) == 0) {
      return false;
    }

    const candidates =
      union |
      this.group_negatives[cellgps[0].group] |
      this.group_negatives[cellgps[1].group] |
      this.group_negatives[cellgps[2].group];

    return this.remove_candidates_from_cell(cell, cellgps, candidates);
  }
  eliminate_exclusive_subsets_from_group(gbits, cell_indexes) {
    const subbits_list = SUBBITS_LISTS[gbits];
    const length = subbits_list.length;
    for (let i = 0; i < length; i++) {
      const subbits = subbits_list[i];
      const bits_list = BITS_LISTS[subbits];
      const length = bits_list.length;
      let union = 0;
      for (let i = 0; i < length; i++) {
        union |= this.cell_candidates[cell_indexes[bits_list[i]]];
      }
      if (count1s(union) == bits_list.length) {
        const compbits = gbits & ~subbits;
        const bits_list = BITS_LISTS[compbits];
        const length = bits_list.length;
        let negatives = false;
        for (let i = 0; i < length; i++) {
          const cell = cell_indexes[bits_list[i]];
          negatives |= this.remove_union_from_cell(
            cell,
            CELL_GROUP_POS[cell],
            union
          );
        }
        return (
          negatives |
          this.eliminate_exclusive_subsets_from_group(subbits, cell_indexes) |
          this.eliminate_exclusive_subsets_from_group(compbits, cell_indexes)
        );
      }
    }
    return false;
  }
  eliminate_exclusive_subsets() {
    while (true) {
      let negatives = false;
      for (
        let changed_groups = this.changed_groups, group = 0;
        changed_groups > 0;
        changed_groups >>= 1, group++
      ) {
        while ((changed_groups & 1) == 0) {
          changed_groups >>= 1;
          group++;
        }
        negatives |= this.eliminate_exclusive_subsets_from_group(
          this.group_cells[group],
          CELL_INDEXES[group]
        );
      }
      if (negatives) {
        this.eliminate_group_negatives();
      } else {
        return;
      }
    }
  }
  is_solved = () =>
    this.is_sudoku &&
    !(
      this.group_cells[0] |
      this.group_cells[1] |
      this.group_cells[2] |
      this.group_cells[3] |
      this.group_cells[4] |
      this.group_cells[5] |
      this.group_cells[6] |
      this.group_cells[7] |
      this.group_cells[8]
    );
  update_shortest() {
    for (let i = 0; i < 9; i++) {
      const group = GROUP_ORDER[i];
      const bits_list = BITS_LISTS[this.group_cells[group]];
      const length = bits_list.length;
      for (let i = 0; i < length; i++) {
        const cell = CELL_INDEXES[group][bits_list[i]];
        const length = count1s(this.cell_candidates[cell]);
        if (length == 2) {
          this.shortest = [2, cell];
          return;
        } else if (length < this.shortest[0]) {
          this.shortest = [length, cell];
        }
      }
    }
  }
  trial_and_error() {
    if (this.shortest[0] > 9) {
      this.update_shortest();
    }

    const cell_candidates = this.cell_candidates.slice();
    const group_cells = this.group_cells.slice();
    const group_negatives = this.group_negatives.slice();

    const [length, cell] = this.shortest;

    const bits_list = BITS_LISTS[cell_candidates[cell]];
    const cellgps = CELL_GROUP_POS[cell];
    for (let index = 0; index < length; index++) {
      const set_candidates = (this.cell_candidates[cell] =
        BIT9[bits_list[index]]);
      this.is_sudoku = true;
      this.shortest = EMTPY_SHORTEST;
      this.set_value(cellgps, set_candidates);
      this.eliminate_group_negatives();
      if (this.is_sudoku) {
        this.eliminate_exclusive_subsets();
      }

      if (this.is_solved()) {
        return;
      } else if (this.is_sudoku) {
        this.trial_and_error();
        if (this.is_solved()) {
          return;
        }
      }

      if (index + 2 == length) {
        this.cell_candidates = cell_candidates;
        this.group_cells = group_cells;
        this.group_negatives = group_negatives;
      } else if (index + 1 != length) {
        this.cell_candidates = cell_candidates.slice();
        this.group_cells = group_cells.slice();
        this.group_negatives = group_negatives.slice();
      }
    }
  }
}

const first_line =
  '╔' +
  Array(3)
    .fill(Array(3).fill('═'.repeat(9)).join('╤'))
    .join('╦') +
  '╗';
const every_line =
  '╟' +
  Array(3)
    .fill(Array(3).fill('─'.repeat(9)).join('┼'))
    .join('╫') +
  '╢';
const three_line =
  '╠' +
  Array(3)
    .fill(Array(3).fill('═'.repeat(9)).join('╪'))
    .join('╬') +
  '╣';
const last_line =
  '╚' +
  Array(3)
    .fill(Array(3).fill('═'.repeat(9)).join('╧'))
    .join('╩') +
  '╝';

const print_board = (board) => {
  const lines = [first_line];
  for (let i = 0; i < 9; i++) {
    lines.push(
      '║' +
        [0, 1, 2]
          .map((j) =>
            board.cell_candidates.slice(i * 9 + j * 3, i * 9 + j * 3 + 3)
          )
          .map((cell_candidates) =>
            cell_candidates
              .map((candidates) => {
                const numbers = BITS_LISTS[candidates]
                  .map((num) => num + 1)
                  .join('');
                return numbers
                  .padStart((numbers.length + 9) / 2, ' ')
                  .padEnd(9, ' ');
              })
              .join('│')
          )
          .join('║') +
        '║'
    );
    if (i % 9 == 8) {
      lines.push(last_line);
    } else if (i % 3 == 2) {
      lines.push(three_line);
    } else {
      lines.push(every_line);
    }
  }

  console.log(lines.join('\n'));
};

const assert = (condition) => {
  if (!condition) {
    throw new Error('Assertion failed');
  }
};

const solve = (input) => {
  assert(input.length == 81);
  const cell_values = input.split('').map((value) => parseInt(value));
  assert(cell_values.every((value) => value >= 0 && value <= 9));
  return new Board().new(cell_values);
};

export { solve };
