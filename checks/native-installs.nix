{
  self,
  lib,
  pkgs,
}:
let
  systems =
    builtins.attrValues self.darwinConfigurations ++ builtins.attrValues self.nixosConfigurations;
  declared = builtins.fromTOML (builtins.readFile ../mods/dotfiles/mise/config.toml);
  nativeOnly = [
    "mise"
    "neovim"
    "neovim-unwrapped"
    "postgresql"
    "omniwm"
    "rtk"
    "direnv"
    "atuin"
  ];
  darwinNative = [
    "btop"
    "fff"
    "statix"
    "tmux"
    "coreutils"
    "gnugrep"
    "gnused"
    "gnumake"
    "wget"
    "tree"
    "ncdu"
    "unzip"
    "watch"
    "luajit"
    "luarocks"
    "git"
  ];
in
assert builtins.hasAttr "aqua:rtk-ai/rtk" declared.tools;
assert builtins.hasAttr "rtk:setup" declared.tasks;
assert builtins.hasAttr "aqua:neovim/neovim" declared.tools;
assert builtins.hasAttr "nvim:prepare" declared.tasks;
assert !(self.inputs ? home-manager) && !(self.inputs ? home-manager-26);
assert lib.all (
  system:
  let
    config = system.config;
    packages = map lib.getName config.environment.systemPackages;
    forbidden = nativeOnly ++ lib.optionals system.pkgs.stdenv.hostPlatform.isDarwin darwinNative;
  in
  !(config ? home-manager)
  && !lib.any (name: builtins.elem name packages) forbidden
  && lib.all (name: builtins.elem name packages) [
    "nil"
    "nixfmt"
    "nix-search-cli"
    "secret_inject"
    "proctmux"
    "stackman"
    "scute"
  ]
) systems;
pkgs.writeText "userland-boundary" "System packages belong to Nix; portable userland belongs to mise.\n"
