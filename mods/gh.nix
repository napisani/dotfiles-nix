{ pkgs, pkgs-unstable, ... }:
{
  programs.gh = {
    enable = true;
    extensions = [ pkgs-unstable.gh-actions-cache ];
  };
}
