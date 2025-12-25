{ config, pkgs, lib, ... }: {
  homebrew = {
    masApps = { };

    casks = [ "slack" "discord" "cryptomator" "docker-desktop" ];

    brews = [ "helm" ];

    taps = [ ];
  };
}
