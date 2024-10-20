{ pkgs, pkgs-unstable, ... }:
with pkgs-unstable; [
  rustc
  cargo
  rustfmt
  rustPackages.clippy
  rust-analyzer
  pkg-config
]

