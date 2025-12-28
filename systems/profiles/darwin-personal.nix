{ config, pkgs, lib, ... }: {
  homebrew = {
    masApps = { };

    casks = [ "slack" "discord" "cryptomator" "docker-desktop" "bambu-studio" ];

    brews = [ "helm" "opencode"];

    taps = [ ];
  };
}
