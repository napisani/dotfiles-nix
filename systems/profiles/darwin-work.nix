{ config, pkgs, lib, ... }: {
  homebrew = {
    masApps = {};
    
    casks = [
      "slack"
      "mongodb-compass"
      "docker-desktop"
    ];
    
    brews = [];
    
    taps = [];
  };
}
