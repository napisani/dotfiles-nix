{ pkgs, pkgs-unstable, golang_dep, ... }:
{
  home.packages = with golang_dep; [
    go_1_22
    gofumpt
    gotools
  ];
}
