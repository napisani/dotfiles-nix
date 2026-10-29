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
      "ngrok"
      # Deprecated upstream: Homebrew disables it 2027-07-12 and points to the
      # `chatgpt` cask. The Codex CLI cask lives in darwin-base.nix.
      "codex-app"
      "chatgpt"

      # AWS Session Manager plugin for the AWS CLI. It's a cask, not a
      # formula — homebrew/core has no session-manager-plugin, so listing it
      # under brews fails `brew bundle` with "No formulae found".
      "session-manager-plugin"

      # Mobile development: Android Studio plus the JDK 17 that the React
      # Native Android build expects.
      "android-studio"
      "zulu@17"
    ];

    brews = [
      "opencode"
      "actionlint"

      # Loancrate dev-environment tooling (mirrors the repo Brewfile).
      # git/jq are provided by macOS; shfmt/uv come from the nix profile,
      # so they're intentionally omitted here.
      "awscli"
      "coder"
      "nvm"
      # nixpkgs' pulumi only ships the bare CLI, no language plugins
      # (pulumi-language-nodejs etc.) — brew's formula bundles them.
      "pulumi"
      # bk@3 is the real formula name; the unversioned "bk" alias breaks
      # `brew bundle check`. The buildkite tap below is trusted declaratively.
      "buildkite/buildkite/bk@3"
      "ghostscript"
      "graphicsmagick"
      # WeasyPrint's native render stack for @loancrate/pdf-render; pango
      # pulls cairo, harfbuzz, fontconfig, and freetype transitively.
      "pango"
      "poppler"
      "conductorone/cone/cone"
      # iOS dependency manager for the mobile app; Xcode itself is installed
      # outside Homebrew.
      "cocoapods"
    ];

    taps = [
      {
        name = "asmvik/formulae";
        trusted = true;
      }
      {
        name = "buildkite/buildkite";
        trusted = true;
      }
      {
        name = "conductorone/cone";
        trusted = true;
      }
      {
        name = "jundot/omlx";
        trusted = true;
      }
      {
        name = "kitlangton/tap";
        trusted = true;
      }
    ];
  };
}
