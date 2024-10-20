{ pkgs, pkgs-unstable, ... }:
with pkgs-unstable; [

  # efm langserver
  efm-langserver
  nodePackages.cspell

  # for doing pretty diffs
  delta
]

