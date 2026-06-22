{
  config,
  pkgs,
  lib,
  ...
}:
{
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