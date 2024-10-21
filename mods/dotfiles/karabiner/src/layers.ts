import { map, simlayer } from "karabiner.ts";
import { formatWithOptions } from "util";




export const layerRules = [
  // Delimiter layer - special characters that are hard-ish to reach / remember
  //     ('")
  //   a [{,.}]
  //     <&  *>
  //
  simlayer('a', 'delimiters layer').manipulators([
    map('r').to({ key_code: '9', modifiers: ['left_shift']}), // (
    map('u').to({ key_code: '0', modifiers: ['left_shift']}), // )
    map('f').to({ key_code: 'open_bracket', modifiers: ['left_shift']}),  // {
    map('j').to({ key_code: 'close_bracket', modifiers: ['left_shift']}), // }
    map('d').to('['), 
    map('k').to(']'), 
    map('t').to("'"),
    map('y').to({key_code: 'quote', modifiers: ['left_shift']}), // "
    map('g').to(','), // ,
    map('h').to('.'), // .
    map('c').to({ key_code: 'comma', modifiers: ['left_shift']}), // <
    map('m').to({ key_code: 'period', modifiers: ['left_shift']}), // >
    map('v').to({ key_code: '7', modifiers: ['left_shift']}), // &
    map('n').to({ key_code: '8', modifiers: ['left_shift']}), // *
  ]),

  simlayer('s', 'arrows layer').manipulators([
    map('h').to({ key_code: 'left_arrow' }),
    map('j').to({ key_code: 'down_arrow' }),
    map('k').to({ key_code: 'up_arrow' }),
    map('l').to({ key_code: 'right_arrow' }),
  ]),

  // Delimiter layer - special characters that are hard-ish to reach / remember
  //  0^$+   -_
  //      :/?= l
  //     \! %|
  // 
  simlayer('l', 'delimiters layer 2').manipulators([
    map('r').to({ key_code: 'equal_sign', modifiers: ['left_shift']}), // +
    map('u').to({ key_code: 'hyphen' }), // -
    map('i').to({ key_code: 'hyphen', modifiers: ['left_shift']}), // _
    map('f').to({ key_code: 'semicolon', modifiers: ['left_shift']}),  // :
    map('j').to({ key_code: 'equal_sign' }), // =
    map('g').to({ key_code: 'slash'}), // /
    map('h').to({ key_code: 'slash', modifiers: ['left_shift']}), // ?
    map('c').to({ key_code: 'backslash'}), // \
    map('m').to({ key_code: 'backslash', modifiers: ['left_shift']}), //  |
    map('n').to({ key_code: '5', modifiers: ['left_shift']}), //  %
    map('e').to({ key_code: '4', modifiers: ['left_shift']}), // $
    map('w').to({ key_code: '6', modifiers: ['left_shift']}), // ^
    map('v').to({ key_code: '1', modifiers: ['left_shift']}), // !
    map('a').to({ key_code: '2', modifiers: ['left_shift']}), // @
    map('q').to({ key_code: '0'} ), // 0
  ]),

  // Number layer 
  //   1 2 3 4 5 6 7 8 9 0 

  simlayer('n', 'number layer').manipulators([
    map('q').to('1'),
    map('w').to('2'),
    map('e').to('3'),
    map('r').to('4'),
    map('t').to('5'),
    map('y').to('6'),
    map('u').to('7'),
    map('i').to('8'),
    map('o').to('9'),
    map('p').to('0'),

  ]),

  // simlayer('e', 'emoji layer').manipulators([
  //   map(';').to({key_code: 'spacebar', modifiers: ['left_command', 'left_control']}),
  // ])
]
