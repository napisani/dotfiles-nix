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
      "datadog-labs/pack/pup"
      "hashicorp/tap/terraform"
    ];

    taps = [
      "anomalyco/tap"
      "datadog-labs/pack"
      "hashicorp/tap"
    ];

  };
}
