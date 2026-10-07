# These names must resolve to functions even when the fragment is re-sourced.
unalias nixswitch nixswitchup nixclean 2>/dev/null || true

# pet: Rebuild and activate the current Nix configuration
nixswitch() (
	cd -- "${DOTFILES_HOME_MANAGER_DIR:-$HOME/code/monorepo/pub/dotfiles-nix}" || return
	if sh_have darwin-rebuild; then
		sudo darwin-rebuild switch --show-trace --no-update-lock-file --flake .# "$@"
	elif sh_have nixos-rebuild; then
		sudo nixos-rebuild --show-trace --no-update-lock-file --flake ".#$(hostname -s)" switch --impure "$@"
	else
		echo "nixswitch: neither darwin-rebuild nor nixos-rebuild is installed" >&2
		return 127
	fi
)

# pet: Pull configuration changes and activate Nix
nixswitchup() (
	cd -- "${DOTFILES_HOME_MANAGER_DIR:-$HOME/code/monorepo/pub/dotfiles-nix}" || return
	git pull && nixswitch "$@"
)

# pet: Delete old Nix generations and optimize the store
nixclean() {
	echo 'Collecting garbage...'
	nix-collect-garbage -d || return
	echo 'Optimizing store...'
	nix store optimise || return
	echo 'Cleaning up old profiles...'
	sudo nix-collect-garbage -d || return
	echo 'Done! Space freed.'
}
