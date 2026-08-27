{
  pkgs,
  config,
  lib,
  homeManagerRelPath,
  useHomeManager26 ? false,
  ...
}:
let
  mkSym =
    path:
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/${homeManagerRelPath}/mods/dotfiles/${path}";
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
      # historyWidget was added in home-manager after the 26.05 release;
      # maclab (x86_64-darwin) uses the 26.05 home-manager stack, which
      # doesn't support this option.
    }
    // lib.optionalAttrs (!useHomeManager26) {
      historyWidget.bash.command = "";
    };
    atuin = {
      enable = true;
      settings = {
        style = "compact";
        sync_address = "https://atuin.napisani.xyz";
        # Self-hosted Atuin AI server (atuin-ai-server in the home chart,
        # OpenRouter-backed). The matching api_token comes from the shared
        # Doppler key ATUIN_AI_AUTH_TOKEN (workstation_env_vars):
        # 0064_atuin_ai.bashrc maps it onto atuin's ATUIN_AI__API_TOKEN env
        # override, which sets `ai.api_token`.
        # See the kube-home-lab atuin.ts app definition for server setup.
        ai = {
          enabled = true;
          endpoint = "https://atuin-ai.napisani.xyz";
        };
      };
    };
    bash = {
      enable = true;
      bashrcExtra = ''
        for file in ~/.bashrc.d/*.bashrc
        do
            file_only=$(basename "$file")
            if ! grep -q "$file_only" ~/.bashrc.d/excludes.txt 2>/dev/null; then
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
    ".config/mcphub/servers.json" = mkForcedSym "mcphub-servers.json";
    ".aerospace.toml" = mkForcedSym ".aerospace.toml";
    "Library/Application Support/com.mitchellh.ghostty/config" = mkForcedSym "ghostty-config";
    "toolbox" = mkForcedSym "toolbox";
    "shell_scripts" = mkForcedSym "shell_scripts";
    ".config/tmux/tmux.conf" = mkForcedSym ".tmux.conf";
    ".config/karabiner/karabiner.json" = mkForcedSym "karabiner.json";

    ".yabairc" = {
      source = ./dotfiles/yabairc;
      executable = true;
    };

    ".config/rift/config.toml" = mkForcedSym "riftrc";
    ".config/alacritty/alacritty.toml" = mkForcedSym "alacritty.toml";
    ".config/scute/config.yaml" =
      let
        machineName = config.home.sessionVariables.MACHINE_NAME or "";
        scuteFile =
          if machineName == "nicks-loancrate-mbp" then
            "scute-nicks-loancrate-mbp.yml"
          else if machineName == "nicks-mbp" then
            "scute-nicks-mbp.yml"
          else if machineName == "maclab" then
            "scute-maclab.yml"
          else if machineName == "supermicro" then
            "scute-supermicro.yml"
          else
            "scute.yml";
      in
      mkForcedSym scuteFile;

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
          if machineName == "nicks-loancrate-mbp" then
            ./dotfiles/loancrate_secret_inject.json
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
