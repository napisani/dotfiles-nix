# agents/codex.nix — Codex CLI: complete installation story
#
# Owns everything specific to Codex: skills, RTK hooks (+ the AGENTS.md
# `@RTK.md` reference, which must be reapplied after writing shared
# instructions since that overwrite would otherwise silently drop it — see
# docs/adr/0001-per-agent-modules.md), MCP servers (TOML), and Workmux status
# hooks.
{
  config,
  lib,
  pkgs-unstable,
  hostname ? "",
  ...
}:
let
  shared = import ./lib.nix { inherit config lib pkgs-unstable hostname; };
  inherit (shared) home dotfiles nodeBin callAgentLib;

  skills = callAgentLib ./skills.nix;
  instructions = callAgentLib ./instructions.nix;
  managedConfig = callAgentLib ./managed-config-lib.nix;

  skillDir = "${home}/.codex/skills";
  instructionsTarget = "${home}/.codex/AGENTS.md";
  configTomlFile = "${home}/.codex/config.toml";
  hooksTargetFile = "${home}/.codex/hooks.json";
  scriptsDir = "${dotfiles}/agents/scripts";
  workmuxStatusDir = "${dotfiles}/agents/workmux-status";

  # Installed globally by mods/npmx.nix (`npm install -g @agentmemory/mcp`),
  # not spawned via `npx` — avoids an npx fetch/resolve on every MCP connect.
  agentmemoryMcpBin = "${home}/.local/bin/agentmemory-mcp";

  declaredMcpEntries = {
    agentmemory = {
      command = agentmemoryMcpBin;
      env = {
        AGENTMEMORY_URL = "http://localhost:3111";
      };
    };
  };
in
{
  home.activation.fixCodexPathConflicts = lib.hm.dag.entryBefore [ "linkGeneration" ] (
    shared.mkFixPathConflicts [ skillDir ]
  );

  home.activation.installCodexSkills = lib.hm.dag.entryAfter [ "linkGeneration" ] (
    skills.mkAgentSkillInstall {
      agentId = "codex";
      inherit skillDir;
      localSkillsRelPath = "agents/codex/skills";
    }
  );

  home.activation.prepareCodexInstructionsForRtk = lib.hm.dag.entryBefore [ "installCodexRtkHooks" ] (
    instructions.removeStaleInstructionSymlink { target = instructionsTarget; }
  );

  home.activation.installCodexRtkHooks = lib.hm.dag.entryAfter [ "installCodexSkills" ] (
    shared.mkRtkHookInstall {
      rtkArgs = "--codex";
      label = "codex";
    }
  );

  # Write shared instructions, then immediately reapply RTK's `@RTK.md`
  # reference — the overwrite above would otherwise drop it every time,
  # since it's not part of the shared source file. Same-file, same-module
  # sequence now instead of a cross-file dependency on a shared step name.
  home.activation.writeCodexInstructions = lib.hm.dag.entryAfter [ "installCodexRtkHooks" ] ''
    ${instructions.writeAgentInstructions { target = instructionsTarget; }}

    ${shared.mkRtkHookInstall {
      rtkArgs = "--codex";
      label = "codex (re-applying RTK.md reference)";
    }}
  '';

  home.activation.configureCodexMcpServers = lib.hm.dag.entryAfter [ "installCodexSkills" ] (
    managedConfig.mkTomlManagedMerge {
      targetFile = configTomlFile;
      managedKey = "mcp_servers";
      declaredEntries = declaredMcpEntries;
      stateId = "codex-mcp-servers";
    }
  );

  # Ordered explicitly after configureCodexMcpServers: both write
  # ~/.codex/config.toml (one via a full TOML parse+stringify, the other via
  # raw line-based text search/replace) — an explicit order removes any
  # doubt about interaction between the two, even though a real round-trip
  # test (realistic hook-state keys, colons and all) found no actual
  # breakage either order.
  home.activation.applyCodexWorkmuxHooks = lib.hm.dag.entryAfter [ "configureCodexMcpServers" ] ''
    HOOKS_TARGET_FILE=${lib.escapeShellArg hooksTargetFile} \
    HOOKS_SOURCE_FILE=${lib.escapeShellArg "${workmuxStatusDir}/codex-hooks.json"} \
    CONFIG_TOML_FILE=${lib.escapeShellArg configTomlFile} \
      ${nodeBin}/node ${scriptsDir}/apply-codex-hooks.js
  '';
}
