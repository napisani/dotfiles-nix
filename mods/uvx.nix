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
    # Install sqlit-tui with the postgres dependency
    ${pkgs.uv}/bin/uv tool install --with psycopg2-binary 'sqlit-tui[postgres]' --force

    for tool in ${builtins.concatStringsSep " " uvxTools}; do
      ${pkgs.uv}/bin/uv tool install $tool || true
    done

    # Install editable multi-module tools from toolbox/
    # Any subdirectory containing a pyproject.toml is treated as an installable tool.
    TOOLBOX="$HOME/toolbox"
    if [ -d "$TOOLBOX" ]; then
      STACKMAN_TOOL="$TOOLBOX/stackman"
      if [ -f "$STACKMAN_TOOL/pyproject.toml" ]; then
        ${pkgs.uv}/bin/uv tool install --editable "$STACKMAN_TOOL"
      fi

      for tool_dir in "$TOOLBOX"/*/; do
        if [ "$tool_dir" = "$STACKMAN_TOOL/" ]; then
          continue
        fi
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
