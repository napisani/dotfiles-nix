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
    caskArgs.no_quarantine = true;
    global.brewfile = true;
    onActivation = {
      upgrade = false;
      cleanup = "zap";
      autoUpdate = false;
    };

    masApps = {
      Xcode = 497799835;
    };

    # Base casks that all Macs should have
    casks = [
      "ollama-app"
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
    ];

    # Base brews that all Macs should have
    brews = [
      # "procmux"
      "koekeishiya/formulae/yabai"
      "opencode"
    ];

    taps = [
      # "napisani/procmux"
      # "homebrew/cask-versions"
      "mongodb/brew"
      "koekeishiya/formulae"
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
