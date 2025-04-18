{ inputs, lib, config, pkgs, pkgs-unstable, user, ... }: {
  home.packages = [
    pkgs-unstable.mongosh
    pkgs-unstable.mongodb-tools
    pkgs-unstable.jira-cli-go
    (pkgs-unstable.google-cloud-sdk.withExtraComponents
      (with pkgs-unstable.google-cloud-sdk.components; [
        gke-gcloud-auth-plugin
        log-streaming
      ]))
  ];

  home.sessionVariables = {
    MACHINE_NAME = "axion-mbp";
    PET_ADDL_SNIPPETS = "/Users/nick/.config/pet/axion-mbp-snippets.toml";
  };

  # home.packages = with pkgs;
  #   [
  #     vi-mongo
  #     # my-scripts
  #   ];
}

