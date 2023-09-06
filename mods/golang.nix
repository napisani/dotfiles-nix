{ pkgs, pkgs-unstable, ... }:
{
  home.packages = with pkgs-unstable; [
    go
    gofumpt
    gotools
  ];
}
