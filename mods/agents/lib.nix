# Shared, agent-blind facts and utilities imported by each agents/* module.
# Deliberately contains no per-agent behavior or branching — see
# docs/adr/0001-per-agent-modules.md. Paths, the skill-catalog agent
# enumeration, machine identity, and a handful of format/shape-generic
# helper functions (never branching on "which agent is this").
#
# Usage: let shared = import ./lib.nix { inherit config lib pkgs-unstable hostname machineRoles; };
#        inherit (shared) dotfiles home allAgents nodeBin gitBin isLoancrateMac
#          mkFixPathConflicts mkRtkHookInstall mkDeclaredEntriesFromSources callAgentLib;
#
# `hostname` and `machineRoles` must be forwarded by the caller from its own
# module arguments (both are specialArgs set in lib/builders.nix from
# flake.nix's own darwinConfigurations/nixosConfigurations entries — the
# single source of truth for "which machine is this", not a hand-duplicated
# string). Machine gating derives from `machineRoles`, not `hostname`.
{
  config,
  lib,
  pkgs-unstable,
  hostname ? "",
  machineRoles ? [ ],
}:
let
  dotfiles = "${config.home.homeDirectory}/.config/home-manager/mods/dotfiles";
  home = config.home.homeDirectory;

  # Skill catalog (skills.nix) still targets all four agents by default;
  # this enumeration has no per-agent branching behavior of its own.
  allAgents = [
    "claude-code"
    "opencode"
    "codex"
    "pi"
  ];

  nodeBin = "${pkgs-unstable.nodejs}/bin";
  gitBin = "${pkgs-unstable.git}/bin";

  # Machine gating: derived from the flake-declared roles list (passed as a
  # specialArg from flake.nix's own machine definitions), not a hostname
  # string equality and not the hand-duplicated MACHINE_NAME sessionVariable.
  # Role-based so renaming a machine in flake.nix can't silently turn every
  # gated asset off — the roles travel with the machine.
  isLoancrateMac = builtins.elem "loancrate" machineRoles;

  # Remove a stale non-directory (symlink, or a plain file left behind by a
  # tool that expects a real dir) at each of `paths`, before linkGeneration
  # runs. Agent-blind: just a list of paths, no identity of its own.
  mkFixPathConflicts =
    paths:
    ''
      for p in ${builtins.concatStringsSep " " (map lib.escapeShellArg paths)}; do
        if [ -L "$p" ] || { [ -e "$p" ] && [ ! -d "$p" ]; }; then
          echo "agents: removing stale non-directory at $p"
          rm -rf "$p"
        fi
      done
    '';

  # Run `rtk init -g <rtkArgs>`, logging success/failure with `label`.
  # Agent-blind: takes the exact flag(s) and a label string, no internal
  # branching on which agent is calling it. Trusted-path-first PATH (matches
  # mkClaudePluginInstall/mkPiPackageInstall in managed-config-lib.nix) so a
  # planted binary in a user-writable npm bin dir can't shadow the real rtk.
  mkRtkHookInstall =
    { rtkArgs, label }:
    ''
      export PATH="/opt/homebrew/bin:/run/current-system/sw/bin:$HOME/.local/bin:$PATH"
      if command -v rtk >/dev/null 2>&1; then
        rtk init -g ${rtkArgs} && echo "agents: RTK hook installed for ${label}" \
          || echo "agents: WARNING: RTK hook failed for ${label}"
      else
        echo "agents: rtk not found on PATH — skipping RTK hook installation (install via: brew install rtk)" >&2
      fi
    '';

  # Filter `sources` (a list of { name, config, condition ? true }) down to
  # enabled entries and reshape into a { name = config; ... } attrset. Pure
  # data transform, no agent identity involved — used to turn an agent
  # module's own MCP-source list into the attrset managed-config-lib.nix's
  # merge utilities expect.
  mkDeclaredEntriesFromSources =
    sources:
    builtins.listToAttrs (
      map (s: {
        inherit (s) name;
        value = s.config;
      }) (builtins.filter (s: s.condition or true) sources)
    );

  # Import one of this directory's own modules with the standard four
  # shared arguments already threaded through, so call sites don't have to
  # re-spell `{ inherit config lib pkgs-unstable hostname; }` every time.
  callAgentLib = path: import path { inherit config lib pkgs-unstable hostname machineRoles; };
in
{
  inherit
    dotfiles
    home
    allAgents
    nodeBin
    gitBin
    isLoancrateMac
    mkFixPathConflicts
    mkRtkHookInstall
    mkDeclaredEntriesFromSources
    callAgentLib
    ;
}
