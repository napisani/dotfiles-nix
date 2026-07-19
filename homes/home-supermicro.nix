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
  homeManagerDir = "~/.config/home-manager";
  switchCommand = "sudo nixos-rebuild --show-trace --no-update-lock-file --flake .#supermicro switch --impure";
  flakeUpdateCommand = "pushd ${homeManagerDir}; nix flake update --refresh && ${switchCommand}; popd";
in
{
  imports = [
    # if you want to use home-manager modules from other flakes (such as nix-colors):
    # inputs.nix-colors.homemanagermodule

    # you can also split up your configuration and import pieces of it here:
    ../mods/base-packages.nix
    ../mods/shell.nix
    ../mods/git.nix
    ../mods/gh.nix
    ../mods/neovim.nix
  ];

  nixpkgs = {
    # you can add overlays here
    overlays = overlays;

    # configure your nixpkgs instance
    config = {
      # disable if you don't want unfree packages
      allowUnfree = true;
      # workaround for https://github.com/nix-community/home-manager/issues/2942
      allowUnfreePredicate = (_: true);
      # packageoverrides = pkgs: rec {
      # secret_inject = pkgs.callpackage ../mods/secret_inject.nix { };
      # };
    };
  };

  home = {
    username = user;
    # homedirectory = "/users/nick";
    sessionVariables = {
      MACHINE_NAME = "supermicro";
    };
  };

  home.packages = with pkgs; [ gcc ];

  # Add stuff for your user as you see fit:
  # programs.neovim.enable = true;
  # home.packages = with pkgs; [ steam ];

  # Enable home-manager and git
  programs.home-manager.enable = true;
  # programs.git.enable = true;

  programs.bash = {
    enable = true;
    sessionVariables = {
      SHELL = "${pkgs.bashInteractive}/bin/bash";
    };
    shellAliases = {
      backup-homelab = "sudo --preserve-env=HOMELAB_BACKUP_RESTIC_PASSWORD /home/nick/toolbox/homelab_backup.py backup";
      nixswitchup = "pushd ${homeManagerDir}; git pull && ${switchCommand}; popd";
      nixswitch = "pushd ${homeManagerDir}; ${switchCommand}; popd";
      nixflakeup = flakeUpdateCommand;
      nixupgrade = flakeUpdateCommand;
      nixclean = "echo 'Collecting garbage...'; nix-collect-garbage -d && echo 'Optimizing store...'; nix store optimise && echo 'Cleaning up old profiles...'; sudo nix-collect-garbage -d && echo 'Done! Space freed.'";
    };
  };

  # Nicely reload system units when changing configs
  systemd.user.startServices = "sd-switch";

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  home.stateVersion = "22.11";

}
