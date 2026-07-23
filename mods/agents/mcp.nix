# agents/mcp.nix — Declarative MCP server configuration
#
# agentMcpSources declares MCP servers to merge into each agent's config file.
# Non-destructive: only adds/updates managed entries, never removes user-added servers.
#
# Supported agents and their config targets:
#   claude-code → ~/.claude.json          (mcpServers key)
#   pi          → ~/.pi/agent/mcp.json    (mcpServers key)
#   codex       → ~/.codex/config.toml    ([mcp_servers.<name>] table)
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
  inherit (shared) dotfiles home nodeBin isLoancrateMac;

  # Installed globally by mods/npmx.nix (`npm install -g @agentmemory/mcp`),
  # not spawned via `npx` — avoids an npx fetch/resolve on every MCP connect.
  agentmemoryMcpBin = "${home}/.local/bin/agentmemory-mcp";

  agentMcpSources = [
    # ── Loancrate: Linear MCP ─────────────────────────────────────────────────
    {
      name = "linear";
      condition = isLoancrateMac;
      config = {
        type = "http";
        url = "https://mcp.linear.app/mcp";
      };
      agents = [ "claude-code" ];
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
      agents = [ "claude-code" ];
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

    # ── agentmemory MCP ───────────────────────────────────────────────────────
    {
      name = "agentmemory";
      config = {
        command = agentmemoryMcpBin;
        env = {
          AGENTMEMORY_URL = "http://localhost:3111";
        };
      };
      agents = [ "claude-code" "codex" ];
    }
    {
      name = "agentmemory";
      config = {
        command = agentmemoryMcpBin;
        env = {
          AGENTMEMORY_URL = "http://localhost:3111";
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
    # apply-mcp-servers.js needs @iarna/toml for Codex's TOML config; install it
    # into scripts/node_modules (declared in scripts/package.json) the first time,
    # so Node's normal module resolution finds it with no global install/NODE_PATH.
    if [ ! -d "${scriptsDir}/node_modules/@iarna/toml" ]; then
      ${nodeBin}/npm install --prefix ${scriptsDir} --no-audit --no-fund --silent
    fi

    MCP_SOURCES=${lib.escapeShellArg (builtins.toJSON enabledMcpSources)} \
      ${nodeBin}/node ${scriptsDir}/apply-mcp-servers.js
  '';
}
