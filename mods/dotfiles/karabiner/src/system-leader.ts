import { type FromKeyParam, rule, to$, toKey } from "karabiner.ts";
import { buildLeaderKeyRule, LeaderNode, systemLeader } from "./leader-utils.ts";

const leaderKeys = ["tab", "q"] as FromKeyParam[];

const leaderTree: LeaderNode[] = [
  {
    key: "w",
    value: "window",
    nest: [
      {
        key: "z", // tmux zoom pane
        value: "window_zoom",
        mutation: to$('open -g "rectangle://execute-action?name=maximize"'),
      },
    ]
  }
    
];

// Build the leader key rule using our tree
const leaderKey = rule("System Leader Key").manipulators(
  buildLeaderKeyRule(systemLeader, leaderTree, leaderKeys),
);

export const systemLeaderRules = [leaderKey];
