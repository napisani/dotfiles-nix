{
  inputs,
  nixpkgs,
  home-manager,
  lib,
  self,
}:
rec {
  # `hostname` is the single source of truth for "which machine is this" at
  # Nix-eval time — it's the same string passed to mkDarwinSystem/
  # mkNixOSSystem below (and thus to flake.nix's darwinConfigurations/
  # nixosConfigurations keys' backing definitions). Exposed as a specialArg
  # so every home-manager module (agent modules in particular) can gate on
  # it directly, instead of the old pattern of each homes/home-*.nix hand-
  # typing a second, independently-maintained MACHINE_NAME sessionVariable
  # string that could (and did) drift out of sync with this one.
  mkSpecialArgs = system: hostname: {
    inherit inputs hostname;
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
            extraSpecialArgs = mkSpecialArgs system hostname;
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
      pkgs = (mkSpecialArgs system hostname).pkgs-unstable;
      modules = [
        home-manager.nixosModules.home-manager
        {
          home-manager = {
            useGlobalPkgs = false;
            useUserPackages = true;
            extraSpecialArgs = mkSpecialArgs system hostname;
            users.${username}.imports = [
              "${self}/homes/profiles/common.nix"
            ]
            ++ homeModules;
          };
        }
      ]
      ++ modules;
      specialArgs = {
        inherit inputs hostname;
        user = username;
      };
    };
}
