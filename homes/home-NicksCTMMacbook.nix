{ inputs, lib, config, pkgs, pkgs-unstable, user, ... }: {
  home.packages = [
    pkgs-unstable.azure-cli
    pkgs.kubelogin
    pkgs-unstable.sqlcmd
    pkgs-unstable.mongosh
  ];
}
