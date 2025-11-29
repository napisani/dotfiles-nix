{ config, pkgs, lib, ... }: {
  documentation.enable = false;
  
  programs = {
    bash = {
      enable = true;
      completion = { enable = true; };
    };
  };

  security.pam.services.sudo_local.touchIdAuth = true;

  system.primaryUser = "nick";

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
      "alacritty"
      "ungoogled-chromium"
      "bitwarden"
      "caffeine"
      "firefox@developer-edition"
      "tailscale-app"
      "obsidian"
      "stats"
      "rectangle"
      "karabiner-elements"
      "alt-tab"
    ];
    
    # Base brews that all Macs should have
    brews = [
      "procmux"
      "sst/tap/opencode"
    ];
    
    taps = [ "napisani/procmux" "homebrew/cask-versions" "mongodb/brew" ];
  };
  
  environment = {
    shells = [ pkgs.bash ];
    systemPackages = with pkgs; [ bashInteractive coreutils gnugrep ];
  };

  fonts.packages = [
    pkgs.nerd-fonts.meslo-lg
    pkgs.nerd-fonts.jetbrains-mono
    pkgs.nerd-fonts.symbols-only
  ];
  
  system.defaults = {
    finder.AppleShowAllExtensions = true;
    finder._FXShowPosixPathInTitle = true;
    finder.FXDefaultSearchScope = "SCcf";
    finder.ShowPathbar = true;
    finder.QuitMenuItem = true;
    finder.ShowStatusBar = true;
    
    NSGlobalDomain.AppleShowAllExtensions = true;
    NSGlobalDomain.AppleInterfaceStyle = "Dark";
    NSGlobalDomain."com.apple.swipescrolldirection" = false;
  };
  
  nix = {
    package = pkgs.nixVersions.stable;
    extraOptions =
      lib.optionalString (config.nix.package == pkgs.nixVersions.stable)
      "experimental-features = nix-command flakes";
    enable = true;
    gc = {
      automatic = true;
      options = "--delete-older-than 30d";
    };
  };
  
  system.stateVersion = 4;
}
