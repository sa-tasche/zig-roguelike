// This file is a placeholder for a more sophisticated font handling code

pub const FONT_HEIGHT = 8;
pub const FONT_WIDTH = 7;
pub const FONT_FALLBACK_GLYPH = 0x7F;

// zig fmt: off
pub const font_data = [96 * FONT_HEIGHT][]const u8{
    // space
    ".......",
    ".......",
    ".......",
    ".......",
    ".......",
    ".......",
    ".......",
    ".......",
    // '!'
    ".......",
    "..xx...",
    "..xx...",
    "..xx...",
    "..xx...",
    ".......",
    "..xx...",
    ".......",
    // '"'
    ".......",
    ".x..x..",
    ".x..x..",
    ".x..x..",
    ".......",
    ".......",
    ".......",
    ".......",
    // '#'
    ".......",
    ".xx.x..",
    "xxxxxx.",
    ".xx.x..",
    ".xx.x..",
    "xxxxxx.",
    ".xx.x..",
    ".......",
    // '$'
    ".......",
    "...x...",
    "xxxxxx.",
    "xx.x...",
    "xxxxxx.",
    "...x.x.",
    "xxxxxx.",
    "...x...",
    // '%'
    ".......",
    "xx...x.",
    "xx..x..",
    "...x...",
    "..x....",
    ".x..xx.",
    "x...xx.",
    ".......",
    // '&'
    ".......",
    ".xxxx..",
    "xx.....",
    "xx..x..",
    "xxxxxx.",
    "xx..x..",
    ".xxxxx.",
    ".......",
    // '''
    ".......",
    "...x...",
    "...x...",
    "...x...",
    ".......",
    ".......",
    ".......",
    ".......",
    // '('
    ".......",
    "..xxxx.",
    ".xx....",
    ".xx....",
    ".xx....",
    ".xx....",
    ".xx....",
    "..xxxx.",
    // ')'
    ".......",
    "xxxx...",
    "...xx..",
    "...xx..",
    "...xx..",
    "...xx..",
    "...xx..",
    "xxxx...",
    // '*'
    ".......",
    "x.x.x..",
    ".xxx...",
    ".xxx...",
    "x.x.x..",
    ".......",
    ".......",
    ".......",
    // '+'
    ".......",
    ".......",
    "..x....",
    "..x....",
    "xxxxx..",
    "..x....",
    "..x....",
    ".......",
    // ','
    ".......",
    ".......",
    ".......",
    ".......",
    ".......",
    "...xx..",
    "...xx..",
    "..xx...",
    // '-'
    ".......",
    ".......",
    ".......",
    ".......",
    "xxxxxxx",
    ".......",
    ".......",
    ".......",
    // '.'
    ".......",
    ".......",
    ".......",
    ".......",
    ".......",
    "..xx...",
    "..xx...",
    ".......",
    // '/'
    ".......",
    ".....x.",
    "....x..",
    "...x...",
    "..x....",
    ".x.....",
    "x......",
    ".......",
    // '0'
    ".......",
    ".xxxx..",
    "xx..xx.",
    "xx.x.x.",
    "xx.x.x.",
    "xxx..x.",
    ".xxxx..",
    ".......",
    // '1'
    ".......",
    ".xxxx..",
    "...xx..",
    "...xx..",
    "...xx..",
    "...xx..",
    "...xx..",
    ".......",
    // '2'
    ".......",
    ".xxxx..",
    "x...xx.",
    "....xx.",
    "..xx...",
    "xx.....",
    "xxxxxx.",
    ".......",
    // '3'
    ".......",
    "xxxxxx.",
    "...xx..",
    "..xxx..",
    "....xx.",
    "x...xx.",
    ".xxxx..",
    ".......",
    // '4'
    ".......",
    "..xxx..",
    ".x.xx..",
    "x..xx..",
    "xxxxxx.",
    "...xx..",
    "...xx..",
    ".......",
    // '5'
    ".......",
    "xxxxxx.",
    "xx.....",
    "xxxxx..",
    ".....x.",
    "xx...x.",
    ".xxxx..",
    ".......",
    // '6'
    ".......",
    "..xxx..",
    ".x.....",
    "xxxxx..",
    "xx...x.",
    "xx...x.",
    ".xxxx..",
    ".......",
    // '7'
    ".......",
    "xxxxxx.",
    ".....x.",
    "...xx..",
    "..xx...",
    "..xx...",
    "..xx...",
    ".......",
    // '8'
    ".......",
    ".xxxx..",
    "xx...x.",
    ".xxxx..",
    "xx...x.",
    "xx...x.",
    ".xxxx..",
    ".......",
    // '9'
    ".......",
    ".xxxx..",
    "xx...x.",
    "xx...x.",
    ".xxxxx.",
    "....xx.",
    ".xxx...",
    ".......",
    // ':'
    ".......",
    ".......",
    "..xx...",
    "..xx...",
    ".......",
    "..xx...",
    "..xx...",
    ".......",
    // ';'
    ".......",
    ".......",
    "...xx..",
    "...xx..",
    ".......",
    "...xx..",
    "...xx..",
    "..xx...",
    // '<'
    ".......",
    ".......",
    "...xx..",
    "..xx...",
    ".xx....",
    "..xx...",
    "...xx..",
    ".......",
    // '='
    ".......",
    ".......",
    ".......",
    "xxxxxx.",
    ".......",
    "xxxxxx.",
    ".......",
    ".......",
    // '>'
    ".......",
    ".......",
    ".xx....",
    "..xx...",
    "...xx..",
    "..xx...",
    ".xx....",
    ".......",
    // '?'
    ".......",
    ".xxxx..",
    "xx...x.",
    ".....x.",
    "...xx..",
    "..xx...",
    "..xx...",
    ".......",
    // '@'
    ".......",
    ".xxxx..",
    "x....x.",
    "x.xxxx.",
    "x.xxxx.",
    "x......",
    ".xxxx..",
    ".......",
    // 'A'
    ".......",
    ".xxxx..",
    "xx...x.",
    "xx...x.",
    "xxxxxx.",
    "xx...x.",
    "xx...x.",
    ".......",
    // 'B'
    ".......",
    "xxxxx..",
    "xx...x.",
    "xx...x.",
    "xxxxx..",
    "xx...x.",
    "xxxxx..",
    ".......",
    // 'C'
    ".......",
    ".xxxx..",
    "xx...x.",
    "xx.....",
    "xx.....",
    "xx...x.",
    ".xxxx..",
    ".......",
    // 'D'
    ".......",
    "xxxxx..",
    "xx...x.",
    "xx...x.",
    "xx...x.",
    "xx...x.",
    "xxxxx..",
    ".......",
    // 'E'
    ".......",
    ".xxxx..",
    "xx...x.",
    "xx.....",
    "xxxxxx.",
    "xx.....",
    ".xxxx..",
    ".......",
    // 'F'
    ".......",
    ".xxxxx.",
    "xx.....",
    "xx.....",
    "xxxxx..",
    "xx.....",
    "xx.....",
    ".......",
    // 'G'
    ".......",
    ".xxxx..",
    "xx...x.",
    "xx.....",
    "xx.xxx.",
    "xx...x.",
    ".xxxx..",
    ".......",
    // 'H'
    ".......",
    "xx...x.",
    "xx...x.",
    "xx...x.",
    "xxxxxx.",
    "xx...x.",
    "xx...x.",
    ".......",
    // 'I'
    ".......",
    "xxxxxx.",
    "..xx...",
    "..xx...",
    "..xx...",
    "..xx...",
    "xxxxxx.",
    ".......",
    // 'J'
    ".......",
    "..xxxx.",
    "....xx.",
    "....xx.",
    "....xx.",
    "x...xx.",
    ".xxxx..",
    ".......",
    // 'K'
    ".......",
    "xx...x.",
    "xx..x..",
    "xxxx...",
    "xx..x..",
    "xx...x.",
    "xx...x.",
    ".......",
    // 'L'
    ".......",
    "xx.....",
    "xx.....",
    "xx.....",
    "xx.....",
    "xx.....",
    "xxxxxx.",
    ".......",
    // 'M'
    ".......",
    ".xxxx..",
    "xx.x.x.",
    "xx.x.x.",
    "xx.x.x.",
    "xx.x.x.",
    "xx...x.",
    ".......",
    // 'N'
    ".......",
    "xxxxx..",
    "xx...x.",
    "xx...x.",
    "xx...x.",
    "xx...x.",
    "xx...x.",
    ".......",
    // 'O'
    ".......",
    ".xxxx..",
    "xx...x.",
    "xx...x.",
    "xx...x.",
    "xx...x.",
    ".xxxx..",
    ".......",
    // 'P'
    ".......",
    "xxxxx..",
    "xx...x.",
    "xx...x.",
    "xxxxx..",
    "xx.....",
    "xx.....",
    ".......",
    // 'Q'
    ".......",
    ".xxxx..",
    "xx...x.",
    "xx...x.",
    "xx.x.x.",
    "xx..x..",
    ".xxx.x.",
    ".......",
    // 'R'
    ".......",
    "xxxxx..",
    "xx...x.",
    "xx...x.",
    "xxxxx..",
    "xx...x.",
    "xx...x.",
    ".......",
    // 'S'
    ".......",
    ".xxxx..",
    "xx...x.",
    ".xxxx..",
    ".....x.",
    "xx...x.",
    ".xxxx..",
    ".......",
    // 'T'
    ".......",
    "xxxxxx.",
    "..xx...",
    "..xx...",
    "..xx...",
    "..xx...",
    "..xx...",
    ".......",
    // 'U'
    ".......",
    "xx...x.",
    "xx...x.",
    "xx...x.",
    "xx...x.",
    "xx...x.",
    ".xxxx..",
    ".......",
    // 'V'
    ".......",
    "xx...x.",
    "xx...x.",
    "xx...x.",
    "xx...x.",
    "xx..x..",
    "xxxx...",
    ".......",
    // 'W'
    ".......",
    "xx...x.",
    "xx.x.x.",
    "xx.x.x.",
    "xx.x.x.",
    "xx.x.x.",
    ".xxxx..",
    ".......",
    // 'X'
    ".......",
    "xx...x.",
    "xx...x.",
    "xx...x.",
    ".xxxx..",
    "xx...x.",
    "xx...x.",
    ".......",
    // 'Y'
    ".......",
    "xx...x.",
    "xx...x.",
    "xx...x.",
    ".xxxx..",
    "...x...",
    "...x...",
    ".......",
    // 'Z'
    ".......",
    "xxxxxx.",
    "....x..",
    "...x...",
    "..x....",
    ".x.....",
    "xxxxxx.",
    ".......",
    // '['
    ".......",
    ".xxxxx.",
    ".xx....",
    ".xx....",
    ".xx....",
    ".xx....",
    ".xx....",
    ".xxxxx.",
    // '\'
    ".......",
    "x......",
    ".x.....",
    "..x....",
    "...x...",
    "....x..",
    ".....x.",
    ".......",
    // ']'
    ".......",
    "xxxxx..",
    "...xx..",
    "...xx..",
    "...xx..",
    "...xx..",
    "...xx..",
    "xxxxx..",
    // '^'
    ".......",
    "...x...",
    "..x.x..",
    ".x...x.",
    ".......",
    ".......",
    ".......",
    ".......",
    // '_'
    ".......",
    ".......",
    ".......",
    ".......",
    ".......",
    ".......",
    "xxxxxx.",
    ".......",
    // '`'
    ".......",
    ".x.....",
    "..x....",
    "...x...",
    ".......",
    ".......",
    ".......",
    ".......",
    // 'a'
    ".......",
    ".......",
    ".xxxx..",
    "xx...x.",
    "xx...x.",
    "xx..xx.",
    ".xxx.x.",
    ".......",
    // 'b'
    ".......",
    "xx.....",
    "xxxxx..",
    "xx...x.",
    "xx...x.",
    "xx...x.",
    "xxxxx..",
    ".......",
    // 'c'
    ".......",
    ".......",
    ".xxxx..",
    "xx...x.",
    "xx.....",
    "xx...x.",
    ".xxxx..",
    ".......",
    // 'd'
    ".......",
    "....xx.",
    ".xxxxx.",
    "x...xx.",
    "x...xx.",
    "x...xx.",
    ".xxxxx.",
    ".......",
    // 'e'
    ".......",
    ".......",
    ".xxxx..",
    "xx...x.",
    "xxxxxx.",
    "xx.....",
    ".xxxx..",
    ".......",
    // 'f'
    ".......",
    ".xxxx..",
    "xx...x.",
    "xx...x.",
    "xxxx...",
    "xx.....",
    "xx.....",
    ".......",
    // 'g'
    ".......",
    ".......",
    ".xxxxx.",
    "xx...x.",
    "xx...x.",
    ".xxxxx.",
    ".....x.",
    ".xxxx..",
    // 'h'
    ".......",
    "xx.....",
    "xxxxx..",
    "xx...x.",
    "xx...x.",
    "xx...x.",
    "xx...x.",
    ".......",
    // 'i'
    ".......",
    ".xx....",
    ".......",
    ".xx....",
    ".xx....",
    ".xx....",
    "..xxx..",
    ".......",
    // 'j'
    ".......",
    "....xx.",
    ".......",
    "....xx.",
    "....xx.",
    "....xx.",
    "x...xx.",
    ".xxxx..",
    // 'k'
    ".......",
    "xx.....",
    "xx...x.",
    "xx...x.",
    "xxxxx..",
    "xx...x.",
    "xx...x.",
    ".......",
    // 'l'
    ".......",
    "xxx....",
    ".xx....",
    ".xx....",
    ".xx....",
    ".xx....",
    "..xxxx.",
    ".......",
    // 'm'
    ".......",
    ".......",
    ".xxxx..",
    "xx.x.x.",
    "xx.x.x.",
    "xx.x.x.",
    "xx...x.",
    ".......",
    // 'n'
    ".......",
    ".......",
    ".xxxx..",
    "xx...x.",
    "xx...x.",
    "xx...x.",
    "xx...x.",
    ".......",
    // 'o'
    ".......",
    ".......",
    ".xxxx..",
    "xx...x.",
    "xx...x.",
    "xx...x.",
    ".xxxx..",
    ".......",
    // 'p'
    ".......",
    ".......",
    ".xxxx..",
    "xx...x.",
    "xx...x.",
    "xxxxx..",
    "xx.....",
    "xx.....",
    // 'q'
    ".......",
    ".......",
    ".xxxx..",
    "x...xx.",
    "x...xx.",
    ".xxxxx.",
    "....xx.",
    "....xx.",
    // 'r'
    ".......",
    ".......",
    ".xxxxx.",
    "xx.....",
    "xx.....",
    "xx.....",
    "xx.....",
    ".......",
    // 's'
    ".......",
    ".......",
    ".xxxxx.",
    "xxx....",
    ".xxxx..",
    ".....x.",
    ".xxxx..",
    ".......",
    // 't'
    ".......",
    ".xx....",
    "xxxxxx.",
    ".xx....",
    ".xx....",
    ".xx..x.",
    "..xxx..",
    ".......",
    // 'u'
    ".......",
    ".......",
    "xx...x.",
    "xx...x.",
    "xx...x.",
    "xx...x.",
    ".xxxx..",
    ".......",
    // 'v'
    ".......",
    ".......",
    "xx...x.",
    "xx...x.",
    "xx...x.",
    "xx..x..",
    "xxxx...",
    ".......",
    // 'w'
    ".......",
    ".......",
    "xx...x.",
    "xx.x.x.",
    "xx.x.x.",
    "xx.x.x.",
    ".xxxx..",
    ".......",
    // 'x'
    ".......",
    ".......",
    "xx...x.",
    "xx...x.",
    ".xxxx..",
    "xx...x.",
    "xx...x.",
    ".......",
    // 'y'
    ".......",
    ".......",
    "xx...x.",
    "xx...x.",
    "xx...x.",
    ".xxxxx.",
    ".....x.",
    ".xxxx..",
    // 'z'
    ".......",
    ".......",
    "xxxxxx.",
    "....x..",
    "..xx...",
    ".x.....",
    "xxxxxx.",
    ".......",
    // '{'
    ".......",
    "...xxx.",
    "..xx...",
    "..xx...",
    "xxxx...",
    "..xx...",
    "..xx...",
    "...xxx.",
    // '|'
    ".......",
    "..xx...",
    "..xx...",
    "..xx...",
    "..xx...",
    "..xx...",
    "..xx...",
    "..xx...",
    // '}'
    ".......",
    "xxx....",
    "..xx...",
    "..xx...",
    "..xxxx.",
    "..xx...",
    "..xx...",
    "xxx....",
    // '~'
    ".......",
    ".......",
    ".......",
    ".xxx.xx",
    "xx.xxx.",
    ".......",
    ".......",
    ".......",
    // delete
    "xxxxxxx",
    "xxxxxxx",
    "xxxxxxx",
    "xxxxxxx",
    "xxxxxxx",
    "xxxxxxx",
    "xxxxxxx",
    "xxxxxxx",
};
// zig fmt: on
