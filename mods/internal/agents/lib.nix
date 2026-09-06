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
      absSrc = ../../dotfiles + "/${sourceRelPath}";
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
    mkFixPathConflicts
    mkLocalFileLinks
    callAgentLib
    ;
}
