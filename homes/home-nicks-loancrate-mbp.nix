{
  inputs,
  lib,
  config,
  pkgs,
  pkgs-unstable,
  user,
  ...
}: {

  home.packages = with pkgs-unstable; [
    postgresql
  ];

  home.sessionVariables = {
    MACHINE_NAME = "nicks-loancrate-mbp";
    PET_ADDL_SNIPPETS = "/Users/nick/.config/pet/loancrate-mbp-snippets.toml";
  };
}