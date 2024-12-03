import { map, rule } from "karabiner.ts";

export const tabRules = [
  rule('tab to alt').manipulators([
    map({
      key_code: "tab", 
      modifiers: {optional: []} 
    })
    .to({
      key_code: "left_option", 
    })
    .toIfAlone({key_code: "tab"}),
  ]),

  rule('tab + q to left_option + left_shift').manipulators([
    map({
      key_code: "q",
      modifiers: {
        mandatory: ["left_option"]
      }
    })
    .to({
      key_code: "left_shift",
      modifiers: ["left_option"]
    })
  ]),
]

