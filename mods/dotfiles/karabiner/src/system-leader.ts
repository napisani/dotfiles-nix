import { type FromKeyParam, rule, toKey } from "karabiner.ts";
import { buildLeaderKeyRule, LeaderNode, systemLeader } from "./leader-utils.ts";

const leaderKeys = ["a", "s"] as FromKeyParam[];

const leaderTree: LeaderNode[] = [
  {
    key: "c",
    value: "code",
    nest: [
      {
        key: "j",
        value: "code_j", // Not actually used since this is a leaf node with mutation
        mutation: toKey("1"),
      },
      {
        key: "k",
        value: "code_k", // Not actually used since this is a leaf node with mutation
        mutation: toKey("2"),
      },
    ],
  },
];

// Build the leader key rule using our tree
const leaderKey = rule("System Leader Key").manipulators(
  buildLeaderKeyRule(systemLeader, leaderTree, leaderKeys),
);

export const systemLeaderRules = [leaderKey];
