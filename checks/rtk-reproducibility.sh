#!/usr/bin/env bash
# Opt-in upgrade gate: rebuild the actual adapter-generated RTK derivations,
# not just the cached runtime check. Requires nix and jq; never activates HOME.
set -euo pipefail
if [ "$#" -ne 1 ]; then
  echo "usage: $0 {darwinConfigurations|nixosConfigurations}.HOST" >&2
  exit 2
fi
cd "$(dirname "$0")/.."
drv_json=$(mktemp)
trap 'rm -f "$drv_json" "$drv_json.list"' EXIT
nix eval --json ".#$1.config.home-manager.users.nick.home.file" --apply '
  files: let
    paths = builtins.filter (path: builtins.hasAttr path files) [
      ".claude/RTK.md" ".codex/RTK.md"
      ".pi/agent/extensions/rtk.ts" ".config/opencode/plugins/rtk.ts"
    ];
  in assert paths != [];
    builtins.concatLists (map (path: builtins.attrNames (builtins.getContext (toString files.${path}.source))) paths)
' > "$drv_json"
# Validate before the loop: process-substitution failures must not look like a
# successful audit with no builds (for example when jq is missing).
jq -er 'unique | if length > 0 and all(.[]; endswith(".drv")) then .[] else error("no RTK derivations") end' "$drv_json" > "$drv_json.list"
while IFS= read -r drv; do
  echo "Checking reproducibility: $drv"
  nix build --no-link "$drv^*"
  # --rebuild compares new outputs with the already-built store outputs.
  nix build --no-link --rebuild "$drv^*"
done < "$drv_json.list"
