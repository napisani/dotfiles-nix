#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
mise="${MISE_COMMAND:-mise}"
scratch="$(mktemp -d)"
trap 'rm -rf "$scratch"' EXIT

export HOME="$scratch/home"
export MISE_CONFIG_DIR="$HOME/.config/mise"
export MISE_SYSTEM_CONFIG_DIR="$scratch/system"
export MISE_DATA_DIR="$scratch/data"
export MISE_STATE_DIR="$scratch/state"
export MISE_CACHE_DIR="$scratch/cache"
export MISE_YES=1
unset MISE_GLOBAL_CONFIG_FILE MISE_CONFIG_FILE MISE_NO_CONFIG
mkdir -p "$MISE_CONFIG_DIR"
test -f "$root/mods/dotfiles/mise/mise.lock"
ln -s "$root/mods/dotfiles/mise/config.toml" "$MISE_CONFIG_DIR/config.toml"
ln -s "$root/mods/dotfiles/mise/mise.lock" "$MISE_CONFIG_DIR/mise.lock"
# Host files include roles through this link, as on a bootstrapped host.
ln -s "$root/mods/dotfiles" "$MISE_CONFIG_DIR/dotfiles"
cd "$HOME"

for host in nicks-mbp nicks-loancrate-mbp maclab supermicro; do
  test -f "$root/homes/$host/mise.local.lock"
  ln -sf "$root/homes/$host/mise.toml" "$MISE_CONFIG_DIR/config.local.toml"
  ln -sf "$root/homes/$host/mise.local.lock" "$MISE_CONFIG_DIR/mise.local.lock"
  "$mise" lock --global --platform macos-arm64,macos-x64,linux-x64
  test -L "$MISE_CONFIG_DIR/mise.lock"
  test -L "$MISE_CONFIG_DIR/mise.local.lock"
done

# The project's own task toolchain.
"$mise" trust "$root/mise.toml"
"$mise" -C "$root" lock --platform macos-arm64,macos-x64,linux-x64
