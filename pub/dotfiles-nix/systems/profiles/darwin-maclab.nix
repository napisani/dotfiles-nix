{ lib, ... }:
{
  ids.gids.nixbld = 350;

  system.activationScripts.power.text = lib.mkAfter ''
    echo "enabling Wake-on-LAN..." >&2
    pmset -a womp 1
  '';

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
