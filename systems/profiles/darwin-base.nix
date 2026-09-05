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
      "look"
    ];

    # Base brews that all Macs should have
    brews = [
      # "procmux"
      "opencode"
      "rtk"
      "raine/workmux/workmux"
      "ollama"
    ];

    taps = [
      # "napisani/procmux"
      # "homebrew/cask-versions"
      "kunkka19xx/tap"
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

  system.activationScripts.postActivation.text = lib.mkAfter ''
    # Disable Spotlight Cmd+Space (64) and Cmd+Option+Space (65)
    # so they don't conflict with app launchers (e.g. Look, Alfred, Raycast).
    USER_HOME="$(dscl . -read /Users/${config.system.primaryUser} NFSHomeDirectory | awk '{print $2}')"
    /usr/bin/plutil -replace AppleSymbolicHotKeys.64.enabled -bool NO \
      "$USER_HOME/Library/Preferences/com.apple.symbolichotkeys.plist" 2>/dev/null || true
    /usr/bin/plutil -replace AppleSymbolicHotKeys.65.enabled -bool NO \
      "$USER_HOME/Library/Preferences/com.apple.symbolichotkeys.plist" 2>/dev/null || true
  '';

  system = {
    primaryUser = "nick";

    defaults = {
      finder = {
        AppleShowAllExtensions = true;
        AppleShowAllFiles = true;
        _FXShowPosixPathInTitle = true;
        _FXSortFoldersFirst = true;
        FXDefaultSearchScope = "SCcf";
        FXPreferredViewStyle = "clmv";
        FXRemoveOldTrashItems = true;
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
