{ inputs, lib, config, pkgs, pkgs-unstable, user, ... }: {

  home.sessionVariables = {
    MACHINE_NAME = "maclab";
    PET_ADDL_SNIPPETS = "/Users/nick/.config/pet/maclab-snippets.toml";
  };

  # maclab's pkgs-unstable is the 26.05 stack, whose rtk 0.41.0 rejects
  # `--no-trust-filters` and `--agent pi`. nixpkgs-unstable no longer supports
  # x86_64-darwin, so build its newer rtk expression against the 26.05 package set.
  agents.rtkPackage = lib.mkForce (pkgs-unstable.callPackage
    "${inputs.nixpkgs-unstable}/pkgs/by-name/rt/rtk/package.nix" { });
}
