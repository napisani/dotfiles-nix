export type WindowAction = {
  id: string;
  binding: string;
  description: string;
  aliases: string[];
  command: string;
  lookCommand?: string;
};

export const riftBin = "/etc/profiles/per-user/nick/bin/rift-cli";
const adjacentWorkspaceScript =
  "$HOME/shell_scripts/rift-workspace-move-adjacent.sh";

export const windowActions: WindowAction[] = [
  {
    id: "focus-left",
    binding: "Tab + H",
    description: "Focus window left",
    aliases: ["focus", "left"],
    command: `${riftBin} execute window focus left`,
  },
  {
    id: "focus-down",
    binding: "Tab + J",
    description: "Focus window down",
    aliases: ["focus", "down"],
    command: `${riftBin} execute window focus down`,
  },
  {
    id: "focus-up",
    binding: "Tab + K",
    description: "Focus window up",
    aliases: ["focus", "up"],
    command: `${riftBin} execute window focus up`,
  },
  {
    id: "focus-right",
    binding: "Tab + L",
    description: "Focus window right",
    aliases: ["focus", "right"],
    command: `${riftBin} execute window focus right`,
  },
  {
    id: "workspace-next",
    binding: "Tab + N",
    description: "Switch to next workspace",
    aliases: ["workspace", "next"],
    command: `${riftBin} execute workspace next`,
  },
  {
    id: "workspace-prev",
    binding: "Tab + P",
    description: "Switch to previous workspace",
    aliases: ["workspace", "previous"],
    command: `${riftBin} execute workspace prev`,
  },
  {
    id: "open-look",
    binding: "Tab + F",
    description: "Open Look launcher",
    aliases: ["launcher", "look"],
    command: "open -a '/Applications/Look.app'",
  },
  {
    id: "move-node-left",
    binding: "Tab + Q + H",
    description: "Move window node left",
    aliases: ["move", "node", "layout", "left"],
    command: `${riftBin} execute layout move-node left`,
  },
  {
    id: "move-node-down",
    binding: "Tab + Q + J",
    description: "Move window node down",
    aliases: ["move", "node", "layout", "down"],
    command: `${riftBin} execute layout move-node down`,
  },
  {
    id: "move-node-up",
    binding: "Tab + Q + K",
    description: "Move window node up",
    aliases: ["move", "node", "layout", "up"],
    command: `${riftBin} execute layout move-node up`,
  },
  {
    id: "move-node-right",
    binding: "Tab + Q + L",
    description: "Move window node right",
    aliases: ["move", "node", "layout", "right"],
    command: `${riftBin} execute layout move-node right`,
  },
  {
    id: "join-left",
    binding: "Tab + Q + Y",
    description: "Join window to the left",
    aliases: ["join", "window", "layout", "left"],
    command: `${riftBin} execute layout join-window left`,
  },
  {
    id: "join-up",
    binding: "Tab + Q + U",
    description: "Join window above",
    aliases: ["join", "window", "layout", "up"],
    command: `${riftBin} execute layout join-window up`,
  },
  {
    id: "join-down",
    binding: "Tab + Q + I",
    description: "Join window below",
    aliases: ["join", "window", "layout", "down"],
    command: `${riftBin} execute layout join-window down`,
  },
  {
    id: "join-right",
    binding: "Tab + Q + O",
    description: "Join window to the right",
    aliases: ["join", "window", "layout", "right"],
    command: `${riftBin} execute layout join-window right`,
  },
  {
    id: "move-workspace-next",
    binding: "Tab + Q + N",
    description: "Move window to next workspace",
    aliases: ["workspace", "move", "next"],
    command: `${adjacentWorkspaceScript} next`,
  },
  {
    id: "move-workspace-prev",
    binding: "Tab + Q + P",
    description: "Move window to previous workspace",
    aliases: ["workspace", "move", "previous"],
    command: `${adjacentWorkspaceScript} prev`,
  },
  {
    id: "toggle-float",
    binding: "Tab + Q + Space",
    description: "Toggle floating window",
    aliases: ["float", "floating", "window"],
    command: `${riftBin} execute window toggle-float`,
  },
  {
    id: "fullscreen-within-gaps",
    binding: "Tab + Q + Z",
    description: "Toggle fullscreen within gaps",
    aliases: ["fullscreen", "gaps", "window"],
    command: `${riftBin} execute window toggle-fullscreen-within-gaps`,
  },
  {
    id: "toggle-orientation",
    binding: "Tab + Q + B",
    description: "Toggle layout orientation",
    aliases: ["layout", "orientation", "split"],
    command: `${riftBin} execute layout toggle-orientation`,
  },
  {
    id: "toggle-stack",
    binding: "Tab + Q + S",
    description: "Toggle stack layout",
    aliases: ["layout", "stack"],
    command: `${riftBin} execute layout toggle-stack`,
  },
  {
    id: "create-workspace",
    binding: "Tab + Q + C",
    description: "Create workspace",
    aliases: ["workspace", "create", "new"],
    command: `${riftBin} execute workspace create`,
  },
  {
    id: "minimize-window",
    binding: "Tab + Q + M",
    description: "Minimize window",
    aliases: ["window", "minimize"],
    command: "",
    lookCommand:
      'osascript -e \'tell application "System Events" to keystroke "m" using {command down}\'',
  },
  {
    id: "close-window",
    binding: "Tab + Q + X",
    description: "Close window",
    aliases: ["window", "close", "quit"],
    command: `${riftBin} execute window close`,
  },
  {
    id: "resize-shrink-horizontal",
    binding: "Tab + Q + -",
    description: "Shrink window horizontally",
    aliases: ["resize", "shrink", "horizontal"],
    command: `${riftBin} execute window resize-shrink --orientation horizontal`,
  },
  {
    id: "resize-grow-horizontal",
    binding: "Tab + Q + =",
    description: "Grow window horizontally",
    aliases: ["resize", "grow", "horizontal"],
    command: `${riftBin} execute window resize-grow --orientation horizontal`,
  },
  {
    id: "resize-shrink-vertical",
    binding: "Tab + Q + Shift + -",
    description: "Shrink window vertically",
    aliases: ["resize", "shrink", "vertical"],
    command: `${riftBin} execute window resize-shrink --orientation vertical`,
  },
  {
    id: "resize-grow-vertical",
    binding: "Tab + Q + Shift + =",
    description: "Grow window vertically",
    aliases: ["resize", "grow", "vertical"],
    command: `${riftBin} execute window resize-grow --orientation vertical`,
  },
];

const actionById = new Map(windowActions.map((action) => [action.id, action]));

export const windowActionCommand = (id: string) => {
  const action = actionById.get(id);
  if (!action || !action.command) {
    throw new Error(`Window action has no Karabiner command: ${id}`);
  }
  return action.command;
};

const tomlString = (value: string) => JSON.stringify(value);

export const windowManagerLookSource = () =>
  [
    "# Generated from src/window-action-catalog.ts; do not edit manually.",
    ...windowActions.map((action) => {
      const aliases = [
        "window manager",
        "rift",
        "w",
        action.binding,
        ...action.aliases,
      ];
      const command = action.lookCommand || action.command;
      return [
        `[window-manager-${action.id}]`,
        `name = ${tomlString(`${action.binding} — ${action.description}`)}`,
        `aliases = ${JSON.stringify([...new Set(aliases)])}`,
        `do = [${tomlString(command)}]`,
      ].join("\n");
    }),
    "",
  ].join("\n\n");

export const adjacentWorkspaceMoveCommand = (direction: "next" | "prev") =>
  windowActionCommand(`move-workspace-${direction}`);
