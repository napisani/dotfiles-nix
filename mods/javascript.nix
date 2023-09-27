{ pkgs, pkgs-unstable, ... }:
{
  home.packages = with pkgs; [
    pkgs-unstable.nodejs_20
    nodePackages_latest.typescript
    nodePackages_latest.eslint_d
    nodePackages.cspell
    nodePackages_latest.pnpm
  ];
}
