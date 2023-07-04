import {
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
  simlayer('a', 'delimiters layer').manipulators([
    map('r').toPaste('('), 
    map('u').toPaste(')'), 
    map('f').toPaste('{'), 
    map('j').toPaste('}'),
    map('d').toPaste('['), 
    map('k').toPaste(']'), 
    map('v').toPaste('<'), 
    map('n').toPaste('>'), 
    map('t').to$(`osascript -e '
set prev to the clipboard
set the clipboard to ASCII character 39 
tell application "System Events"
  keystroke "v" using command down
  delay 0.1
end tell
set the clipboard to prev'`),
    map('y').toPaste('\\"'),
    map('g').toPaste(','), 
    map('h').toPaste('.')
  ]),
])
