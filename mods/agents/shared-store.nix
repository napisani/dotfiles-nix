# agents/shared-store.nix — the cross-agent global skill store (~/.agents/skills).
#
# Pi auto-discovers this directory directly; Claude/Codex/OpenCode get the same
# shared-skills content linked into their own skill dirs by their own modules.
# One tiny module owns the global store via home.file so no single agent's file
# has to, and so removing a shared skill revokes cleanly everywhere. See
# docs/adr/0002-layered-asset-management.md.
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
  skills = shared.callAgentLib ./skills.nix;
  storeDir = "${shared.home}/.agents/skills";
in
{
  # If the store dir is a stale symlink (e.g. left by the old wipe-and-rebuild
  # bridge), clear it so linkGeneration can populate it with home.file links.
  # A real directory is left untouched.
  home.activation.fixSharedStorePathConflicts = lib.hm.dag.entryBefore [ "linkGeneration" ] (
    shared.mkFixPathConflicts [ storeDir ]
  );

  home.file = skills.mkLocalSkillFiles {
    sourceRelPath = "agents/shared-skills";
    targetDirRelPath = ".agents/skills";
  };
}
