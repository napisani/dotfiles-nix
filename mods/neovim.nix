{ pkgs, pkgs-unstable, oxlint_dep, neovim_dep, config, ... }: {
  programs.neovim = {
    enable = true;
    defaultEditor = true;
    package = neovim_dep.neovim-unwrapped;
    #package = pkgs-unstable.neovim-unwrapped;
    viAlias = false;
    vimAlias = true;
    withNodeJs = false;
    withPython3 = true;
    extraPackages = with pkgs-unstable; [

      pkgs-unstable.nodejs_20

      # js
      nodePackages.typescript
      nodePackages.typescript-language-server
      nodePackages.eslint_d
      nodePackages.prettier
      oxlint_dep.oxlint

      # vuejs
      nodePackages.vls

      # html/css/js
      nodePackages.vscode-langservers-extracted

      # efm langserver
      efm-langserver

      nodePackages."@tailwindcss/language-server"

      nodePackages.cspell

      # python
      python3Packages.isort
      nodePackages.pyright
      black
      python3Packages.flake8
      mypy
      pkgs-unstable.ruff
      yapf

      # json
      nodePackages.fixjson
      jq

      # yaml 
      yq

      # lua
      stylua

      # Nix
      statix
      nixfmt
      nil

      # bash
      shellcheck
      shfmt

      delta
    ];
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

