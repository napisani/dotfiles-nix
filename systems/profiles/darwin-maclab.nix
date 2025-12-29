{ config, pkgs, lib, ... }: {
  ids.gids.nixbld = 350;

  homebrew = {
    masApps = { };

    casks = [
      "slack"
      "discord"
      "cryptomator"
      "docker-desktop"
      "bambu-studio"
      "bluebubbles"
    ];

    brews = [
      "helm"

    ];

    taps = [ ];
  };
}
