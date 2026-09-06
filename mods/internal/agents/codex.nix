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
  tomlNodePath = import ./toml-node-path.nix { pkgs = pkgs-unstable; };

  agentCfg = config.agents.codex;
  selectedSkillNames = skillFiles.skillNamesFor "codex";

  rtkAssets = import ./rtk-assets.nix {
    inherit lib;
    pkgs = pkgs-unstable;
    rtk = config.agents.rtkPackage;
    args = [ "--codex" ];
    files = [ ".codex/RTK.md" ];
  };
  configTomlFile = "${home}/.codex/config.toml";
  hooksTargetFile = "${home}/.codex/hooks.json";
  nativeScripts = import ../native-scripts.nix { inherit lib; };
  scriptsDir = "${nativeScripts}/agents/scripts";
  workmuxStatusDir = ../../dotfiles/agents/workmux-status;

  # Codex's real manual-only control isn't the `disable-model-invocation`
  # frontmatter field — it's a sibling `agents/openai.yaml` with
  # `policy.allow_implicit_invocation: false` (see
  # github.com/mattpocock/skills#516). Catalog skills are read-only pinned
  # store paths, so a skill selected with manualOnly = true gets that file
  # injected into a patched copy instead.
  patchCodexSkillSource =
    s: src:
    if
      skillFiles.isSkillManualOnlyFor {
        skillName = s.name;
        agentId = "codex";
      }
    then
      skillFiles.mkPatchedSkillSource {
        name = s.name;
        sourcePath = src;
        addFiles."agents/openai.yaml" = ''
          policy:
            allow_implicit_invocation: false
        '';
      }
    else
      src;
  # Codex's hidden .system directory remains outside the named links below.
  files =
    (skillFiles.mkSkillFiles {
      skillNames = selectedSkillNames;
      targetDirRelPath = ".codex/skills";
      patchSource = patchCodexSkillSource;
    })
    // instructions.mkInstructionFiles {
      target = ".codex/AGENTS.md";
      source = config.agents.instructions;
      extraText = lib.optionalString agentCfg.rtk.enable "\n@${home}/.codex/RTK.md\n";
    }
    // lib.optionalAttrs agentCfg.rtk.enable {
      ".codex/RTK.md" = {
        source = "${rtkAssets}/.codex/RTK.md";
        force = true;
      };
    };

in
lib.mkIf (config.agents.enable && agentCfg.enable) {
  home.file = files;
  nativeManagedFiles = builtins.attrNames files;

  globalToolOperations.codex-hooks.command = ''
    HOOKS_TARGET_FILE=${lib.escapeShellArg hooksTargetFile} \
    HOOKS_SOURCE_FILE=${lib.escapeShellArg "${workmuxStatusDir}/codex-hooks.json"} \
      ${nodeBin}/node ${scriptsDir}/apply-codex-hooks.js
  '';
  globalToolOperations.codex-config = {
    after = [ "codex-hooks" ];
    command = ''
      NODE_PATH=${lib.escapeShellArg tomlNodePath} \
      MCP_SERVERS=${lib.escapeShellArg (builtins.toJSON agentCfg.mcpServers)} \
      HOOKS_TARGET_FILE=${lib.escapeShellArg hooksTargetFile} \
      CONFIG_TOML_FILE=${lib.escapeShellArg configTomlFile} \
        ${nodeBin}/node ${scriptsDir}/apply-codex-config.js
    '';
  };
}
