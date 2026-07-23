# agents/hooks.nix — RTK init hooks and Workmux window-status hooks
#
# RTK (Rust Token Killer) hooks are installed by `rtk init -g` per-agent.
# Each agent uses its own init flag:
#   Claude Code:  rtk init -g --auto-patch
#   Codex:        rtk init -g --codex
#   OpenCode:     rtk init -g --opencode
#   Pi:           no rtk init target in the current rtk CLI
#
# Workmux status hooks merge into Claude Code and Codex config files so the
# terminal multiplexer window title reflects the current agent task.
{
  config,
  lib,
  pkgs-unstable,
  ...
}:
let
  shared = import ./lib.nix { inherit config pkgs-unstable; };
  inherit (shared) dotfiles nodeBin;

  scriptsDir = "${dotfiles}/agents/scripts";
in
{
  # Apply Workmux window-status hooks to Claude Code and Codex config.
  # Runs after skills so agent config files exist before merging hooks into them.
  # CLAUDE_SETTINGS also carries always-on user-level settings.json defaults:
  #   editorMode          — vim keybindings in the built-in editor
  #   permissions.defaultMode = "auto" — start every session in Auto Mode
  #     (requires Opus/Sonnet 4.6+; falls back to normal mode otherwise)
  home.activation.applyWorkmuxHooks = lib.hm.dag.entryAfter [ "installAgentSkills" ] ''
    DOTFILES=${lib.escapeShellArg dotfiles} \
    CLAUDE_SETTINGS=${lib.escapeShellArg (
      builtins.toJSON {
        editorMode = "vim";
        permissions.defaultMode = "auto";
      }
    )} \
      ${nodeBin}/node ${scriptsDir}/apply-workmux-hooks.js
  '';

  # Install RTK Bash-rewrite hooks for each agent when rtk is available.
  # RTK intercepts shell tool calls and transparently rewrites commands
  # (e.g. `git status` → `rtk git status`) for token savings.
  # Re-runs on every switch so hooks stay up to date with rtk upgrades.
  home.activation.installRtkHooks = lib.hm.dag.entryAfter [ "installAgentSkills" ] ''
    export PATH="$HOME/.local/bin:/opt/homebrew/bin:/run/current-system/sw/bin:$PATH"

    if command -v rtk >/dev/null 2>&1; then
      echo "agents: installing RTK hooks ($(rtk --version 2>/dev/null || echo unknown))"

      rtk init -g --auto-patch   && echo "agents: RTK hook installed for claude-code" || echo "agents: WARNING: RTK hook failed for claude-code"
      rtk init -g --codex        && echo "agents: RTK hook installed for codex"       || echo "agents: WARNING: RTK hook failed for codex"
      rtk init -g --opencode     && echo "agents: RTK hook installed for opencode"    || echo "agents: WARNING: RTK hook failed for opencode"
    else
      echo "agents: rtk not found on PATH — skipping RTK hook installation (install via: brew install rtk)"
    fi
  '';
}
