{ pkgs, ... }: {
  programs.neovim = {
    enable = true;
    viAlias = false;
    vimAlias = true;
    withNodeJs = false;
    withPython3 = true;
    extraPackages = with pkgs; [
        nodejs-16_x
        # js
        nodePackages.typescript
        nodePackages.typescript-language-server
        nodePackages.eslint_d
        nodePackages.prettier
        # vuejs
        nodePackages.vls
        # nodePackages."@volar/vue-language-server"

        # html/css/js
        nodePackages.vscode-langservers-extracted

        # python
        nodePackages.pyright


        nodePackages."@tailwindcss/language-server"
        nodePackages.cspell

        # python
        python3Packages.isort
        nodePackages.pyright
        black
        python3Packages.flake8
        mypy

        #rust
        rustc 
        cargo 
        rustfmt 
        rustPackages.clippy
        rust-analyzer 

        # Nix
        deadnix
        statix
        nil
        nixpkgs-fmt
      ];
  };
  home.file.".config/nvim".source = ./dotfiles/nvim;
}

