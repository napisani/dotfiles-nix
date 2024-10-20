{ pkgs, pkgs-unstable, ... }:
with pkgs-unstable; [
  # lua
  stylua
  luarocks
  luajit
]

