import { rule, to$ } from "karabiner.ts";

const riftBin = "/opt/homebrew/bin/rift-cli";

const TAB_WINDOW_MODE = "tab_window_mode_active";
const TAB_Q_NESTED_MODE = "tab_q_nested_mode_active";

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
      to: [to$(`${riftBin} execute window focus left`)],
      conditions: [{ type: "variable_if", name: TAB_WINDOW_MODE, value: 1 }],
    },
    {
      type: "basic",
      from: { key_code: "j" },
      to: [to$(`${riftBin} execute window focus down`)],
      conditions: [{ type: "variable_if", name: TAB_WINDOW_MODE, value: 1 }],
    },
    {
      type: "basic",
      from: { key_code: "k" },
      to: [to$(`${riftBin} execute window focus up`)],
      conditions: [{ type: "variable_if", name: TAB_WINDOW_MODE, value: 1 }],
    },
    {
      type: "basic",
      from: { key_code: "l" },
      to: [to$(`${riftBin} execute window focus right`)],
      conditions: [{ type: "variable_if", name: TAB_WINDOW_MODE, value: 1 }],
    },
    {
      type: "basic",
      from: { key_code: "n" },
      to: [to$(`${riftBin} execute workspace next true`)],
      conditions: [{ type: "variable_if", name: TAB_WINDOW_MODE, value: 1 }],
    },
    {
      type: "basic",
      from: { key_code: "p" },
      to: [to$(`${riftBin} execute workspace prev true`)],
      conditions: [{ type: "variable_if", name: TAB_WINDOW_MODE, value: 1 }],
    },
    {
      type: "basic",
      from: { key_code: "m" },
      to: [to$(`${riftBin} execute window focus-largest`)],
      conditions: [{ type: "variable_if", name: TAB_WINDOW_MODE, value: 1 }],
    },
    {
      type: "basic",
      from: { key_code: "r" },
      to: [to$(`${riftBin} execute window cycle-focus recent`)],
      conditions: [{ type: "variable_if", name: TAB_WINDOW_MODE, value: 1 }],
    },
    {
      type: "basic",
      from: { key_code: "spacebar" },
      to: [to$(`${riftBin} execute window toggle-fullscreen`)],
      conditions: [{ type: "variable_if", name: TAB_WINDOW_MODE, value: 1 }],
    },
    {
      type: "basic",
      from: { key_code: "b" },
      to: [to$(`${riftBin} execute layout balance`)],
      conditions: [{ type: "variable_if", name: TAB_WINDOW_MODE, value: 1 }],
    },
    {
      type: "basic",
      from: { key_code: "q" },
      to: [
        { set_variable: { name: TAB_Q_NESTED_MODE, value: 1 } },
      ],
      to_after_key_up: [{ set_variable: { name: TAB_Q_NESTED_MODE, value: 0 } }],
      conditions: [{ type: "variable_if", name: TAB_WINDOW_MODE, value: 1 }],
    },
  ]);

const riftNestedRules = rule("Tab+Q: Rift Nested Actions")
  .manipulators([
    {
      type: "basic",
      from: { key_code: "h" },
      to: [to$(`${riftBin} execute layout move-node left`)],
      conditions: [
        { type: "variable_if", name: TAB_WINDOW_MODE, value: 1 },
        { type: "variable_if", name: TAB_Q_NESTED_MODE, value: 1 },
      ],
    },
    {
      type: "basic",
      from: { key_code: "j" },
      to: [to$(`${riftBin} execute layout move-node down`)],
      conditions: [
        { type: "variable_if", name: TAB_WINDOW_MODE, value: 1 },
        { type: "variable_if", name: TAB_Q_NESTED_MODE, value: 1 },
      ],
    },
    {
      type: "basic",
      from: { key_code: "k" },
      to: [to$(`${riftBin} execute layout move-node up`)],
      conditions: [
        { type: "variable_if", name: TAB_WINDOW_MODE, value: 1 },
        { type: "variable_if", name: TAB_Q_NESTED_MODE, value: 1 },
      ],
    },
    {
      type: "basic",
      from: { key_code: "l" },
      to: [to$(`${riftBin} execute layout move-node right`)],
      conditions: [
        { type: "variable_if", name: TAB_WINDOW_MODE, value: 1 },
        { type: "variable_if", name: TAB_Q_NESTED_MODE, value: 1 },
      ],
    },
    {
      type: "basic",
      from: {
        key_code: "h",
        modifiers: { mandatory: ["shift"] },
      },
      to: [to$(`${riftBin} execute layout move-node left`)],
      conditions: [
        { type: "variable_if", name: TAB_WINDOW_MODE, value: 1 },
        { type: "variable_if", name: TAB_Q_NESTED_MODE, value: 1 },
      ],
    },
    {
      type: "basic",
      from: {
        key_code: "j",
        modifiers: { mandatory: ["shift"] },
      },
      to: [to$(`${riftBin} execute layout move-node down`)],
      conditions: [
        { type: "variable_if", name: TAB_WINDOW_MODE, value: 1 },
        { type: "variable_if", name: TAB_Q_NESTED_MODE, value: 1 },
      ],
    },
    {
      type: "basic",
      from: {
        key_code: "k",
        modifiers: { mandatory: ["shift"] },
      },
      to: [to$(`${riftBin} execute layout move-node up`)],
      conditions: [
        { type: "variable_if", name: TAB_WINDOW_MODE, value: 1 },
        { type: "variable_if", name: TAB_Q_NESTED_MODE, value: 1 },
      ],
    },
    {
      type: "basic",
      from: {
        key_code: "l",
        modifiers: { mandatory: ["shift"] },
      },
      to: [to$(`${riftBin} execute layout move-node right`)],
      conditions: [
        { type: "variable_if", name: TAB_WINDOW_MODE, value: 1 },
        { type: "variable_if", name: TAB_Q_NESTED_MODE, value: 1 },
      ],
    },
    {
      type: "basic",
      from: { key_code: "n" },
      to: [to$(`${riftBin} execute window move-to-workspace next true`)],
      conditions: [
        { type: "variable_if", name: TAB_WINDOW_MODE, value: 1 },
        { type: "variable_if", name: TAB_Q_NESTED_MODE, value: 1 },
      ],
    },
    {
      type: "basic",
      from: { key_code: "p" },
      to: [to$(`${riftBin} execute window move-to-workspace prev true`)],
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
      from: { key_code: "s" },
      to: [to$(`${riftBin} execute layout toggle-split`)],
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
  ]);

export const tabWindowManagerRules = [tabKeyRule, riftPrimaryRules, riftNestedRules];
