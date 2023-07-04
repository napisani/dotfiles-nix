import {
  ifApp,
  map,
  ModifierKeyCode,
  rule,
  writeToProfile,
} from 'karabiner.ts'
import { writeToProfileInDotfiles } from './output'

const hyperModifiers :ModifierKeyCode[] = ['right_command', 'right_control',  'right_shift', 'right_option']
const allStandardApps :string[] = [
  "^com\\.apple\\.Terminal",
  "^com\\.googlecode\\.iterm2",
  "^io\\.alacritty",
  "^org\\.alacritty",
  "^com\\.jetbrains\\..*"
]
const ifAnyStandardApp = ifApp(allStandardApps, "any standard app").unless()
const ifAnyDevApps = ifApp(allStandardApps, "dev app")

writeToProfileInDotfiles('default', [
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

    map({
      key_code: "u",
      modifiers: {mandatory: [...hyperModifiers]}
    }).to({
      "key_code": "page_up",
    }).description("Hyper + u = page up"),
    
    map({
      key_code: "d",
      modifiers: {mandatory: [...hyperModifiers]}
    }).to({
      "key_code": "page_down",
    }).description("Hyper + d = page down"),

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

  rule('Swap left_command <-> left_control', ifAnyStandardApp).manipulators([
    map("left_command").to("left_control")
    .description("left_command -> left_control for standard apps"),
  ]),

  rule('fn -> left_command standard apps', ifAnyStandardApp).manipulators([
    map("fn").to("left_command")
    .description("fn -> left_command for standard apps"),
  ]),

  rule('fn -> left_control dev apps', ifAnyDevApps).manipulators([
    map("fn").to("left_control")
    .description("fn -> left_control for dev apps"),
  ]),

  rule('escape -> grave_accent_and_tilde').manipulators([
    map("escape").to("grave_accent_and_tilde")
    .description("escape -> grave_accent_and_tilde"), 
  ]),
])
