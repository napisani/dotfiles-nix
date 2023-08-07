{ pkgs, pkgs-unstable, ... }:
{
  home.packages = with pkgs; [
    nodejs-16_x
    nodePackages_latest.typescript
    nodePackages_latest.eslint_d
    nodePackages.cspell
    nodePackages_latest.pnpm

  ];
}
