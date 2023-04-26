{ pkgs, ... }: {
  programs.fzf = {
    enable = true;
    enableBashIntegration = true;
  };
  programs.bash = {
    enable = true;
    shellAliases = { 
      /* vim = "nvim"; */
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
  programs.tmux = {
    enable = true;
    terminal = "screen-256color";
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
