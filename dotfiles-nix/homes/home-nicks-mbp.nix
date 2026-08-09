{ inputs, lib, config, pkgs, user, ... }: {

  home.sessionVariables = {
    MACHINE_NAME = "nicks-mbp";
    PET_ADDL_SNIPPETS = "/Users/nick/.config/pet/nick-mbp-snippets.toml";
  };
}
