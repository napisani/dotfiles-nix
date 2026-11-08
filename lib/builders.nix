{
  inputs,
  nixpkgs,
  nixpkgs-unstable,
  darwin,
  darwin-26,
  self,
}:
rec {
  # nixpkgs 26.05 is the last release supporting Intel Macs.
  isIntelMac = system: system == "x86_64-darwin";
  nixpkgsFor = system: if isIntelMac system then nixpkgs else nixpkgs-unstable;
  darwinFor = system: if isIntelMac system then darwin-26 else darwin;
  pkgsFor =
    system:
    import (nixpkgsFor system) {
      inherit system;
      config.allowUnfree = true;
    };

  mkDarwinSystem =
    {
      system,
      hostname,
      username,
      modules ? [ ],
    }:
    (darwinFor system).lib.darwinSystem {
      inherit system;
      specialArgs = {
        inherit inputs hostname;
        user = username;
      };
      modules = [
        "${self}/systems/profiles/darwin-base.nix"
        "${self}/mods/base-packages.nix"
        {
          nixpkgs.pkgs = pkgsFor system;
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
    }:
    (nixpkgsFor system).lib.nixosSystem {
      inherit system;
      pkgs = pkgsFor system;
      specialArgs = {
        inherit inputs hostname;
        user = username;
      };
      modules = [ "${self}/mods/base-packages.nix" ] ++ modules;
    };
}
