import { readFileSync } from 'fs';
import { solve } from './sudoku.js';

const filename = process.argv[2];
if (filename) {
  process.stdout.write(
    readFileSync(filename)
      .toString()
      .split('\n')
      .map((line) => line.trim('s'))
      .filter((line) => line.length > 0)
      .map((puzzle) => `${puzzle},${solve(puzzle)}`)
      .join('\n')
  );
} else {
  console.error('Usage: node index.js <filename>');
}
