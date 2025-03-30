{ pkgs, pkgs-unstable, procmux, secret_inject, ... }:
let
  kubekill = pkgs.writeScriptBin "killkube.sh" ''
    #!/usr/bin/env bash
    kubectl delete deployment postgres -n home 
    kubectl delete deployment pgvector -n home
    kubectl delete deployment mongo -n home
  '';
in {
  environment.systemPackages = with pkgs; [ tmux unzip wget kubectl kubekill inotify-tools ];

}
