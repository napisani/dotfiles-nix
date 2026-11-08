# shellcheck shell=bash
# Overrides direnv's stdlib use_flake so a dev shell that fails to evaluate
# fails the .envrc instead of loading an empty environment.
use_flake() {
	watch_file flake.nix
	watch_file flake.lock
	local environment
	mkdir -p "$(direnv_layout_dir)" || return
	environment=$(nix print-dev-env --profile "$(direnv_layout_dir)/flake-profile") || return
	eval "$environment"
}
