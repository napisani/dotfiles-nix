# agents/claude.nix — Claude Code: complete installation story
#
# Owns everything specific to Claude Code: skills, RTK hooks, shared
# instructions, MCP servers, plugin marketplace installs, Workmux status
# hooks, and (Loancrate-only) the loancrate.json config. See
# docs/adr/0001-per-agent-modules.md for why this isn't split across
# cross-agent shared files anymore.
{
  config,
  lib,
  pkgs-unstable,
  hostname ? "",
  machineRoles ? [ ],
  inputs ? { },
  homeManagerRelPath,
  ...
}:
let
  shared = import ./lib.nix {
    inherit
      config
      lib
      pkgs-unstable
      hostname
      machineRoles
      inputs
      homeManagerRelPath
      ;
  };
  inherit (shared)
    home
    dotfiles
    nodeBin
    callAgentLib
    ;

  skillFiles = callAgentLib ./skill-files.nix;
  instructions = callAgentLib ./instructions.nix;
  managedConfig = callAgentLib ./managed-config-lib.nix;

  agentCfg = config.agents.claude;
  selectedSkillNames = skillFiles.skillNamesFor "claude";

  instructionsTarget = "${home}/.claude/CLAUDE.md";
  mcpTarget = "${home}/.claude.json";
  scriptsDir = "${dotfiles}/agents/scripts";
  workmuxStatusDir = "${dotfiles}/agents/workmux-status";

  # Desired manual-only skills land here as
  # { skillName = "user-invocable-only"; }, applied to settings.json below.
  declaredSkillOverrides = skillFiles.mkSkillOverrides {
    agentId = "claude-code";
    skillNames = selectedSkillNames;
  };

in
lib.mkIf (config.agents.enable && agentCfg.enable) {
  # The adapter resolves desired skill names through the source catalog. Pinned
  # skills become store links; repo-local skills remain live out-of-store links.
  home.file = skillFiles.mkSkillFiles {
    skillNames = selectedSkillNames;
    targetDirRelPath = ".claude/skills";
  };

  home.activation.prepareClaudeInstructionsForRtk = lib.hm.dag.entryBefore [
    "installClaudeRtkHooks"
  ] (instructions.removeStaleInstructionSymlink { target = instructionsTarget; });

  home.activation.installClaudeRtkHooks = lib.hm.dag.entryAfter [ "linkGeneration" ] (
    shared.mkRtkHookInstall {
      rtkArgs = "--auto-patch";
      label = "claude-code";
    }
  );

  home.activation.writeClaudeInstructions = lib.hm.dag.entryAfter [ "installClaudeRtkHooks" ] ''
    ${instructions.writeAgentInstructions {
      target = instructionsTarget;
      source = config.agents.instructions;
    }}

    ${shared.mkRtkHookInstall {
      rtkArgs = "--auto-patch";
      label = "claude-code (re-applying RTK.md reference)";
    }}
  '';

  home.activation.configureClaudeMcpServers = lib.hm.dag.entryAfter [ "linkGeneration" ] (
    managedConfig.mkJsonManagedMerge {
      targetFile = mcpTarget;
      managedKey = "mcpServers";
      declaredEntries = agentCfg.mcpServers;
    }
  );

  # Full ownership of settings.json's skillOverrides key, chained after
  # applyClaudeWorkmuxHooks since that step also reads/writes settings.json —
  # sequencing avoids one activation step clobbering the other's write.
  # Revocable like mcpServers: clearing a selection's manualOnly flag removes
  # it from the declared override set, so the next switch rewrites the key
  # without it.
  home.activation.configureClaudeSkillOverrides =
    lib.hm.dag.entryAfter [ "applyClaudeWorkmuxHooks" ]
      (
        managedConfig.mkJsonManagedMerge {
          targetFile = "${home}/.claude/settings.json";
          managedKey = "skillOverrides";
          declaredEntries = declaredSkillOverrides;
        }
      );

  home.activation.installClaudePlugins = lib.hm.dag.entryAfter [ "linkGeneration" ] (
    managedConfig.mkClaudePluginInstall {
      marketplaces = agentCfg.pluginMarketplaces;
      declaredPlugins = agentCfg.plugins;
      stateId = "claude-plugins";
    }
  );

  home.activation.applyClaudeWorkmuxHooks = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    TARGET_FILE=${lib.escapeShellArg "${home}/.claude/settings.json"} \
    SOURCE_FILE=${lib.escapeShellArg "${workmuxStatusDir}/claude-hooks.json"} \
    EXTRA_SETTINGS=${lib.escapeShellArg (builtins.toJSON agentCfg.settings)} \
      ${nodeBin}/node ${scriptsDir}/apply-claude-hooks.js
  '';

  home.activation.applyLoancrateConfig = lib.mkIf (agentCfg.loancrateConfig != null) (
    lib.hm.dag.entryAfter [ "installClaudePlugins" ] ''
      export PATH="${nodeBin}:$PATH"
      LOANCRATE_BASE_CONFIG=${lib.escapeShellArg (builtins.toJSON agentCfg.loancrateConfig)} \
        ${nodeBin}/node ${scriptsDir}/apply-loancrate-config.js
    ''
  );
}
