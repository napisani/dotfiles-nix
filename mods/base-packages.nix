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
  workmux,
  ...
}:
let
  languagePackages = import ./languages/all.nix { inherit pkgs pkgs-unstable; };
  inherit (pkgs.stdenv.hostPlatform) system;
  fixedDirenv = pkgs-unstable.direnv.overrideAttrs (old: {
    env = (old.env or { }) // {
      CGO_ENABLED = 1;
    };
  });
  fixedMise = pkgs-unstable.mise.override {
    direnv = fixedDirenv;
  };
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
      workmux.packages.${system}.default
      # tmuxp
      nodemon
      fixedMise

      k9s

      lazysql
      lazydocker
      # bitwarden-cli
      cursor-cli
      (lib.lowPrio sox) # lowPrio to avoid /bin/play conflict with gotools

    ];

}
