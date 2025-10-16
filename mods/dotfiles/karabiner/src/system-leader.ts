// filepath: mods/dotfiles/karabiner/src/tab.ts
import {
  ifVar,
  map,
  mapSimultaneous,
  rule,
  toKey,
  toSetVar,
  functionKeyCodes,
  letterKeyCodes,
  numberKeyCodes,
  otherKeyCodes,
  type FromKeyParam,
  type ToEvent,
  withCondition,
  Manipulator,
} from 'karabiner.ts';


const tabLeader = 'tab_leader';

// Helper function to exit leader mode
export const exitLeader = () => [toSetVar(tabLeader, 0)];

// Helper function to map a key with an action and exit leader mode
const leaderAction = (key: FromKeyParam, action: ToEvent | ToEvent[]) => map(key).to(action).to(exitLeader());

// Trigger keys for the leader mode
const leaderKeys = ['tab', 'q'] as FromKeyParam[];

const allKeyCodes = [...letterKeyCodes, ...numberKeyCodes, ...functionKeyCodes, ...otherKeyCodes];

/**
 * Type definition for a leader key node in the tree
 */
type LeaderNode = {
  key: FromKeyParam;       // The key to press
  value: string | number;  // The leader variable value for this node's layer
  nest?: LeaderNode[];     // Child nodes for nested layers
  mutation?: ToEvent | ToEvent[]; // Action to perform (if this is a leaf node)
}

const leaderTree: LeaderNode[] = [
  {
    key: 'c',
    value: 'code',
    nest: [
      {
        key: 'j',
        value: 'code_j', // Not actually used since this is a leaf node with mutation
        mutation: toKey('1'),
      },
      {
        key: 'k',
        value: 'code_k', // Not actually used since this is a leaf node with mutation
        mutation: toKey('2'),
      }
    ]
  },
  {
    key: 'w',
    value: 'window',
    nest: [
      {
        key: 'h',
        value: 'window_h', // Not used since this is a leaf with mutation
        mutation: toKey('left_arrow', ['command', 'option', 'control', 'shift']),
      },
      {
        key: 'j',
        value: 'window_j',
        mutation: toKey('down_arrow', ['command', 'option', 'control', 'shift']),
      },
      {
        key: 'k',
        value: 'window_k',
        mutation: toKey('up_arrow', ['command', 'option', 'control', 'shift']),
      },
      {
        key: 'l',
        value: 'window_l',
        mutation: toKey('right_arrow', ['command', 'option', 'control', 'shift']),
      }
    ]
  },
];

/**
 * Recursively builds manipulators for a leader key tree
 * @param nodes - Array of LeaderNode objects
 * @param parentValue - Value of the parent node (used for ifVar condition)
 * @returns Array of manipulators and manipulator builders
 */
function buildLeaderManipulators(
  nodes: LeaderNode[], 
  parentValue: string | number = 1
): Manipulator[] {
  let manipulators: Manipulator[] = [];
  
  // Get all keys at this level for unmapped key handling
  const layerKeys = nodes.map(n => n.key);
  
  // For each node at this level
  for (const node of nodes) {
    if (node.nest && node.nest.length > 0) {
      manipulators.push(
        ...withCondition(ifVar(tabLeader, parentValue))([
          map(node.key).toVar(tabLeader, node.value),
        ])
      );
      
      manipulators = manipulators.concat(
        buildLeaderManipulators(node.nest, node.value)
      );
    } else if (node.mutation) {
      manipulators.push(
        ...withCondition(ifVar(tabLeader, parentValue))([
          leaderAction(node.key, node.mutation),
        ])
      );
    }
  }
  
  const unmappedKeys = allKeyCodes.filter((k: FromKeyParam) => !layerKeys.includes(k) && k !== 'escape');
  
  manipulators.push(
    ...withCondition(ifVar(tabLeader, parentValue))([
      ...unmappedKeys.map(k => map(k).to(exitLeader())),
    ])
  );
  
  return manipulators;
}

/**
 * Builds a complete rule with all leader key manipulators
 * @param nodes - The leader key tree
 * @param triggerKeys - Keys that activate leader mode
 * @returns A rule with all manipulators
 */
function buildLeaderKeyRule(nodes: LeaderNode[], triggerKeys: FromKeyParam[]): Manipulator[] {
  // Initial trigger to activate leader mode
  const trigger = mapSimultaneous([...triggerKeys], undefined, 250)
    .toVar(tabLeader, 1);
  
  // Escape key handler for all layers
  const escapeHandler = withCondition(ifVar(tabLeader, 0).unless())([
    map('escape').to(exitLeader()),
  ]);
  
  // Build all other manipulators from the tree
  const treeManipulators = buildLeaderManipulators(nodes, 1);
  
  return [trigger, escapeHandler, ...treeManipulators] as Manipulator[];
}

// Build the leader key rule using our tree
const leaderKey = rule('Tab Leader Key').manipulators(
  buildLeaderKeyRule(leaderTree, leaderKeys)
);

export const tabRules = [leaderKey];

export const systemLeaderRules = tabRules;
