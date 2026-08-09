{
  lib,
  config,
  pkgs,
  pkgs-unstable,
  procmux,
  secret_inject,
  animal_rescue,
  scrollbacktamer,
  proctmux,
  ...
}:
let
  languagePackages = import ./languages/all.nix { inherit pkgs pkgs-unstable; };
  inherit (pkgs.stdenv.hostPlatform) system;
in
{

  home.packages =
    with pkgs-unstable;
    languagePackages
    ++ [
      tmux
      pkgs.bashInteractive
      bat
      btop
      coreutils
      gnupg
      gnugrep
      gnumake
      ripgrep
      tree
      watch
      wget
      #postman
      doppler
      pet
      # Tree-sitter CLI for nvim-treesitter :TSInstall / parser builds (same role as brew tree-sitter-cli)
      tree-sitter
      ncdu
      git-lfs
      # ngrok
      fd

      # search for packages on nixos
      nix-search-cli

      secret_inject.packages.${system}.default
      animal_rescue.packages.${system}.default
      scrollbacktamer.packages.${system}.default
      proctmux.packages.${system}.default
      # tmuxp
      nodemon
      mise

      k9s

      lazysql
      lazydocker
      # bitwarden-cli
      (lib.lowPrio sox) # lowPrio to avoid /bin/play conflict with gotools

    ];

}
