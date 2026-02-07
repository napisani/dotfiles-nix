{
  config,
  lib,
  pkgs-unstable,
  ...
}:

let
  # List npm packages to install globally into $HOME/.local.
  # Examples: [ "eslint" "@biomejs/biome" "typescript@5" ]
  npmxTools = [
    "@ellery/terminal-mcp@latest"
    "@napisani/scute@latest"
  ];

  npm = "${pkgs-unstable.nodejs}/bin/npm";
  nodeBin = "${pkgs-unstable.nodejs}/bin";
in
{
  home.packages = [
    pkgs-unstable.nodejs
  ];

  home.activation.installNpmxTools = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    export NPM_CONFIG_PREFIX="$HOME/.local"
    mkdir -p "$NPM_CONFIG_PREFIX/bin" "$NPM_CONFIG_PREFIX/lib"

    # Home Manager activation runs with a minimal PATH; ensure npm scripts can
    # find `node`.
    export PATH="${nodeBin}:$NPM_CONFIG_PREFIX/bin:$PATH"

    for tool in ${builtins.concatStringsSep " " npmxTools}; do
      ${npm} install -g --no-fund --no-audit "$tool" || true
    done

    # Some npm packages ship their bin entrypoints without the executable bit.
    # Ensure anything linked into ~/.local/bin is runnable.
    chmod -R u+rx "$NPM_CONFIG_PREFIX/bin" 2>/dev/null || true
  '';
}
