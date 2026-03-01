{ pkgs, config, ... }:
let
  mkSym =
    path:
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/home-manager/mods/dotfiles/${path}";
  mkForcedSym = path: {
    source = mkSym path;
    force = true;
  };
in
{
  programs = {
    fzf = {
      enable = true;
      enableBashIntegration = true;
    };
    atuin = {
      enable = true;
      settings = {
        style = "compact";
        sync_address = "https://atuin.napisani.xyz";
      };
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
    # tmux = {
    #   enable = true;
    #   terminal = "xterm-256color";
    #   secureSocket = false;
    #   # extraConfig = builtins.readFile ./dotfiles/.tmux.conf;
    # };
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
    ".aider.conf.yml".source = ./dotfiles/aider.conf.yml;
    ".config/mcphub/servers.json" = mkForcedSym "mcphub-servers.json";
    ".aerospace.toml" = mkForcedSym ".aerospace.toml";
    "Library/Application Support/com.mitchellh.ghostty/config" = mkForcedSym "ghostty-config";
    "global_python_scripts" = mkForcedSym "global_python_scripts";
    "shell_scripts" = mkForcedSym "shell_scripts";
    ".config/tmux/tmux.conf" = mkForcedSym ".tmux.conf";
    ".config/scute/config.yaml" = mkForcedSym "scute.yml";

    ".config/opencode/config.json" = mkForcedSym "opencode-config.json";
    ".config/opencode/commands" = mkForcedSym "opencode/commands";
    ".config/opencode/agents" = mkForcedSym "opencode/agents";
    ".config/opencode/modes" = mkForcedSym "opencode/modes";
    ".config/opencode/plugins" = mkForcedSym "opencode/plugins";
    ".config/opencode/themes" = mkForcedSym "opencode/themes";
    ".config/opencode/skills" = mkForcedSym "opencode/skills";

    ".opencode/agents" = mkForcedSym "opencode/agents";
    ".opencode/commands" = mkForcedSym "opencode/commands";
    ".opencode/modes" = mkForcedSym "opencode/modes";
    ".opencode/plugins" = mkForcedSym "opencode/plugins";
    ".opencode/themes" = mkForcedSym "opencode/themes";
    ".opencode/skills" = mkForcedSym "opencode/skills";

    ".config/karabiner/karabiner.json" = mkForcedSym "karabiner.json";

    ".yabairc" = {
      source = ./dotfiles/yabairc;
      executable = true;
    };

    ".config/rift/config.toml" = mkForcedSym "riftrc";
    ".config/alacritty/alacritty.toml" = mkForcedSym "alacritty.toml";

    ".aider.model.settings.yml".source = ./dotfiles/aider.model.settings.yml;
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
    "/Library/Application Support/discordo/config.toml".source = ./dotfiles/discordo-config.toml;
    ".config/starship.toml".source = ./dotfiles/starship.toml;
    ".config/.secret_inject.json".source =
      let
        machineName = config.home.sessionVariables.MACHINE_NAME or "";
        secretFile =
          if machineName == "axion-mbp" then
            ./dotfiles/axion_secret_inject.json
          else
            ./dotfiles/personal_secret_inject.json;
      in
      secretFile;
  };

  # this is a cross-shell way to add to PATH
  # but because of brew using shellenv being called in the
  # .bashrc we can't use this to add to the PATH (it gets overwritten)
  # home.sessionPath = [
  #   # this supports `uv tool install <x>`
  #   "${config.home.homeDirectory}/.local/bin"
  #   "${config.home.homeDirectory}/shell_scripts"
  # ];
}
