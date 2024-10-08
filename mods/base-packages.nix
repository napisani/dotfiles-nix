{ pkgs, pkgs-unstable, procmux, secret_inject, animal_rescue, ... }: {

  home.packages = with pkgs-unstable; [
    pkgs.bashInteractive
    bat
    coreutils
    gnupg
    gnugrep
    gnumake
    jq
    ripgrep
    tree
    watch
    wget
    #postman
    doppler
    pkgs.bitwarden-cli
    pet
    tree-sitter
    ncdu
    git-lfs
    discordo

    secret_inject.packages.${pkgs.system}.default
    animal_rescue.packages.${pkgs.system}.default
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
    rye

    #pkgs-unstable.python310Packages.tiktoken
    # custom_node_packages.opencommit

  ];

}
