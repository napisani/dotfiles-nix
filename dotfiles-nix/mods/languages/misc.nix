{ pkgs, pkgs-unstable, ... }:
with pkgs-unstable;
[

  # efm langserver
  efm-langserver
  cspell

  # for doing pretty diffs
  delta
]
