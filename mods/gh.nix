{ pkgs, pkgs-unstable, nixhub_dep, ... }: {
  programs.gh = {
    enable = true;
    extensions = [ nixhub_dep.gh-copilot ];
  };
}

