import { rule, to$ } from "karabiner.ts";
import {
  adjacentWorkspaceMoveCommand,
  windowActionCommand,
} from "./window-action-catalog.ts";

const TAB_WINDOW_MODE = "tab_window_mode_active";
const TAB_Q_NESTED_MODE = "tab_q_nested_mode_active";

type Direction = "left" | "right" | "up" | "down";

const action = (id: string) => to$(windowActionCommand(id));

const windowFocus = (direction: Direction) => action(`focus-${direction}`);

const workspaceSwitch = (direction: "next" | "prev") =>
  action(`workspace-${direction}`);

const windowMove = (direction: Direction) => action(`move-${direction}`);

const windowJoin = (direction: Direction) => action(`join-${direction}`);

const workspaceMoveWindow = (direction: "next" | "prev") =>
  to$(adjacentWorkspaceMoveCommand(direction));

const windowResize = (
  operation: "grow" | "shrink",
  span: "primary" | "secondary",
) => action(`resize-${operation}-${span}`);

const tabKeyRule = rule("Tab Key: Dual Role (Tab/OmniWM Management)")
  .manipulators([
    {
      type: "basic",
      from: { key_code: "tab" },
      to: [
        { set_variable: { name: TAB_WINDOW_MODE, value: 1 } },
      ],
      to_if_alone: [{ key_code: "tab" }],
      to_after_key_up: [{ set_variable: { name: TAB_WINDOW_MODE, value: 0 } }],
    },
  ]);

const omniwmPrimaryRules = rule("Tab: OmniWM Primary Actions")
  .manipulators([
    {
      type: "basic",
      from: { key_code: "h" },
      to: [windowFocus("left")],
      conditions: [
        { type: "variable_if", name: TAB_WINDOW_MODE, value: 1 },
        { type: "variable_if", name: TAB_Q_NESTED_MODE, value: 0 },
      ],
    },
    {
      type: "basic",
      from: { key_code: "j" },
      to: [windowFocus("down")],
      conditions: [
        { type: "variable_if", name: TAB_WINDOW_MODE, value: 1 },
        { type: "variable_if", name: TAB_Q_NESTED_MODE, value: 0 },
      ],
    },
    {
      type: "basic",
      from: { key_code: "k" },
      to: [windowFocus("up")],
      conditions: [
        { type: "variable_if", name: TAB_WINDOW_MODE, value: 1 },
        { type: "variable_if", name: TAB_Q_NESTED_MODE, value: 0 },
      ],
    },
    {
      type: "basic",
      from: { key_code: "l" },
      to: [windowFocus("right")],
      conditions: [
        { type: "variable_if", name: TAB_WINDOW_MODE, value: 1 },
        { type: "variable_if", name: TAB_Q_NESTED_MODE, value: 0 },
      ],
    },
    {
      type: "basic",
      from: { key_code: "n" },
      to: [workspaceSwitch("next")],
      conditions: [
        { type: "variable_if", name: TAB_WINDOW_MODE, value: 1 },
        { type: "variable_if", name: TAB_Q_NESTED_MODE, value: 0 },
      ],
    },
    {
      type: "basic",
      from: { key_code: "p" },
      to: [workspaceSwitch("prev")],
      conditions: [
        { type: "variable_if", name: TAB_WINDOW_MODE, value: 1 },
        { type: "variable_if", name: TAB_Q_NESTED_MODE, value: 0 },
      ],
    },
    {
      type: "basic",
      from: { key_code: "q" },
      to: [
        { set_variable: { name: TAB_Q_NESTED_MODE, value: 1 } },
      ],
      to_after_key_up: [{
        set_variable: { name: TAB_Q_NESTED_MODE, value: 0 },
      }],
      conditions: [{ type: "variable_if", name: TAB_WINDOW_MODE, value: 1 }],
    },
    {
      type: "basic",
      from: { key_code: "f" },
      to: [action("open-look")],
      conditions: [
        { type: "variable_if", name: TAB_WINDOW_MODE, value: 1 },
        { type: "variable_if", name: TAB_Q_NESTED_MODE, value: 0 },
      ],
    },
  ]);

const omniwmNestedRules = rule("Tab+Q: OmniWM Nested Actions")
  .manipulators([
    {
      type: "basic",
      from: { key_code: "h" },
      to: [windowMove("left")],
      conditions: [
        { type: "variable_if", name: TAB_WINDOW_MODE, value: 1 },
        { type: "variable_if", name: TAB_Q_NESTED_MODE, value: 1 },
      ],
    },
    {
      type: "basic",
      from: { key_code: "j" },
      to: [windowMove("down")],
      conditions: [
        { type: "variable_if", name: TAB_WINDOW_MODE, value: 1 },
        { type: "variable_if", name: TAB_Q_NESTED_MODE, value: 1 },
      ],
    },
    {
      type: "basic",
      from: { key_code: "k" },
      to: [windowMove("up")],
      conditions: [
        { type: "variable_if", name: TAB_WINDOW_MODE, value: 1 },
        { type: "variable_if", name: TAB_Q_NESTED_MODE, value: 1 },
      ],
    },
    {
      type: "basic",
      from: { key_code: "l" },
      to: [windowMove("right")],
      conditions: [
        { type: "variable_if", name: TAB_WINDOW_MODE, value: 1 },
        { type: "variable_if", name: TAB_Q_NESTED_MODE, value: 1 },
      ],
    },
    {
      type: "basic",
      from: { key_code: "y" },
      to: [windowJoin("left")],
      conditions: [
        { type: "variable_if", name: TAB_WINDOW_MODE, value: 1 },
        { type: "variable_if", name: TAB_Q_NESTED_MODE, value: 1 },
      ],
    },
    {
      type: "basic",
      from: { key_code: "u" },
      to: [windowJoin("up")],
      conditions: [
        { type: "variable_if", name: TAB_WINDOW_MODE, value: 1 },
        { type: "variable_if", name: TAB_Q_NESTED_MODE, value: 1 },
      ],
    },
    {
      type: "basic",
      from: { key_code: "i" },
      to: [windowJoin("down")],
      conditions: [
        { type: "variable_if", name: TAB_WINDOW_MODE, value: 1 },
        { type: "variable_if", name: TAB_Q_NESTED_MODE, value: 1 },
      ],
    },
    {
      type: "basic",
      from: { key_code: "o" },
      to: [windowJoin("right")],
      conditions: [
        { type: "variable_if", name: TAB_WINDOW_MODE, value: 1 },
        { type: "variable_if", name: TAB_Q_NESTED_MODE, value: 1 },
      ],
    },
    {
      type: "basic",
      from: { key_code: "n" },
      to: [workspaceMoveWindow("next")],
      conditions: [
        { type: "variable_if", name: TAB_WINDOW_MODE, value: 1 },
        { type: "variable_if", name: TAB_Q_NESTED_MODE, value: 1 },
      ],
    },
    {
      type: "basic",
      from: { key_code: "p" },
      to: [workspaceMoveWindow("prev")],
      conditions: [
        { type: "variable_if", name: TAB_WINDOW_MODE, value: 1 },
        { type: "variable_if", name: TAB_Q_NESTED_MODE, value: 1 },
      ],
    },
    {
      type: "basic",
      from: { key_code: "spacebar" },
      to: [action("toggle-float")],
      conditions: [
        { type: "variable_if", name: TAB_WINDOW_MODE, value: 1 },
        { type: "variable_if", name: TAB_Q_NESTED_MODE, value: 1 },
      ],
    },
    {
      type: "basic",
      from: { key_code: "z" },
      to: [action("toggle-fullscreen")],
      conditions: [
        { type: "variable_if", name: TAB_WINDOW_MODE, value: 1 },
        { type: "variable_if", name: TAB_Q_NESTED_MODE, value: 1 },
      ],
    },
    {
      type: "basic",
      from: { key_code: "b" },
      to: [action("toggle-column-tabbed")],
      conditions: [
        { type: "variable_if", name: TAB_WINDOW_MODE, value: 1 },
        { type: "variable_if", name: TAB_Q_NESTED_MODE, value: 1 },
      ],
    },
    {
      type: "basic",
      from: { key_code: "s" },
      to: [action("toggle-workspace-layout")],
      conditions: [
        { type: "variable_if", name: TAB_WINDOW_MODE, value: 1 },
        { type: "variable_if", name: TAB_Q_NESTED_MODE, value: 1 },
      ],
    },
    {
      type: "basic",
      from: { key_code: "c" },
      to: [action("command-palette")],
      conditions: [
        { type: "variable_if", name: TAB_WINDOW_MODE, value: 1 },
        { type: "variable_if", name: TAB_Q_NESTED_MODE, value: 1 },
      ],
    },
    {
      type: "basic",
      from: { key_code: "a" },
      to: [action("focus-previous")],
      conditions: [
        { type: "variable_if", name: TAB_WINDOW_MODE, value: 1 },
        { type: "variable_if", name: TAB_Q_NESTED_MODE, value: 1 },
      ],
    },
    {
      type: "basic",
      from: { key_code: "v" },
      to: [action("toggle-overview")],
      conditions: [
        { type: "variable_if", name: TAB_WINDOW_MODE, value: 1 },
        { type: "variable_if", name: TAB_Q_NESTED_MODE, value: 1 },
      ],
    },
    {
      type: "basic",
      from: { key_code: "t" },
      to: [action("toggle-quake-terminal")],
      conditions: [
        { type: "variable_if", name: TAB_WINDOW_MODE, value: 1 },
        { type: "variable_if", name: TAB_Q_NESTED_MODE, value: 1 },
      ],
    },
    {
      type: "basic",
      from: { key_code: "g" },
      to: [action("balance-sizes")],
      conditions: [
        { type: "variable_if", name: TAB_WINDOW_MODE, value: 1 },
        { type: "variable_if", name: TAB_Q_NESTED_MODE, value: 1 },
      ],
    },
    {
      type: "basic",
      from: { key_code: "m" },
      to: [
        {
          key_code: "m",
          modifiers: ["left_command"],
        },
      ],
      conditions: [
        { type: "variable_if", name: TAB_WINDOW_MODE, value: 1 },
        { type: "variable_if", name: TAB_Q_NESTED_MODE, value: 1 },
      ],
    },
    {
      type: "basic",
      from: { key_code: "x" },
      to: [action("close-window")],
      conditions: [
        { type: "variable_if", name: TAB_WINDOW_MODE, value: 1 },
        { type: "variable_if", name: TAB_Q_NESTED_MODE, value: 1 },
      ],
    },
  ]);

const omniwmResizeRules = rule("Tab+Q: OmniWM Resize").manipulators([
  {
    type: "basic",
    from: { key_code: "hyphen" },
    to: [windowResize("shrink", "primary")],
    conditions: [
      { type: "variable_if", name: TAB_WINDOW_MODE, value: 1 },
      { type: "variable_if", name: TAB_Q_NESTED_MODE, value: 1 },
    ],
  },
  {
    type: "basic",
    from: { key_code: "equal_sign" },
    to: [windowResize("grow", "primary")],
    conditions: [
      { type: "variable_if", name: TAB_WINDOW_MODE, value: 1 },
      { type: "variable_if", name: TAB_Q_NESTED_MODE, value: 1 },
    ],
  },
  {
    type: "basic",
    from: {
      key_code: "hyphen",
      modifiers: { mandatory: ["left_shift"] },
    },
    to: [windowResize("shrink", "secondary")],
    conditions: [
      { type: "variable_if", name: TAB_WINDOW_MODE, value: 1 },
      { type: "variable_if", name: TAB_Q_NESTED_MODE, value: 1 },
    ],
  },
  {
    type: "basic",
    from: {
      key_code: "equal_sign",
      modifiers: { mandatory: ["left_shift"] },
    },
    to: [windowResize("grow", "secondary")],
    conditions: [
      { type: "variable_if", name: TAB_WINDOW_MODE, value: 1 },
      { type: "variable_if", name: TAB_Q_NESTED_MODE, value: 1 },
    ],
  },
]);

export const tabWindowManagerRules = [
  tabKeyRule,
  omniwmPrimaryRules,
  omniwmNestedRules,
  omniwmResizeRules,
];
