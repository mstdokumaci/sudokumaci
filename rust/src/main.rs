use rayon::prelude::*;
use std::env;
use std::fs;

mod bitset;
// mod make_list;
mod sudoku;

fn main() {
    let filename = match env::args().nth(1) {
        Some(filename) => filename,
        None => {
            println!("Usage: sudoku <filename>");
            return;
        }
    };

    let sudokus = fs::read_to_string(filename).unwrap();

    print!(
        "{}",
        sudokus
            .lines()
            .collect::<Vec<&str>>()
            .par_iter()
            .map(|puzzle| format!("{},{}", *puzzle, sudoku::solve(*puzzle)))
            .collect::<Vec<String>>()
            .join("\n")
    );
}

// fn main() {
//     for index in bitset::BitSetTraverse::new((
//         0b1111111111000101101111111111000101101111111111000000000000000000,
//         0b0111111111110110110100011111111111111100011111111111111100011111,
//         0b0000000000000000000000000000001111111111011011011111111111011011,
//     ))
//     .into_iter()
//     {
//         println!("{}", index)
//     }
// }
