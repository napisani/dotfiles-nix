# agents/opencode.nix — OpenCode: complete installation story
#
# Owns skills, RTK hooks, and shared instructions for OpenCode. Deliberately
# does NOT manage MCP servers via activation script: OpenCode's MCP config
# lives inside mods/dotfiles/opencode-config.json (symlinked live into
# ~/.config/opencode/config.json by mods/opencode.nix, a sibling file that
# owns OpenCode's dotfile-symlinking — unrelated to this file's concern). That
# file is deliberately kept hand-edited/"edit without rebuild" per its own
# header comment, so an MCP entry there is a direct edit, not a Nix
# declaration — see the agentmemory MCP entry already present in it.
#
# Path conflicts for ~/.config/opencode/skills are handled by the sibling
# mods/opencode.nix's `fixOpencodePathConflicts` (which also links the `local`
# skills symlink there); this file only adds the community/shared skill links
# beside it. Task 11 of the nix-native refactor merges that sibling in here.
{
  config,
  lib,
  pkgs-unstable,
  hostname ? "",
  machineRoles ? [ ],
  inputs ? { },
  ...
}:
let
  shared = import ./lib.nix { inherit config lib pkgs-unstable hostname machineRoles inputs; };
  inherit (shared) home callAgentLib;

  skills = callAgentLib ./skills.nix;
  instructions = callAgentLib ./instructions.nix;

  instructionsTarget = "${home}/.config/opencode/AGENTS.md";
in
{
  # Skills are Layer 0: home.file links (community = store symlinks, shared =
  # out-of-store). The sibling mods/opencode.nix separately links
  # `.config/opencode/skills/local`; names don't collide. See
  # docs/adr/0002-layered-asset-management.md.
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
    };

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
