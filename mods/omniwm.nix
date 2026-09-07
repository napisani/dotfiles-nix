{ pkgs-unstable, ... }:
{
  programs.omniwm = {
    enable = true;
    package = pkgs-unstable.omniwm;
    settings = {
      general.ipcEnabled = true;
    };
  };
}
