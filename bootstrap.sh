#!/bin/sh
set -eu

usage() {
	printf 'Usage: %s [MACHINE] [--only PHASES]\n' "$0" >&2
	exit 2
}

root=$(CDPATH='' cd -- "$(dirname -- "$0")" && pwd -P)
if [ "$#" -gt 0 ] && [ "$1" != --only ]; then
	machine=$1
	shift
else
	# shellcheck source=mods/dotfiles/shell/bash/lib/machine.sh
	. "$root/mods/dotfiles/shell/bash/lib/machine.sh"
	machine=$(sh_machine_name)
fi
case "$machine" in
'' | .* | */*)
	printf 'Unknown machine: %s\n' "$machine" >&2
	exit 2
	;;
esac
if [ ! -f "$root/homes/$machine/mise.toml" ]; then
	printf 'Unknown machine: %s (no homes/%s/mise.toml)\n' "$machine" "$machine" >&2
	exit 2
fi
scope=dotfiles,tools,packages
if [ "$#" -gt 0 ]; then
	[ "$#" -eq 2 ] && [ "$1" = --only ] || usage
	scope=$2
fi
config="$HOME/.config/mise"
mise="$HOME/.local/bin/mise"
data_home="${XDG_DATA_HOME:-$HOME/.local/share}"
data="${MISE_DATA_DIR:-$data_home/mise}"
plugins="$data/plugins"
skills="$HOME/.local/share/dotfiles/skills"

source_for() {
	case "$1" in
	config.toml | mise.lock) printf '%s/mods/dotfiles/mise/%s\n' "$root" "$1" ;;
	config.local.toml) printf '%s/homes/%s/mise.toml\n' "$root" "$machine" ;;
	mise.local.lock) printf '%s/homes/%s/mise.local.lock\n' "$root" "$machine" ;;
	dotfiles) printf '%s/mods/dotfiles\n' "$root" ;;
	esac
}

check_link() {
	if [ ! -e "$1" ]; then
		printf 'Missing bootstrap source: %s\n' "$1" >&2
		exit 1
	fi
	if [ -L "$2" ] && [ "$(readlink "$2")" = "$1" ]; then
		return
	fi
	if [ -e "$2" ] || [ -L "$2" ]; then
		printf 'Review or migrate the existing bootstrap target: %s\n' "$2" >&2
		exit 1
	fi
}

# Refuse redirected ancestors before installing or creating any links.
for parent in "$HOME/.config" "$config" "$HOME/.local" "$HOME/.local/bin" "$data_home" "$data" "$plugins" "$HOME/.local/share" "$HOME/.local/share/dotfiles" "$skills" "$skills/links"; do
	if [ -L "$parent" ] || { [ -e "$parent" ] && [ ! -d "$parent" ]; }; then
		printf 'Review the existing bootstrap parent: %s\n' "$parent" >&2
		exit 1
	fi
done
if [ -e "$config/conf.d/nix.toml" ] || [ -L "$config/conf.d/nix.toml" ]; then
	printf 'Review and migrate the retired Nix fragment: %s\n' "$config/conf.d/nix.toml" >&2
	exit 1
fi
for name in config.toml config.local.toml dotfiles mise.lock mise.local.lock; do
	check_link "$(source_for "$name")" "$config/$name"
done
for name in claude pi; do
	check_link "$root/mods/dotfiles/mise/runtime/mise/plugins/$name" "$plugins/$name"
done

if [ -L "$mise" ] || { [ -e "$mise" ] && { [ ! -f "$mise" ] || [ ! -x "$mise" ]; }; }; then
	printf 'Review the existing mise installer target: %s\n' "$mise" >&2
	exit 1
fi
if [ ! -x "$mise" ]; then
	installer=$(mktemp)
	trap 'rm -f "$installer"' EXIT
	trap 'exit 1' HUP INT TERM
	curl -fsSL https://mise.jdx.dev/install.sh -o "$installer"
	MISE_INSTALL_PATH="$mise" sh "$installer"
fi
"$mise" --version
PATH="$HOME/.local/bin:$PATH"
export PATH

# Dotfiles precede tool installation, so first-run skills need an empty view.
mkdir -p "$config" "$skills/links"
for name in config.toml config.local.toml dotfiles mise.lock mise.local.lock; do
	target="$config/$name"
	[ -L "$target" ] || ln -s "$(source_for "$name")" "$target"
done

for name in claude pi; do
	if [ ! -L "$plugins/$name" ]; then
		"$mise" -C "$HOME" plugins link "$name" "$root/mods/dotfiles/mise/runtime/mise/plugins/$name"
	fi
done

# GUI packages require the migration's separate reviewed ownership transfer.
MISE_SYSTEM_PACKAGES_MANAGERS=claude,pi "$mise" -C "$HOME" bootstrap --only "$scope"
