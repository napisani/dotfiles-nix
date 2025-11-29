{ config, pkgs, lib, ... }: {
  homebrew = {
    masApps = {};
    
    casks = [
      "slack"
      "discord"
      "skype"
      "cryptomator"
      "docker-desktop"
    ];
    
    brews = [
      "helm"
    ];
    
    taps = [];
  };
}
