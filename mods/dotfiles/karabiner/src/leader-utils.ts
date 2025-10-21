import {
  FromKeyParam,
  FromModifierParam,
  functionKeyCodes,
  ifVar,
  letterKeyCodes,
  Manipulator,
  map,
  mapSimultaneous,
  numberKeyCodes,
  otherKeyCodes,
  ToEvent,
  toSetVar,
  withCondition,
} from "karabiner.ts";
export const systemLeader = "system_leader";
export const windowLeader = "window_leader";

// Helper function to exit leader mode
export const exitLeader =
  () => [toSetVar(systemLeader, 0), toSetVar(windowLeader, 0)];

// Helper function to map a key with an action and exit leader mode
const leaderAction = (key: FromKeyParam, action: ToEvent | ToEvent[]) =>
  map(key).to(action).to(exitLeader());

export const allKeyCodes = [
  ...letterKeyCodes,
  ...numberKeyCodes,
  ...functionKeyCodes,
  ...otherKeyCodes,
];

/**
 * Type definition for a leader key node in the tree
 */
export type LeaderNode = {
  key: FromKeyParam; // The key to press
  keyMandatoryModifiers?: FromModifierParam | "" | null;
  value: string | number; // The leader variable value for this node's layer
  nest?: LeaderNode[]; // Child nodes for nested layers
  mutation?: ToEvent | ToEvent[]; // Action to perform (if this is a leaf node)
};

/**
 * Recursively builds manipulators for a leader key tree
 * @param nodes - Array of LeaderNode objects
 * @param parentValue - Value of the parent node (used for ifVar condition)
 * @returns Array of manipulators and manipulator builders
 */
function buildLeaderManipulators(
  leaderVariable:  string,
  nodes: LeaderNode[],
  parentValue: string | number = 1,
): Manipulator[] {
  let manipulators: Manipulator[] = [];

  // Get all keys at this level for unmapped key handling
  const layerKeys = nodes.map((n) => n.key);

  // For each node at this level
  for (const node of nodes) {
    if (node.nest && node.nest.length > 0) {
      manipulators.push(
        ...withCondition(ifVar(leaderVariable, parentValue))([
          map(node.key, node.keyMandatoryModifiers).toVar(
            leaderVariable,
            node.value,
          ),
        ]),
      );

      manipulators = manipulators.concat(
        buildLeaderManipulators(leaderVariable, node.nest, node.value),
      );
    } else if (node.mutation) {
      manipulators.push(
        ...withCondition(ifVar(leaderVariable, parentValue))([
          leaderAction(node.key, node.mutation),
        ]),
      );
    }
  }

  const unmappedKeys = allKeyCodes.filter((k: FromKeyParam) =>
    !layerKeys.includes(k) && k !== "escape"
  );

  manipulators.push(
    ...withCondition(ifVar(leaderVariable, parentValue))([
      ...unmappedKeys.map((k) => map(k).to(exitLeader())),
    ]),
  );

  return manipulators;
}

/**
 * Builds a complete rule with all leader key manipulators
 * @param nodes - The leader key tree
 * @param triggerKeys - Keys that activate leader mode
 * @returns A rule with all manipulators
 */
export function buildLeaderKeyRule(
  leaderVariable: string,
  nodes: LeaderNode[],
  triggerKeys: FromKeyParam[],
): Manipulator[] {
  // Initial trigger to activate leader mode
  const trigger = mapSimultaneous([...triggerKeys], undefined, 250)
    .toVar(leaderVariable, 1);

  // Escape key handler for all layers
  const escapeHandler = withCondition(ifVar(leaderVariable, 0).unless())([
    map("escape").to(exitLeader()),
  ]);

  // Build all other manipulators from the tree
  const treeManipulators = buildLeaderManipulators(leaderVariable, nodes, 1);

  return [trigger, escapeHandler, ...treeManipulators] as Manipulator[];
}
