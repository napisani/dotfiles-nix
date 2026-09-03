{
  description = "Home Manager configuration";
  inputs = {
    # Core infrastructure
    # nixpkgs 26.11 dropped x86_64-darwin (Intel Macs). The main nixpkgs
    # input is the 26.05-darwin branch — the last release supporting Intel
    # Macs — and every input that follows nixpkgs (procmux, animal_rescue,
    # rift, stackman, nix-darwin-26, home-manager-26) stays on it so
    # everything evaluates on all systems. Arm64 Macs get bleeding-edge
    # packages via the separate nixpkgs-unstable input (pkgs-unstable in
    # specialArgs); Intel Macs (maclab) get 26.05 there instead, since
    # unstable dropped them.
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

    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    # home-manager release branch matching nixpkgs 26.05, for maclab only.
    # master asserts fzf >= 0.73.0 for nushell integration, but nixpkgs
    # 26.05 ships fzf 0.72.0; release-26.05 has no such assertion.
    home-manager-26 = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Custom packages
    procmux = {
      url = "github:napisani/procmux";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    proctmux.url = "github:napisani/proctmux";
    stackman = {
      url = "path:../stackman";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    secret_inject = {
      url = "github:napisani/secret_inject";
      # Its own lock pins a 26.11-era nixpkgs that dropped x86_64-darwin;
      # follow the main nixpkgs (26.05-darwin) so maclab can evaluate it.
      inputs.nixpkgs.follows = "nixpkgs";
    };
    tmux_picker = {
      url = "path:../tmux-picker";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    animal_rescue = {
      url = "path:../animalcontrol";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    scrollbacktamer = {
      url = "path:../scrollbacktamer";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    rift = {
      url = "github:napisani/rift/main-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Look launcher — keyboard-first desktop launcher (macOS/Linux).
    # The nix flake only builds for Linux; on macOS we install via brew cask.
    look = {
      url = "github:kunkka19xx/look?dir=apps/linows";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };

    # ── Community skill sources (content-only, pinned via flake.lock) ──────
    # Consumed by mods/agents/skills.nix's catalog; each is a plain content
    # repo (flake = false), not a Nix flake. Update one with:
    #   nix flake update <input-name>
    # proctmux skills reuse the existing `proctmux` input above (a flake
    # input's source tree works the same whether or not it's a flake).
    anthropic-skills = {
      url = "github:anthropics/skills";
      flake = false;
    };
    wshobson-agents = {
      url = "github:wshobson/agents";
      flake = false;
    };
    intellectronica-agent-skills = {
      url = "github:intellectronica/agent-skills";
      flake = false;
    };
    addyosmani-agent-skills = {
      url = "github:addyosmani/agent-skills";
      flake = false;
    };
    superpowers = {
      url = "github:obra/superpowers";
      flake = false;
    };
    mattpocock-skills = {
      url = "github:mattpocock/skills";
      flake = false;
    };
    arjunmahishi-dotfiles = {
      url = "github:arjunmahishi/dotfiles";
      flake = false;
    };
    vantage-nvim-skills = {
      url = "path:../vantage-nvim";
      flake = false;
    };
    playwright-cli-skills = {
      url = "github:microsoft/playwright-cli";
      flake = false;
    };
    deepagents = {
      url = "github:langchain-ai/deepagents";
      flake = false;
    };
    softaworks-agent-toolkit = {
      url = "github:softaworks/agent-toolkit";
      flake = false;
    };
    workmux-skills = {
      url = "github:raine/workmux";
      flake = false;
    };
    gh-stack-skills = {
      url = "github:github/gh-stack";
      flake = false;
    };
    no-ai-slop = {
      url = "github:petergyang/no-ai-slop";
      flake = false;
    };
    humanlayer-skills = {
      url = "github:humanlayer/skills";
      flake = false;
    };
    builderio-skills = {
      url = "github:nicobailon/visual-explainer";
      flake = false;
    };
    # Private napisani repos — fetched over HTTPS (gh auth token required to
    # update the lock; rebuilds use the pinned lock and need no network).
    # SSH URLs don't work here: darwin-rebuild runs as root via sudo, and
    # root's ssh can't see /Users/<user>/.ssh keys nor the (empty) agent.
    # private-skills now lives in napisani/monorepo at priv/skills/.
    private-skills = {
      url = "git+https://github.com/napisani/monorepo.git";
      flake = false;
    };
    lc-script-skills = {
      url = "git+https://github.com/napisani/lc-script";
      flake = false;
    };
    patricio0312rev-skills = {
      url = "github:patricio0312rev/skills";
      flake = false;
    };
    deepwiki-rs-skills = {
      url = "github:sopaco/deepwiki-rs";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      nixpkgs-unstable,
      home-manager,
      home-manager-26,
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
          home-manager
          home-manager-26
          darwin
          darwin-26
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
          roles = [ "personal" ];
          modules = [ ./systems/profiles/darwin-personal.nix ];
          homeModules = [ ./homes/home-nicks-mbp.nix ];
        };

        "Nicks-Loancrate-MacBook-Pro" = builders.mkDarwinSystem {
          system = "aarch64-darwin";
          hostname = "Nicks-Loancrate-MacBook-Pro";
          username = "nick";
          roles = [
            "work"
            "loancrate"
          ];
          modules = [ ./systems/profiles/darwin-loancrate.nix ];
          homeModules = [ ./homes/home-nicks-loancrate-mbp.nix ];
        };

        "maclab" = builders.mkDarwinSystem {
          system = "x86_64-darwin";
          hostname = "maclab";
          username = "nick";
          roles = [ "lab" ];
          modules = [ ./systems/profiles/darwin-maclab.nix ];
          homeModules = [ ./homes/home-maclab.nix ];
        };
      };

      nixosConfigurations = {
        "supermicro" = builders.mkNixOSSystem {
          system = "x86_64-linux";
          hostname = "supermicro";
          username = "nick";
          roles = [ "server" ];
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
          darwinNames = builtins.filter (n: n != "maclab") (builtins.attrNames self.darwinConfigurations);
          forceDarwinScript =
            name:
            builtins.stringLength self.darwinConfigurations.${name}.config.system.activationScripts.script.text;
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
