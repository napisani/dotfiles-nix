import { Modifier, ModifierKeyCode, map, rule } from "karabiner.ts";

const mehModifiers: Modifier[] = ['right_option', 'right_control',  'right_shift']
export const mehRules = [
  rule('backslash to Meh').manipulators([
    map({
      key_code: "backslash", 
      modifiers: {optional: []} 
    })
    .to({
      key_code: "right_option", 
      modifiers: ["right_control", "right_shift"]
    })
    .toIfAlone({key_code: "backslash"}),
    map({
      key_code: "tab",
      modifiers: {mandatory: [
        ...mehModifiers
      ]}
    }).to({
      "key_code": "tab",
      "modifiers": ["left_command"]
    }).description("Meh + Tab = switch to next tab"),
  ])
]
    
  
