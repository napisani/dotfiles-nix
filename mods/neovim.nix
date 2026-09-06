{
  pkgs,
  pkgs-unstable,
  config,
  homeManagerRelPath,
  ...
}:
let
  langPackages = import ./languages/all.nix { inherit pkgs pkgs-unstable; };
in
{
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    package = pkgs-unstable.neovim-unwrapped;
    #package = pkgs-unstable.neovim-unwrapped;
    sideloadInitLua = true;
    viAlias = false;
    vimAlias = true;
    withNodeJs = false;
    withPython3 = true;
    extraPackages = with pkgs-unstable; langPackages ++ [ ];
    withRuby = true;
  };
  # Vocal only needs Python + requests. Home Manager owns this immutable
  # runtime link; no mutable venv, pip install, or reconciliation state.
  nativeManagedFiles = [ ".local/share/nvim/vocal-python" ];
  home.file.".local/share/nvim/vocal-python".source = pkgs.python3.withPackages (ps: [ ps.requests ]);

  # home.file.".config/nvim".source = config.lib.file.mkOutOfStoreSymlink ./dotfiles/nvim;

  # xdg.configFile.nvim = {
  # source = ./dotfiles/nvim;
  # recursive = true;
  # };
  xdg.configFile = {
    "nvim" = {
      source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/${homeManagerRelPath}/mods/dotfiles/nvim";
      recursive = true;
    };
  };
}
