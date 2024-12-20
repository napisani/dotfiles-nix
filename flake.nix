{
  description = "Home Manager configuration";
  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    # Where we get most of our software. Giant mono repo with recipes
    # called derivations that say how to build software.
    # nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-24.05-darwin";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.05";
    home-manager.url = "github:nix-community/home-manager/release-24.05"; # ...
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-24.05-darwin";
    # nixpkgs-darwin.url = "github:nixos/nixpkgs/nixpkgs-24.05-darwin";
    # nix-darwin = {
    #   url = "github:lnl7/nix-darwin";
    #   inputs.nixpkgs.follows = "nixpkgs-darwin";
    # };
    # nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-24.05";

    # Manages configs links things into your home directory
    # home-manager = {
    #   url = "github:nix-community/home-manager/master";
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };

    nixpkgs-unstable = { url = "github:nixos/nixpkgs/nixpkgs-unstable"; };

    # Controls system level software and settings including fonts
    darwin.url = "github:lnl7/nix-darwin";
    darwin.inputs.nixpkgs.follows = "nixpkgs";

    # nixos-nixpkgs = {
    #   url = "github:nixos/nixpkgs/nixos-24.05";
    #   follows = "nixpkgs";
    # };

    # procmux.url =
    #   "github:napisani/procmux/e18accb8fdab8fdb72b75febeb91ab0f93637f3a";

    procmux.url =
      "github:napisani/procmux/ab479fa499fb35b040c2230ac52d5958b05b1934";
    procmux.inputs.nixpkgs.follows = "nixpkgs";

    # neovim 0.9.5
    neovim_dep.url =
      "github:NixOS/nixpkgs/1a9df4f74273f90d04e621e8516777efcec2802a";

    golang_dep.url =
      "github:NixOS/nixpkgs/c0b7a892fb042ede583bdaecbbdc804acb85eabe";

    nixhub_dep.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    secret_inject.url =
      "github:napisani/secret_inject/58be3ae97e2e55aef6b4255ec3e3f387f307973a";

    animal_rescue.url =
      "github:napisani/animal-rescue/321b2e7de5a915d30526ee083fb23b98fbf10cb5";

  };

  outputs = { flake-utils, nixpkgs, nixpkgs-unstable, home-manager, darwin
    , procmux, secret_inject, animal_rescue, neovim_dep, golang_dep, nixhub_dep
    , ... }@inputs:
    let
      allSystems = [ "x86_64-linux" "aarch64-darwin" ];
      inputsBySystem = builtins.listToAttrs (map (system: {
        name = system;
        value = {
          system = system;
          extraSpecialArgs = {
            inherit inputs;
            pkgs-unstable = import nixpkgs-unstable {
              inherit system;
              config.allowUnfree = true;
            };
            procmux = procmux;
            neovim_dep = inputs.neovim_dep.legacyPackages."${system}";
            golang_dep = inputs.golang_dep.legacyPackages."${system}";
            secret_inject = secret_inject;
            animal_rescue = animal_rescue;
            nixhub_dep = import inputs.nixhub_dep {
              inherit system;
              config.allowUnfree = true;
            };
            overlays = [
              # import ./packages/node/node-packages.nix
              # inputs.neovim-nightly-overlay.overlay

            ];

            user = "nick";
          };
        };
      }) allSystems);

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
                extraSpecialArgs =
                  inputsBySystem."aarch64-darwin".extraSpecialArgs;
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
                extraSpecialArgs =
                  inputsBySystem."aarch64-darwin".extraSpecialArgs;
                users.nick.imports =
                  [ ./homes/macs.nix ./homes/home-nicks-axion-ray-mbp.nix ];
              };
            }
          ];
        };
      };

      nixosConfigurations = {
        "supermicro" = nixpkgs-unstable.lib.nixosSystem {
          system = "x86_64-linux";
          pkgs = inputsBySystem."x86_64-linux".extraSpecialArgs.pkgs-unstable;
          modules = [
            home-manager.nixosModules.home-manager
            ./systems/supermicro/configuration.nix

            {
              home-manager = {
                useGlobalPkgs = false;
                useUserPackages = true;
                extraSpecialArgs =
                  inputsBySystem."x86_64-linux".extraSpecialArgs;
                users.nick.imports = [ ./homes/home-supermicro.nix ];
              };
            }
          ];
          specialArgs = {
            inherit inputs;
            user = "nick";
          };
        };
      };

      defaultPackage = {
        # x86_64-darwin = home-manager.defaultPackage.x86_64-darwin;
        aarch64-darwin = home-manager.defaultPackage.aarch64-darwin;
        # aarch64-linux = home-manager.defaultPackage.aarch64-linux;
      };
    };
}

