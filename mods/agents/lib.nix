# Shared bindings imported by each agents/* submodule.
# Usage: let shared = import ./lib.nix { inherit config pkgs-unstable; };
#        inherit (shared) dotfiles home allAgents isAxionMac isLoancrateMac nodeBin gitBin;
{ config, pkgs-unstable }:
let
  dotfiles = "${config.home.homeDirectory}/.config/home-manager/mods/dotfiles";
  home = config.home.homeDirectory;
  allAgents = [
    "claude-code"
    "cursor"
    "opencode"
    "codex"
    "pi"
  ];
  isAxionMac = (config.home.sessionVariables.MACHINE_NAME or "") == "axion-mbp";
  isLoancrateMac = (config.home.sessionVariables.MACHINE_NAME or "") == "nicks-loancrate-mbp";
  nodeBin = "${pkgs-unstable.nodejs}/bin";
  gitBin = "${pkgs-unstable.git}/bin";
in
{ inherit dotfiles home allAgents isAxionMac isLoancrateMac nodeBin gitBin; }
