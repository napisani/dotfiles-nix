{ pkgs, pkgs-unstable, procmux, secret_inject, ... }: {
  home.packages = with pkgs-unstable; [
    bashInteractive
    bat
    coreutils
    gnupg
    gnugrep
    jq
    ripgrep
    tree
    watch
    wget
    #postman
    doppler
    bitwarden-cli
    pet
    tree-sitter
    ncdu
    git-lfs

    secret_inject.packages.${pkgs.system}.default
    #pkgs.pscale
    #pkgs.mysql80
    #pkgs.pulumi

    # for doing pretty diffs
    delta

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
