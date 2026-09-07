{ pkgs-unstable, ... }:
{
  programs.omniwm = {
    enable = true;
    package = pkgs-unstable.omniwm;
    settings = ./dotfiles/omniwm-settings.toml;
  };
}
