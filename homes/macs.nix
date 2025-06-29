# This is your home-manager configuration file
# Use this to configure your home environment (it replaces ~/.config/nixpkgs/home.nix)

{ inputs, lib, config, pkgs, user, overlays, ... }: {

  #manual.manpages.enable = false;
  # You can import other home-manager modules here
  imports = [
    # If you want to use home-manager modules from other flakes (such as nix-colors):
    # inputs.nix-colors.homeManagerModule

    # You can also split up your configuration and import pieces of it here:
    ../mods/base-packages.nix
    ../mods/shell.nix
    ../mods/git.nix
    ../mods/gh.nix
    # ../mods/rust.nix
    # ../mods/javascript.nix
    # ../mods/golang.nix
    ../mods/neovim.nix
    # ../mods/secret_inject.nix
    # ../mods/packer_plugin_manager.nix
    ../mods/alacritty.nix
    ../mods/karabiner.nix
    ../mods/ui-packages.nix
  ];

  nixpkgs = {
    # You can add overlays here
    overlays = [ (import ../overlays/vi-mongo.nix) ] ++ overlays;

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

  home.packages = with pkgs;
    [
      vi-mongo
      # my-scripts
    ];

  # Add stuff for your user as you see fit:
  # programs.neovim.enable = true;
  # home.packages = with pkgs; [ steam ];

  # Enable home-manager and git
  programs.home-manager.enable = true;
  # programs.git.enable = true;

  programs.bash = {
    shellAliases = {
      nixswitchup =
        "pushd ~/.config/home-manager; git pull && sudo darwin-rebuild switch --show-trace --flake ~/.config/home-manager/.# ; popd";
      nixswitch =
        "pushd ~/.config/home-manager; sudo darwin-rebuild switch --show-trace --flake ~/.config/home-manager/.# ; popd";
      nixup = "pushd ~/.config/home-manager; nix flake update; nixswitch; popd";
    };
  };

  # Nicely reload system units when changing configs
  systemd.user.startServices = "sd-switch";

  # https://nixos.wiki/wiki/FAQ/When_do_I_update_stateVersion
  home.stateVersion = "22.11";
}
