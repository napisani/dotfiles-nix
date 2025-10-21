import { type FromKeyParam, rule, to$, toKey, toSetVar } from "karabiner.ts";
import { buildLeaderKeyRule, LeaderNode, windowLeader } from "./leader-utils.ts";


// Trigger keys for the leader mode
const leaderKeys = ["a", "w"] as FromKeyParam[];

const leaderTree: LeaderNode[] = [
  {
    key: "quote", // tmux vertical split
    keyMandatoryModifiers: ["left_shift"],
    value: "window_split_v",
    mutation: to$('open -g "rectangle://execute-action?name=top-half"'),
  },
  {
    key: "5",
    keyMandatoryModifiers: ["left_shift"],
    value: "window_split_h",
    mutation: to$('open -g "rectangle://execute-action?name=left-half"'),
  },
  // Window navigation with arrow keys (similar to tmux pane navigation)
  {
    key: "left_arrow", // tmux left pane
    value: "window_left",
    mutation: to$('open -g "rectangle://execute-action?name=left-half"'),
  },
  {
    key: "down_arrow", // tmux down pane
    value: "window_down",
    mutation: to$('open -g "rectangle://execute-action?name=bottom-half"'),
  },
  {
    key: "up_arrow", // tmux up pane
    value: "window_up",
    mutation: to$('open -g "rectangle://execute-action?name=top-half"'),
  },
  {
    key: "right_arrow", // tmux right pane
    value: "window_right",
    mutation: to$('open -g "rectangle://execute-action?name=right-half"'),
  },
  // Window navigation with hjkl (alternative tmux navigation)
  {
    key: "h", // tmux left pane (with h)
    value: "window_h",
    mutation: to$('open -g "rectangle://execute-action?name=left-half"'),
  },
  {
    key: "j", // tmux down pane (with j)
    value: "window_j",
    mutation: to$('open -g "rectangle://execute-action?name=bottom-half"'),
  },
  {
    key: "k", // tmux up pane (with k)
    value: "window_k",
    mutation: to$('open -g "rectangle://execute-action?name=top-half"'),
  },
  {
    key: "l", // tmux right pane (with l)
    value: "window_l",
    mutation: to$('open -g "rectangle://execute-action?name=right-half"'),
  },
  // Resize windows (similar to tmux resize-pane commands)
  {
    key: "h", // tmux resize-pane -L
    keyMandatoryModifiers: ["left_shift"],
    value: "window_resize_left",
    mutation: to$(
      'open -g "rectangle://execute-action?name=first-two-thirds"',
    ),
  },
  {
    key: "j", // tmux resize-pane -D
    keyMandatoryModifiers: ["left_shift"],
    value: "window_resize_down",
    mutation: to$(
      'open -g "rectangle://execute-action?name=last-two-thirds"',
    ),
  },
  {
    key: "k", // tmux resize-pane -U
    keyMandatoryModifiers: ["left_shift"],
    value: "window_resize_up",
    mutation: to$(
      'open -g "rectangle://execute-action?name=first-two-thirds"',
    ),
  },
  {
    key: "l", // tmux resize-pane -R
    keyMandatoryModifiers: ["left_shift"],
    value: "window_resize_right",
    mutation: to$(
      'open -g "rectangle://execute-action?name=last-two-thirds"',
    ),
  },
  // // Fine-tuned resizing (similar to tmux's repeated resize commands)
  // {
  //   key: 'left',  // tmux repeated resize-pane -L
  //   value: 'window_resize_smaller',
  //   mutation: to$('open -g "rectangle://execute-action?name=smaller"'),
  // },
  // {
  //   key: 'right',  // tmux repeated resize-pane -R
  //   value: 'window_resize_larger',
  //   mutation: to$('open -g "rectangle://execute-action?name=larger"'),
  // },
  // Corner positions (no direct tmux equivalent, but useful)
  {
    key: "1",
    value: "window_1",
    mutation: to$('open -g "rectangle://execute-action?name=top-left"'),
  },
  {
    key: "2",
    value: "window_2",
    mutation: to$('open -g "rectangle://execute-action?name=top-right"'),
  },
  {
    key: "3",
    value: "window_3",
    mutation: to$('open -g "rectangle://execute-action?name=bottom-left"'),
  },
  {
    key: "4",
    value: "window_4",
    mutation: to$('open -g "rectangle://execute-action?name=bottom-right"'),
  },
  // Full screen and maximize (similar to tmux zoom pane)
  {
    key: "z", // tmux zoom pane
    value: "window_zoom",
    mutation: to$('open -g "rectangle://execute-action?name=maximize"'),
  },
  // Layout presets (similar to tmux select-layout)
  // {
  //   key: 'space',  // tmux next-layout
  //   value: 'window_cycle_layout',
  //   mutation: to$('open -g "rectangle://execute-action?name=center"'),
  // },
  // Display navigation (similar to tmux's session navigation)
  {
    key: "n", // tmux next-window
    value: "window_next_display",
    // mutation: to$('open -g "rectangle://execute-action?name=next-display"'),
    mutation: toKey('f4', 'left_control'),
  },
  {
    key: "p", // tmux previous-window
    value: "window_prev_display",
    // mutation: to$(
    //   'open -g "rectangle://execute-action?name=previous-display"',
    // ),
    mutation: toKey('tab', ['left_command', 'left_shift']),
  },
  // Third layouts (similar to tmux layouts)
  // {
  //   key: 'M-1',  // Alt+1, similar to tmux select-layout even-horizontal
  //   value: 'window_first_third',
  //   mutation: to$('open -g "rectangle://execute-action?name=first-third"'),
  // },
  // {
  //   key: 'M-2',  // Alt+2, similar to tmux select-layout even-vertical
  //   value: 'window_center_third',
  //   mutation: to$('open -g "rectangle://execute-action?name=center-third"'),
  // },
  // {
  //   key: 'M-3',  // Alt+3, custom layout
  //   value: 'window_last_third',
  //   mutation: to$('open -g "rectangle://execute-action?name=last-third"'),
  // },
  // Balance windows (similar to tmux's even layouts)
  {
    key: "=", // tmux select-layout even-horizontal/even-vertical
    value: "window_balance",
    mutation: to$(
      'open -g "rectangle://execute-action?name=almost-maximize"',
    ),
  },
  // Center window (no direct tmux equivalent)
  {
    key: "c",
    value: "window_center",
    mutation: to$('open -g "rectangle://execute-action?name=center"'),
  },
  // Tile/cascade (similar to tmux layouts)
  {
    key: "t", // for "tile"
    value: "window_tile",
    mutation: to$('open -g "rectangle://execute-action?name=tile-all"'),
  },
  // {
  //   key: 'C',  // capital C for "cascade"
  //   value: 'window_cascade',
  //   mutation: to$('open -g "rectangle://execute-action?name=cascade-all"'),
  // }
];

// Build the leader key rule using our tree
const leaderKey = rule("Window Leader Key").manipulators(
  buildLeaderKeyRule(windowLeader, leaderTree, leaderKeys),
);

export const windowLeaderRules = [leaderKey];
