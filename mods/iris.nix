{
  config,
  inputs,
  pkgs,
  ...
}:
let
  mkForcedSym = path: {
    source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/home-manager/mods/dotfiles/${path}";
    force = true;
  };
in
{
  home.packages = [
    inputs.iris.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];

  home.file = {
    ".config/iris/config.toml" = mkForcedSym "iris/config.toml";
    ".config/iris/theme.toml" = mkForcedSym "iris/theme.toml";
  };
}
