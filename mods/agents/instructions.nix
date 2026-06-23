# agents/instructions.nix — Shared agent instructions propagation
#
# A single source file (mods/dotfiles/agents/AGENTS.md) is written as a
# normal file (not a symlink) to each agent's instruction path after RTK runs.
# RTK may write these paths during `rtk init`, so we remove stale symlinks
# before RTK and restore the repo-managed content after.
{
  config,
  lib,
  pkgs-unstable,
  ...
}:
let
  shared = import ./lib.nix { inherit config pkgs-unstable; };
  inherit (shared) dotfiles;

  sharedAgentInstructions = "${dotfiles}/agents/AGENTS.md";
in
{
  # RTK writes global agent instruction files during init; remove any old
  # symlinks before RTK runs so repo-managed instructions stay immutable.
  home.activation.prepareAgentInstructionsForRtk = lib.hm.dag.entryBefore [ "installRtkHooks" ] ''
    for p in \
      "$HOME/.codex/AGENTS.md" \
      "$HOME/.config/opencode/AGENTS.md" \
      "$HOME/.claude/CLAUDE.md" \
      "$HOME/.pi/agent/AGENTS.md"; do
      if [ -L "$p" ]; then
        echo "agents: removing old instruction symlink at $p"
        rm -f "$p"
      fi
    done
  '';

  # Write repo-managed instruction content to each agent after RTK init.
  # Uses a temp-file rename for atomicity (avoids partial writes).
  home.activation.applySharedAgentInstructions = lib.hm.dag.entryAfter [ "installRtkHooks" ] ''
    _base="${sharedAgentInstructions}"

    _write_agent_instructions() {
      _target="$1"

      mkdir -p "$(dirname "$_target")"

      if [ -d "$_target" ] && [ ! -L "$_target" ]; then
        echo "agents: refusing to replace directory at $_target"
        return 0
      fi

      _tmp="$(mktemp)"
      cat "$_base" > "$_tmp"
      mv "$_tmp" "$_target"
      echo "agents: wrote shared instructions -> $_target"
    }

    _write_agent_instructions "$HOME/.codex/AGENTS.md"
    _write_agent_instructions "$HOME/.config/opencode/AGENTS.md"
    _write_agent_instructions "$HOME/.claude/CLAUDE.md"
    _write_agent_instructions "$HOME/.pi/agent/AGENTS.md"
  '';
}
