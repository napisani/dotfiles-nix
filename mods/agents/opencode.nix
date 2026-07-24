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
# NB: the path-conflict-fix activation entry below is named
# fixOpencodeSkillPathConflicts, not fixOpencodePathConflicts like the other
# three agents' — mods/opencode.nix (the sibling file above) already owns
# `home.activation.fixOpencodePathConflicts` for its own plugin/skills dirs.
# Reusing that exact name here collides (`home-manager switch` fails with
# "conflicting definition values"), so this one is deliberately named for
# the specific directory it fixes instead of matching the sibling pattern.
{
  config,
  lib,
  pkgs-unstable,
  hostname ? "",
  ...
}:
let
  shared = import ./lib.nix { inherit config lib pkgs-unstable hostname; };
  inherit (shared) home callAgentLib;

  skills = callAgentLib ./skills.nix;
  instructions = callAgentLib ./instructions.nix;

  skillDir = "${home}/.config/opencode/skills";
  instructionsTarget = "${home}/.config/opencode/AGENTS.md";
in
{
  home.activation.fixOpencodeSkillPathConflicts = lib.hm.dag.entryBefore [ "linkGeneration" ] (
    shared.mkFixPathConflicts [ skillDir ]
  );

  home.activation.installOpencodeSkills = lib.hm.dag.entryAfter [ "linkGeneration" ] (
    skills.mkAgentSkillInstall {
      agentId = "opencode";
      inherit skillDir;
      localSkillsRelPath = "agents/opencode/skills";
    }
  );

  home.activation.prepareOpencodeInstructionsForRtk =
    lib.hm.dag.entryBefore [ "installOpencodeRtkHooks" ]
      (instructions.removeStaleInstructionSymlink { target = instructionsTarget; });

  home.activation.installOpencodeRtkHooks = lib.hm.dag.entryAfter [ "installOpencodeSkills" ] (
    shared.mkRtkHookInstall {
      rtkArgs = "--opencode";
      label = "opencode";
    }
  );

  home.activation.writeOpencodeInstructions = lib.hm.dag.entryAfter [ "installOpencodeRtkHooks" ] (
    instructions.writeAgentInstructions { target = instructionsTarget; }
  );
}
