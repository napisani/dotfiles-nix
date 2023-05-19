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

  };
  outputs = { nixpkgs, nixpkgs-unstable, home-manager, darwin, procmux, ... }@inputs:
    let
      commonInherits = {
        inherit (nixpkgs) lib;
        inherit inputs nixpkgs nixpkgs-unstable home-manager darwin procmux;
      };
    in
    {
      darwinConfigurations = {
        "nick-macbook-small" = inputs.darwin.lib.darwinSystem {
          pkgs = nixpkgs.legacyPackages.aarch64-darwin;
          system = "aarch64-darwin";
          modules = [
            ./systems/darwin.nix
            home-manager.darwinModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = false;
                useUserPackages = true;
                extraSpecialArgs = {
                  inherit inputs;
                  pkgs-unstable = nixpkgs-unstable.legacyPackages.aarch64-darwin;
                  procmux = procmux;
                };
                users.nick.imports = [
                  (import
                    ./homes/macs.nix
                    (commonInherits //
                      {
                        user = "nick";
                      }))
                ];
              };
            }
          ];
        };
        "NicksCTMMacbook" = inputs.darwin.lib.darwinSystem {
          pkgs = nixpkgs.legacyPackages.aarch64-darwin;
          system = "aarch64-darwin";
          modules = [
            ./systems/darwin.nix
            home-manager.darwinModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = false;
                useUserPackages = true;
                extraSpecialArgs = {
                  inherit inputs;
                  pkgs-unstable = nixpkgs-unstable.legacyPackages.aarch64-darwin;
                  procmux = procmux;
                };
                users.nickpisani.imports = [
                  (import
                    ./homes/macs.nix
                    (commonInherits //
                      {
                        user = "nickpisani";
                      }))
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
