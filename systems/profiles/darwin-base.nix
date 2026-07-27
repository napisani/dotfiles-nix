{
  config,
  pkgs,
  lib,
  ...
}:
{
  documentation.enable = false;

  programs = {
    bash = {
      enable = true;
      completion = {
        enable = true;
      };
    };
  };

  security.pam.services.sudo_local.touchIdAuth = true;

  homebrew = {
    enable = true;
    global.brewfile = true;
    onActivation = {
      upgrade = false;
      # Homebrew 5 requires --force/--force-cleanup or HOMEBREW_ASK for
      # `brew bundle install --cleanup`. nix-darwin currently emits --cleanup
      # without those flags, so keep activation non-interactive and avoid
      # cleanup during system switches.
      cleanup = "none";
      autoUpdate = false;
    };

    masApps = {
      Xcode = 497799835;
    };

    # Base casks that all Macs should have
    casks = [
      "alacritty"
      # "ungoogled-chromium"
      "bitwarden"
      "caffeine"
      # "firefox@developer-edition"
      "brave-browser"
      "tailscale-app"
      "obsidian"
      "stats"
      "karabiner-elements"
      "claude-code"
      "codex"
    ]
    # Intel Macs can't run MLX, so keep the ollama app there instead of mlx-lm.
    ++ lib.optionals pkgs.stdenv.hostPlatform.isx86_64 [ "ollama-app" ];

    # Base brews that all Macs should have
    brews = [
      # "procmux"
      "opencode"
      "rtk"
      "raine/workmux/workmux"
    ]
    # mlx-lm (headless MLX LLM server, replaces the ollama-app cask) is
    # Apple-Silicon-only, so keep it off the Intel maclab. `hf` is the
    # huggingface CLI the mlx-lm model manager uses to pre-pull models
    # (mlx-lm bundles huggingface_hub but doesn't expose its CLI on PATH).
    ++ lib.optionals pkgs.stdenv.hostPlatform.isAarch64 [
      "mlx-lm"
      "hf"
    ];

    taps = [
      # "napisani/procmux"
      # "homebrew/cask-versions"
      "mongodb/brew"
      "raine/workmux"
    ];
  };

  environment = {
    shells = [ pkgs.bash ];
    systemPackages = with pkgs; [
      bashInteractive
      coreutils
      gnugrep
    ];
  };

  fonts.packages = [
    pkgs.nerd-fonts.meslo-lg
    pkgs.nerd-fonts.jetbrains-mono
    pkgs.nerd-fonts.symbols-only
  ];

  system = {
    primaryUser = "nick";

    defaults = {
      finder = {
        AppleShowAllExtensions = true;
        _FXShowPosixPathInTitle = true;
        FXDefaultSearchScope = "SCcf";
        ShowPathbar = true;
        QuitMenuItem = true;
        ShowStatusBar = true;
      };

      NSGlobalDomain = {
        AppleShowAllExtensions = true;
        AppleInterfaceStyle = "Dark";
        "com.apple.swipescrolldirection" = false;
      };
    };

    stateVersion = 4;
  };

  nix = {
    package = pkgs.nixVersions.stable;
    extraOptions = lib.optionalString (
      config.nix.package == pkgs.nixVersions.stable
    ) "experimental-features = nix-command flakes";
    enable = true;
    gc = {
      automatic = true;
      options = "--delete-older-than 30d";
    };
  };

}
