export type WindowAction = {
  id: string;
  binding: string;
  description: string;
  aliases: string[];
  command: string;
  lookCommand?: string;
};

const omniwmctl = "/etc/profiles/per-user/nick/bin/omniwmctl";
const adjacentWorkspaceScript =
  "$HOME/shell_scripts/omniwm-workspace-move-adjacent.sh";

export const windowActions: WindowAction[] = [
  {
    id: "focus-left",
    binding: "Tab + H",
    description: "Focus window left",
    aliases: ["focus", "left"],
    command: `${omniwmctl} command focus left`,
  },
  {
    id: "focus-down",
    binding: "Tab + J",
    description: "Focus window down",
    aliases: ["focus", "down"],
    command: `${omniwmctl} command focus down`,
  },
  {
    id: "focus-up",
    binding: "Tab + K",
    description: "Focus window up",
    aliases: ["focus", "up"],
    command: `${omniwmctl} command focus up`,
  },
  {
    id: "focus-right",
    binding: "Tab + L",
    description: "Focus window right",
    aliases: ["focus", "right"],
    command: `${omniwmctl} command focus right`,
  },
  {
    id: "workspace-next",
    binding: "Tab + N",
    description: "Switch to next workspace",
    aliases: ["workspace", "next"],
    command: `${omniwmctl} command switch-workspace next`,
  },
  {
    id: "workspace-prev",
    binding: "Tab + P",
    description: "Switch to previous workspace",
    aliases: ["workspace", "previous"],
    command: `${omniwmctl} command switch-workspace prev`,
  },
  {
    id: "open-look",
    binding: "Tab + F",
    description: "Open Look launcher",
    aliases: ["launcher", "look"],
    command: "open -a '/Applications/Look.app'",
  },
  {
    id: "move-left",
    binding: "Tab + Q + H",
    description: "Move window left",
    aliases: ["move", "window", "left"],
    command: `${omniwmctl} command move left`,
  },
  {
    id: "move-down",
    binding: "Tab + Q + J",
    description: "Move window down",
    aliases: ["move", "window", "down"],
    command: `${omniwmctl} command move down`,
  },
  {
    id: "move-up",
    binding: "Tab + Q + K",
    description: "Move window up",
    aliases: ["move", "window", "up"],
    command: `${omniwmctl} command move up`,
  },
  {
    id: "move-right",
    binding: "Tab + Q + L",
    description: "Move window right",
    aliases: ["move", "window", "right"],
    command: `${omniwmctl} command move right`,
  },
  {
    id: "join-left",
    binding: "Tab + Q + Y",
    description: "Join or expel window to the left",
    aliases: ["join", "window", "left"],
    command: `${omniwmctl} command move left`,
  },
  {
    id: "join-up",
    binding: "Tab + Q + U",
    description: "Join or expel window above",
    aliases: ["join", "window", "up"],
    command: `${omniwmctl} command move up`,
  },
  {
    id: "join-down",
    binding: "Tab + Q + I",
    description: "Join or expel window below",
    aliases: ["join", "window", "down"],
    command: `${omniwmctl} command move down`,
  },
  {
    id: "join-right",
    binding: "Tab + Q + O",
    description: "Join or expel window to the right",
    aliases: ["join", "window", "right"],
    command: `${omniwmctl} command move right`,
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
    command: `${omniwmctl} command toggle-focused-window-floating`,
  },
  {
    id: "toggle-fullscreen",
    binding: "Tab + Q + Z",
    description: "Toggle fullscreen",
    aliases: ["fullscreen", "window"],
    command: `${omniwmctl} command toggle-fullscreen`,
  },
  {
    id: "toggle-column-tabbed",
    binding: "Tab + Q + B",
    description: "Toggle Niri column tabbed",
    aliases: ["layout", "column", "tabbed"],
    command: `${omniwmctl} command toggle-column-tabbed`,
  },
  {
    id: "toggle-workspace-layout",
    binding: "Tab + Q + S",
    description: "Toggle workspace layout",
    aliases: ["layout", "niri", "dwindle"],
    command: `${omniwmctl} command toggle-workspace-layout`,
  },
  {
    id: "command-palette",
    binding: "Tab + Q + C",
    description: "Open OmniWM command palette",
    aliases: ["command", "palette", "omniwm"],
    command: `${omniwmctl} command open-command-palette`,
  },
  {
    id: "focus-previous",
    binding: "Tab + Q + A",
    description: "Focus previous window",
    aliases: ["focus", "previous", "last"],
    command: `${omniwmctl} command focus previous`,
  },
  {
    id: "toggle-overview",
    binding: "Tab + Q + V",
    description: "Toggle window overview",
    aliases: ["overview", "windows"],
    command: `${omniwmctl} command toggle-overview`,
  },
  {
    id: "toggle-quake-terminal",
    binding: "Tab + Q + T",
    description: "Toggle Quake terminal",
    aliases: ["terminal", "quake", "ghostty"],
    command: `${omniwmctl} command toggle-quake-terminal`,
  },
  {
    id: "balance-sizes",
    binding: "Tab + Q + G",
    description: "Balance window sizes",
    aliases: ["layout", "balance", "sizes"],
    command: `${omniwmctl} command balance-sizes`,
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
    command: `${omniwmctl} command close-focused-window`,
  },
  {
    id: "resize-shrink-primary",
    binding: "Tab + Q + -",
    description: "Shrink container primary span",
    aliases: ["resize", "shrink", "primary", "span"],
    command: `${omniwmctl} command set-container-primary-span -10%`,
  },
  {
    id: "resize-grow-primary",
    binding: "Tab + Q + =",
    description: "Grow container primary span",
    aliases: ["resize", "grow", "primary", "span"],
    command: `${omniwmctl} command set-container-primary-span +10%`,
  },
  {
    id: "resize-shrink-secondary",
    binding: "Tab + Q + Shift + -",
    description: "Shrink window secondary span",
    aliases: ["resize", "shrink", "secondary", "span"],
    command: `${omniwmctl} command set-window-secondary-span -10%`,
  },
  {
    id: "resize-grow-secondary",
    binding: "Tab + Q + Shift + =",
    description: "Grow window secondary span",
    aliases: ["resize", "grow", "secondary", "span"],
    command: `${omniwmctl} command set-window-secondary-span +10%`
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
        "omniwm",
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
