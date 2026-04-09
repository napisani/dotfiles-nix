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
    overlays = overlays ++ [ direnvOverlay ];

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
      nixswitchup = "pushd ~/.config/home-manager; git pull && sudo nixos-rebuild --show-trace --flake .#supermicro switch --impure ; popd";
      nixswitch = "pushd ~/.config/home-manager; sudo nixos-rebuild --show-trace --flake .#supermicro switch --impure ; popd";
      nixflakeup = "pushd ~/.config/home-manager; sudo nix flake update && sudo nix flake lock --override-input workmux github:raine/workmux/1764fe71affc24984b084e1ce9409985a0d11afb && sudo nixswitch; popd";
      nixclean = "echo 'Collecting garbage...'; nix-collect-garbage -d && echo 'Optimizing store...'; nix store optimise && echo 'Cleaning up old profiles...'; sudo nix-collect-garbage -d && echo 'Done! Space freed.'";
    };
  };

  # Nicely reload system units when changing configs
  systemd.user.startServices = "sd-switch";

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  home.stateVersion = "22.11";

}
