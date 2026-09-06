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
      inputs
      homeManagerRelPath
      ;
  };
  inherit (shared)
    home
    nodeBin
    callAgentLib
    ;

  skillFiles = callAgentLib ./skill-files.nix;
  instructions = callAgentLib ./instructions.nix;
  managedConfig = callAgentLib ./managed-config-lib.nix;

  agentCfg = config.agents.claude;
  enabled = config.agents.enable && agentCfg.enable;
  selectedSkillNames = skillFiles.skillNamesFor "claude";

  rtk = config.agents.rtkPackage;
  rtkAssets = import ./rtk-assets.nix {
    inherit lib rtk;
    pkgs = pkgs-unstable;
    args = [ "--auto-patch" ];
    files = [
      ".claude/RTK.md"
      ".claude/settings.json"
    ];
    patch = ''
      substituteInPlace "$out/.claude/settings.json" \
        --replace-fail 'rtk hook claude' '${rtk}/bin/rtk hook claude'
    '';
  };
  mcpTarget = "${home}/.claude.json";
  nativeScripts = import ../native-scripts.nix { inherit lib; };
  scriptsDir = "${nativeScripts}/agents/scripts";
  workmuxStatusDir = ../../dotfiles/agents/workmux-status;

  # Desired manual-only skills land here as
  # { skillName = "user-invocable-only"; }, applied to settings.json below.
  declaredSkillOverrides = skillFiles.mkSkillOverrides {
    agentId = "claude-code";
    skillNames = selectedSkillNames;
  };

  files =
    (skillFiles.mkSkillFiles {
      skillNames = selectedSkillNames;
      targetDirRelPath = ".claude/skills";
    })
    // instructions.mkInstructionFiles {
      target = ".claude/CLAUDE.md";
      source = config.agents.instructions;
      extraText = lib.optionalString agentCfg.rtk.enable "\n@RTK.md\n";
    }
    // lib.optionalAttrs agentCfg.rtk.enable {
      ".claude/RTK.md" = {
        source = "${rtkAssets}/.claude/RTK.md";
        force = true;
      };
    };

in
lib.mkMerge [
  (lib.mkIf enabled {
    home.file = files;
    nativeManagedFiles = builtins.attrNames files;

    globalToolOperations.claude-mcp.command = managedConfig.mkJsonManagedMerge {
      targetFile = mcpTarget;
      managedKey = "mcpServers";
      declaredEntries = agentCfg.mcpServers;
    };
    globalToolOperations.claude-settings.command = ''
      TARGET_FILE=${lib.escapeShellArg "${home}/.claude/settings.json"} \
      SOURCE_FILE=${lib.escapeShellArg "${workmuxStatusDir}/claude-hooks.json"} \
      RTK_SOURCE_FILE=${
        lib.escapeShellArg (if agentCfg.rtk.enable then "${rtkAssets}/.claude/settings.json" else "")
      } \
      EXTRA_SETTINGS=${lib.escapeShellArg (builtins.toJSON agentCfg.settings)} \
      SKILL_OVERRIDES=${lib.escapeShellArg (builtins.toJSON declaredSkillOverrides)} \
        ${nodeBin}/node ${scriptsDir}/apply-claude-hooks.js
    '';
    globalToolOperations.claude-loancrate = lib.mkIf (agentCfg.loancrateConfig != null) {
      after = [ "claude-plugins" ];
      command = ''
        export PATH="${nodeBin}:$PATH"
        LOANCRATE_BASE_CONFIG=${lib.escapeShellArg (builtins.toJSON agentCfg.loancrateConfig)} \
          ${nodeBin}/node ${scriptsDir}/apply-loancrate-config.js
      '';
    };
  })
  {
    globalToolOperations.claude-plugins = {
      canUpdate = true;
      command = ''
        export PATH="${nodeBin}:/opt/homebrew/bin:/run/current-system/sw/bin:$HOME/.local/bin:$PATH"
        MARKETPLACES=${lib.escapeShellArg (builtins.toJSON (lib.optionals enabled agentCfg.pluginMarketplaces))} \
        DECLARED_PLUGINS=${lib.escapeShellArg (builtins.toJSON (lib.optionals enabled agentCfg.plugins))} \
        STATE_FILE=${lib.escapeShellArg "${home}/.local/state/agents-nix/claude-plugins.json"} \
        FORCE_REPAIR="''${GLOBAL_TOOLS_FORCE_REPAIR:-}" \
        UPDATE="''${GLOBAL_TOOLS_UPDATE:-}" \
          ${nodeBin}/node ${scriptsDir}/apply-claude-plugins.js
      '';
    };
  }
]
