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

      # Loancrate work apps. tailscale-app lives in darwin-base.nix.
      "1password"
      "linear"
      "loom"
      "notion"
      "wispr-flow"
      "yubico-authenticator"
    ];

    brews = [
      "opencode"

      # Loancrate dev-environment tooling (mirrors the repo Brewfile).
      # git/jq are provided by macOS; shfmt/uv come from the nix profile,
      # so they're intentionally omitted here.
      "awscli"
      "nvm"
      # bk@3 is the real formula name; the unversioned "bk" alias breaks
      # `brew bundle check`. Requires the buildkite tap below (and a
      # one-time `brew trust buildkite/buildkite` on Homebrew 6+).
      "buildkite/buildkite/bk@3"
      "ghostscript"
      "graphicsmagick"
      # WeasyPrint's native render stack for @loancrate/pdf-render; pango
      # pulls cairo, harfbuzz, fontconfig, and freetype transitively.
      "pango"
      "poppler"
    ];

    taps = [
      "buildkite/buildkite"
    ];
  };
}