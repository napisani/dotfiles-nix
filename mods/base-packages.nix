{ pkgs, pkgs-unstable, procmux, secret_inject, ... }:
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
    #pkgs.postman
    pkgs-unstable.doppler
    pkgs.bitwarden-cli
    pkgs.pet
    pkgs.tree-sitter
    pkgs.ncdu
    pkgs.git-lfs

    secret_inject.packages.${pkgs.system}.default
    #pkgs.pscale
    #pkgs.mysql80
    #pkgs.pulumi


    # for doing pretty diffs
    pkgs.delta

    # for personal dashboards
    # pkgs.wtf
    # pkgs-unstable.nodePackages."node-inspector"

    procmux.packages.${pkgs.system}.default
    (pkgs-unstable.python310.withPackages (p: [
      p.ipython # interactive shell
      p.pipx
      # p.tiktoken
    ]))
    #pkgs-unstable.python310Packages.tiktoken
  ];
}
