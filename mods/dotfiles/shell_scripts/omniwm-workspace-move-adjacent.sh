#!/usr/bin/env bash
set -euo pipefail

omniwmctl="/etc/profiles/per-user/nick/bin/omniwmctl"
direction="${1:?usage: omniwm-workspace-move-adjacent.sh next|prev}"
workspace_data="$($omniwmctl query workspaces --format json --fields number,is-current)"
target="$({
  OMNIWM_DIRECTION="$direction" OMNIWM_WS_JSON="$workspace_data" /usr/bin/env python3 <<'PY'
import json
import os


direction = os.environ["OMNIWM_DIRECTION"]
data = json.loads(os.environ["OMNIWM_WS_JSON"])
workspaces = data.get("workspaces", data) if isinstance(data, dict) else data
ordered = sorted(
    (workspace for workspace in workspaces if workspace.get("number") is not None),
    key=lambda workspace: workspace["number"],
)
if not ordered:
    raise SystemExit(1)

active_index = next(
    (index for index, workspace in enumerate(ordered) if workspace.get("isCurrent")),
    0,
)
if direction == "next":
    target_index = (active_index + 1) % len(ordered)
elif direction == "prev":
    target_index = (active_index - 1) % len(ordered)
else:
    raise SystemExit(f"unknown direction: {direction}")

print(ordered[target_index]["number"], end="")
PY
})"

if [[ -n "$target" ]]; then
  "$omniwmctl" command move-to-workspace "$target"
fi
