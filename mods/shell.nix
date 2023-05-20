{ pkgs, ... }: {
  programs.fzf = {
    enable = true;
    enableBashIntegration = true;
  };
  programs.bash = {
    enable = true;
    profileExtra = ''
      for file in ~/.bashrc.d/*.bashrc
      do
          file_only=$(basename "$file")
          if ! grep -q "$file_only" ~/.bashrc.d/excludes.txt; then
              source "$file"
          fi
      done
    '';
    shellAliases = { 
      vim = "nvim";
      /* vi = "nvim"; */
      grep = "grep --color=auto";
      fgrep = "fgrep --color=auto";
      egrep ="egrep --color=auto";
      ls = "ls --color";
      ll = "ls -alF";
      la = "ls -A";
      l = "ls -CF";
    };
  };
  home.file.".config/pet".source = ./dotfiles/pet;
  home.file.".bashrc.d".source = ./dotfiles/.bashrc.d;
  home.file.".inputrc".source = ./dotfiles/.inputrc;
  home.file.".ideavimrc".source = ./dotfiles/.ideavimrc;
  programs.tmux = {
    enable = true;
    terminal = "xterm-256color";
    secureSocket = false;
    extraConfig = builtins.readFile ./dotfiles/.tmux.conf;
  };
  home.file.".tmux/tokyonight.tmuxtheme".source = ./dotfiles/tokyonight.tmuxtheme;
  programs.direnv = {
    enable = true;
    enableBashIntegration = true;
    nix-direnv.enable = true;
  };
  programs.starship = {
    enable = true;
  };
  
  home.file.".config/starship.toml".source = ./dotfiles/starship.toml;
}
