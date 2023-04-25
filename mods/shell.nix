{ pkgs, ... }: {
  programs.fzf = {
    enable = true;
    enableBashIntegration = true;
  };
  programs.bash = {
    enable = true;
    enableCompletion = true;
    profileExtra = builtins.readFile ./dotfiles/.bash_profile;
    historyControl = [ "erasedups" "ignoredups" ];
    historySize = 100000;
    historyFileSize = 100000;
    sessionVariables = {
      EDITOR = "vi";
      TERM="screen-256color";
      SHELL = "${pkgs.bashInteractive}/bin/bash";
      CLICOLOR = "1";
      MANPAGER = "vi +Man!";
      PAGER = "less";
      BASH_SILENCE_DEPRECATION_WARNING = "1";
    };
    shellOptions = [
      "histappend"
    ];
    shellAliases = { 
      vim = "nvim";
      vi = "nvim";
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
  programs.direnv = {
    enable = true;
    enableBashIntegration = true;
    nix-direnv.enable = true;
  };
  programs.starship = {
    enable = true;
  };
}
