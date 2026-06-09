# opencode.nix — Declarative OpenCode (~/.config/opencode) layout:
#
# - Dotfiles: config, commands, agents, modes, themes → symlinks into mods/dotfiles (edit without rebuild).
# - plugins/: symlinked repo files.
# - skills:
#   - local/       → symlink mods/dotfiles/opencode/local-skills (your custom opencode skills)
#   - community skills (from git repos) → managed in mods/agents.nix (shared with all agents)
{
  config,
  lib,
  pkgs-unstable,
  ...
}:
let
  mkSym =
    path:
    config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/.config/home-manager/mods/dotfiles/${path}";
  mkForcedSym = path: {
    source = mkSym path;
    force = true;
  };

  nodeBin = "${pkgs-unstable.nodejs}/bin";
  gitBin = "${pkgs-unstable.git}/bin";
in
{
  home = {
    activation = {
      # plugins/skills must be directories; broken symlinks slip past `test -e`.
      fixOpencodePathConflicts = lib.hm.dag.entryBefore [ "linkGeneration" ] ''
        for p in "$HOME/.config/opencode/plugin" "$HOME/.config/opencode/plugins" "$HOME/.config/opencode/skills"; do
          if [ -L "$p" ] || { [ -e "$p" ] && [ ! -d "$p" ]; }; then
            echo "home-manager: removing stale path at $p (OpenCode expects a directory here)"
            rm -rf "$p"
          fi
        done

        # OpenCode's current plugin directory is plural (`plugins/`). Remove the
        # old singular workmux symlink so the status plugin is not loaded twice.
        _stale_workmux_plugin="$HOME/.config/opencode/plugin/workmux-status.ts"
        if [ -L "$_stale_workmux_plugin" ]; then
          rm -f "$_stale_workmux_plugin"
          rmdir "$HOME/.config/opencode/plugin" 2>/dev/null || true
        fi
      '';
    };

    file = {
      ".config/opencode/config.json" = mkForcedSym "opencode-config.json";
      ".config/opencode/commands" = mkForcedSym "opencode/commands";
      ".config/opencode/agents" = mkForcedSym "opencode/agents";
      ".config/opencode/modes" = mkForcedSym "opencode/modes";
      ".config/opencode/themes" = mkForcedSym "opencode/themes";

      ".config/opencode/plugins/tmux-status.ts" = mkForcedSym "opencode/plugins/tmux-status.ts";
      ".config/opencode/plugins/workmux-status.ts" = mkForcedSym "opencode/plugins/workmux-status.ts";

      ".config/opencode/skills/local" = mkForcedSym "opencode/local-skills";
    };
  };
}
