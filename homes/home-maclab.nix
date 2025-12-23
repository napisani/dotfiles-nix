{ inputs, lib, config, pkgs, user, ... }: {

  home.sessionVariables = {
    MACHINE_NAME = "maclab";
    PET_ADDL_SNIPPETS = "/Users/nick/.config/pet/maclab-snippets.toml";
  };
}
