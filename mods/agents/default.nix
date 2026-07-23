# agents/default.nix — Declarative multi-agent configuration
#
# Manages skills, plugins, MCPs, and RTK hooks across AI coding agents:
#   claude-code, codex, opencode, pi
#
# ARCHITECTURE
# ─────────────────────────────────────────────────────────────────────────────
# ~/.agents/skills/<name>/          Global skill store (managed by skills@latest)
#   ├── shared from dotfiles         mods/dotfiles/agents/shared-skills/<name>/
#   ├── Axion from git               github.com/napisani/axion-skills
#   └── community (from git repos)   installed via activation hook
#
# Per-agent skill dirs receive symlinks from ~/.agents/skills/:
#   ~/.claude/skills/<name>
#   ~/.codex/skills/<name>
#   ~/.config/opencode/skills/<name>
#
# Pi is the exception: it auto-discovers both ~/.pi/agent/skills and
# ~/.agents/skills. Shared/community skills must live only in ~/.agents/skills
# for Pi, otherwise Pi reports name collisions at startup.
#
# SUBMODULES
# ─────────────────────────────────────────────────────────────────────────────
#   skills.nix           — agentSkillSources, community + local skill installation
#   plugins.nix          — agentPluginSources, Claude Code plugin installation
#   mcp.nix              — agentMcpSources, MCP server config (claude-code, pi, codex)
#   pi.nix               — Pi extensions, themes, settings, Understand-Anything plugin
#   hooks.nix            — RTK init hooks + Workmux window-status hooks
#   instructions.nix     — shared AGENTS.md / CLAUDE.md propagation
#   loancrate-config.nix — ~/.claude/loancrate.json (loancrate system only)
#
# All source lists support an optional `condition` attribute (boolean).
# When false the entry is skipped. Defaults to true (installed everywhere).
# Use this instead of lib.optionals to keep all sources readable in one place.
#
# ACTIVATION ORDER
# ─────────────────────────────────────────────────────────────────────────────
# fixAgentPathConflicts (before linkGeneration)
#   → linkGeneration
#     → installAgentSkills (after linkGeneration)
#       → installClaudePlugins   (after installAgentSkills)
#       → configureMcpServers    (after installAgentSkills)
#       → installPiConfig        (after installAgentSkills)
#       → applyWorkmuxHooks      (after installAgentSkills)
#       → prepareAgentInstructionsForRtk (before installRtkHooks)
#       → installRtkHooks        (after installAgentSkills)
#         → applySharedAgentInstructions (after installRtkHooks)
#       → applyLoancrateConfig   (after installClaudePlugins, loancrate only)
{
  config,
  lib,
  pkgs-unstable,
  ...
}:
{
  imports = [
    ./skills.nix
    ./plugins.nix
    ./mcp.nix
    ./pi.nix
    ./hooks.nix
    ./instructions.nix
    ./loancrate-config.nix
  ];

  # Remove stale files that must be dirs (skills@latest requires dirs, not symlinks).
  # Runs before linkGeneration so home-manager can create its own symlinks cleanly.
  home.activation.fixAgentPathConflicts = lib.hm.dag.entryBefore [ "linkGeneration" ] ''
    for p in \
      "$HOME/.agents/skills" \
      "$HOME/.claude/skills" \
      "$HOME/.claude/commands" \
      "$HOME/.codex/skills" \
      "$HOME/.pi/agent/skills" \
      "$HOME/.pi/agent/extensions" \
      "$HOME/.pi/agent/themes"; do
      if [ -L "$p" ] || { [ -e "$p" ] && [ ! -d "$p" ]; }; then
        echo "agents: removing stale non-directory at $p"
        rm -rf "$p"
      fi
    done
  '';
}
