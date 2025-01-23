{ pkgs, pkgs-unstable,  config, ... }:
let langPackages = import ./languages/all.nix { inherit pkgs pkgs-unstable; };
in {
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    package = pkgs-unstable.neovim-unwrapped;
    #package = pkgs-unstable.neovim-unwrapped;
    viAlias = false;
    vimAlias = true;
    withNodeJs = false;
    withPython3 = true;
    extraPackages = with pkgs-unstable; langPackages ++ [ ];
  };
  # home.file.".config/nvim".source = config.lib.file.mkOutOfStoreSymlink ./dotfiles/nvim;

  # xdg.configFile.nvim = {
  # source = ./dotfiles/nvim;
  # recursive = true;
  # };
  xdg.configFile = {
    "nvim" = {
      source = config.lib.file.mkOutOfStoreSymlink
        "${config.home.homeDirectory}/.config/home-manager/mods/dotfiles/nvim";
      recursive = true;
    };
  };
}

