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
            .iter()
            // .par_iter()
            .map(|puzzle| format!("{},{}", *puzzle, sudoku::solve(*puzzle)))
            .collect::<Vec<String>>()
            .join("\n")
    );
}

// fn main() {
//     for i in bitset::BitSetTraverse::new([
//         0b0000000000000000000000000000000110110011011000000110110011011000,
//         0b1001101100000011011000001101100001101100001101100001101100000000,
//         0b0000000000000000000000000000001000000000000000000110110000001101,
//     ])
//     .into_iter()
//     {
//         println!("{}", i)
//     }
// }
