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
      # vi = "nvim";
      grep = "grep --color=auto";
      fgrep = "fgrep --color=auto";
      egrep = "egrep --color=auto";
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
  programs.gh = { enable = true; };

  home.file.".tmux/tokyonight.tmuxtheme".source =
    ./dotfiles/tokyonight.tmuxtheme;
  home.file.".tmux/plugins/tpm".source = pkgs.fetchFromGitHub {
    owner = "tmux-plugins";
    repo = "tpm";
    rev = "99469c4a9b1ccf77fade25842dc7bafbc8ce9946";
    sha256 = "hW8mfwB8F9ZkTQ72WQp/1fy8KL1IIYMZBtZYIwZdMQc=";
  };

  home.file.".config/discordo/config.toml".source =
    ./dotfiles/discordo-config.toml;

  home.file."/Library/Application Support/discordo/config.toml".source =
    ./dotfiles/discordo-config.toml;

  programs.direnv = {
    enable = true;
    enableBashIntegration = true;
    nix-direnv.enable = true;
  };
  programs.starship = { enable = true; };

  home.file.".config/starship.toml".source = ./dotfiles/starship.toml;
  home.file.".config/.secret_inject.json".source =
    ./dotfiles/secret_inject.json;
}
