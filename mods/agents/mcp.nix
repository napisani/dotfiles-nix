# agents/mcp.nix — Declarative MCP server configuration
#
# agentMcpSources declares MCP servers to merge into each agent's config file.
# Non-destructive: only adds/updates managed entries, never removes user-added servers.
#
# Supported agents and their config targets:
#   claude-code → ~/.claude.json          (mcpServers key)
#   cursor      → ~/.cursor/mcp.json      (mcpServers key)
#   pi          → ~/.pi/agent/mcp.json    (mcpServers key)
#
# Fields:
#   name      — MCP server key in the config file
#   config    — the mcpServers entry object for that agent
#   agents    — list of agent IDs to configure
#   condition — boolean; when false the entry is skipped (default: true)
#
# When the same server has different config shapes for different agents
# (e.g. Pi needs oauth/lifecycle fields that claude-code does not), add
# separate entries with non-overlapping agents lists.
{
  config,
  lib,
  pkgs-unstable,
  ...
}:
let
  shared = import ./lib.nix { inherit config pkgs-unstable; };
  inherit (shared) dotfiles nodeBin isLoancrateMac;

  agentMcpSources = [
    # ── Loancrate: Linear MCP ─────────────────────────────────────────────────
    {
      name = "linear";
      condition = isLoancrateMac;
      config = {
        type = "http";
        url = "https://mcp.linear.app/mcp";
      };
      agents = [ "claude-code" "cursor" ];
    }
    {
      name = "linear";
      condition = isLoancrateMac;
      config = {
        url = "https://mcp.linear.app/mcp";
        lifecycle = "lazy";
      };
      agents = [ "pi" ];
    }

    # ── Loancrate: Figma MCP ──────────────────────────────────────────────────
    {
      name = "figma";
      condition = isLoancrateMac;
      config = {
        type = "http";
        url = "https://mcp.figma.com/mcp";
      };
      agents = [ "claude-code" "cursor" ];
    }
    {
      name = "figma";
      condition = isLoancrateMac;
      config = {
        url = "https://mcp.figma.com/mcp";
        auth = "oauth";
        oauth = {
          clientName = "Codex";
          clientUri = "https://github.com/openai/codex";
          scope = "mcp:connect";
        };
        lifecycle = "lazy";
      };
      agents = [ "pi" ];
    }
  ];

  enabledMcpSources = builtins.filter (s: s.condition or true) agentMcpSources;

  scriptsDir = "${dotfiles}/agents/scripts";
in
{
  home.activation.configureMcpServers = lib.hm.dag.entryAfter [ "installAgentSkills" ] ''
    MCP_SOURCES=${lib.escapeShellArg (builtins.toJSON enabledMcpSources)} \
      ${nodeBin}/node ${scriptsDir}/apply-mcp-servers.js
  '';
}
