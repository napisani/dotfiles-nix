{
  description = "System configuration and portable mise userland";
  inputs = {
    # Intel hosts and shared package inputs need the last Intel-compatible release.
    # ARM Macs and Linux use nixpkgs-unstable through the system builders.
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-26.05-darwin";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";

    darwin = {
      url = "github:lnl7/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    # 26.05 release branch of nix-darwin, paired with the main nixpkgs
    # input for the Intel Mac (maclab, x86_64-darwin) config only.
    darwin-26 = {
      url = "github:lnl7/nix-darwin/nix-darwin-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Custom packages
    proctmux = {
      url = "path:../proctmux";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    scute = {
      url = "path:../scute";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nixpkgs-darwin.follows = "nixpkgs";
    };
    stackman = {
      url = "path:../stackman";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    secret_inject = {
      url = "path:../secret_inject";
      # Its own lock pins a 26.11-era nixpkgs that dropped x86_64-darwin;
      # follow the main nixpkgs (26.05-darwin) so maclab can evaluate it.
      inputs.nixpkgs.follows = "nixpkgs";
    };
    tmux_picker = {
      url = "path:../tmux-picker";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    mushy_lint = {
      url = "path:../mushy-lint";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.nixpkgs-darwin.follows = "nixpkgs";
    };
    animal_rescue = {
      url = "path:../animalcontrol";
      inputs.nixpkgs.follows = "nixpkgs";
    };

  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-unstable,
      darwin,
      darwin-26,
      ...
    }@inputs:
    let
      inherit (nixpkgs) lib;
      builders = import ./lib/builders.nix {
        inherit
          inputs
          nixpkgs
          nixpkgs-unstable
          darwin
          darwin-26
          self
          ;
      };
      mkActivationMergeForcedCheck =
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          darwinNames = builtins.attrNames self.darwinConfigurations;
          forceDarwinScript =
            name:
            builtins.stringLength self.darwinConfigurations.${name}.config.system.activationScripts.script.text
            + builtins.stringLength self.darwinConfigurations.${name}.system.drvPath;
          total = lib.foldl' (a: b: a + b) 0 (
            map forceDarwinScript darwinNames
            ++ map (cfg: builtins.stringLength cfg.config.system.build.toplevel.drvPath) (
              builtins.attrValues self.nixosConfigurations
            )
          );
        in
        pkgs.runCommand "activation-merge-forced-${toString total}" { } "echo ${toString total} > $out";
    in
    {
      darwinConfigurations = {
        "nicks-mbp" = builders.mkDarwinSystem {
          system = "aarch64-darwin";
          hostname = "nicks-mbp";
          username = "nick";
          modules = [ ./systems/profiles/darwin-personal.nix ];
        };

        "Nicks-Loancrate-MacBook-Pro" = builders.mkDarwinSystem {
          system = "aarch64-darwin";
          hostname = "Nicks-Loancrate-MacBook-Pro";
          username = "nick";
          modules = [ ./systems/profiles/darwin-loancrate.nix ];
        };

        "maclab" = builders.mkDarwinSystem {
          system = "x86_64-darwin";
          hostname = "maclab";
          username = "nick";
          modules = [ ./systems/profiles/darwin-maclab.nix ];
        };
      };

      nixosConfigurations = {
        "supermicro" = builders.mkNixOSSystem {
          system = "x86_64-linux";
          hostname = "supermicro";
          username = "nick";
          modules = [ ./systems/supermicro/configuration.nix ];
        };
      };

      # Forcing merged activation strings catches conflicts before switching;
      # enumerating their attribute names alone does not evaluate their values.
      checks = lib.genAttrs [ "aarch64-darwin" "x86_64-darwin" "x86_64-linux" ] (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          activation-merge-forced = mkActivationMergeForcedCheck system;

          userland-boundary = import ./checks/native-installs.nix {
            inherit self lib pkgs;
          };
        }
      );
    };
}
