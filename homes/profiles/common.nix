{
  inputs,
  lib,
  config,
  pkgs,
  user,
  overlays,
  ...
}:
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
    overlays = [ (import ../../overlays/vi-mongo.nix) ] ++ overlays;

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
