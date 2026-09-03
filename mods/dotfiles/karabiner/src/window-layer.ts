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

const layoutMoveNode = (direction: Direction) =>
  action(`move-node-${direction}`);

const layoutJoinWindow = (direction: Direction) => action(`join-${direction}`);

const workspaceMoveWindow = (direction: "next" | "prev") =>
  to$(adjacentWorkspaceMoveCommand(direction));

const windowResize = (
  operation: "grow" | "shrink",
  orientation: "horizontal" | "vertical",
) => action(`resize-${operation}-${orientation}`);

const tabKeyRule = rule("Tab Key: Dual Role (Tab/Rift Management)")
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

const riftPrimaryRules = rule("Tab: Rift Primary Actions")
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

const riftNestedRules = rule("Tab+Q: Rift Nested Actions")
  .manipulators([
    {
      type: "basic",
      from: { key_code: "h" },
      to: [layoutMoveNode("left")],
      conditions: [
        { type: "variable_if", name: TAB_WINDOW_MODE, value: 1 },
        { type: "variable_if", name: TAB_Q_NESTED_MODE, value: 1 },
      ],
    },
    {
      type: "basic",
      from: { key_code: "j" },
      to: [layoutMoveNode("down")],
      conditions: [
        { type: "variable_if", name: TAB_WINDOW_MODE, value: 1 },
        { type: "variable_if", name: TAB_Q_NESTED_MODE, value: 1 },
      ],
    },
    {
      type: "basic",
      from: { key_code: "k" },
      to: [layoutMoveNode("up")],
      conditions: [
        { type: "variable_if", name: TAB_WINDOW_MODE, value: 1 },
        { type: "variable_if", name: TAB_Q_NESTED_MODE, value: 1 },
      ],
    },
    {
      type: "basic",
      from: { key_code: "l" },
      to: [layoutMoveNode("right")],
      conditions: [
        { type: "variable_if", name: TAB_WINDOW_MODE, value: 1 },
        { type: "variable_if", name: TAB_Q_NESTED_MODE, value: 1 },
      ],
    },
    {
      type: "basic",
      from: { key_code: "y" },
      to: [layoutJoinWindow("left")],
      conditions: [
        { type: "variable_if", name: TAB_WINDOW_MODE, value: 1 },
        { type: "variable_if", name: TAB_Q_NESTED_MODE, value: 1 },
      ],
    },
    {
      type: "basic",
      from: { key_code: "u" },
      to: [layoutJoinWindow("up")],
      conditions: [
        { type: "variable_if", name: TAB_WINDOW_MODE, value: 1 },
        { type: "variable_if", name: TAB_Q_NESTED_MODE, value: 1 },
      ],
    },
    {
      type: "basic",
      from: { key_code: "i" },
      to: [layoutJoinWindow("down")],
      conditions: [
        { type: "variable_if", name: TAB_WINDOW_MODE, value: 1 },
        { type: "variable_if", name: TAB_Q_NESTED_MODE, value: 1 },
      ],
    },
    {
      type: "basic",
      from: { key_code: "o" },
      to: [layoutJoinWindow("right")],
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
      to: [action("fullscreen-within-gaps")],
      conditions: [
        { type: "variable_if", name: TAB_WINDOW_MODE, value: 1 },
        { type: "variable_if", name: TAB_Q_NESTED_MODE, value: 1 },
      ],
    },
    {
      type: "basic",
      from: { key_code: "b" },
      to: [action("toggle-orientation")],
      conditions: [
        { type: "variable_if", name: TAB_WINDOW_MODE, value: 1 },
        { type: "variable_if", name: TAB_Q_NESTED_MODE, value: 1 },
      ],
    },
    {
      type: "basic",
      from: { key_code: "s" },
      to: [action("toggle-stack")],
      conditions: [
        { type: "variable_if", name: TAB_WINDOW_MODE, value: 1 },
        { type: "variable_if", name: TAB_Q_NESTED_MODE, value: 1 },
      ],
    },
    {
      type: "basic",
      from: { key_code: "c" },
      to: [action("create-workspace")],
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

const riftResizeRules = rule("Tab+Q: Rift Resize").manipulators([
  {
    type: "basic",
    from: { key_code: "hyphen" },
    to: [windowResize("shrink", "horizontal")],
    conditions: [
      { type: "variable_if", name: TAB_WINDOW_MODE, value: 1 },
      { type: "variable_if", name: TAB_Q_NESTED_MODE, value: 1 },
    ],
  },
  {
    type: "basic",
    from: { key_code: "equal_sign" },
    to: [windowResize("grow", "horizontal")],
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
    to: [windowResize("shrink", "vertical")],
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
    to: [windowResize("grow", "vertical")],
    conditions: [
      { type: "variable_if", name: TAB_WINDOW_MODE, value: 1 },
      { type: "variable_if", name: TAB_Q_NESTED_MODE, value: 1 },
    ],
  },
]);

export const tabWindowManagerRules = [
  tabKeyRule,
  riftPrimaryRules,
  riftNestedRules,
  riftResizeRules,
];
