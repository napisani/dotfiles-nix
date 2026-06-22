{
  config,
  pkgs,
  lib,
  ...
}:
{
  ids.gids.nixbld = 350;

  homebrew = {
    masApps = { };

    casks = [
      "slack"
      "docker-desktop"
    ];

    brews = [
      "opencode"
    ];

    taps = [ ];
  };
}