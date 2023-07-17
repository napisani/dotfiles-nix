import { map, simlayer } from "karabiner.ts";

export const layerRules = [

  // Delimiter layer - special characters that are hard-ish to reach / remember
  //     ('")
  //   a  [{,.}]
  //      <&  *>
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
  

  // Number layer 
  //    4 5 6  
  //   0 1 2 3 
  //      7 8 9 

  simlayer('n', 'number layer').manipulators([
    map('s').to('0'),
    map('d').to('1'),
    map('f').to('2'),
    map('g').to('3'),
    map('e').to('4'),
    map('r').to('5'),
    map('t').to('6'),
    map('c').to('7'),
    map('v').to('8'),
    map('b').to('9'),
  ]),

  // simlayer('e', 'emoji layer').manipulators([
  //   map(';').to({key_code: 'spacebar', modifiers: ['left_command', 'left_control']}),
  // ])
]
