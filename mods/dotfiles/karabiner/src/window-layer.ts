import { rule, to$ } from "karabiner.ts";

const riftBin = "/Users/nick/code/rift/target/release/rift-cli";

const TAB_WINDOW_MODE = "tab_window_mode_active";
const TAB_Q_NESTED_MODE = "tab_q_nested_mode_active";

const windowFocus = (direction: "left" | "right" | "up" | "down") =>
  to$(`${riftBin} execute window focus --direction ${direction}`);

const workspaceSwitch = (direction: "next" | "prev") =>
  to$(`${riftBin} execute workspace ${direction}`);

const withDirectionalFallback = (subcommand: string) =>
  (direction: "left" | "right" | "up" | "down") =>
    to$(
      `if ${riftBin} execute ${subcommand} --direction ${direction}; then
  :
else
  ${riftBin} execute ${subcommand} ${direction}
fi`,
    );

const layoutMoveNode = withDirectionalFallback("layout move-node");

const layoutJoinWindow = withDirectionalFallback("layout join-window");

const workspaceMoveWindow = (direction: "next" | "prev") =>
  to$(
    `workspace_data=$(${riftBin} query workspaces)
target=$(RIFT_DIRECTION=${direction} RIFT_WS_JSON="$workspace_data" /usr/bin/env python3 <<'PY'
import json, os, sys

direction = os.environ.get("RIFT_DIRECTION", "next")
workspace_json = os.environ.get("RIFT_WS_JSON", "[]")

data = json.loads(workspace_json)
if not data:
    raise SystemExit(1)

ordered = sorted(data, key=lambda ws: ws.get("index", 0))
active_idx = next((i for i, ws in enumerate(ordered) if ws.get("is_active")), 0)

if direction == "next":
    indices = list(range(active_idx + 1, len(ordered))) + list(range(0, active_idx))
else:
    indices = list(range(active_idx - 1, -1, -1)) + list(range(len(ordered) - 1, active_idx, -1))

if indices:
    target_idx = indices[0]
else:
    target_idx = active_idx

target = ordered[target_idx].get("index")
if target is not None:
    print(target, end="")
PY
)
if [ -n "$target" ]; then
  ${riftBin} execute workspace move-window "$target"
fi`,
  );

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
      to: [to$(`${riftBin} execute window toggle-float`)],
      conditions: [
        { type: "variable_if", name: TAB_WINDOW_MODE, value: 1 },
        { type: "variable_if", name: TAB_Q_NESTED_MODE, value: 1 },
      ],
    },
    {
      type: "basic",
      from: { key_code: "z" },
      to: [to$(`${riftBin} execute window toggle-fullscreen-within-gaps`)],
      conditions: [
        { type: "variable_if", name: TAB_WINDOW_MODE, value: 1 },
        { type: "variable_if", name: TAB_Q_NESTED_MODE, value: 1 },
      ],
    },
    {
      type: "basic",
      from: { key_code: "b" },
      to: [to$(`${riftBin} execute layout toggle-orientation`)],
      conditions: [
        { type: "variable_if", name: TAB_WINDOW_MODE, value: 1 },
        { type: "variable_if", name: TAB_Q_NESTED_MODE, value: 1 },
      ],
    },
    {
      type: "basic",
      from: { key_code: "s" },
      to: [to$(`${riftBin} execute layout toggle-stack`)],
      conditions: [
        { type: "variable_if", name: TAB_WINDOW_MODE, value: 1 },
        { type: "variable_if", name: TAB_Q_NESTED_MODE, value: 1 },
      ],
    },
    {
      type: "basic",
      from: { key_code: "c" },
      to: [to$(`${riftBin} execute workspace create`)],
      conditions: [
        { type: "variable_if", name: TAB_WINDOW_MODE, value: 1 },
        { type: "variable_if", name: TAB_Q_NESTED_MODE, value: 1 },
      ],
    },
    {
      type: "basic",
      from: { key_code: "m" },
      to: [
        to$(
          "/usr/bin/osascript -e 'tell application \"System Events\" to keystroke \"m\" using {command down}'",
        ),
      ],
      conditions: [
        { type: "variable_if", name: TAB_WINDOW_MODE, value: 1 },
        { type: "variable_if", name: TAB_Q_NESTED_MODE, value: 1 },
      ],
    },
    {
      type: "basic",
      from: { key_code: "x" },
      to: [
        to$(
          "/usr/bin/osascript -e 'tell application \"System Events\" to keystroke \"w\" using {command down}'",
        ),
      ],
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
];
