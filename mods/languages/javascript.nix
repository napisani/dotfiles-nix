{ pkgs, pkgs-unstable, ... }:

with pkgs-unstable;
[
  deno
  nodejs
  bun
  typescript
  typescript-language-server
  eslint_d
  prettier
  # pnpm is available as pkgs-unstable.pnpm if needed
  oxlint

  # vuejs
  # vls

  # html/css/js
  vscode-langservers-extracted

  tailwindcss-language-server

  # json
  fixjson
  jq

  # yaml
  yq
]
