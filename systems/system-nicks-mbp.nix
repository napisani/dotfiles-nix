{ config, pkgs, lib, ... }: {
  homebrew = {
    masApps = {
      # "Apple Configurator" = 1037126344;
    };
    # anything installed with brew cask
    casks = [
      "slack"
      "discord"
      "skype"
      "cryptomator"
      # "nikitabobko/tap/aerospace"
      # "ghostty"
      # "diffusionbee" 
    ];
    # anything installed with brew (non-casks)
    brews = [
      "helm"
      # "procmux"
      # "mkcert"
    ];
    # any custom taps / repos
    taps = [ ];
  };
}
