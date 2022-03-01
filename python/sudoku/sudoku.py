from collections import namedtuple
from dataclasses import dataclass


def get_cel_index(group: int, pos: int) -> int:
    gindex = group // 9
    group = group % 9
    if gindex == 0:
        return group * 9 + pos
    elif gindex == 1:
        return pos * 9 + group
    elif gindex == 2:
        return (group // 3) * 27 + (pos // 3) * 9 + (group % 3) * 3 + pos % 3
    else:
        return 0


CELL_INDEXES = tuple(
    tuple(get_cel_index(group, pos) for pos in range(9)) for group in range(27)
)

BIT9 = [
    0b1,
    0b10,
    0b100,
    0b1000,
    0b10000,
    0b100000,
    0b1000000,
    0b10000000,
    0b100000000,
]

BITS_LISTS = tuple(
    tuple(index for index, bit in enumerate(BIT9) if bits & bit != 0)
    for bits in range(512)
)


def count1s(i: int) -> int:
    i = i - ((i >> 1) & 0x55555555)
    i = (i & 0x33333333) + ((i >> 2) & 0x33333333)
    i = (i + (i >> 4)) & 0x0F0F0F0F
    i = i + (i >> 8)
    i = i + (i >> 16)
    return +(i & 0x3F)


def is_valid_subset(super_length: int, super_bits: int, sub_bits: int) -> bool:
    if sub_bits & ~super_bits:
        return False
    sub_length = count1s(sub_bits)
    return 1 < sub_length < super_length


def get_subbits_list(super_bits: int) -> tuple[int, ...]:
    super_length = count1s(super_bits)
    return tuple(
        sub_bits
        for sub_bits in range(0, super_bits)
        if is_valid_subset(super_length, super_bits, sub_bits)
    )


SUBBITS_LISTS = tuple(get_subbits_list(super_bits) for super_bits in range(512))


GroupPos = namedtuple("GroupPos", ["group", "pos"])


def get_cellgps(cell: int) -> tuple[GroupPos, GroupPos, GroupPos]:
    row = cell // 9
    col = cell % 9
    sqr = (row // 3) * 3 + (col // 3)
    sqp = (row % 3) * 3 + (col % 3)
    return (
        GroupPos(group=row, pos=col),
        GroupPos(group=col + 9, pos=row),
        GroupPos(group=sqr + 18, pos=sqp),
    )


CELL_GROUP_POS = tuple(get_cellgps(cell) for cell in range(81))

Shortest = namedtuple("Shortest", ["length", "cell"])

EMPTY_SHORTEST = Shortest(length=10, cell=-1)
GROUP_ORDER = (22, 23, 25, 21, 19, 20, 26, 24, 18)


@dataclass
class Board:
    is_sudoku: bool
    group_cells: list[int]
    group_negatives: list[int]
    cell_candidates: list[int]
    changed_groups: int
    shortest: Shortest

    @classmethod
    def new(cls, cell_values: tuple[int, ...]) -> str:
        board = Board(
            is_sudoku=True,
            group_cells=[0] * 27,
            group_negatives=[0] * 27,
            cell_candidates=[0] * 81,
            changed_groups=0,
            shortest=EMPTY_SHORTEST,
        )
        for cell, value in enumerate(cell_values):
            cellgps = CELL_GROUP_POS[cell]
            if value == 0:
                board.group_cells[cellgps[0].group] |= BIT9[cellgps[0].pos]
                board.group_cells[cellgps[1].group] |= BIT9[cellgps[1].pos]
                board.group_cells[cellgps[2].group] |= BIT9[cellgps[2].pos]
                board.cell_candidates[cell] = 511
            else:
                candidates = 511 & BIT9[value - 1]
                board.group_negatives[cellgps[0].group] |= candidates
                board.group_negatives[cellgps[1].group] |= candidates
                board.group_negatives[cellgps[2].group] |= candidates
                board.cell_candidates[cell] = candidates

        board.eliminate_group_negatives()
        board.eliminate_exclusive_subsets()
        assert board.is_sudoku
        if not board.is_solved:
            board.trial_and_error()
        assert board.is_sudoku
        return "".join(
            str(BITS_LISTS[candidates][0] + 1) if count1s(candidates) == 1 else "0"
            for candidates in board.cell_candidates
        )

    def set_value(
        self, cellgps: tuple[GroupPos, GroupPos, GroupPos], candidates: int
    ) -> bool:
        for cellgp in cellgps:
            self.group_cells[cellgp.group] &= ~BIT9[cellgp.pos]
            self.is_sudoku &= (self.group_negatives[cellgp.group] & candidates) == 0
            self.group_negatives[cellgp.group] |= candidates
        return self.is_sudoku

    def remove_candidates_from_cell(
        self, cell: int, cellgps: tuple[GroupPos, GroupPos, GroupPos], candidates: int
    ) -> bool:
        if not self.cell_candidates[cell] & candidates:
            return False

        self.cell_candidates[cell] &= ~candidates
        candidates = self.cell_candidates[cell]
        self.changed_groups |= (
            511 & 1 << cellgps[0].group | 1 << cellgps[1].group | 1 << cellgps[2].group
        )

        candidate_count = count1s(candidates)

        if candidate_count == 0:
            self.is_sudoku = False
            return False
        elif candidate_count == 1:
            if self.shortest.cell == cell:
                self.shortest = EMPTY_SHORTEST
            return self.set_value(cellgps, candidates)
        elif candidate_count < self.shortest.length:
            self.shortest = Shortest(length=2, cell=cell)

        return False

    def eliminate_group_negatives(self) -> None:
        negatives = True
        while negatives:
            negatives = False
            for group in range(9):
                for pos in BITS_LISTS[self.group_cells[group]]:
                    cell = CELL_INDEXES[group][pos]
                    cellgps = CELL_GROUP_POS[cell]
                    negatives |= self.remove_candidates_from_cell(
                        cell,
                        cellgps,
                        self.group_negatives[cellgps[0].group]
                        | self.group_negatives[cellgps[1].group]
                        | self.group_negatives[cellgps[2].group],
                    )

    def eliminate_exclusive_subsets_from_group(
        self, gbits: int, cell_indexes: tuple[int, ...]
    ) -> bool:
        for subbits in SUBBITS_LISTS[gbits]:
            union = 0
            for pos in BITS_LISTS[subbits]:
                union |= self.cell_candidates[cell_indexes[pos]]
            if count1s(union) == count1s(subbits):
                compbits = gbits & ~subbits
                negatives = False
                for pos in BITS_LISTS[compbits]:
                    cell = cell_indexes[pos]
                    negatives = self.remove_candidates_from_cell(
                        cell, CELL_GROUP_POS[cell], union
                    )
                return (
                    negatives
                    | self.eliminate_exclusive_subsets_from_group(subbits, cell_indexes)
                    | self.eliminate_exclusive_subsets_from_group(
                        compbits, cell_indexes
                    )
                )
        return False

    def eliminate_exclusive_subsets(self) -> None:
        while True:
            negatives = False
            i = 0
            changed_groups = self.changed_groups
            while changed_groups > 0:
                if not changed_groups & 1:
                    changed_groups >>= 1
                    i += 1
                    continue
                negatives |= self.eliminate_exclusive_subsets_from_group(
                    self.group_cells[i], CELL_INDEXES[i]
                )
                changed_groups >>= 1
                i += 1
            if negatives:
                self.eliminate_group_negatives()
            else:
                return

    @property
    def is_solved(self) -> bool:
        return self.is_sudoku and not (
            self.group_cells[0]
            | self.group_cells[1]
            | self.group_cells[2]
            | self.group_cells[3]
            | self.group_cells[4]
            | self.group_cells[5]
            | self.group_cells[6]
            | self.group_cells[7]
            | self.group_cells[8]
        )

    def update_shortest(self) -> None:
        for group in GROUP_ORDER:
            for pos in BITS_LISTS[self.group_cells[group]]:
                cell = CELL_INDEXES[group][pos]
                length = count1s(self.cell_candidates[cell])
                if length == 2:
                    self.shortest = Shortest(length=2, cell=cell)
                    return
                elif length < self.shortest.length:
                    self.shortest = Shortest(length=length, cell=cell)

    def trial_and_error(self) -> None:
        if self.shortest.length > 9:
            self.update_shortest()

        cell: int = self.shortest.cell
        cell_candidates = [*self.cell_candidates]
        group_cells = [*self.group_cells]
        group_negatives = [*self.group_negatives]

        candidates = cell_candidates[cell]
        length = count1s(candidates)

        for index, candidate in enumerate(BITS_LISTS[candidates]):
            set_candidates = BIT9[candidate]
            self.cell_candidates[cell] = set_candidates
            self.is_sudoku = True
            self.shortest = EMPTY_SHORTEST
            self.set_value(CELL_GROUP_POS[cell], set_candidates)
            self.eliminate_group_negatives()
            self.eliminate_exclusive_subsets()

            if self.is_solved:
                return
            elif self.is_sudoku:
                self.trial_and_error()
                if self.is_solved:
                    return

            if index + 2 == length:
                self.cell_candidates = cell_candidates
                self.group_cells = group_cells
                self.group_negatives = group_negatives
            elif index + 1 != length:
                self.cell_candidates = [*cell_candidates]
                self.group_cells = [*group_cells]
                self.group_negatives = [*group_negatives]
            self.shortest = EMPTY_SHORTEST


first_line = "╔" + "╦".join(["╤".join(["═" * 9] * 3)] * 3) + "╗"
every_line = "╟" + "╫".join(["┼".join(["─" * 9] * 3)] * 3) + "╢"
three_line = "╠" + "╬".join(["╪".join(["═" * 9] * 3)] * 3) + "╣"
last_line = "╚" + "╩".join(["╧".join(["═" * 9] * 3)] * 3) + "╝"


def print_board(board: Board) -> None:
    lines = [first_line]
    for i in range(9):
        cell_groups = (
            board.cell_candidates[i * 9 + j * 3 : i * 9 + j * 3 + 3] for j in range(3)
        )
        lines.append(
            "║"
            + "║".join(
                "│".join(
                    "".join(str(value + 1) for value in BITS_LISTS[cell]).center(9)
                    for cell in cell_candidates
                )
                for cell_candidates in cell_groups
            )
            + "║"
        )
        if i % 9 == 8:
            lines.append(last_line)
        elif i % 3 == 2:
            lines.append(three_line)
        else:
            lines.append(every_line)

    print("\n".join(lines))


def solve(input: str) -> str:
    assert len(input) == 81
    cell_values = tuple(int(value) for value in input)
    assert all(0 <= value <= 9 for value in cell_values)
    return Board.new(cell_values)
