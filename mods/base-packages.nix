{ pkgs, pkgs-unstable, procmux, secret_inject, animal_rescue, scrollbacktamer
, proctmux, ... }:
let
  languagePackages = import ./languages/all.nix { inherit pkgs pkgs-unstable; };
in {

  home.packages = with pkgs-unstable;
    languagePackages ++ [
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

      secret_inject.packages.${pkgs.system}.default
      animal_rescue.packages.${pkgs.system}.default
      scrollbacktamer.packages.${pkgs.system}.default
      proctmux.packages.${pkgs.system}.default
      lazydocker
      tmuxp
      nodemon
      mise
 
       k9s

    ];

}
