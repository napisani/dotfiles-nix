{ inputs, lib, config, pkgs, pkgs-unstable, user, ... }: {
  home.packages = [
    pkgs-unstable.mongosh
    pkgs-unstable.mongodb-tools
    pkgs-unstable.jira-cli-go
  ];
}
