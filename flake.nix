{
  description = "Home Manager configuration";
  inputs = {
    # Where we get most of our software. Giant mono repo with recipes
    # called derivations that say how to build software.
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-22.11-darwin";

    # Manages configs links things into your home directory
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixpkgs-unstable = {
      url = "github:nixos/nixpkgs/nixpkgs-unstable";
    };

    # Controls system level software and settings including fonts
    darwin.url = "github:lnl7/nix-darwin";
    darwin.inputs.nixpkgs.follows = "nixpkgs";

    procmux.url = "github:napisani/procmux";
    procmux.inputs.nixpkgs.follows = "nixpkgs";

    # neovim-nightly-overlay.url = "github:nix-community/neovim-nightly-overlay";

  };
  outputs = { nixpkgs, nixpkgs-unstable, home-manager, darwin, procmux, ... }@inputs:
    let
      overlays = [
          # inputs.neovim-nightly-overlay.overlay
      ];
      commonInherits = {
        inherit (nixpkgs) lib;
        inherit (nixpkgs) pkgs;
        inherit inputs nixpkgs nixpkgs-unstable home-manager darwin procmux;
      };
    in
    {
      darwinConfigurations = {
        "nicks-mbp" = inputs.darwin.lib.darwinSystem {
          pkgs = nixpkgs.legacyPackages.aarch64-darwin;
          system = "aarch64-darwin";
          modules = [
            ({ config, pkgs, lib, user, ... }:{
              users = {
                users.nick = {
                  home = /Users/nick;
                };
              };
            })
            ./systems/darwin.nix 
            ./systems/system-nicks-mbp.nix
            home-manager.darwinModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = false;
                useUserPackages = true;
                extraSpecialArgs = {
                  inherit inputs;
                  pkgs-unstable = nixpkgs-unstable.legacyPackages.aarch64-darwin;
                  procmux = procmux;
                  overlays = overlays;
                  user = "nick";
                };
                users.nick.imports = [
                  ./homes/macs.nix
                  ./homes/home-nicks-mbp.nix
                ];
              };
            }
          ];
        };
        "NicksCTMMacbook" = inputs.darwin.lib.darwinSystem {
          pkgs = nixpkgs.legacyPackages.aarch64-darwin;
          system = "aarch64-darwin";
          modules = [
            ({ config, pkgs, lib, user, ... }:{
              users = {
                users.nickpisani = {
                  home = /Users/nickpisani;
                };
              };
            })
            ./systems/darwin.nix 
            ./systems/system-NickCTMMackbook.nix
            home-manager.darwinModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = false;
                useUserPackages = true;
                extraSpecialArgs = {
                  inherit inputs;
                  pkgs-unstable = nixpkgs-unstable.legacyPackages.aarch64-darwin;
                  procmux = procmux;
                  overlays = overlays;
                  user = "nickpisani";
                };
                users.nickpisani.imports = [
                  ./homes/macs.nix
                  ./homes/home-NicksCTMMacbook.nix
                ];
              };
            }
          ];
        };
      };
      defaultPackage = {
        /* x86_64-darwin = home-manager.defaultPackage.x86_64-darwin; */
        aarch64-darwin = home-manager.defaultPackage.aarch64-darwin;
        /* aarch64-linux = home-manager.defaultPackage.aarch64-linux; */
      };
    };

}
