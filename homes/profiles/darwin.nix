{
  pkgs,
  rift,
  ...
}:
let
  system = pkgs.stdenv.hostPlatform.system;
in
{
  home.packages = [
    rift.packages.${system}.default
  ];

  # The nix* rebuild aliases used to be generated here, interpolating
  # homeManagerRelPath and the platform's rebuild command into
  # programs.bash.shellAliases. They now live in
  # mods/dotfiles/shell/bash/rc.d/55-nix-aliases.sh, which picks the rebuild
  # command by probing for darwin-rebuild vs nixos-rebuild and takes the flake
  # directory from $DOTFILES_HOME_MANAGER_DIR — so the same file works on both
  # platforms and defines nothing at all on a host without nix.
}
