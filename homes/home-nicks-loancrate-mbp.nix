{
  inputs,
  lib,
  config,
  pkgs,
  pkgs-unstable,
  user,
  ...
}:
{

  imports = [
    ./nicks-loancrate-mbp/agents.nix
    ../mods/omniwm.nix
  ];

  nativeTools.npm.extraNpmrc = "//registry.npmjs.org/:_authToken=\${NODE_AUTH_TOKEN}\n";

  home.packages = with pkgs-unstable; [
    postgresql
  ];

  home.sessionVariables = {
    MACHINE_NAME = "nicks-loancrate-mbp";
    PET_ADDL_SNIPPETS = "/Users/nick/.config/pet/loancrate-mbp-snippets.toml";
  };
}
