{ pkgs, pkgs-unstable, procmux, secret_inject, animal_rescue, scrollbacktamer
, ... }:
let
  languagePackages = import ./languages/all.nix { inherit pkgs pkgs-unstable; };
in {

  home.packages = with pkgs-unstable;
    languagePackages ++ [
      pkgs.bashInteractive
      blesh
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
      # old_bitwarden.bitwarden-cli
      pet
      tree-sitter
      ncdu
      git-lfs
      discordo
      ngrok
      fd
      duckdb

      # search for packages on nixos
      nix-search-cli

      # ai refactoring tools
      aider-chat
      ollama

      secret_inject.packages.${pkgs.system}.default
      animal_rescue.packages.${pkgs.system}.default
      scrollbacktamer.packages.${pkgs.system}.default
      lazydocker
      tmuxp
      #pkgs.pscale
      #pkgs.mysql80
      #pkgs.pulumi

      # python3Packages.procmux
      # procmux.packages.${pkgs.system}.default
      # for personal dashboards
      # pkgs.wtf
      # pkgs-unstable.nodePackages."node-inspector"

      #pkgs-unstable.python310Packages.tiktoken
      # custom_node_packages.opencommit

      k9s
    ];

}
