import {
    ToEvent,
  ifApp,
  map,
  rule,
  simlayer,
} from 'karabiner.ts'
import { writeToProfileInDotfiles } from './output'
import { hyperRules } from './hyper'
import { modifierSwapRules } from './modifierSwap'
import { mehRules } from './meh'

writeToProfileInDotfiles('default', [
  ...hyperRules,
  ...modifierSwapRules,
  ...mehRules,
  rule('escape -> grave_accent_and_tilde').manipulators([
    map("escape").to("grave_accent_and_tilde")
    .description("escape -> grave_accent_and_tilde"), 
  ]),

  //     ('")
  //   a  [{,.}]
  //       <  > 
  //
  simlayer('a', 'ielimiters layer').manipulators([
    map('r').to({ key_code: '9', modifiers: ['left_shift']}), // (
    map('u').to({ key_code: '0', modifiers: ['left_shift']}), // )
    map('f').to({ key_code: 'open_bracket', modifiers: ['left_shift']}),  // {
    map('j').to({ key_code: 'close_bracket', modifiers: ['left_shift']}), // }
    map('d').to('['), 
    map('k').to(']'), 
    map('v').to({ key_code: 'comma', modifiers: ['left_shift']}), // <
    map('n').to({ key_code: 'period', modifiers: ['left_shift']}), // >
    map('t').to("'"),
    map('y').to({key_code: 'quote', modifiers: ['left_shift']}), // "
    map('g').to(','), // ,
    map('h').to('.'), // .
  ]),
])


