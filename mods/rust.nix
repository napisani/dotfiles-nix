
{ pkgs, pkgs-unstable, ... }:
{
  home.packages = with pkgs-unstable; [
    rustc 
    cargo 
    rustfmt 
    rustPackages.clippy
    rust-analyzer 
    pkg-config
    luajit
  ];
}
