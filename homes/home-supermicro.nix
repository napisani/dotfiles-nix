{ inputs, lib, config, pkgs, pkgs-unstable, user, ... }: {
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
    ../mods/secret_inject.nix
    ../mods/packer_plugin_manager.nix
    ../mods/alacritty.nix
  ];

}
