#[macro_use]
extern crate lazy_static;

// use rayon::prelude::*;
// use std::env;
// use std::fs;

mod make_list;
mod sudoku;

// fn main() {
//     let filename = match env::args().nth(1) {
//         Some(filename) => filename,
//         None => {
//             println!("Usage: sudoku <filename>");
//             return;
//         }
//     };

//     let sudokus = fs::read_to_string(filename).unwrap();

//     print!(
//         "{}",
//         sudokus
//             .lines()
//             .collect::<Vec<&str>>()
//             .par_iter()
//             .map(|puzzle| format!("{},{}", *puzzle, sudoku::solve(*puzzle)))
//             .collect::<Vec<String>>()
//             .join("\n")
//     );
// }

fn main() {
    make_list::make_possible_combinations();
}
