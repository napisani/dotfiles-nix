import { rule, FromKeyCode, ToKeyCode } from "karabiner.ts";
import { exitLeader } from "./leader-utils.ts";

const CAPS_LAYER = "caps-layer";

// 1) Caps as layer toggle (dual-role)
const capsLayerRule = rule("Caps: Dual Role (Caps Layer)").manipulators([
  {
    type: "basic",
    from: { key_code: "caps_lock" },
    to: [{ set_variable: { name: CAPS_LAYER, value: 1 } }],
    to_if_alone: [{ key_code: "escape" }, ...exitLeader()],
    to_after_key_up: [{ set_variable: { name: CAPS_LAYER, value: 0 } }],
  },
]);

// Helper condition used across the layer
const capsLayerIf = [{ type: "variable_if", name: CAPS_LAYER, value: 1 } as const];

// 2) Space -> tmux prefix (Ctrl+Space)
const capsSpaceRule = rule("Caps-layer + space = tmux prefix/leader").manipulators([
  {
    type: "basic",
    from: { key_code: "spacebar" },
    to: [{ key_code: "spacebar", modifiers: ["left_control"] }],
    conditions: capsLayerIf,
  },
]);

// 3) Letter mappings (except h, j, k, l) + quote -> Ctrl+<key>
const letterKeys = [..."abcdefghijklmnopqrstuvwxyz".split(""), "quote"].filter(
  (k) => !["j", "k", "l", "h"].includes(k),
);

const letterRules = letterKeys.map((key) =>
  rule(`Caps-layer + ${key} = ctrl + ${key}`).manipulators([
    {
      type: "basic",
      from: { key_code: key as FromKeyCode },
      to: [{ key_code: key as ToKeyCode, modifiers: ["left_control"] }],
      conditions: capsLayerIf,
    },
  ])
);

// 4) hjkl -> arrow keys
const arrowsRule = rule("Caps-layer + hjkl to arrow keys").manipulators([
  {
    type: "basic",
    from: { key_code: "h" },
    to: [{ key_code: "left_arrow" }],
    conditions: capsLayerIf,
  },
  {
    type: "basic",
    from: { key_code: "l" },
    to: [{ key_code: "right_arrow" }],
    conditions: capsLayerIf,
  },
  {
    type: "basic",
    from: { key_code: "k" },
    to: [{ key_code: "up_arrow" }],
    conditions: capsLayerIf,
  },
  {
    type: "basic",
    from: { key_code: "j" },
    to: [{ key_code: "down_arrow" }],
    conditions: capsLayerIf,
  },
]);

// 5) Screenshots
const screenshotRules = [
  rule("Caps-layer + 4 = select screenshot").manipulators([
    {
      type: "basic",
      from: { key_code: "4" },
      to: [{ key_code: "4", modifiers: ["left_command", "left_shift"] }],
      conditions: capsLayerIf,
    },
  ]),
  rule("Caps-layer + 5 = select screen record").manipulators([
    {
      type: "basic",
      from: { key_code: "5" },
      to: [{ key_code: "5", modifiers: ["left_command", "left_shift"] }],
      conditions: capsLayerIf,
    },
  ]),
];

export const capsRules = [
  capsLayerRule,
  capsSpaceRule,
  ...letterRules,
  arrowsRule,
  ...screenshotRules,
];
