{ pkgs, pkgs-unstable, config, ... }: {
  /* home.file.".config/karabiner/karabiner.json".source = ./dotfiles/karabiner.json; */
  xdg.configFile = {
    "karabiner/karabiner.json" = {
      source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/home-manager/mods/dotfiles/karabiner.json";
    };
  };
}
