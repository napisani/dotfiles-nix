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

  home.activation.installSqlit = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    # Install sqlit-tui with the postgres dependency
    ${pkgs.uv}/bin/uv tool install --with psycopg2-binary 'sqlit-tui[postgres]' --force

    for tool in ${builtins.concatStringsSep " " uvxTools}; do
      ${pkgs.uv}/bin/uv tool install $tool || true
    done

    # Create isolated venv for vocal.nvim (needs requests for OpenAI Whisper API)
    VOCAL_VENV="$HOME/.local/share/nvim/vocal-venv"
    if [ ! -d "$VOCAL_VENV" ]; then
      ${pkgs.uv}/bin/uv venv "$VOCAL_VENV"
    fi
    ${pkgs.uv}/bin/uv pip install --python "$VOCAL_VENV/bin/python" requests
  '';
}
