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

    procmux.url = "github:napisani/procmux/2785927bff9a236682dc4e98a412ef0aadee212d";
    procmux.inputs.nixpkgs.follows = "nixpkgs";

    oxlint_dep.url =
      "github:NixOS/nixpkgs/85306ef2470ba705c97ce72741d56e42d0264015";

    # neovim 0.9.5
    neovim_dep.url =
      "github:NixOS/nixpkgs/1a9df4f74273f90d04e621e8516777efcec2802a";

    golang_dep.url =
      "github:NixOS/nixpkgs/c0b7a892fb042ede583bdaecbbdc804acb85eabe";

    nixhub_dep.url =
      "github:NixOS/nixpkgs/080a4a27f206d07724b88da096e27ef63401a504";
  };
  outputs = { flake-utils, nixpkgs, nixpkgs-unstable, home-manager, darwin
    , procmux, oxlint_dep, neovim_dep, golang_dep, nixhub_dep, ... }@inputs:
    let
      overlays = [
        # inputs.neovim-nightly-overlay.overlay
      ];
      system = "aarch64-darwin";
      extraSpecialArgs = {
        inherit inputs;
        pkgs-unstable = nixpkgs-unstable.legacyPackages."${system}";
        procmux = procmux;
        oxlint_dep = inputs.oxlint_dep.legacyPackages."${system}";
        neovim_dep = inputs.neovim_dep.legacyPackages."${system}";
        golang_dep = inputs.golang_dep.legacyPackages."${system}";
        nixhub_dep = import inputs.nixhub_dep {
          inherit system;
          config.allowUnfree = true;
        };
        overlays = overlays;
        user = "nick";
      };
    in {
      darwinConfigurations = {
        "nicks-mbp" = inputs.darwin.lib.darwinSystem {
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
                extraSpecialArgs = extraSpecialArgs;
                users.nick.imports =
                  [ ./homes/macs.nix ./homes/home-nicks-mbp.nix ];
              };
            }
          ];
        };

        "nicks-axion-ray-mbp" = inputs.darwin.lib.darwinSystem {
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
                extraSpecialArgs = extraSpecialArgs;
                users.nick.imports =
                  [ ./homes/macs.nix ./homes/home-nicks-axion-ray-mbp.nix ];
              };
            }
          ];
        };

        "NicksCTMMacbook" = inputs.darwin.lib.darwinSystem {
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
                extraSpecialArgs = extraSpecialArgs;
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

