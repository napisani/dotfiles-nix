{ pkgs, config, ... }: {
  programs = {
    fzf = {
      enable = true;
      enableBashIntegration = true;
    };
    bash = {
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
        grep = "grep --color=auto";
        fgrep = "fgrep --color=auto";
        egrep = "egrep --color=auto";
        ls = "ls --color";
        ll = "ls -alF";
        la = "ls -A";
        l = "ls -CF";
      };
    };
    tmux = {
      enable = true;
      terminal = "xterm-256color";
      secureSocket = false;
      extraConfig = builtins.readFile ./dotfiles/.tmux.conf;
    };
    gh.enable = true;
    direnv = {
      enable = true;
      enableBashIntegration = true;
      nix-direnv.enable = true;
    };
    starship.enable = true;
  };
  home.file = {
    ".config/pet".source = ./dotfiles/pet;
    ".aider.conf.yml".source = ./dotfiles/.aider.conf.yml;
    ".aerospace.toml".source = config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/.config/home-manager/mods/dotfiles/.aerospace.toml";
    "Library/Application Support/com.mitchellh.ghostty/config".source =
      config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/.config/home-manager/mods/dotfiles/ghostty-config";
    "global_python_scripts".source = config.lib.file.mkOutOfStoreSymlink
      "${config.home.homeDirectory}/.config/home-manager/mods/dotfiles/global_python_scripts";
    ".aider.model.settings.yml".source = ./dotfiles/.aider.model.settings.yml;
    ".bashrc.d".source = ./dotfiles/.bashrc.d;
    ".inputrc".source = ./dotfiles/.inputrc;
    ".ideavimrc".source = ./dotfiles/.ideavimrc;
    ".tmux/tokyonight.tmuxtheme".source = ./dotfiles/tokyonight.tmuxtheme;
    ".tmux/plugins/tpm".source = pkgs.fetchFromGitHub {
      owner = "tmux-plugins";
      repo = "tpm";
      rev = "99469c4a9b1ccf77fade25842dc7bafbc8ce9946";
      sha256 = "hW8mfwB8F9ZkTQ72WQp/1fy8KL1IIYMZBtZYIwZdMQc=";
    };
    ".config/discordo/config.toml".source = ./dotfiles/discordo-config.toml;
    "/Library/Application Support/discordo/config.toml".source =
      ./dotfiles/discordo-config.toml;
    ".config/starship.toml".source = ./dotfiles/starship.toml;
    ".config/.secret_inject.json".source = ./dotfiles/secret_inject.json;
  };
}

