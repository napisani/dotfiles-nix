{ pkgs, pkgs-unstable, procmux, secret_inject, ... }: {
  environment.systemPackages = with pkgs; [
    tmux
    unzip
    wget
  ];

}
