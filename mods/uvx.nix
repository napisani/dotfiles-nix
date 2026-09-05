{
  config,
  lib,
  pkgs,
  ...
}:
let
  nativeScripts = import ./native-scripts.nix { inherit lib; };
  uvxTools = {
    sqlit-tui = {
      package = "sqlit-tui[postgres]";
      extras = [ "postgres" ];
      "with" = [ "psycopg2-binary" ];
    };
  };
in
{
  home.packages = [
    pkgs.uv
    pkgs.libpq
  ];

  home.activation.installUvTools = lib.hm.dag.entryAfter [ "writeBoundary" "linkGeneration" ] ''
    DECLARED_TOOLS=${lib.escapeShellArg (builtins.toJSON uvxTools)} \
    TOOLBOX=${lib.escapeShellArg "${config.home.homeDirectory}/toolbox"} \
    VOCAL_VENV=${lib.escapeShellArg "${config.home.homeDirectory}/.local/share/nvim/vocal-venv"} \
    STATE_FILE=${lib.escapeShellArg "${config.home.homeDirectory}/.local/state/agents-nix/uvx-tools.json"} \
    UV_COMMAND=${pkgs.uv}/bin/uv \
    PYTHON_COMMAND=${pkgs.python3}/bin/python3 \
    FORCE_REPAIR="''${AGENTS_FORCE_REPAIR:-}" \
      ${pkgs.nodejs}/bin/node ${nativeScripts}/agents/scripts/apply-uv-tools.js \
      || { echo "uvx: reconciliation failed; inspect the per-tool reason above" >&2; }
  '';
}
