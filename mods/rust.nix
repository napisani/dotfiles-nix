
{ pkgs, pkgs-unstable, ... }:
{
  home.packages = with pkgs; [
    #rust
    rustc 
    cargo 
    rustfmt 
    rustPackages.clippy
    rust-analyzer 
  ];
}
