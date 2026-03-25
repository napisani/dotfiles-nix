{
  inputs,
  lib,
  config,
  pkgs,
  user,
  overlays,
  ...
}:
let
  direnvOverlay = final: prev: {
    direnv = prev.direnv.overrideAttrs (old: {
      env = (old.env or { }) // {
        CGO_ENABLED = 1;
      };
    });

    mise = prev.mise.override {
      direnv = final.direnv;
    };
  };
in
{
  imports = [
    ../../mods/base-packages.nix
    ../../mods/shell.nix
    ../../mods/git.nix
    ../../mods/gh.nix
    ../../mods/neovim.nix
    ../../mods/ui-packages.nix
    ../../mods/uvx.nix
    ../../mods/npmx.nix
  ];

  nixpkgs = {
    overlays = [ direnvOverlay ];

    config = {
      allowUnfree = true;
      allowUnfreePredicate = (_: true);
    };
  };

  home = {
    username = user;
  };

  programs.home-manager.enable = true;

  systemd.user.startServices = lib.mkIf pkgs.stdenv.isLinux "sd-switch";

  home.stateVersion = "22.11";
}
