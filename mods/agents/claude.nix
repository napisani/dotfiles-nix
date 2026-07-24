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
  ...
}:
let
  shared = import ./lib.nix { inherit config lib pkgs-unstable hostname; };
  inherit (shared) home dotfiles nodeBin isLoancrateMac callAgentLib;

  skills = callAgentLib ./skills.nix;
  instructions = callAgentLib ./instructions.nix;
  managedConfig = callAgentLib ./managed-config-lib.nix;

  skillDir = "${home}/.claude/skills";
  commandsDir = "${home}/.claude/commands";
  instructionsTarget = "${home}/.claude/CLAUDE.md";
  mcpTarget = "${home}/.claude.json";
  scriptsDir = "${dotfiles}/agents/scripts";
  workmuxStatusDir = "${dotfiles}/agents/workmux-status";

  # Installed globally by mods/npmx.nix (`npm install -g @agentmemory/mcp`),
  # not spawned via `npx` — avoids an npx fetch/resolve on every MCP connect.
  agentmemoryMcpBin = "${home}/.local/bin/agentmemory-mcp";

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
      name = "agentmemory";
      config = {
        command = agentmemoryMcpBin;
        env = {
          AGENTMEMORY_URL = "http://localhost:3111";
        };
      };
    }
  ];
  declaredMcpEntries = shared.mkDeclaredEntriesFromSources mcpSources;

  # Claude Code plugin marketplace — Loancrate org skills package (lc@ and
  # code@ plugins).
  pluginMarketplace = if isLoancrateMac then "loancrate/org-claude-skills#workmux" else null;
  declaredPlugins = lib.optionals isLoancrateMac [
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
  home.activation.fixClaudePathConflicts = lib.hm.dag.entryBefore [ "linkGeneration" ] (
    shared.mkFixPathConflicts [
      # $HOME/.agents/skills is the shared global skill store all four
      # agents' installXSkills steps wipe/rebuild — it only needs fixing
      # once, before any of them run; claude.nix is as good a place as any.
      "${home}/.agents/skills"
      skillDir
      commandsDir
    ]
  );

  home.activation.installClaudeSkills = lib.hm.dag.entryAfter [ "linkGeneration" ] (
    skills.mkAgentSkillInstall {
      agentId = "claude-code";
      inherit skillDir;
      localSkillsRelPath = "agents/claude/skills";
    }
  );

  # Claude slash commands: wiped and rebuilt from mods/dotfiles/agents/claude/commands
  # every activation, so a removed command actually disappears (matching the
  # revocation bar the skill-install mechanism already meets).
  home.activation.installClaudeCommands = lib.hm.dag.entryAfter [ "installClaudeSkills" ] ''
    for _entry in ${lib.escapeShellArg commandsDir}/*; do
      [ -e "$_entry" ] || [ -L "$_entry" ] || continue
      rm -rf "$_entry"
    done
    ${skills.mkLocalSkillSyncScript {
      sourceRelPath = "agents/claude/commands";
      targetAbsPath = commandsDir;
    }}
  '';

  home.activation.prepareClaudeInstructionsForRtk = lib.hm.dag.entryBefore [ "installClaudeRtkHooks" ] (
    instructions.removeStaleInstructionSymlink { target = instructionsTarget; }
  );

  home.activation.installClaudeRtkHooks = lib.hm.dag.entryAfter [ "installClaudeSkills" ] (
    shared.mkRtkHookInstall {
      rtkArgs = "--auto-patch";
      label = "claude-code";
    }
  );

  home.activation.writeClaudeInstructions = lib.hm.dag.entryAfter [ "installClaudeRtkHooks" ] (
    instructions.writeAgentInstructions { target = instructionsTarget; }
  );

  home.activation.configureClaudeMcpServers = lib.hm.dag.entryAfter [ "installClaudeSkills" ] (
    managedConfig.mkJsonManagedMerge {
      targetFile = mcpTarget;
      managedKey = "mcpServers";
      declaredEntries = declaredMcpEntries;
      stateId = "claude-mcp-servers";
    }
  );

  home.activation.installClaudePlugins = lib.hm.dag.entryAfter [ "installClaudeSkills" ] (
    managedConfig.mkClaudePluginInstall {
      marketplace = pluginMarketplace;
      inherit declaredPlugins;
      stateId = "claude-plugins";
    }
  );

  home.activation.applyClaudeWorkmuxHooks = lib.hm.dag.entryAfter [ "installClaudeSkills" ] ''
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
