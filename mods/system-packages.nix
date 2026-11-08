{ pkgs, ... }:
let
  kubekill = pkgs.writeScriptBin "killkube.sh" ''
    #!/usr/bin/env bash
    kubectl delete deployment postgres -n home 
    kubectl delete deployment pgvector -n home
    kubectl delete deployment mongo -n home
  '';
in
{
  environment.systemPackages = with pkgs; [
    tmux
    coreutils
    gnugrep
    gnused
    gnumake
    tree
    ncdu
    gnupg
    unzip
    wget
    watch
    luajit
    luarocks
    bash-completion
    git
    gcc
    kubectl
    kubekill
    # for fixing the backup disk occasionally
    hfsprogs
    restic
    nfs-utils # mount/umount NFS shares for restic backup
  ];

}
