{ inputs, lib, config, pkgs, pkgs-unstable, user, ... }: {
  home.packages = [
    pkgs-unstable.mongosh
    pkgs-unstable.mongodb-tools
    pkgs-unstable.jira-cli-go
  ];

  home.sessionVariables = {
    MACHINE_NAME = "axion-mbp";
    PET_ADDL_SNIPPETS = "/Users/nick/.config/pet/axion-mbp-snippets.toml";
  };

}
