{ pkgs-unstable, ... }:
{
  programs.omniwm = {
    enable = true;
    # nixpkgs currently ships OmniWM 0.6.3, whose focused-border surface can
    # overlap the managed window. Use the 0.6.8 release, which renders the
    # border as an exterior surface below the focused window.
    package = pkgs-unstable.omniwm.overrideAttrs (_: {
      version = "0.6.8";
      src = pkgs-unstable.fetchurl {
        url = "https://github.com/BarutSRB/OmniWM/releases/download/v0.6.8/OmniWM-v0.6.8.zip";
        hash = "sha256-CCOWPIpcO96FT3/dA82MJcRCGkC9b3SETyyPfBaiZ2U=";
      };
    });
    settings = ./dotfiles/omniwm-settings.toml;
  };
}
