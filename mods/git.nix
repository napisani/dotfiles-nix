{ pkgs-unstable, ... }:
{
  # Git config is a live-editable native file under mods/dotfiles/shell/git/,
  # linked by mods/shell.nix. The gh credential helper and gpg program are bare
  # commands so they resolve from PATH instead of pinning Nix store paths.
  #
  # `git` itself was previously installed as a side effect of
  # `programs.git.enable`, so request it explicitly. git-lfs and gnupg come from
  # mods/base-packages.nix.
  home.packages = [ pkgs-unstable.git ];
}
