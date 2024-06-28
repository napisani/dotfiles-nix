{ pkgs, pkgs-unstable, nixhub_dep, ... }: {
  programs.gh = {
    enable = true;
    extensions = [ nixhub_dep.gh-copilot nixhub_dep.gh-actions-cache ];
  };
}

