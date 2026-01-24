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
  '';
}
