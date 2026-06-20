{
  inputs,
  lib,
  config,
  pkgs,
  user,
  ...
}: {

  home.sessionVariables = {
    MACHINE_NAME = "nicks-loancrate-mbp";
    PET_ADDL_SNIPPETS = "/Users/nick/.config/pet/loancrate-mbp-snippets.toml";
  };
}