# agents/pi.nix — Pi-specific configuration
#
# Handles everything specific to the Pi agent:
#   - Extension and theme symlinking from dotfiles
#   - Pi settings (provider, model, packages, skill paths)
#   - Understand-Anything plugin clone + symlink
#   - Deduplication of skills that Pi would discover twice (global store + local)
{
  config,
  lib,
  pkgs-unstable,
  ...
}:
let
  shared = import ./lib.nix { inherit config pkgs-unstable; };
  inherit (shared) dotfiles nodeBin gitBin;

  scriptsDir = "${dotfiles}/agents/scripts";

  syncPiExtensions = ''
    _src="${dotfiles}/agents/pi/extensions"
    _dst="$HOME/.pi/agent/extensions"
    mkdir -p "$_dst"

    if [ -d "$_src" ]; then
      for _extension_file in "$_src"/*.js "$_src"/*.ts; do
        [ -f "$_extension_file" ] || continue

        _extension_name=$(basename "$_extension_file")
        case "$_extension_name" in
          *.test.*) continue ;;
        esac

        _target_link="$_dst/$_extension_name"
        if [ -e "$_target_link" ] && [ ! -L "$_target_link" ]; then
          echo "agents: refusing to replace non-symlink Pi extension at $_target_link"
          continue
        fi

        if [ ! -L "$_target_link" ] || [ "$(readlink "$_target_link")" != "$_extension_file" ]; then
          ln -sfn "$_extension_file" "$_target_link"
          echo "agents: linked Pi extension '$_extension_name' -> $_target_link"
        fi
      done
    fi
  '';

  syncPiThemes = ''
    _src="${dotfiles}/agents/pi/themes"
    _dst="$HOME/.pi/agent/themes"
    mkdir -p "$_dst"

    if [ -d "$_src" ]; then
      for _theme_file in "$_src"/*.json; do
        [ -f "$_theme_file" ] || continue

        _theme_name=$(basename "$_theme_file")
        _target_link="$_dst/$_theme_name"
        if [ -e "$_target_link" ] && [ ! -L "$_target_link" ]; then
          echo "agents: refusing to replace non-symlink Pi theme at $_target_link"
          continue
        fi

        if [ ! -L "$_target_link" ] || [ "$(readlink "$_target_link")" != "$_theme_file" ]; then
          ln -sfn "$_theme_file" "$_target_link"
          echo "agents: linked Pi theme '$_theme_name' -> $_target_link"
        fi
      done
    fi
  '';

  # Pi discovers ~/.agents/skills in addition to ~/.pi/agent/skills. Keep Pi's
  # agent-local directory for Pi-only skills, and delete duplicate entries that
  # are already available through the global store.
  removePiGlobalSkillDuplicates = ''
    if [ -d "$HOME/.agents/skills" ] && [ -d "$HOME/.pi/agent/skills" ]; then
      for _global_skill_dir in "$HOME/.agents/skills"/*/; do
        [ -d "$_global_skill_dir" ] || continue
        _skill_name=$(basename "$_global_skill_dir")
        _pi_skill="$HOME/.pi/agent/skills/$_skill_name"
        if [ -e "$_pi_skill" ] || [ -L "$_pi_skill" ]; then
          rm -rf "$_pi_skill"
          echo "agents: removed duplicate Pi skill '$_skill_name' (already in ~/.agents/skills)"
        fi
      done
    fi
  '';

  installUnderstandAnythingPlugin = ''
    _ua_repo_url="https://github.com/Lum1104/Understand-Anything.git"
    _ua_repo_dir="$HOME/.understand-anything/repo"
    _ua_plugin_root="$_ua_repo_dir/understand-anything-plugin"
    _ua_plugin_link="$HOME/.understand-anything-plugin"

    if [ -d "$_ua_repo_dir/.git" ]; then
      echo "agents: updating Understand-Anything checkout at $_ua_repo_dir"
      if ! ${gitBin}/git -C "$_ua_repo_dir" fetch --depth=1 origin main; then
        echo "agents: WARNING: failed to fetch Understand-Anything" >&2
      elif ! ${gitBin}/git -C "$_ua_repo_dir" reset --hard origin/main; then
        echo "agents: WARNING: failed to reset Understand-Anything checkout" >&2
      fi
    else
      if [ -e "$_ua_repo_dir" ] || [ -L "$_ua_repo_dir" ]; then
        echo "agents: replacing unmanaged Understand-Anything checkout at $_ua_repo_dir"
        rm -rf "$_ua_repo_dir"
      fi
      mkdir -p "$(dirname "$_ua_repo_dir")"
      echo "agents: cloning Understand-Anything -> $_ua_repo_dir"
      if ! ${gitBin}/git clone --depth=1 "$_ua_repo_url" "$_ua_repo_dir"; then
        echo "agents: WARNING: failed to clone Understand-Anything" >&2
      fi
    fi

    if [ -d "$_ua_plugin_root" ]; then
      if [ -e "$_ua_plugin_link" ] && [ ! -L "$_ua_plugin_link" ]; then
        echo "agents: replacing unmanaged Understand-Anything plugin root at $_ua_plugin_link"
        rm -rf "$_ua_plugin_link"
      fi

      if [ ! -L "$_ua_plugin_link" ] || [ "$(readlink "$_ua_plugin_link")" != "$_ua_plugin_root" ]; then
        ln -sfn "$_ua_plugin_root" "$_ua_plugin_link"
        echo "agents: linked Understand-Anything plugin root -> $_ua_plugin_link"
      fi
    else
      echo "agents: WARNING: Understand-Anything plugin root missing at $_ua_plugin_root" >&2
    fi
  '';
in
{
  home.activation.installPiConfig = lib.hm.dag.entryAfter [ "installAgentSkills" ] ''
    # ── Extensions and themes ─────────────────────────────────────────────────
    ${syncPiExtensions}
    ${syncPiThemes}

    # ── Settings (provider, model, packages, skill paths) ─────────────────────
    ${nodeBin}/node ${scriptsDir}/apply-pi-settings.js

    # ── Understand-Anything plugin (Pi-only, requires full repo clone) ─────────
    ${installUnderstandAnythingPlugin}

    # ── Deduplicate skills Pi would find in both ~/.agents/skills and ~/.pi/agent/skills
    ${removePiGlobalSkillDuplicates}
  '';
}
