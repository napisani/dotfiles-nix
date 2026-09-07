{ inputs, lib, config, pkgs, user, ... }: {

  imports = [ ../mods/omniwm.nix ];

  home.sessionVariables = {
    MACHINE_NAME = "nicks-mbp";
    PET_ADDL_SNIPPETS = "/Users/nick/.config/pet/nick-mbp-snippets.toml";
  };
}
