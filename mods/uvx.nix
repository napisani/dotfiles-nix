{
  config,
  lib,
  pkgs,
  ...
}:

let
  uvxTools = [
  ];
in
{
  home.packages = [
    pkgs.uv
    pkgs.libpq
  ];

  home.activation.installUvTools = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    # Stackman graduated from toolbox/uv-tool to a first-class Nix package.
    # Prune any old uv-installed shim so ~/.local/bin cannot shadow the Nix executable.
    if ${pkgs.uv}/bin/uv tool list | ${pkgs.gnugrep}/bin/grep -q '^stackman '; then
      ${pkgs.uv}/bin/uv tool uninstall stackman || true
    fi

    # Remove the old Python picker so it cannot shadow the native Nix package.
    if ${pkgs.uv}/bin/uv tool list | ${pkgs.gnugrep}/bin/grep -q '^tmux-picker '; then
      ${pkgs.uv}/bin/uv tool uninstall tmux-picker || true
    fi

    # Install sqlit-tui with the postgres dependency
    ${pkgs.uv}/bin/uv tool install --with psycopg2-binary 'sqlit-tui[postgres]' --force

    for tool in ${builtins.concatStringsSep " " uvxTools}; do
      ${pkgs.uv}/bin/uv tool install $tool || true
    done

    # Install editable multi-module tools that still live in toolbox/.
    # Any subdirectory containing a pyproject.toml is treated as an installable tool.
    TOOLBOX="$HOME/toolbox"
    if [ -d "$TOOLBOX" ]; then
      for tool_dir in "$TOOLBOX"/*/; do
        if [ -f "''${tool_dir}pyproject.toml" ]; then
          ${pkgs.uv}/bin/uv tool install --editable "$tool_dir" || true
        fi
      done
    fi

    # Create isolated venv for vocal.nvim (needs requests for OpenAI Whisper API)
    VOCAL_VENV="$HOME/.local/share/nvim/vocal-venv"
    if [ ! -d "$VOCAL_VENV" ]; then
      ${pkgs.uv}/bin/uv venv "$VOCAL_VENV"
    fi
    ${pkgs.uv}/bin/uv pip install --python "$VOCAL_VENV/bin/python" requests
  '';
}
