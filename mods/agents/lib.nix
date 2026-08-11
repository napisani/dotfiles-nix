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
  inputs ? { },
  # Where this flake checkout lives relative to $HOME. The one default lives
  # in lib/builders.nix (defaultHomeManagerRelPath) — every dotfiles-path-
  # deriving module just declares this as required and threads it through
  # (see callAgentLib below), rather than re-declaring its own default.
  homeManagerRelPath,
}:
let
  dotfiles = "${config.home.homeDirectory}/${homeManagerRelPath}/mods/dotfiles";
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

  # agentmemory MCP server facts, shared by claude/codex/pi's own MCP
  # declarations. Agent-blind data, not policy — each agent still declares
  # its own MCP entry shape locally (Pi adds lifecycle="lazy", etc.); only
  # these two facts are shared, so changing the port is a one-line edit.
  # The binary is installed globally by mods/npmx.nix (`npm install -g
  # @agentmemory/mcp`), not spawned via npx.
  agentmemoryMcpBin = "${home}/.local/bin/agentmemory-mcp";
  agentmemoryUrl = "http://localhost:3111";

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

  # Emit a warning: to stderr (visible in switch output) AND appended to the
  # activation warning file so report.nix can summarize it at the end. Uses
  # ${AGENTS_WARN_FILE:-/dev/null} so a call before report.nix's init entry
  # degrades to stderr-only rather than aborting under `set -u`. Agent-blind.
  mkWarn =
    msg:
    ''{ printf '%s\n' ${lib.escapeShellArg "agents: WARNING: ${msg}"} >&2; printf '%s\n' ${lib.escapeShellArg msg} >> "''${AGENTS_WARN_FILE:-/dev/null}"; }'';

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
          || ${mkWarn "RTK hook failed for ${label}"}
      else
        ${mkWarn "rtk not found on PATH — skipping RTK hook for ${label} (install via: brew install rtk)"}
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

  # Link every regular file with one of `extensions` under a dotfiles subdir
  # into targetDirRelPath as an out-of-store symlink (live-editable), skipping
  # *.test.* files. Enumerated at eval time from the flake's own tracked tree,
  # so adding/removing a file needs a switch but edits to a linked file are
  # live. Agent-blind: takes paths, not agent identity. Used for Pi
  # extensions/themes.
  mkLocalFileLinks =
    {
      sourceRelPath,
      targetDirRelPath,
      extensions,
    }:
    let
      absSrc = ../dotfiles + "/${sourceRelPath}";
      ok =
        name: type:
        type == "regular"
        && lib.any (ext: lib.hasSuffix ext name) extensions
        && !(lib.hasInfix ".test." name);
      names =
        if builtins.pathExists absSrc then
          lib.attrNames (lib.filterAttrs ok (builtins.readDir absSrc))
        else
          [ ];
    in
    builtins.listToAttrs (
      map (name: {
        name = "${targetDirRelPath}/${name}";
        value = {
          source = config.lib.file.mkOutOfStoreSymlink "${dotfiles}/${sourceRelPath}/${name}";
          force = true;
        };
      }) names
    );

  # Import one of this directory's own modules with the standard shared
  # arguments already threaded through, so call sites don't have to re-spell
  # `{ inherit config lib pkgs-unstable hostname machineRoles inputs; }`.
  callAgentLib =
    path:
    import path {
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
in
{
  inherit
    dotfiles
    home
    allAgents
    nodeBin
    gitBin
    agentmemoryMcpBin
    agentmemoryUrl
    isLoancrateMac
    mkFixPathConflicts
    mkRtkHookInstall
    mkWarn
    mkLocalFileLinks
    mkDeclaredEntriesFromSources
    callAgentLib
    ;
}
