{ config, pkgs, lib, ... }: {
  homebrew = {
    masApps = {};
    
    casks = [
      "slack"
      "mongodb-compass"
    ];
    
    brews = [];
    
    taps = [];
  };
}
