
{ pkgs, pkgs-unstable, ... }:
{
  home.packages = [
    #rust
    rustc 
    cargo 
    rustfmt 
    rustPackages.clippy
    rust-analyzer 
  ];
}
