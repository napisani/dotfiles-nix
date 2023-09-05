{ inputs, lib, config, pkgs, pkgs-unstable, user, ... }: {
  home.packages = [
    pkgs-unstable.azure-cli
  ];
}
