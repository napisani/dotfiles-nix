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

  modelRuntimes = {
    declaredModels.ollama = [
      "qwen3:1.7b"
      "qwen3.6:35b-a3b-mxfp8"
    ];
    customModels."qwen3.6-coding" = {
      from = "qwen3.6:35b-a3b-mxfp8";
      parameters = {
        num_ctx = 16384;
        presence_penalty = 0;
        temperature = 0.7;
      };
    };
  };

  home.sessionVariables = {
    MACHINE_NAME = "nicks-loancrate-mbp";
    PET_ADDL_SNIPPETS = "/Users/nick/.config/pet/loancrate-mbp-snippets.toml";
  };
}
