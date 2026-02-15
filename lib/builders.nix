{
  inputs,
  nixpkgs,
  home-manager,
  lib,
  self,
}:
rec {
  mkSpecialArgs = system: {
    inherit inputs;
    pkgs-unstable = import nixpkgs {
      inherit system;
      config.allowUnfree = true;
    };
    # Make custom packages available directly
    inherit (inputs)
      procmux
      proctmux
      secret_inject
      animal_rescue
      scrollbacktamer
      rift
      ;
    overlays = [ ];
    user = "nick";
  };

  mkDarwinSystem =
    {
      system,
      hostname,
      username,
      modules ? [ ],
      homeModules ? [ ],
    }:
    inputs.darwin.lib.darwinSystem {
      inherit system;
      modules = [
        "${self}/systems/profiles/darwin-base.nix"

        home-manager.darwinModules.home-manager
        {
          home-manager = {
            useGlobalPkgs = false;
            useUserPackages = true;
            extraSpecialArgs = mkSpecialArgs system;
            users.${username}.imports = [
              "${self}/homes/profiles/common.nix"
              "${self}/homes/profiles/darwin.nix"
            ]
            ++ homeModules;
          };

          users.users.${username}.home = /Users/${username};
        }
      ]
      ++ modules;
    };

  mkNixOSSystem =
    {
      system,
      hostname,
      username,
      modules ? [ ],
      homeModules ? [ ],
    }:
    nixpkgs.lib.nixosSystem {
      inherit system;
      pkgs = (mkSpecialArgs system).pkgs-unstable;
      modules = [
        home-manager.nixosModules.home-manager
        {
          home-manager = {
            useGlobalPkgs = false;
            useUserPackages = true;
            extraSpecialArgs = mkSpecialArgs system;
            users.${username}.imports = [
              "${self}/homes/profiles/common.nix"
            ]
            ++ homeModules;
          };
        }
      ]
      ++ modules;
      specialArgs = {
        inherit inputs;
        user = username;
      };
    };
}
