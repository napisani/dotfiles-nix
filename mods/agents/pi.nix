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

  agentCfg = config.agents.pi;
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
  instructionsTarget = "${home}/.pi/agent/AGENTS.md";
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

in
lib.mkIf (config.agents.enable && agentCfg.enable) {
  # Pi discovers repo-local shared skills through ~/.agents/skills, so only
  # pinned shared skills and explicit Pi-only additions are linked here.
  home.file =
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
    };

  home.activation.preparePiInstructionsForRtk = lib.hm.dag.entryBefore [ "installPiRtkHooks" ] (
    instructions.removeStaleInstructionSymlink { target = instructionsTarget; }
  );

  home.activation.installPiRtkHooks = lib.hm.dag.entryAfter [ "linkGeneration" ] (
    shared.mkRtkHookInstall {
      rtkArgs = "--agent pi";
      label = "pi";
    }
  );

  home.activation.writePiInstructions = lib.hm.dag.entryAfter [ "installPiRtkHooks" ] (
    instructions.writeAgentInstructions {
      target = instructionsTarget;
      source = config.agents.instructions;
    }
  );

  home.activation.configurePiMcpServers = lib.hm.dag.entryAfter [ "linkGeneration" ] (
    managedConfig.mkJsonManagedMerge {
      targetFile = mcpTarget;
      managedKey = "mcpServers";
      declaredEntries = agentCfg.mcpServers;
    }
  );

  home.activation.installPiPackages = lib.hm.dag.entryAfter [ "linkGeneration" ] (
    managedConfig.mkPiPackageInstall {
      declaredPackages = agentCfg.packages;
      stateId = "pi-packages";
    }
  );

  home.activation.installPiConfig = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
    # ── Settings (provider defaults, model, skill paths) ──────────────────────
    PI_MANAGED_SETTINGS=${lib.escapeShellArg (builtins.toJSON agentCfg.settings)} \
    PI_SKILL_PATHS=${lib.escapeShellArg (builtins.toJSON agentCfg.skillPaths)} \
      ${nodeBin}/node ${scriptsDir}/apply-pi-settings.js

    # ── Custom providers/models → ~/.pi/agent/models.json (the file Pi reads) ─
    MANAGED_PROVIDERS=${lib.escapeShellArg (builtins.toJSON managedPiProviders)} \
    REMOVED_PROVIDERS=${lib.escapeShellArg (builtins.toJSON [ "mlx" ])} \
      ${nodeBin}/node ${scriptsDir}/apply-pi-models.js
  '';
}
