{
  description = "Home Manager configuration";
  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    # Where we get most of our software. Giant mono repo with recipes
    # called derivations that say how to build software.
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-22.11-darwin";

    # Manages configs links things into your home directory
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nixpkgs-unstable = { url = "github:nixos/nixpkgs/nixpkgs-unstable"; };

    # Controls system level software and settings including fonts
    darwin.url = "github:lnl7/nix-darwin";
    darwin.inputs.nixpkgs.follows = "nixpkgs";

    procmux.url = "github:napisani/procmux";
    procmux.inputs.nixpkgs.follows = "nixpkgs";

    oxlint_dep.url =
      "github:NixOS/nixpkgs/85306ef2470ba705c97ce72741d56e42d0264015";

    neovim_dep.url = "github:NixOS/nixpkgs/4fddc9be4eaf195d631333908f2a454b03628ee5";

    golang_dep.url = "github:NixOS/nixpkgs/c0b7a892fb042ede583bdaecbbdc804acb85eabe";

  };
  outputs =
    { flake-utils
    , nixpkgs
    , nixpkgs-unstable
    , home-manager
    , darwin
    , procmux
    , oxlint_dep
    , neovim_dep
    , golang_dep
    , ...
    }@inputs:
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
            ({ config, pkgs, lib, user, ... }: {
              users = { users.nick = { home = /Users/nick; }; };
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
                  pkgs-unstable =
                    nixpkgs-unstable.legacyPackages.aarch64-darwin;
                  procmux = procmux;
                  oxlint_dep = inputs.oxlint_dep.legacyPackages.aarch64-darwin;
                  neovim_dep = inputs.neovim_dep.legacyPackages.aarch64-darwin;
                  golang_dep = inputs.golang_dep.legacyPackages.aarch64-darwin;
                  overlays = overlays;
                  user = "nick";
                };
                users.nick.imports =
                  [ ./homes/macs.nix ./homes/home-nicks-mbp.nix ];
              };
            }
          ];
        };

        "nicks-axion-ray-mbp" = inputs.darwin.lib.darwinSystem {
          pkgs = nixpkgs.legacyPackages.aarch64-darwin;
          system = "aarch64-darwin";
          modules = [
            ({ config, pkgs, lib, user, ... }: {
              users = { users.nick = { home = /Users/nick; }; };
            })
            ./systems/darwin.nix
            ./systems/system-nicks-axion-ray-mbp.nix
            home-manager.darwinModules.home-manager
            {
              home-manager = {
                useGlobalPkgs = false;
                useUserPackages = true;
                extraSpecialArgs = {
                  inherit inputs;
                  pkgs-unstable = nixpkgs-unstable.legacyPackages.aarch64-darwin;
                  procmux = procmux;
                  oxlint_dep = inputs.oxlint_dep.legacyPackages.aarch64-darwin;
                  neovim_dep = inputs.neovim_dep.legacyPackages.aarch64-darwin;
                  golang_dep = inputs.golang_dep.legacyPackages.aarch64-darwin;
                  overlays = overlays;
                  user = "nick";
                };
                users.nick.imports =
                  [ ./homes/macs.nix ./homes/home-nicks-axion-ray-mbp.nix ];
              };
            }
          ];
        };

        "NicksCTMMacbook" = inputs.darwin.lib.darwinSystem {
          pkgs = nixpkgs.legacyPackages.aarch64-darwin;
          system = "aarch64-darwin";
          modules = [
            ({ config, pkgs, lib, user, ... }: {
              users = { users.nickpisani = { home = /Users/nickpisani; }; };
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
                  pkgs-unstable =
                    nixpkgs-unstable.legacyPackages.aarch64-darwin;
                  procmux = procmux;
                  oxlint_dep = inputs.oxlint_dep.legacyPackages.aarch64-darwin;
                  neovim_dep = inputs.neovim_dep.legacyPackages.aarch64-darwin;
                  golang_dep = inputs.golang_dep.legacyPackages.aarch64-darwin;
                  overlays = overlays;
                  user = "nickpisani";
                };
                users.nickpisani.imports =
                  [ ./homes/macs.nix ./homes/home-NicksCTMMacbook.nix ];
              };
            }
          ];
        };
      };
      defaultPackage = {
        # x86_64-darwin = home-manager.defaultPackage.x86_64-darwin;
        aarch64-darwin = home-manager.defaultPackage.aarch64-darwin;
        # aarch64-linux = home-manager.defaultPackage.aarch64-linux;
      };
    };

}
