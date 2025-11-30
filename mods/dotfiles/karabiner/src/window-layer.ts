import { rule, to$ } from "karabiner.ts";

const yabaiBin = "/opt/homebrew/bin/yabai";

const TAB_WINDOW_MODE = "tab_window_mode_active";
const TAB_Q_NESTED_MODE = "tab_q_nested_mode_active";

const tabKeyRule = rule("Tab Key: Dual Role (Tab/Yabai Management)")
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

const yabaiPrimaryRules = rule("Tab: Yabai Primary Actions")
  .manipulators([
    {
      type: "basic",
      from: { key_code: "h" },
      to: [to$(`${yabaiBin} -m window --focus west`)],
      conditions: [{ type: "variable_if", name: TAB_WINDOW_MODE, value: 1 }],
    },
    {
      type: "basic",
      from: { key_code: "j" },
      to: [to$(`${yabaiBin} -m window --focus south`)],
      conditions: [{ type: "variable_if", name: TAB_WINDOW_MODE, value: 1 }],
    },
    {
      type: "basic",
      from: { key_code: "k" },
      to: [to$(`${yabaiBin} -m window --focus north`)],
      conditions: [{ type: "variable_if", name: TAB_WINDOW_MODE, value: 1 }],
    },
    {
      type: "basic",
      from: { key_code: "l" },
      to: [to$(`${yabaiBin} -m window --focus east`)],
      conditions: [{ type: "variable_if", name: TAB_WINDOW_MODE, value: 1 }],
    },
    {
      type: "basic",
      from: { key_code: "n" },
      to: [to$(`${yabaiBin} -m space --focus next || ${yabaiBin} -m space --focus first`)],
      conditions: [{ type: "variable_if", name: TAB_WINDOW_MODE, value: 1 }],
    },
    {
      type: "basic",
      from: { key_code: "p" },
      to: [to$(`${yabaiBin} -m space --focus prev || ${yabaiBin} -m space --focus last`)],
      conditions: [{ type: "variable_if", name: TAB_WINDOW_MODE, value: 1 }],
    },
    {
      type: "basic",
      from: { key_code: "m" },
      to: [to$(`${yabaiBin} -m window --focus largest`)],
      conditions: [{ type: "variable_if", name: TAB_WINDOW_MODE, value: 1 }],
    },
    {
      type: "basic",
      from: { key_code: "r" },
      to: [to$(`${yabaiBin} -m window --focus recent`)],
      conditions: [{ type: "variable_if", name: TAB_WINDOW_MODE, value: 1 }],
    },
    {
      type: "basic",
      from: { key_code: "spacebar" },
      to: [to$(`${yabaiBin} -m window --toggle zoom-fullscreen`)],
      conditions: [{ type: "variable_if", name: TAB_WINDOW_MODE, value: 1 }],
    },
    {
      type: "basic",
      from: { key_code: "b" },
      to: [to$(`${yabaiBin} -m space --balance`)],
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

const yabaiNestedRules = rule("Tab+Q: Yabai Nested Actions")
  .manipulators([
    {
      type: "basic",
      from: { key_code: "h" },
      to: [to$(`${yabaiBin} -m window --swap west`)],
      conditions: [
        { type: "variable_if", name: TAB_WINDOW_MODE, value: 1 },
        { type: "variable_if", name: TAB_Q_NESTED_MODE, value: 1 },
      ],
    },
    {
      type: "basic",
      from: { key_code: "j" },
      to: [to$(`${yabaiBin} -m window --swap south`)],
      conditions: [
        { type: "variable_if", name: TAB_WINDOW_MODE, value: 1 },
        { type: "variable_if", name: TAB_Q_NESTED_MODE, value: 1 },
      ],
    },
    {
      type: "basic",
      from: { key_code: "k" },
      to: [to$(`${yabaiBin} -m window --swap north`)],
      conditions: [
        { type: "variable_if", name: TAB_WINDOW_MODE, value: 1 },
        { type: "variable_if", name: TAB_Q_NESTED_MODE, value: 1 },
      ],
    },
    {
      type: "basic",
      from: { key_code: "l" },
      to: [to$(`${yabaiBin} -m window --swap east`)],
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
      to: [to$(`${yabaiBin} -m window --warp west`)],
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
      to: [to$(`${yabaiBin} -m window --warp south`)],
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
      to: [to$(`${yabaiBin} -m window --warp north`)],
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
      to: [to$(`${yabaiBin} -m window --warp east`)],
      conditions: [
        { type: "variable_if", name: TAB_WINDOW_MODE, value: 1 },
        { type: "variable_if", name: TAB_Q_NESTED_MODE, value: 1 },
      ],
    },
    {
      type: "basic",
      from: { key_code: "n" },
      to: [to$(`${yabaiBin} -m window --space next && ${yabaiBin} -m space --focus next`)],
      conditions: [
        { type: "variable_if", name: TAB_WINDOW_MODE, value: 1 },
        { type: "variable_if", name: TAB_Q_NESTED_MODE, value: 1 },
      ],
    },
    {
      type: "basic",
      from: { key_code: "p" },
      to: [to$(`${yabaiBin} -m window --space prev && ${yabaiBin} -m space --focus prev`)],
      conditions: [
        { type: "variable_if", name: TAB_WINDOW_MODE, value: 1 },
        { type: "variable_if", name: TAB_Q_NESTED_MODE, value: 1 },
      ],
    },
    {
      type: "basic",
      from: { key_code: "spacebar" },
      to: [to$(`${yabaiBin} -m window --toggle float`)],
      conditions: [
        { type: "variable_if", name: TAB_WINDOW_MODE, value: 1 },
        { type: "variable_if", name: TAB_Q_NESTED_MODE, value: 1 },
      ],
    },
    {
      type: "basic",
      from: { key_code: "s" },
      to: [to$(`${yabaiBin} -m window --toggle split`)],
      conditions: [
        { type: "variable_if", name: TAB_WINDOW_MODE, value: 1 },
        { type: "variable_if", name: TAB_Q_NESTED_MODE, value: 1 },
      ],
    },
    {
      type: "basic",
      from: { key_code: "c" },
      to: [to$(`${yabaiBin} -m space --create`)],
      conditions: [
        { type: "variable_if", name: TAB_WINDOW_MODE, value: 1 },
        { type: "variable_if", name: TAB_Q_NESTED_MODE, value: 1 },
      ],
    },
  ]);

export const tabWindowManagerRules = [tabKeyRule, yabaiPrimaryRules, yabaiNestedRules];
