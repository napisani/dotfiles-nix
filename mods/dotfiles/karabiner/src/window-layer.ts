import { map, rule, to$, toKey, toSetVar } from "karabiner.ts";

// Variable name for managing the tab key state
const TAB_WINDOW_MODE = "tab_window_mode_active";

// Define the tab key rule - acts as a normal tab when pressed alone
// and activates window management mode when held
const tabKeyRule = rule("Tab Key: Dual Role (Tab/Window Management)")
  .manipulators([
    {
      type: "basic",
      from: { key_code: "tab" },
      to: [{ set_variable: { name: TAB_WINDOW_MODE, value: 1 } }],
      to_if_alone: [{ key_code: "tab" }],
      to_after_key_up: [{ set_variable: { name: TAB_WINDOW_MODE, value: 0 } }],
    },
  ]);

// Create window management actions
const windowManagementRules = rule("Tab Window Management Actions")
  .manipulators([
    // Window navigation with hjkl
    {
      type: "basic",
      from: { key_code: "h" },
      to: [to$('open -g "rectangle://execute-action?name=left-half"')],
      conditions: [{ type: "variable_if", name: TAB_WINDOW_MODE, value: 1 }],
    },
    {
      type: "basic",
      from: { key_code: "j" },
      to: [to$('open -g "rectangle://execute-action?name=bottom-half"')],
      conditions: [{ type: "variable_if", name: TAB_WINDOW_MODE, value: 1 }],
    },
    {
      type: "basic",
      from: { key_code: "k" },
      to: [to$('open -g "rectangle://execute-action?name=top-half"')],
      conditions: [{ type: "variable_if", name: TAB_WINDOW_MODE, value: 1 }],
    },
    {
      type: "basic",
      from: { key_code: "l" },
      to: [to$('open -g "rectangle://execute-action?name=right-half"')],
      conditions: [{ type: "variable_if", name: TAB_WINDOW_MODE, value: 1 }],
    },

    // Resize windows
    {
      type: "basic",
      from: {
        key_code: "h",
        modifiers: { mandatory: ["right_shift"], optional: ["any"] },
      },
      to: [to$('open -g "rectangle://execute-action?name=first-two-thirds"')],
      conditions: [{ type: "variable_if", name: TAB_WINDOW_MODE, value: 1 }],
    },
    {
      type: "basic",
      from: {
        key_code: "j",
        modifiers: { mandatory: ["right_shift"], optional: ["any"] },
      },
      to: [to$('open -g "rectangle://execute-action?name=last-two-thirds"')],
      conditions: [{ type: "variable_if", name: TAB_WINDOW_MODE, value: 1 }],
    },
    {
      type: "basic",
      from: {
        key_code: "k",
        modifiers: { mandatory: ["right_shift"], optional: ["any"] },
      },
      to: [to$('open -g "rectangle://execute-action?name=first-two-thirds"')],
      conditions: [{ type: "variable_if", name: TAB_WINDOW_MODE, value: 1 }],
    },
    {
      type: "basic",
      from: {
        key_code: "l",
        modifiers: { mandatory: ["right_shift"], optional: ["any"] },
      },
      to: [to$('open -g "rectangle://execute-action?name=last-two-thirds"')],
      conditions: [{ type: "variable_if", name: TAB_WINDOW_MODE, value: 1 }],
    },

    // // Corner positions
    {
      type: "basic",
      from: { key_code: "1" },
      to: [to$('open -g "rectangle://execute-action?name=top-left"')],
      conditions: [{ type: "variable_if", name: TAB_WINDOW_MODE, value: 1 }],
    },
    {
      type: "basic",
      from: { key_code: "2" },
      to: [to$('open -g "rectangle://execute-action?name=top-right"')],
      conditions: [{ type: "variable_if", name: TAB_WINDOW_MODE, value: 1 }],
    },
    {
      type: "basic",
      from: { key_code: "3" },
      to: [to$('open -g "rectangle://execute-action?name=bottom-left"')],
      conditions: [{ type: "variable_if", name: TAB_WINDOW_MODE, value: 1 }],
    },
    {
      type: "basic",
      from: { key_code: "4" },
      to: [to$('open -g "rectangle://execute-action?name=bottom-right"')],
      conditions: [{ type: "variable_if", name: TAB_WINDOW_MODE, value: 1 }],
    },

    // // Full screen and maximize
    {
      type: "basic",
      from: { key_code: "z" },
      to: [to$('open -g "rectangle://execute-action?name=maximize"')],
      conditions: [{ type: "variable_if", name: TAB_WINDOW_MODE, value: 1 }],
    },

    // Display navigation
    {
      type: "basic",
      from: { key_code: "n" },
      to: [{ key_code: "tab", modifiers: ["left_command"] }],
      conditions: [{ type: "variable_if", name: TAB_WINDOW_MODE, value: 1 }],
    },
    {
      type: "basic",
      from: { key_code: "p" },
      to: [{ key_code: "tab", modifiers: ["left_command", "left_shift"] }],
      conditions: [{ type: "variable_if", name: TAB_WINDOW_MODE, value: 1 }],
    },
    // // Balance windows
    // {
    //   type: "basic",
    //   from: { key_code: "equal_sign" }, // "=" key
    //   to: [to$('open -g "rectangle://execute-action?name=almost-maximize"')],
    //   conditions: [{ type: "variable_if", name: TAB_WINDOW_MODE, value: 1 }]
    // },

    // // Center window
    // {
    //   type: "basic",
    //   from: { key_code: "c" },
    //   to: [to$('open -g "rectangle://execute-action?name=center"')],
    //   conditions: [{ type: "variable_if", name: TAB_WINDOW_MODE, value: 1 }]
    // },

    // // Tile/cascade
    // {
    //   type: "basic",
    //   from: { key_code: "t" },
    //   to: [to$('open -g "rectangle://execute-action?name=tile-all"')],
    //   conditions: [{ type: "variable_if", name: TAB_WINDOW_MODE, value: 1 }]
    // }
  ]);

// Export all rules
export const tabWindowManagerRules = [tabKeyRule, windowManagementRules];
