{ config, pkgs, lib, ... }:
{
  programs = {
    bash = {
      enable = true;
      enableCompletion = true;
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
       magnet = 441258766;
       /* "Apple Configurator" = 1037126344; */
    };
    # anything installed with brew cask
    casks = [
      "google-chrome"
      "bitwarden"
      "caffeine"
      "docker"
    ];
    # anything installed with brew (non-casks)
    brews = [
      /* "procmux" */
      /* "mkcert" */
    ];
    # any custom taps / repos
    taps = [
        "napisani/procmux"
    ];
  };
  environment = {
    shells = [ pkgs.bash ];
    loginShell = pkgs.bash;
    systemPackages =
      with pkgs; [
      	bashInteractive
        coreutils 
        gnugrep
      ];
  };
  fonts.fontDir.enable = true; # DANGER
  fonts.fonts = [ 
  (pkgs.nerdfonts.override { fonts = [ 
    "Meslo" 
  ]; }) ];
  system.defaults = {
    finder.AppleShowAllExtensions = true;
    finder._FXShowPosixPathInTitle = true;
    NSGlobalDomain.AppleShowAllExtensions = true;
    NSGlobalDomain.AppleInterfaceStyle = "Dark";
    NSGlobalDomain."com.apple.swipescrolldirection" = false;
    finder.ShowPathbar = true;
    finder.QuitMenuItem = true;
    finder.ShowStatusBar = true;
    trackpad.Clicking = true;
  };
  nix = {
    package = pkgs.nixFlakes;
    extraOptions = lib.optionalString (config.nix.package == pkgs.nixFlakes) ''
      experimental-features = nix-command flakes
    '';
  };
  system = {
    /* dock = { */
    /*   autohide = true; */
    /* }; */
    stateVersion = 4;
  };

  /* users = { */
  /*   users.${user} = { */
  /*     home = /Users/${user}; */
  /*   }; */
  /* }; */

}
