{ pkgs, pkgs-unstable, ... }:

with pkgs; [
  pkgs-unstable.deno
  pkgs-unstable.nodejs_20
  nodePackages_latest.typescript
  nodePackages.typescript-language-server
  nodePackages_latest.eslint_d
  nodePackages.prettier
  nodePackages_latest.pnpm
  pkgs-unstable.oxlint

  # vuejs
  nodePackages.vls
  # html/css/js
  nodePackages.vscode-langservers-extracted

  nodePackages."@tailwindcss/language-server"

  # json
  nodePackages.fixjson
  jq

  # yaml 
  yq
]
