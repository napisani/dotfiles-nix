# agents/instructions.nix — Shared AGENTS.md source + write utility
#
# A single source file (mods/dotfiles/agents/AGENTS.md) is the shared content
# every agent gets. This file owns no home.activation of its own — each agent
# module calls `writeAgentInstructions` itself for its own instruction path,
# deciding its own ordering (e.g. Codex chains an RTK-reference reapply step
# immediately after, in the same file — see docs/adr/0001-per-agent-modules.md).
{
  config,
  lib,
  pkgs-unstable,
  hostname ? "",
  machineRoles ? [ ],
  homeManagerRelPath,
  ...
}:
let
  shared = import ./lib.nix {
    inherit config lib pkgs-unstable hostname machineRoles homeManagerRelPath;
  };
  inherit (shared) dotfiles;

  sharedAgentInstructionsSource = "${dotfiles}/agents/AGENTS.md";

  # Write repo-managed instruction content to one agent's instruction path.
  # Uses a temp-file rename for atomicity (avoids partial writes). Agent-
  # blind: takes a target path plus an optional list of extra source paths
  # (e.g. an agent-only addendum) to concatenate after the shared source —
  # never an agent identity. Callers with no extras get exactly the old
  # behavior.
  writeAgentInstructions =
    {
      target,
      extraSourcePaths ? [ ],
    }:
    let
      allSources = [ sharedAgentInstructionsSource ] ++ extraSourcePaths;
      catArgs = lib.concatMapStringsSep " " lib.escapeShellArg allSources;
    in
    ''
      _target="${target}"

      mkdir -p "$(dirname "$_target")"

      if [ -d "$_target" ] && [ ! -L "$_target" ]; then
        echo "agents: refusing to replace directory at $_target"
      else
        _tmp="$(mktemp)"
        cat ${catArgs} > "$_tmp"
        mv "$_tmp" "$_target"
        echo "agents: wrote shared instructions -> $_target"
      fi
    '';

  # RTK may write a symlink at an agent's instruction path during `rtk init`;
  # remove any stale symlink before that agent's own RTK-init step runs, so
  # writeAgentInstructions always replaces it with a normal repo-managed file.
  # Agent-blind: takes a target path.
  removeStaleInstructionSymlink =
    { target }:
    ''
      if [ -L "${target}" ]; then
        echo "agents: removing old instruction symlink at ${target}"
        rm -f "${target}"
      fi
    '';
in
{
  inherit
    writeAgentInstructions
    removeStaleInstructionSymlink
    ;
}
