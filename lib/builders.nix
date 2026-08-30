{
  inputs,
  nixpkgs,
  nixpkgs-unstable,
  home-manager,
  home-manager-26,
  darwin,
  darwin-26,
  lib,
  self,
}:
rec {
  # nixpkgs 26.11 dropped x86_64-darwin (Intel Macs). maclab is the only
  # x86_64-darwin host, so it stays on the 26.05 stack (nixpkgs + nix-darwin-26
  # + home-manager release-26.05). NixOS hosts use the matching
  # nixpkgs-unstable/Home Manager stack.
  isIntelMac = system: system == "x86_64-darwin";
  # The main nixpkgs input is already the 26.05-darwin branch; on non-Intel
  # systems, "unstable" for pkgs-unstable means the separate
  # nixpkgs-unstable input, and the 26.05 branch on Intel Macs (since
  # nixpkgs-unstable dropped them).
  nixpkgsFor = system: if isIntelMac system then nixpkgs else nixpkgs-unstable;
  darwinFor = system: if isIntelMac system then darwin-26 else darwin;
  homeManagerFor = system: if isIntelMac system then home-manager-26 else home-manager;

  # Where this flake checkout lives relative to $HOME, on every host that
  # doesn't override it in flake.nix. This is the ONE place that default
  # lives — mkDarwinSystem/mkNixOSSystem forward whatever's passed (or this
  # default) as the `homeManagerRelPath` specialArg, and every downstream
  # module (mods/shell.nix, mods/agents/lib.nix, etc.) just declares
  # `homeManagerRelPath` as a required arg rather than re-declaring a
  # default of its own — don't add `? "..."` fallbacks elsewhere. A machine
  # applying a standalone clone of the public repo (not from the monorepo)
  # should override this to ".config/home-manager" in its flake.nix entry.
  defaultHomeManagerRelPath = "code/monorepo/pub/dotfiles-nix";

  # `hostname` is the single source of truth for "which machine is this" at
  # Nix-eval time — it's the same string passed to mkDarwinSystem/
  # mkNixOSSystem below (and thus to flake.nix's darwinConfigurations/
  # nixosConfigurations keys' backing definitions). Exposed as a specialArg
  # so every home-manager module (agent modules in particular) can gate on
  # it directly, instead of the old pattern of each homes/home-*.nix hand-
  # typing a second, independently-maintained MACHINE_NAME sessionVariable
  # string that could (and did) drift out of sync with this one.
  mkSpecialArgs = system: hostname: roles: homeManagerRelPath: {
    inherit inputs hostname homeManagerRelPath;
    # Machine roles declared per-machine in flake.nix (e.g. [ "work"
    # "loancrate" ]). Agent modules gate on these instead of hostname string
    # equality, so renaming a machine can't silently disable gated assets.
    machineRoles = roles;
    # macOS Intel Macs (x86_64-darwin) use the nixpkgs-26.05-darwin stack
    # (nixpkgs 26.11 dropped Intel support). Modules can use this flag to
    # conditionally avoid options that don't exist in the 26.05 release.
    useHomeManager26 = isIntelMac system;
    # "unstable" is nixpkgs-unstable everywhere except x86_64-darwin, where
    # it's the 26.05-darwin branch (the last release supporting Intel Macs).
    pkgs-unstable = import (nixpkgsFor system) {
      inherit system;
      config.allowUnfree = true;
      overlays = [ ];
    };
    # Make custom packages available directly
    inherit (inputs)
      procmux
      proctmux
      stackman
      secret_inject
      tmux_picker
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
      homeManagerRelPath ? defaultHomeManagerRelPath,
    }:
    (darwinFor system).lib.darwinSystem {
      inherit system;
      modules = [
        "${self}/systems/profiles/darwin-base.nix"

        (homeManagerFor system).darwinModules.home-manager
        {
          home-manager = {
            useGlobalPkgs = false;
            useUserPackages = true;
            extraSpecialArgs = mkSpecialArgs system hostname roles homeManagerRelPath;
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
      homeManagerRelPath ? defaultHomeManagerRelPath,
    }:
    nixpkgs-unstable.lib.nixosSystem {
      inherit system;
      # Keep the NixOS module set and system package set on the same release.
      pkgs = import nixpkgs-unstable {
        inherit system;
        config.allowUnfree = true;
        overlays = [ ];
      };
      modules = [
        (homeManagerFor system).nixosModules.home-manager
        {
          home-manager = {
            useGlobalPkgs = false;
            useUserPackages = true;
            extraSpecialArgs = mkSpecialArgs system hostname roles homeManagerRelPath;
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
