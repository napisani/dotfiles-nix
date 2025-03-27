{ config, pkgs, lib, ... }: {
  # as of 2025-03-26 karabiner-elements version 15 is not working correctly with nix-darwin 
  # this overlay is a workaround to use version 14.13.0, it can be removed once version 15 is working
  # https://github.com/LnL7/nix-darwin/issues/1041
  nixpkgs.overlays = [
    (self: super: {
      karabiner-elements = super.karabiner-elements.overrideAttrs (old: {
        version = "14.13.0";

        src = super.fetchurl {
          inherit (old.src) url;
          hash = "sha256-gmJwoht/Tfm5qMecmq1N6PSAIfWOqsvuHU8VDJY8bLw=";
        };
      });
    })
  ];

  documentation.enable = false;
  programs = {
    bash = {
      enable = true;
      completion = { enable = true; };
    };
  };

  security.pam.enableSudoTouchIdAuth = true;
  services = {
    nix-daemon.enable = true;
    karabiner-elements.enable = true;
  };

  homebrew = {
    enable = true;
    caskArgs.no_quarantine = true;
    global.brewfile = true;
    onActivation = {
      upgrade = true;
      cleanup = "zap";
      autoUpdate = true;
    };
    # app store apps
    masApps = {
      Xcode = 497799835;
      # magnet = 441258766;
      # "Apple Configurator" = 1037126344;
    };
    # anything installed with brew cask
    casks = [
      "eloston-chromium"
      "bitwarden"
      "caffeine"
      "docker"
      "github"
      "lulu"
      "firefox@developer-edition"
      "tailscale"
      "obsidian"
      "stats"
    ];
    # anything installed with brew (non-casks)
    brews = [
      # "mongodb-community"
      "procmux"
      # "mkcert"
      "mongodb-atlas-cli"
    ];
    # any custom taps / repos
    taps = [ "napisani/procmux" "homebrew/cask-versions" "mongodb/brew" ];
  };
  environment = {
    shells = [ pkgs.bash ];
    # loginShell = pkgs.bash;
    systemPackages = with pkgs; [ bashInteractive coreutils gnugrep ];
  };
  # fonts.fontDir.enable = true; # DANGER
  fonts.packages = [
    (pkgs.nerdfonts.override {
      fonts = [ "Meslo" "JetBrainsMono" "NerdFontsSymbolsOnly" ];
    })
  ];

  system.defaults = {
    finder.AppleShowAllExtensions = true;
    finder._FXShowPosixPathInTitle = true;
    # When performing a search, search the current folder by default
    finder.FXDefaultSearchScope = "SCcf";
    #NSGlobalDomain.WebKitDeveloperExtras = true;
    NSGlobalDomain.AppleShowAllExtensions = true;
    NSGlobalDomain.AppleInterfaceStyle = "Dark";
    NSGlobalDomain."com.apple.swipescrolldirection" = false;
    finder.ShowPathbar = true;
    finder.QuitMenuItem = true;
    finder.ShowStatusBar = true;
    #trackpad.Clicking = true;
    #"com.apple.screencapture" = {
    #  location = "~/Desktop";
    #  type = "png";
    #};
  };
  nix = {
    package = pkgs.nixVersions.stable;
    extraOptions =
      lib.optionalString (config.nix.package == pkgs.nixVersions.stable)
      "experimental-features = nix-command flakes";
  };
  system = {
    # dock = {
    # autohide = true;
    # };
    stateVersion = 4;
  };

  # users = {
  # users.${user} = {
  # home = /Users/${user};
  # };
  # };

}
