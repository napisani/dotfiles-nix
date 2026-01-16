{
  inputs,
  lib,
  config,
  pkgs,
  pkgs-unstable,
  user,
  ...
}:
let
  gcp_sdk = pkgs-unstable.google-cloud-sdk;
  gcp_sdk_with_extras = gcp_sdk.withExtraComponents (
    with gcp_sdk.components;
    [
      gke-gcloud-auth-plugin
      log-streaming
    ]
  );
in
{
  home.packages = [
    pkgs-unstable.mongosh
    pkgs-unstable.mongodb-tools
    pkgs-unstable.postgresql_16
    gcp_sdk_with_extras
  ];

  home.sessionVariables = {
    MACHINE_NAME = "axion-mbp";
    PET_ADDL_SNIPPETS = "/Users/nick/.config/pet/axion-mbp-snippets.toml";
  };
}
