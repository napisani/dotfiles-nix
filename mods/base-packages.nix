{ pkgs, pkgs-unstable, procmux, secret_inject, animal_rescue, ... }:
let
  languagePackages = import ./languages/all.nix { inherit pkgs pkgs-unstable; };
in {
  home.packages = with pkgs-unstable;
    languagePackages ++ [
      pkgs.bashInteractive
      bat
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
      pkgs.bitwarden-cli
      pet
      tree-sitter
      # pkgs.ncdu
      git-lfs
      discordo
      ngrok

      secret_inject.packages.${pkgs.system}.default
      animal_rescue.packages.${pkgs.system}.default
      #pkgs.pscale
      #pkgs.mysql80
      #pkgs.pulumi

      procmux.packages.${pkgs.system}.default
      # for personal dashboards
      # pkgs.wtf
      # pkgs-unstable.nodePackages."node-inspector"

      #pkgs-unstable.python310Packages.tiktoken
      # custom_node_packages.opencommit

    ];

}
