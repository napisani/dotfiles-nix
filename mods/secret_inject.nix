{ inputs, lib, config, pkgs, ... }: {
  nixpkgs = {
    # Configure your nixpkgs instance
    config = {
      packageOverrides = pkgs: rec {
        secret_inject = pkgs.callPackage ../packages/secret_inject.nix { };
      };
    };
  };

  home.packages = with pkgs; [
   secret_inject 
  ];
}
