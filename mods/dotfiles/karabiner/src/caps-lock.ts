import { FromKeyCode, map, ModifierKeyCode, rule, ToKeyCode } from "karabiner.ts";

const hyperModifiers: ModifierKeyCode[] = ['right_command', 'right_control',  'right_shift', 'right_option']
export const capsRules = [ 
 // rule('caps lock to escape or left_control if held').manipulators([
 //    {
 //      type: 'basic',
 //      from: { key_code: 'caps_lock' },
 //      to: [{ key_code: 'left_control' }],
 //      to_if_alone: [{ key_code: 'escape' }],
 //    },
 //  ]),

  rule('CapsLock to Hyper').manipulators([
    map({
      key_code: "caps_lock", 
      modifiers: {optional: ["any"]}
    })
    .to({
      key_code: "right_shift", 
      modifiers: ["right_command", "right_control", "right_option"]
    })
    .toIfAlone({key_code: "escape"})
    .description("CapsLock = hyper (held), Escape (alone)"),
  ]),

  rule('Hyper + space = tmux prefix/leader').manipulators([
    map({
      key_code: "spacebar",
      modifiers: {mandatory: [...hyperModifiers]}
    }).to({
      "key_code": "spacebar",
      "modifiers": ["left_control"]
    }).description("Hyper + space = tmux prefix/leader")
  ]),

  ...('abcdefghijklmnopqrstuvwxyz'.split(''))
    .filter((key) => !['j', 'k', 'l', 'h'].includes(key))
    .map((key) => {
    return (rule(`Hyper + ${key} = ctl + ${key}`).manipulators([
        map({
          key_code: key as FromKeyCode, 
          modifiers: {mandatory: [...hyperModifiers]}
        }).to({
          "key_code": key as ToKeyCode, 
          "modifiers": ["left_control"]
        }).description(`Hyper + ${key} = ctl + ${key}`)
      ]));
    }),
  

  rule('Hyper + hjkl to arrow keys').manipulators([
    map({
      key_code: "h",
      modifiers: {mandatory: [...hyperModifiers]} 
    }).to({
      "key_code": "left_arrow",
    }).description("Hyper + h = left_arrow"),

    map({
      key_code: "l",
      modifiers: {mandatory: [...hyperModifiers]} 
    }).to({
      "key_code": "right_arrow",
    }).description("Hyper + l = right_arrow"),

    map({
      key_code: "k",
      modifiers: {mandatory: [...hyperModifiers]} 
    }).to({
      "key_code": "up_arrow",
    }).description("Hyper + k = up arrow"),

    map({
      key_code: "j",
      modifiers: {mandatory: [...hyperModifiers]}
    }).to({
      "key_code": "down_arrow",
    }).description("Hyper + j = down arrow"),

  ]),

  rule('Hyper + shift n/p - switch tabs').manipulators([
    map({
      key_code: "p",
      modifiers: {mandatory: [...hyperModifiers, "left_shift"]}
    }).to({
      "key_code": "tab",
      "modifiers": ["left_shift", "left_command"]
    }).description("Hyper + shift + p = switch to previous tab"),
    map({
      key_code: "n",
      modifiers: {mandatory: [...hyperModifiers, "left_shift"]}
    }).to({
      "key_code": "tab",
      "modifiers": ["left_command"]
    }).description("Hyper + shift + n = switch to next tab"),
  ]),
  rule('Hyper + 4 = select screenshot').manipulators([
    map({
      key_code: "4",
      modifiers: {mandatory: [...hyperModifiers]}
        }).to({
          "key_code": "4",
          "modifiers": ["left_command", "left_shift"]
    }).description("Hyper + 4 = select screenshot")
  ]),
  rule('Hyper + 5 = select screen record').manipulators([
    map({
      key_code: "5",
      modifiers: {mandatory: [...hyperModifiers]}
        }).to({
          "key_code": "5",
          "modifiers": ["left_command", "left_shift"]
    }).description("Hyper + 5 = select screen record")
  ])
]


