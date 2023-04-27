{ inputs, lib, config, pkgs, ... }: {
  nixpkgs = {
    # Configure your nixpkgs instance
    config = {
      packageOverrides = pkgs: rec {
        procmux = pkgs.callPackage ../packages/procmux.nix { };
      };
    };
  };

  home.packages = with pkgs; [
    procmux 
  ];
}
