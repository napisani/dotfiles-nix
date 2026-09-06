# agents/opencode.nix — OpenCode: complete installation story
#
# Owns OpenCode's *entire* story: skills, RTK hooks, shared instructions, and
# the dotfile symlink layout (config.json, commands, agents, modes, themes,
# plugins, local skills) that used to live in the separate mods/opencode.nix.
#
# OpenCode MCP servers do not need an activation-time merge: the adapter
# merges declared settings, MCP servers, plugins, and provider policy into the
# generated config during Nix evaluation.
# See docs/adr/0002-layered-asset-management.md.
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
    dotfiles
    callAgentLib
    ;

  skillFiles = callAgentLib ./skill-files.nix;
  instructions = callAgentLib ./instructions.nix;

  agentCfg = config.agents.opencode;
  selectedSkillNames = skillFiles.skillNamesFor "opencode";

  rtk = config.agents.rtkPackage;
  rtkAssets = import ./rtk-assets.nix {
    inherit lib rtk;
    pkgs = pkgs-unstable;
    args = [ "--opencode" ];
    files = [ ".config/opencode/plugins/rtk.ts" ];
    patch = ''
      substituteInPlace "$out/.config/opencode/plugins/rtk.ts" \
        --replace-fail 'which rtk' 'test -x ${rtk}/bin/rtk' \
        --replace-fail 'rtk rewrite ''${command}' '${rtk}/bin/rtk rewrite ''${command}'
    '';
  };

  # Out-of-store symlink into the working tree (edit without rebuild), for the
  # hand-edited OpenCode dotfiles.
  mkSym = path: config.lib.file.mkOutOfStoreSymlink "${dotfiles}/${path}";
  mkForcedSym = path: {
    source = mkSym path;
    force = true;
  };

  ollamaProvider = config.agents.providers.ollama;
  mkOpencodeModels =
    ids:
    builtins.listToAttrs (
      map (id: {
        name = id;
        value.name = id;
      }) ids
    );
  baseOpencodeConfig = agentCfg.settings;
  opencodeConfig =
    baseOpencodeConfig
    // {
      mcp = (baseOpencodeConfig.mcp or { }) // agentCfg.mcpServers;
      provider = {
        ollama = {
          npm = "@ai-sdk/openai-compatible";
          name = "ollama";
          options.baseURL = ollamaProvider.baseUrl;
          models = mkOpencodeModels ollamaProvider.models;
        };
      };
    }
    // lib.optionalAttrs ((baseOpencodeConfig.plugin or [ ]) != [ ] || agentCfg.plugins != [ ]) {
      plugin = (baseOpencodeConfig.plugin or [ ]) ++ agentCfg.plugins;
    };
  # Config is generated; hand-edited assets remain live links.
  files =
    skillFiles.mkSkillFiles {
      skillNames = selectedSkillNames;
      targetDirRelPath = ".config/opencode/skills";
    }
    // {
      ".config/opencode/config.json" = {
        text = builtins.toJSON opencodeConfig;
        force = true;
      };
      ".config/opencode/commands" = mkForcedSym "opencode/commands";
      ".config/opencode/agents" = mkForcedSym "opencode/agents";
      ".config/opencode/modes" = mkForcedSym "opencode/modes";
      ".config/opencode/themes" = mkForcedSym "opencode/themes";
      ".config/opencode/plugins/tmux-status.ts" = mkForcedSym "opencode/plugins/tmux-status.ts";
      ".config/opencode/plugins/workmux-status.ts" = mkForcedSym "opencode/plugins/workmux-status.ts";
      ".config/opencode/skills/local" = mkForcedSym "opencode/local-skills";
    }
    // instructions.mkInstructionFiles {
      target = ".config/opencode/AGENTS.md";
      source = config.agents.instructions;
    }
    // lib.optionalAttrs agentCfg.rtk.enable {
      ".config/opencode/plugins/rtk.ts" = {
        source = "${rtkAssets}/.config/opencode/plugins/rtk.ts";
        force = true;
      };
    };

in
lib.mkIf (config.agents.enable && agentCfg.enable) {
  home.file = files;
  nativeManagedFiles = builtins.attrNames files;

  # plugins/skills must be directories; a stale symlink or broken path there
  # slips past home-manager's checks, so clear it before linkGeneration.
  home.activation.fixOpencodePathConflicts = lib.hm.dag.entryBefore [ "linkGeneration" ] (
    shared.mkFixPathConflicts [
      "${home}/.config/opencode/plugin"
      "${home}/.config/opencode/plugins"
      "${home}/.config/opencode/skills"
    ]
    + ''
      # OpenCode's plugin dir is plural (plugins/); drop the old singular
      # workmux symlink so the status plugin isn't loaded twice.
      _stale_workmux_plugin="$HOME/.config/opencode/plugin/workmux-status.ts"
      if [ -L "$_stale_workmux_plugin" ]; then
        rm -f "$_stale_workmux_plugin"
        rmdir "$HOME/.config/opencode/plugin" 2>/dev/null || true
      fi
    ''
  );

}
