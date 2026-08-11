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
  mkSpecialArgs = system: hostname: roles: {
    inherit inputs hostname;
    # Machine roles declared per-machine in flake.nix (e.g. [ "work"
    # "loancrate" ]). Agent modules gate on these instead of hostname string
    # equality, so renaming a machine can't silently disable gated assets.
    machineRoles = roles;
    pkgs-unstable = import nixpkgs {
      inherit system;
      config.allowUnfree = true;
      overlays = [ (import "${self}/overlays/oxlint-darwin-ps-fix.nix") ];
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
      roles ? [ ],
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
            extraSpecialArgs = mkSpecialArgs system hostname roles;
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
      roles ? [ ],
      modules ? [ ],
      homeModules ? [ ],
    }:
    nixpkgs.lib.nixosSystem {
      inherit system;
      pkgs = (mkSpecialArgs system hostname roles).pkgs-unstable;
      modules = [
        home-manager.nixosModules.home-manager
        {
          home-manager = {
            useGlobalPkgs = false;
            useUserPackages = true;
            extraSpecialArgs = mkSpecialArgs system hostname roles;
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
        machineRoles = roles;
        user = username;
      };
    };
}
