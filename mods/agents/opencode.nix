# agents/opencode.nix — OpenCode: complete installation story
#
# Owns OpenCode's *entire* story: skills, RTK hooks, shared instructions, and
# the dotfile symlink layout (config.json, commands, agents, modes, themes,
# plugins, local skills) that used to live in the separate mods/opencode.nix.
#
# OpenCode MCP servers do not need an activation-time merge: common entries
# live in mods/dotfiles/opencode-config.json, while machine-role-specific
# entries are merged into the generated config below during Nix evaluation.
# See docs/adr/0002-layered-asset-management.md.
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
  inherit (shared) home dotfiles isLoancrateMac callAgentLib;

  skills = callAgentLib ./skills.nix;
  instructions = callAgentLib ./instructions.nix;

  instructionsTarget = "${home}/.config/opencode/AGENTS.md";

  # Out-of-store symlink into the working tree (edit without rebuild), for the
  # hand-edited OpenCode dotfiles.
  mkSym = path: config.lib.file.mkOutOfStoreSymlink "${dotfiles}/${path}";
  mkForcedSym = path: {
    source = mkSym path;
    force = true;
  };

  # config.json is generated so this route (Loancrate Mac local vs. shared
  # remote provider — see ollama-provider.nix) is evaluated per machine.
  ollamaProvider = import ./ollama-provider.nix { inherit isLoancrateMac; };
  mkOpencodeModels = ids: builtins.listToAttrs (map (id: {
    name = id;
    value.name = id;
  }) ids);
  baseOpencodeConfig = builtins.fromJSON (builtins.readFile ../dotfiles/opencode-config.json);
  loancrateMcpServers = {
    linear = {
      type = "remote";
      url = "https://mcp.linear.app/mcp";
    };
    figma = {
      type = "remote";
      url = "https://mcp.figma.com/mcp";
    };
    bde = {
      type = "remote";
      url = "https://bde.dsci.loancrate.dev/mcp";
    };
  };
  opencodeConfig = baseOpencodeConfig // {
    mcp = (baseOpencodeConfig.mcp or { }) // lib.optionalAttrs isLoancrateMac loancrateMcpServers;
    provider = {
      ollama = {
        npm = "@ai-sdk/openai-compatible";
        name = "ollama";
        options.baseURL = ollamaProvider.baseUrl;
        models = mkOpencodeModels ollamaProvider.models;
      };
    };
  };
in
{
  # Skills are Layer 0: home.file links (community = store symlinks, shared =
  # out-of-store). config.json is Nix-generated (its ollama provider comes from
  # the shared source); the other OpenCode dotfiles (commands, agents, modes,
  # themes, plugins, local skills) stay live out-of-store symlinks.
  # `.config/opencode/skills/local` sits beside the community/shared skill
  # links; names don't collide.
  home.file =
    skills.mkCommunitySkillFiles {
      agentId = "opencode";
      skillDirRelPath = ".config/opencode/skills";
    }
    // skills.mkLocalSkillFiles {
      sourceRelPath = "agents/shared-skills";
      targetDirRelPath = ".config/opencode/skills";
    }
    // skills.mkLocalSkillFiles {
      sourceRelPath = "agents/opencode/skills";
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
    };

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

  home.activation.prepareOpencodeInstructionsForRtk =
    lib.hm.dag.entryBefore [ "installOpencodeRtkHooks" ]
      (instructions.removeStaleInstructionSymlink { target = instructionsTarget; });

  home.activation.installOpencodeRtkHooks = lib.hm.dag.entryAfter [ "linkGeneration" ] (
    shared.mkRtkHookInstall {
      rtkArgs = "--opencode";
      label = "opencode";
    }
  );

  home.activation.writeOpencodeInstructions = lib.hm.dag.entryAfter [ "installOpencodeRtkHooks" ] (
    instructions.writeAgentInstructions { target = instructionsTarget; }
  );
}
