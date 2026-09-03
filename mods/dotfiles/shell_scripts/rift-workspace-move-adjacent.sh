#!/usr/bin/env bash
set -euo pipefail

rift_bin="/etc/profiles/per-user/nick/bin/rift-cli"
direction="${1:?usage: rift-workspace-move-adjacent.sh next|prev}"
workspace_data="$($rift_bin query workspaces)"
target="$(
  RIFT_DIRECTION="$direction" RIFT_WS_JSON="$workspace_data" /usr/bin/env python3 <<'PY'
import json
import os


direction = os.environ.get("RIFT_DIRECTION", "next")
workspace_json = os.environ.get("RIFT_WS_JSON", "[]")
data = json.loads(workspace_json)
if not data:
    raise SystemExit(1)

ordered = sorted(data, key=lambda ws: ws.get("index", 0))
active_idx = next((i for i, ws in enumerate(ordered) if ws.get("is_active")), 0)

if direction == "next":
    indices = list(range(active_idx + 1, len(ordered))) + list(range(0, active_idx))
else:
    indices = list(range(active_idx - 1, -1, -1)) + list(range(len(ordered) - 1, active_idx, -1))

target_idx = indices[0] if indices else active_idx
target = ordered[target_idx].get("index")
if target is not None:
    print(target, end="")
PY
)"

if [[ -n "$target" ]]; then
  "$rift_bin" execute workspace move-window "$target"
fi
