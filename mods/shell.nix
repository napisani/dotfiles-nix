{
  pkgs,
  pkgs-unstable,
  config,
  lib,
  homeManagerRelPath,
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
  mkShellSym = path: mkSym "shell/${path}";
  mkShellFile = path: {
    source = mkShellSym path;
    force = true;
  };
in
{
  home = {
    # ── packages ────────────────────────────────────────────────────────────
    # Keep packages explicit instead of enabling Home Manager program modules
    # that would also generate configuration and shell init we own natively.
    #
    # bash-completion is here for a non-obvious reason:
    # `programs.bash.enableCompletion` sourced it straight out of /nix/store
    # without ever adding it to the user profile, so nothing else puts a
    # bash_completion.sh in a profile path our shell config can find.
    # bash/rc.d/20-bash-completion.sh probes the profile path.
    packages = with pkgs-unstable; [
      atuin
      bash-completion
      blesh
      fzf
      gh
      starship
    ];

    # Shell configuration is linked directly from the checkout. Home Manager
    # owns link reconciliation; mkOutOfStoreSymlink keeps edits live without a
    # rebuild.
    file = {
      ".bashrc" = mkShellFile "bash/bashrc";
      ".bash_profile" = mkShellFile "bash/bash_profile";
      ".profile" = mkShellFile "bash/profile";
      ".inputrc" = mkShellFile "inputrc";
      ".config/shell" = mkForcedSym "shell";
      ".config/atuin/config.toml" = mkShellFile "atuin/config.toml";
      ".config/gh/config.yml" = mkShellFile "gh/config.yml";
      ".config/git/config" = mkShellFile "git/config";
      ".config/git/ignore" = mkShellFile "git/ignore";
      ".config/git/local-include" = mkShellFile "git/local-include";

      # gh-stack is a package, so nix keeps installing it. This replaces
      # `programs.gh.extensions`, which can't be used without also letting the
      # gh module own ~/.config/gh/config.yml — and that file is native now.
      # gh expects <extensions>/<name>/ to contain the executable.
      ".local/share/gh/extensions/gh-stack".source = "${pkgs-unstable.gh-stack}/bin";

      ".config/pet".source = ./dotfiles/pet;
      ".config/mcphub/servers.json" = mkForcedSym "mcphub-servers.json";
      ".aerospace.toml" = mkForcedSym ".aerospace.toml";
      "Library/Application Support/com.mitchellh.ghostty/config" = mkForcedSym "ghostty-config";
      "toolbox" = mkForcedSym "toolbox";
      "shell_scripts" = mkForcedSym "shell_scripts";
      ".config/tmux/tmux.conf" = mkForcedSym ".tmux.conf";
      ".config/karabiner/karabiner.json" = mkForcedSym "karabiner.json";

      # Frequently edited user-facing config stays live-editable.
      ".yabairc".source = mkSym "yabairc";

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

      ".ideavimrc".source = mkSym ".ideavimrc";
      ".tmux/tokyonight.tmuxtheme".source = ./dotfiles/tokyonight.tmuxtheme;
      ".tmux/plugins/tpm".source = pkgs.fetchFromGitHub {
        owner = "tmux-plugins";
        repo = "tpm";
        rev = "99469c4a9b1ccf77fade25842dc7bafbc8ce9946";
        sha256 = "hW8mfwB8F9ZkTQ72WQp/1fy8KL1IIYMZBtZYIwZdMQc=";
      };
      ".config/discordo/config.toml".source = ./dotfiles/discordo-config.toml;
      "/Library/Application Support/discordo/config.toml".source = ./dotfiles/discordo-config.toml;
      ".config/starship.toml".source = mkSym "starship.toml";
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

    # The previous rc.d generated this completion once and then sourced it
    # forever, so upgrades left a stale user-local file shadowing mise's
    # version-matched package completion. Remove only that recognizable legacy
    # artifact; bash-completion will lazy-load the packaged mise.bash instead.
    activation.removeLegacyMiseCompletion = lib.hm.dag.entryAfter [ "linkGeneration" ] ''
      _legacy_mise_completion="$HOME/.local/share/bash-completion/completions/mise"
      if [ -f "$_legacy_mise_completion" ] && [ ! -L "$_legacy_mise_completion" ] \
        && grep -q '^# @generated by usage-cli' "$_legacy_mise_completion" \
        && grep -q '^_mise()' "$_legacy_mise_completion"; then
        rm -f "$_legacy_mise_completion"
      fi
      unset _legacy_mise_completion
    '';
  };

  # direnv stays a nix `programs.*` on purpose, and only for nix-direnv: the
  # library it installs at ~/.config/direnv/lib/hm-nix-direnv.sh is nix-specific
  # by definition, and direnv loads it from that directory with no shell wiring.
  # The bash hook itself is ours (bash/rc.d/79-direnv.sh), hence
  # enableBashIntegration = false.
  programs.direnv = {
    enable = true;
    enableBashIntegration = false;
    nix-direnv.enable = true;
  };

  # Owning fzf init natively also removes the previous Home Manager version
  # divergence: maclab's older module lacked `programs.fzf.historyWidget`, so
  # atuin could not reliably own Ctrl-R there.

  # this is a cross-shell way to add to PATH
  # but because of brew using shellenv being called in the
  # profile we can't use this to add to the PATH (it gets overwritten)
  # home.sessionPath = [
  #   # this supports `uv tool install <x>`
  #   "${config.home.homeDirectory}/.local/bin"
  #   "${config.home.homeDirectory}/shell_scripts"
  # ];
}
