{
  description = "Home Manager configuration";
  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    nixpkgs-darwin.url = "github:NixOS/nixpkgs/nixpkgs-25.05-darwin";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nil.url = "github:oxalica/nil";
    darwin = {
      url = "github:lnl7/nix-darwin/nix-darwin-25.05";
      inputs.nixpkgs.follows = "nixpkgs-darwin";
    };
    home-manager = {
      url = "github:nix-community/home-manager/release-25.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # For using new modules before the realease of the next nixos version
    home-manager-master = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Where we get most of our software. Giant mono repo with recipes
    # called derivations that say how to build software.
    # nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-24.05-darwin";

    # nixpkgs.url = "github:NixOS/nixpkgs/nixos-24.11";
    # home-manager.url = "github:nix-community/home-manager/release-24.11"; # ...
    # home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # nixpkgs-unstable = { url = "github:nixos/nixpkgs/nixpkgs-unstable"; };

    # Controls system level software and settings including fonts
    # darwin.url = "github:lnl7/nix-darwin/nix-darwin-24.11";
    # darwin.inputs.nixpkgs.follows = "nixpkgs";

    procmux.url = "github:napisani/procmux";
    procmux.inputs.nixpkgs.follows = "nixpkgs";

    nixhub_dep.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    secret_inject.url = "github:napisani/secret_inject";

    animal_rescue.url = "github:napisani/animal-rescue";

    scrollbacktamer.url = "github:napisani/scrollbacktamer";

    proctmux.url = "github:napisani/proctmux";

    # old_bitwarden.url =
    #   "github:NixOS/nixpkgs/dd613136ee91f67e5dba3f3f41ac99ae89c5406b";

  };

  outputs = { flake-utils, nixpkgs, nixpkgs-unstable, home-manager, darwin
    , procmux, secret_inject, animal_rescue, nixhub_dep, scrollbacktamer, proctmux, ...
    }@inputs:
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
            # neovim_dep = inputs.neovim_dep.legacyPackages."${system}";
            # golang_dep = inputs.golang_dep.legacyPackages."${system}";
            secret_inject = secret_inject;
            animal_rescue = animal_rescue;
            nixhub_dep = import inputs.nixhub_dep {
              inherit system;
              config.allowUnfree = true;
            };
            scrollbacktamer = scrollbacktamer;
            proctmux = proctmux;
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

