{ pkgs-unstable, ... }:
{
  programs.omniwm = {
    enable = true;
    # Only nixpkgs-unstable packages OmniWM.
    package = pkgs-unstable.omniwm;
    settings = ./dotfiles/omniwm-settings.toml;
  };
}
