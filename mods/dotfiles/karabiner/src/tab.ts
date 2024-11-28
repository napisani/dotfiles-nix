import { Modifier, map, rule } from "karabiner.ts";

const mehModifiers: Modifier[] = ['right_option', 'right_control',  'right_shift']
export const tabRules= [
  rule('tab to Meh').manipulators([
    map({
      key_code: "tab", 
      modifiers: {optional: []} 
    })
    .to({
      key_code: "right_option", 
      modifiers: ["right_control", "right_shift"]
    })
    .toIfAlone({key_code: "tab"}),


    map({
      key_code: "n",
      modifiers: {mandatory: [
        ...mehModifiers
      ]}
    }).to({
      "key_code": "tab",
      "modifiers": ["left_command"]
    }).description("Meh + Tab = switch to next tab"),

    map({
      key_code: "p",
      modifiers: {mandatory: [
        ...mehModifiers
      ]}
    }).to({
      "key_code": "tab",
      "modifiers": ["left_command", "left_shift"]
    }).description("Meh + Tab = switch to next tab"),



  ]),
]
    
  
