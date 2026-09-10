#!/usr/bin/env bash

# Render the Git state for the pane whose ID is supplied by tmux's status format.
pane_id="${1:-${TMUX_PANE:-}}"
if [ -z "$pane_id" ]; then
  printf ' —'
  exit 0
fi

repo_path="$(tmux display-message -p -t "$pane_id" '#{pane_current_path}' 2>/dev/null)" || {
  printf ' —'
  exit 0
}

branch="$(git -C "$repo_path" symbolic-ref --quiet --short HEAD 2>/dev/null || git -C "$repo_path" rev-parse --short HEAD 2>/dev/null)" || {
  printf ' —'
  exit 0
}

if [ -n "$(git -C "$repo_path" status --porcelain=v1 2>/dev/null)" ]; then
  printf ' ± %s' "$branch"
else
  printf ' ✓ %s' "$branch"
fi
