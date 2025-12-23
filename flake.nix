{
  description = "Home Manager configuration";
  inputs = {
    # Core infrastructure
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    
    darwin = {
      url = "github:lnl7/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    
    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Development tools
    nil.url = "github:oxalica/nil";

    # Custom packages
    procmux = {
      url = "github:napisani/procmux";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    
    proctmux.url = "github:napisani/proctmux";
    secret_inject.url = "github:napisani/secret_inject";
    animal_rescue.url = "github:napisani/animal-rescue";
    scrollbacktamer.url = "github:napisani/scrollbacktamer";
  };

  outputs = { self, nixpkgs, home-manager, darwin, ... }@inputs:
    let
      inherit (nixpkgs) lib;
      builders = import ./lib/builders.nix {
        inherit inputs nixpkgs home-manager lib self;
      };
    in {
      darwinConfigurations = {
        "nicks-mbp" = builders.mkDarwinSystem {
          system = "aarch64-darwin";
          hostname = "nicks-mbp";
          username = "nick";
          modules = [
            ./systems/profiles/darwin-personal.nix
          ];
          homeModules = [
            ./homes/home-nicks-mbp.nix
          ];
        };

        "nicks-axion-ray-mbp" = builders.mkDarwinSystem {
          system = "aarch64-darwin";
          hostname = "nicks-axion-ray-mbp";
          username = "nick";
          modules = [
            ./systems/profiles/darwin-work.nix
          ];
          homeModules = [
            ./homes/home-nicks-axion-ray-mbp.nix
          ];
        };

        "maclab" = builders.mkDarwinSystem {
          system = "x86_64-darwin";
          hostname = "maclab";
          username = "nick";
          modules = [
            ./systems/profiles/darwin-personal.nix
          ];
          homeModules = [
            ./homes/home-maclab.nix
          ];
        };
      };

      nixosConfigurations = {
        "supermicro" = builders.mkNixOSSystem {
          system = "x86_64-linux";
          hostname = "supermicro";
          username = "nick";
          modules = [
            ./systems/supermicro/configuration.nix
          ];
          homeModules = [
            ./homes/home-supermicro.nix
          ];
        };
      };
    };
}

