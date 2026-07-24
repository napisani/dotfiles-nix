# agents/default.nix — Declarative multi-agent configuration
#
# Each of claude.nix, codex.nix, opencode.nix, pi.nix owns its complete
# installation story end to end (skills, MCP servers, capability/plugin
# installs via whatever mechanism is native to that agent, RTK hooks, shared
# instructions) — see docs/adr/0001-per-agent-modules.md for why this isn't
# split across cross-agent shared files.
#
# What's still shared, deliberately agent-blind (no per-agent branching):
#   lib.nix                 — paths, allAgents enumeration, machine identity
#                              (hostname-derived), mkFixPathConflicts
#   skills.nix               — the skill catalog (DRY data, not behavior) +
#                              mkAgentSkillInstall utility
#   instructions.nix         — the shared AGENTS.md source + writeAgentInstructions
#   managed-config-lib.nix   — JSON/TOML managed-key merge+prune, and the
#                              CLI-driven diff+prune shape (Claude plugins,
#                              Pi packages)
#
# All source lists (skill catalog, MCP entries, plugin/package lists) support
# an optional `condition` attribute (boolean). When false the entry is
# skipped. Defaults to true (installed everywhere).
{
  config,
  lib,
  pkgs-unstable,
  ...
}:
{
  imports = [
    ./claude.nix
    ./codex.nix
    ./opencode.nix
    ./pi.nix
  ];
}
