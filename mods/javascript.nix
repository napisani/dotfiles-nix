{ pkgs, pkgs-unstable, ... }:

let
  # npmjs deps that are not available in `nodePackages` (yet)
  customNodePackages = pkgs.callPackage ../packages/node/default.nix {
    nodejs = pkgs-unstable.nodejs_20;
  };
in {
  home.packages = with pkgs; [
    pkgs-unstable.nodejs_20
    nodePackages_latest.typescript
    nodePackages_latest.eslint_d
    nodePackages.cspell
    nodePackages_latest.pnpm
    customNodePackages.aicommits
  ];
}
