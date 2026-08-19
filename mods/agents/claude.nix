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
    inherit config lib pkgs-unstable hostname machineRoles inputs homeManagerRelPath;
  };
  inherit (shared) home dotfiles nodeBin isLoancrateMac callAgentLib;

  skills = callAgentLib ./skills.nix;
  instructions = callAgentLib ./instructions.nix;
  managedConfig = callAgentLib ./managed-config-lib.nix;

  instructionsTarget = "${home}/.claude/CLAUDE.md";
  mcpTarget = "${home}/.claude.json";
  scriptsDir = "${dotfiles}/agents/scripts";
  workmuxStatusDir = "${dotfiles}/agents/workmux-status";

  mcpSources = [
    {
      name = "linear";
      condition = isLoancrateMac;
      config = {
        type = "http";
        url = "https://mcp.linear.app/mcp";
      };
    }
    {
      name = "figma";
      condition = isLoancrateMac;
      config = {
        type = "http";
        url = "https://mcp.figma.com/mcp";
      };
    }
    {
      name = "bde";
      condition = isLoancrateMac;
      config = {
        type = "http";
        url = "https://bde.dsci.loancrate.dev/mcp";
      };
    }
  ];
  declaredMcpEntries = shared.mkDeclaredEntriesFromSources mcpSources;

  # Catalog skills flagged manualOnlyAgents = [ "claude-code" ... ] land here
  # as { skillName = "user-invocable-only"; }, applied to settings.json below.
  declaredSkillOverrides = skills.mkSkillOverrides { agentId = "claude-code"; };

  # Claude Code plugins — public community plugins + Loancrate org plugins.
  pluginMarketplaces = [
    "nicobailon/visual-explainer"
  ]
  ++ lib.optionals isLoancrateMac [ "loancrate/org-claude-skills#workmux" ];
  declaredPlugins = [
    "visual-explainer@visual-explainer-marketplace"
  ]
  ++ lib.optionals isLoancrateMac [
    "lc@lc"
    "code@lc"
  ];

  loancrateBaseConfig = builtins.toJSON {
    user_prefix = "nick";
    work_root = "${home}/Work";
    team_repos = {
      lc = "${home}/code/loancrate/loancrate";
    };
  };
in
{
  # Skills and commands are Layer 0 (only Nix writes these dirs): installed as
  # home.file links instead of an activation script. Community skills are store
  # symlinks (pinned via flake.lock); shared/local skills and commands are
  # out-of-store symlinks into the working tree (live-editable). Revocation is
  # home-manager's own link bookkeeping. See docs/adr/0002-layered-asset-management.md.
  home.file =
    skills.mkCommunitySkillFiles {
      agentId = "claude-code";
      skillDirRelPath = ".claude/skills";
    }
    // skills.mkLocalSkillFiles {
      sourceRelPath = "agents/shared-skills";
      targetDirRelPath = ".claude/skills";
    }
    // skills.mkLocalSkillFiles {
      sourceRelPath = "agents/claude/skills";
      targetDirRelPath = ".claude/skills";
    }
    // skills.mkLocalSkillFiles {
      sourceRelPath = "agents/claude/commands";
      targetDirRelPath = ".claude/commands";
    };

  home.activation.prepareClaudeInstructionsForRtk = lib.hm.dag.entryBefore [ "installClaudeRtkHooks" ] (
    instructions.removeStaleInstructionSymlink { target = instructionsTarget; }
  );

  home.activation.installClaudeRtkHooks = lib.hm.dag.entryAfter [ "linkGeneration" ] (
    shared.mkRtkHookInstall {
      rtkArgs = "--auto-patch";
      label = "claude-code";
    }
  );

  home.activation.writeClaudeInstructions = lib.hm.dag.entryAfter [ "installClaudeRtkHooks" ] ''
    ${instructions.writeAgentInstructions { target = instructionsTarget; }}

    ${shared.mkRtkHookInstall {
      rtkArgs = "--auto-patch";
      label = "claude-code (re-applying RTK.md reference)";
    }}
  '';

  home.activation.configureClaudeMcpServers = lib.hm.dag.entryAfter [ "linkGeneration" ] (
    managedConfig.mkJsonManagedMerge {
      targetFile = mcpTarget;
      managedKey = "mcpServers";
      declaredEntries = declaredMcpEntries;
    }
  );

  # Full ownership of settings.json's skillOverrides key, chained after
  # applyClaudeWorkmuxHooks since that step also reads/writes settings.json —
  # sequencing avoids one activation step clobbering the other's write.
  # Revocable like mcpServers: dropping a skill's manualOnlyAgents entry
  # removes it from the declared set, so the next switch rewrites the key
  # without it.
  home.activation.configureClaudeSkillOverrides = lib.hm.dag.entryAfter [ "applyClaudeWorkmuxHooks" ] (
    managedConfig.mkJsonManagedMerge {
      targetFile = "${home}/.claude/settings.json";
      managedKey = "skillOverrides";
      declaredEntries = declaredSkillOverrides;
    }
  );

  home.activation.installClaudePlugins = lib.hm.dag.entryAfter [ "linkGeneration" ] (
    managedConfig.mkClaudePluginInstall {
      marketplaces = pluginMarketplaces;
      inherit declaredPlugins;
      stateId = "claude-plugins";
    }
  );

  home.activation.applyClaudeWorkmuxHooks = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    TARGET_FILE=${lib.escapeShellArg "${home}/.claude/settings.json"} \
    SOURCE_FILE=${lib.escapeShellArg "${workmuxStatusDir}/claude-hooks.json"} \
    EXTRA_SETTINGS=${
      lib.escapeShellArg (
        builtins.toJSON {
          editorMode = "vim";
          permissions.defaultMode = "auto";
        }
      )
    } \
      ${nodeBin}/node ${scriptsDir}/apply-claude-hooks.js
  '';

  home.activation.applyLoancrateConfig = lib.mkIf isLoancrateMac (
    lib.hm.dag.entryAfter [ "installClaudePlugins" ] ''
      export PATH="${nodeBin}:$PATH"
      LOANCRATE_BASE_CONFIG=${lib.escapeShellArg loancrateBaseConfig} \
        ${nodeBin}/node ${scriptsDir}/apply-loancrate-config.js
    ''
  );
}
