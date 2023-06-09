{ pkgs, pkgs-unstable, procmux, ... }:
{
  home.packages = [
    pkgs.bashInteractive
    pkgs.bat
    pkgs.coreutils
    pkgs.gnupg
    pkgs.gnugrep
    pkgs.jq
    pkgs.ripgrep
    pkgs.tree
    pkgs.watch
    pkgs.wget
    pkgs.postman
    pkgs-unstable.doppler
    pkgs.bitwarden-cli
    pkgs.pet
    pkgs.tree-sitter
    pkgs.gh
    pkgs.ncdu
    procmux.packages.${pkgs.system}.default

    (pkgs.python310.withPackages (p: [
      p.ipython # interactive shell
      p.pipx
    ]))
  ];
}
