# Out-of-band updaters — things Nix does not own.
#
# Nix already owns everything declared in this flake; `nixupgrade` (55) covers
# that half. What's left are the tools that manage their own versions inside a
# nix-managed home: lazy.nvim's plugin clones, Homebrew on the Darwin hosts, and
# pi's npm-installed extensions. `pi.nix` declares *which* extensions exist, not
# which versions, so bumping them is a runtime operation.
#
# Each updater no-ops with a message rather than failing when its tool is absent
# — that's what lets `update-all` run unchanged on both the Darwin laptops and
# the NixOS host.

# pet: Update all Neovim plugins from the command line
update-nvim() {
	if ! sh_have nvim; then
		echo "update-nvim: nvim is not installed — skipping" >&2
		return 0
	fi
	# lazy.nvim's headless entry point. `Lazy! sync` is the non-interactive
	# form (no confirmation prompt); it installs, updates, and cleans in one
	# pass, then rewrites nvim/lazy-lock.json in this checkout.
	echo "==> Updating Neovim plugins (lazy.nvim sync)"
	nvim --headless "+Lazy! sync" +qa
}

# pet: Update all system packages (Homebrew on macOS, no-op under Nix-managed systems)
update-packages() {
	if sh_have brew; then
		echo "==> Updating Homebrew packages"
		brew update && brew upgrade && brew cleanup
		return
	fi
	# On NixOS the system closure is declarative: package updates come from
	# `nixupgrade` (flake inputs + rebuild), never from a package manager
	# reaching out on its own. Nothing to do here by design.
	if sh_have nixos-rebuild || [ -e /etc/NIXOS ]; then
		echo "==> Nix-managed system: packages come from nixupgrade — nothing to do"
		return 0
	fi
	echo "update-packages: no supported package manager found — skipping" >&2
	return 0
}

# pet: Update all installed pi extensions
update-pi() {
	if ! sh_have pi; then
		echo "update-pi: pi is not installed — skipping" >&2
		return 0
	fi
	echo "==> Updating pi extensions"
	pi update --extensions
}

# pet: Run every out-of-band updater (neovim plugins, system packages, pi extensions)
update-all() {
	local step failed=()
	for step in update-packages update-nvim update-pi; do
		# Deliberately keep going after a failure: a broken Homebrew tap
		# shouldn't stop the nvim plugins from updating. Failures are
		# collected and reported together at the end.
		"$step" || failed+=("$step")
	done

	if [ ${#failed[@]} -gt 0 ]; then
		printf '==> update-all: %s failed\n' "${failed[*]}" >&2
		return 1
	fi
	echo "==> update-all: done"
}
