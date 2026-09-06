# agents/pi.nix — Pi: complete installation story
#
# Owns everything specific to Pi: skills (community + Pi-local via home.file;
# shared skills come from the global store ~/.agents/skills that Pi
# auto-discovers, so they're deliberately not linked into ~/.pi/agent/skills),
# RTK hooks, shared instructions, MCP servers (JSON), state-tracked package
# installs/removals, extension/theme links, and settings.
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

  agentCfg = config.agents.pi;
  enabled = config.agents.enable && agentCfg.enable;
  selectedSkillNames =
    skillFiles.skillNamesByKind "pinned" skillFiles.sharedSkillNames
    ++ skillFiles.perAgentSkillNamesFor "pi";

  ollamaProvider = config.agents.providers.ollama;

  managedPiProviders = {
    ollama = {
      baseUrl = ollamaProvider.baseUrl;
      api = "openai-completions";
      apiKey = "ollama";
      models = ollamaProvider.models;
    };
  };

  nativeScripts = import ../native-scripts.nix { inherit lib; };
  scriptsDir = "${nativeScripts}/agents/scripts";
  rtk = config.agents.rtkPackage;
  rtkAssets = import ./rtk-assets.nix {
    inherit lib rtk;
    pkgs = pkgs-unstable;
    args = [
      "--agent"
      "pi"
    ];
    files = [ ".pi/agent/extensions/rtk.ts" ];
    patch = ''
      substituteInPlace "$out/.pi/agent/extensions/rtk.ts" \
        --replace-fail 'pi.exec("rtk"' 'pi.exec("${rtk}/bin/rtk"'
    '';
  };
  mcpTarget = "${home}/.pi/agent/mcp.json";

  # Pi natively honors `disable-model-invocation: true` in a skill's own
  # SKILL.md frontmatter, but catalog skills are read-only pinned store
  # paths — so for a skill selected with manualOnly = true, splice that key
  # into a patched copy instead of editing the vendored file.
  patchPiSkillSource =
    s: src:
    if
      skillFiles.isSkillManualOnlyFor {
        skillName = s.name;
        agentId = "pi";
      }
    then
      skillFiles.mkPatchedSkillSource {
        name = s.name;
        sourcePath = src;
        insertAfterLine = {
          file = "SKILL.md";
          afterLine = 1;
          text = "disable-model-invocation: true";
        };
      }
    else
      src;

  # Pi discovers repo-local shared skills through ~/.agents/skills.
  files =
    skillFiles.mkSkillFiles {
      skillNames = selectedSkillNames;
      targetDirRelPath = ".pi/agent/skills";
      patchSource = patchPiSkillSource;
    }
    // shared.mkLocalFileLinks {
      sourceRelPath = "agents/pi/extensions";
      targetDirRelPath = ".pi/agent/extensions";
      extensions = [
        ".js"
        ".ts"
      ];
    }
    // shared.mkLocalFileLinks {
      sourceRelPath = "agents/pi/themes";
      targetDirRelPath = ".pi/agent/themes";
      extensions = [ ".json" ];
    }
    // instructions.mkInstructionFiles {
      target = ".pi/agent/AGENTS.md";
      source = config.agents.instructions;
    }
    // lib.optionalAttrs agentCfg.rtk.enable {
      ".pi/agent/extensions/rtk.ts" = {
        source = "${rtkAssets}/.pi/agent/extensions/rtk.ts";
        force = true;
      };
    };

in
lib.mkMerge [
  (lib.mkIf enabled {
    home.file = files;
    nativeManagedFiles = builtins.attrNames files;

    globalToolOperations.pi-mcp.command = managedConfig.mkJsonManagedMerge {
      targetFile = mcpTarget;
      managedKey = "mcpServers";
      declaredEntries = agentCfg.mcpServers;
    };
    globalToolOperations.pi-settings = {
      after = [ "pi-packages" ];
      command = ''
        # ── Settings (provider defaults, model, skill paths) ──────────────────────
        PI_MANAGED_SETTINGS=${lib.escapeShellArg (builtins.toJSON agentCfg.settings)} \
        PI_SKILL_PATHS=${lib.escapeShellArg (builtins.toJSON agentCfg.skillPaths)} \
          ${nodeBin}/node ${scriptsDir}/apply-pi-settings.js

      '';
    };
    globalToolOperations.pi-models.command = ''
      # ── Custom providers/models → ~/.pi/agent/models.json (the file Pi reads) ─
      MANAGED_PROVIDERS=${lib.escapeShellArg (builtins.toJSON managedPiProviders)} \
      REMOVED_PROVIDERS=${lib.escapeShellArg (builtins.toJSON [ "mlx" ])} \
        ${nodeBin}/node ${scriptsDir}/apply-pi-models.js
    '';
  })
  {
    globalToolOperations.pi-packages = {
      canUpdate = true;
      after = [ "npm" ];
      command = ''
        export PATH="${nodeBin}:/opt/homebrew/bin:/run/current-system/sw/bin:$HOME/.local/bin:$PATH"
        DECLARED_PACKAGES=${lib.escapeShellArg (builtins.toJSON (lib.optionals enabled agentCfg.packages))} \
        STATE_FILE=${lib.escapeShellArg "${home}/.local/state/agents-nix/pi-packages.json"} \
        FORCE_REPAIR="''${GLOBAL_TOOLS_FORCE_REPAIR:-''${GLOBAL_TOOLS_UPDATE:-}}" \
          ${nodeBin}/node ${scriptsDir}/apply-pi-packages.js
      '';
    };
  }
]
