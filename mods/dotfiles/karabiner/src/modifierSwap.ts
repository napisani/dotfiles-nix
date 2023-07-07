import { ifApp, map, rule } from "karabiner.ts"

const allStandardApps :string[] = [
  "^com\\.apple\\.Terminal",
  "^com\\.googlecode\\.iterm2",
  "^io\\.alacritty",
  "^org\\.alacritty",
  "^com\\.jetbrains\\..*"
]
const ifAnyStandardApp = ifApp(allStandardApps, "any standard app").unless()
const ifAnyDevApps = ifApp(allStandardApps, "dev app")
export const modifierSwapRules = [
  rule('Swap left_command -> left_control', ifAnyStandardApp).manipulators([
    map("left_command").to("left_control")
    .description("left_command -> left_control for standard apps"),
  ]),

  rule('Swap left_command <- left_control', ifAnyStandardApp).manipulators([
    map("left_control").to("left_command")
    .description("left_control -> left_command for standard apps"),
  ]),

  rule('fn -> left_command standard apps', ifAnyStandardApp).manipulators([
    map("fn").to("left_command")
    .description("fn -> left_command for standard apps"),
  ]),

  rule('fn -> left_control dev apps', ifAnyDevApps).manipulators([
    map("fn").to("left_control")
    .description("fn -> left_control for dev apps"),
  ]),

]
