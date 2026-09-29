# Shared, agent-blind facts and utilities imported by each agents/* module.
# Deliberately contains no per-agent behavior or branching — see
# docs/adr/0001-per-agent-modules.md. Paths and format/shape-generic helpers
# only; machine policy lives in the public configuration modules.
#
# Usage: let shared = import ./lib.nix { inherit config lib pkgs-unstable homeManagerRelPath; };
#        inherit (shared) dotfiles home nodeBin mkFixPathConflicts
#          callAgentLib;
#
{
  config,
  lib,
  pkgs-unstable,
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

  nodeBin = "${pkgs-unstable.nodejs}/bin";

  # The vendored native install scripts, bound to the evaluated generation, and
  # the agents/ subtree every per-agent adapter shells into. Centralized here so
  # adapters don't each re-import native-scripts.nix.
  nativeScripts = import ../native-scripts.nix { inherit lib; };
  scriptsDir = "${nativeScripts}/agents/scripts";

  # Remove a stale non-directory (symlink, or a plain file left behind by a
  # tool that expects a real dir) at each of `paths`, before linkGeneration
  # runs. Agent-blind: just a list of paths, no identity of its own.
  mkFixPathConflicts = paths: ''
    for p in ${builtins.concatStringsSep " " (map lib.escapeShellArg paths)}; do
      if [ -L "$p" ] || { [ -e "$p" ] && [ ! -d "$p" ]; }; then
        echo "agents: removing stale non-directory at $p"
        rm -rf "$p"
      fi
    done
  '';

  # Flake evaluation only sees tracked entry-point directories; adding one needs a switch.
  # Out-of-store links keep edits to existing assets live.
  mkLocalFileLinks =
    {
      sourceRelPath,
      targetDirRelPath,
      extensions,
      directoryEntryPoints ? [ ],
    }:
    let
      absSrc = ../../dotfiles + "/${sourceRelPath}";
      ok =
        name: type:
        (
          type == "regular"
          && lib.any (ext: lib.hasSuffix ext name) extensions
          && !(lib.hasInfix ".test." name)
        )
        || (
          type == "directory"
          && lib.any (entry: builtins.pathExists (absSrc + "/${name}/${entry}")) directoryEntryPoints
        );
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
  # `{ inherit config lib pkgs-unstable inputs homeManagerRelPath; }`.
  callAgentLib =
    path:
    import path {
      inherit
        config
        lib
        pkgs-unstable
        inputs
        homeManagerRelPath
        ;
    };
in
{
  inherit
    dotfiles
    home
    nodeBin
    nativeScripts
    scriptsDir
    mkFixPathConflicts
    mkLocalFileLinks
    callAgentLib
    ;
}
