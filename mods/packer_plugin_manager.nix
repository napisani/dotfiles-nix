{ inputs, lib, config, pkgs, ... }: {
  nixpkgs = {
    # Configure your nixpkgs instance
    config = {
      packageOverrides = pkgs: rec {
        packer_plugin_updater = pkgs.callPackage ../packages/packer_plugin_updater_from_src.nix { };
      };
    };
  };

  home.packages = with pkgs; [
    packer_plugin_updater
  ];
}
