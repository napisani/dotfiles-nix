{ inputs, lib, config, pkgs, user, overlays, ... }: {
  imports = [
    # If you want to use home-manager modules from other flakes (such as nix-colors):
    # inputs.nix-colors.homeManagerModule

    # You can also split up your configuration and import pieces of it here:
    ../mods/base-packages.nix
    ../mods/shell.nix
    ../mods/git.nix
    ../mods/gh.nix
    ../mods/rust.nix
    ../mods/javascript.nix
    ../mods/golang.nix
    ../mods/neovim.nix
    # ../mods/secret_inject.nix
    # ../mods/packer_plugin_manager.nix
    # ../mods/alacritty.nix
  ];

  nixpkgs = {
    # You can add overlays here
    overlays = overlays;

    # Configure your nixpkgs instance
    config = {
      # Disable if you don't want unfree packages
      allowUnfree = true;
      # Workaround for https://github.com/nix-community/home-manager/issues/2942
      allowUnfreePredicate = (_: true);
      # packageOverrides = pkgs: rec {
      # secret_inject = pkgs.callPackage ../mods/secret_inject.nix { };
      # };
    };
  };

  home = {
    username = user;
    # homeDirectory = "/Users/nick";
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
    sessionVariables = { SHELL = "${pkgs.bashInteractive}/bin/bash"; };
    shellAliases = {
      nixswitch =
        "pushd ~/.config/home-manager; sudo nixos-rebuild --flake .#supermicro switch --impure ; popd";
      nixup =
        "pushd ~/.config/home-manager; sudo nix flake update; sudo nixswitch; popd";
    };
  };

  # Nicely reload system units when changing configs
  systemd.user.startServices = "sd-switch";

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  home.stateVersion = "22.11";
}
