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
      "mongodb-compass"
      "docker-desktop"
      "1password-cli"
    ];

    brews = [
      "anomalyco/tap/opencode"
      "hashicorp/tap/terraform"
    ];

    taps = [
      "hashicorp/tap"
      "anomalyco/tap"
    ];

  };
}
