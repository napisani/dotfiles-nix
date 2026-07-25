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

    # Custom packages
    procmux = {
      url = "github:napisani/procmux";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    proctmux.url = "github:napisani/proctmux";
    secret_inject.url = "github:napisani/secret_inject";
    animal_rescue.url = "github:napisani/animal-rescue";
    scrollbacktamer.url = "github:napisani/scrollbacktamer";

    rift = {
      url = "github:napisani/rift/main-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

  };

  outputs =
    {
      self,
      nixpkgs,
      home-manager,
      darwin,
      ...
    }@inputs:
    let
      inherit (nixpkgs) lib;
      builders = import ./lib/builders.nix {
        inherit
          inputs
          nixpkgs
          home-manager
          lib
          self
          ;
      };
    in
    {
      darwinConfigurations = {
        "nicks-mbp" = builders.mkDarwinSystem {
          system = "aarch64-darwin";
          hostname = "nicks-mbp";
          username = "nick";
          modules = [ ./systems/profiles/darwin-personal.nix ];
          homeModules = [ ./homes/home-nicks-mbp.nix ];
        };

        "Nicks-Loancrate-MacBook-Pro" = builders.mkDarwinSystem {
          system = "aarch64-darwin";
          hostname = "Nicks-Loancrate-MacBook-Pro";
          username = "nick";
          modules = [ ./systems/profiles/darwin-loancrate.nix ];
          homeModules = [ ./homes/home-nicks-loancrate-mbp.nix ];
        };

        "maclab" = builders.mkDarwinSystem {
          system = "x86_64-darwin";
          hostname = "maclab";
          username = "nick";
          modules = [ ./systems/profiles/darwin-maclab.nix ];
          homeModules = [ ./homes/home-maclab.nix ];
        };
      };

      nixosConfigurations = {
        "supermicro" = builders.mkNixOSSystem {
          system = "x86_64-linux";
          hostname = "supermicro";
          username = "nick";
          modules = [ ./systems/supermicro/configuration.nix ];
          homeModules = [ ./homes/home-supermicro.nix ];
        };
      };

      # Force every merged activation value that `darwin-rebuild switch` itself
      # evaluates, so `nix flake check` catches option-merge conflicts (two
      # files defining home.activation.<sameName> differently) at eval time
      # instead of at switch time. builtins.attrNames alone does NOT force the
      # merged values — only forcing the actual string does. See
      # mods/dotfiles/agents/shared-skills/agent-management/SKILL.md
      # ("Verifying a change actually works") for the reasoning.
      checks.aarch64-darwin.activation-merge-forced =
        let
          pkgs = nixpkgs.legacyPackages.aarch64-darwin;
          # maclab is x86_64-darwin, which nixpkgs 26.11 has dropped support
          # for — forcing anything about it throws unconditionally, for a
          # reason unrelated to the activation-name-collision class this check
          # exists to catch. Exclude it so the check stays green on the
          # machines that actually build.
          darwinNames = builtins.filter (n: n != "maclab") (
            builtins.attrNames self.darwinConfigurations
          );
          forceDarwinScript =
            name:
            builtins.stringLength
              self.darwinConfigurations.${name}.config.system.activationScripts.script.text;
          forceHomeActivation =
            cfg:
            let
              acts = cfg.config.home-manager.users.nick.home.activation;
            in
            lib.foldl' (sum: n: sum + builtins.stringLength acts.${n}.data) 0 (builtins.attrNames acts);
          total = lib.foldl' (a: b: a + b) 0 (
            map forceDarwinScript darwinNames
            ++ map (n: forceHomeActivation self.darwinConfigurations.${n}) darwinNames
            ++ map (n: forceHomeActivation self.nixosConfigurations.${n}) (
              builtins.attrNames self.nixosConfigurations
            )
          );
        in
        pkgs.runCommand "activation-merge-forced-${toString total}" { } "echo ${toString total} > $out";
    };
}
